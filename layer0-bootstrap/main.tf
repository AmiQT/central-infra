data "aws_caller_identity" "current" {}

locals {
  state_bucket = "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------------------
# Remote Terraform state: S3 (storage) + DynamoDB (locking)
# Closes the "local state has no locking/durability" gap.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket

  # Guard against accidental `terraform destroy` wiping every layer's state.
  lifecycle {
    prevent_destroy = true
  }
}

# Keep a version history of state so a corrupt or bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# State files contain secrets (Grafana password, SA tokens) — encrypt at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State must never be public.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Distributed lock so two concurrent `terraform apply` runs can't corrupt state.
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # no idle cost — pay only per lock operation
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ---------------------------------------------------------------------------
# ECR: private registry for the talent-api image (replaces the local k3d registry)
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "talent_api" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE" # git-SHA tags can never be overwritten

  image_scanning_configuration {
    scan_on_push = true # CVE scan every pushed image — pairs with Trivy in CI
  }
}

# Expire untagged/old images so the registry doesn't grow unbounded.
resource "aws_ecr_lifecycle_policy" "talent_api" {
  repository = aws_ecr_repository.talent_api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC: short-lived, keyless CI auth (no static AWS access keys)
# ---------------------------------------------------------------------------

# Fetch GitHub's OIDC TLS thumbprint dynamically instead of hardcoding it.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# Trust policy: only workflows in THIS repo may assume the role.
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope to the specific repository — any branch/tag/PR within it.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "central-infra-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# Least-privilege: CI may push/pull images to the talent-api ECR repo only.
data "aws_iam_policy_document" "ci_ecr" {
  # Auth token is account-wide and required before any push.
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.talent_api.arn]
  }
}

resource "aws_iam_role_policy" "ci_ecr" {
  name   = "ecr-push-pull"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ci_ecr.json
}

# Let CI deploy by telling the k3s node (via SSM Run Command) to roll the new
# image — no kubeconfig in CI, no exposed kube API.
data "aws_iam_policy_document" "ci_deploy" {
  statement {
    sid       = "DiscoverInstance"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  # SendCommand authorizes both the document and the target instances.
  statement {
    sid       = "SendCommandDocument"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:*::document/AWS-RunShellScript"]
  }

  statement {
    sid       = "SendCommandInstances"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = ["central-infra"]
    }
  }

  statement {
    sid       = "ReadCommandResult"
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci_deploy" {
  name   = "deploy-via-ssm"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ci_deploy.json
}
