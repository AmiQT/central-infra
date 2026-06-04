locals {
  is_k3d = var.cluster_mode == "k3d"
  is_aws = var.cluster_mode == "aws-ec2"
}

# ===========================================================================
# MODE: k3d (local) — original behaviour, gated by count
# ===========================================================================
resource "null_resource" "k3d_cluster" {
  count = local.is_k3d ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
  }

  # Provisioning logic lives in versioned, shellcheck-clean bash scripts under
  # ./scripts/ — declarative HCL, testable shell.
  provisioner "local-exec" {
    command     = "chmod +x ${path.module}/scripts/create-cluster.sh && ${path.module}/scripts/create-cluster.sh ${self.triggers.cluster_name} ${var.api_port} ${var.servers_count} ${var.agents_count} ${var.host_ingress_port} ${var.registry_name} ${var.registry_port}"
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "chmod +x ${path.module}/scripts/destroy-cluster.sh && ${path.module}/scripts/destroy-cluster.sh ${self.triggers.cluster_name}"
    interpreter = ["bash", "-c"]
  }
}

# ===========================================================================
# MODE: aws-ec2 — single-node k3s on EC2, gated by count
# ===========================================================================

# Ubuntu 22.04 LTS AMI (kept current via Canonical's public SSM parameter).
data "aws_ssm_parameter" "ubuntu" {
  count = local.is_aws ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Use the account's default VPC/subnet — no NAT gateway cost for a sandbox.
data "aws_vpc" "default" {
  count   = local.is_aws ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = local.is_aws ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# Account ID is needed to build the ECR registry hostname for the node's pull auth.
data "aws_caller_identity" "current" {
  count = local.is_aws ? 1 : 0
}

# Stable public address so the API cert + kubeconfig survive restarts.
resource "aws_eip" "k3s" {
  count  = local.is_aws ? 1 : 0
  domain = "vpc"
}

# Only port 80 (the app) is open to the world. The kube API (6443) is limited
# to the admin CIDR. No port 22 — all access is via SSM Session Manager.
resource "aws_security_group" "k3s" {
  count       = local.is_aws ? 1 : 0
  name        = "central-infra-k3s"
  description = "k3s node: app on 80 (world), API on 6443 (admin only), no SSH"
  vpc_id      = data.aws_vpc.default[0].id

  ingress {
    description = "App traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API for host-driven layers 2-4"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instance role: SSM access (keyless admin) + ECR pull + write kubeconfig to SSM.
data "aws_iam_policy_document" "assume_ec2" {
  count = local.is_aws ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s" {
  count              = local.is_aws ? 1 : 0
  name               = "central-infra-k3s-node"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2[0].json
}

# Managed policy grants Session Manager + the SSM agent's needs (no SSH keys).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = local.is_aws ? 1 : 0
  role       = aws_iam_role.k3s[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Pull images from the private ECR repo created in layer0.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  count      = local.is_aws ? 1 : 0
  role       = aws_iam_role.k3s[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allow the node to publish its own kubeconfig into SSM Parameter Store.
data "aws_iam_policy_document" "put_kubeconfig" {
  count = local.is_aws ? 1 : 0
  statement {
    actions   = ["ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}:*:parameter/central-infra/kubeconfig"]
  }
}

resource "aws_iam_role_policy" "put_kubeconfig" {
  count  = local.is_aws ? 1 : 0
  name   = "put-kubeconfig"
  role   = aws_iam_role.k3s[0].id
  policy = data.aws_iam_policy_document.put_kubeconfig[0].json
}

resource "aws_iam_instance_profile" "k3s" {
  count = local.is_aws ? 1 : 0
  name  = "central-infra-k3s"
  role  = aws_iam_role.k3s[0].name
}

resource "aws_instance" "k3s" {
  count                  = local.is_aws ? 1 : 0
  ami                    = data.aws_ssm_parameter.ubuntu[0].value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default[0].ids[0]
  vpc_security_group_ids = [aws_security_group.k3s[0].id]
  iam_instance_profile   = aws_iam_instance_profile.k3s[0].name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    aws_region   = var.aws_region
    eip          = aws_eip.k3s[0].public_ip
    ecr_registry = "${data.aws_caller_identity.current[0].account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  })

  # Re-provision the node when the bootstrap script changes (e.g. ECR auth update).
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "central-infra-k3s" }
}

resource "aws_eip_association" "k3s" {
  count         = local.is_aws ? 1 : 0
  instance_id   = aws_instance.k3s[0].id
  allocation_id = aws_eip.k3s[0].id
}

# Give cloud-init time to install k3s and publish the kubeconfig to SSM (~2-4 min).
# Because this depends_on a not-yet-created resource, Terraform defers the SSM
# read below to apply time.
resource "time_sleep" "wait_k3s" {
  count           = local.is_aws ? 1 : 0
  depends_on      = [aws_eip_association.k3s]
  create_duration = "240s"
}

# Read the kubeconfig natively through the AWS provider — no host AWS CLI needed.
# (If the instance is slow and the parameter isn't ready yet, just re-run apply;
# the read is idempotent and the wait will already be satisfied.)
data "aws_ssm_parameter" "kubeconfig" {
  count      = local.is_aws ? 1 : 0
  depends_on = [time_sleep.wait_k3s]
  name       = "/central-infra/kubeconfig"
}

# Write it locally so layers 2-4 consume it transparently — exactly like k3d mode.
# Terraform manages the file, so it's removed automatically on destroy.
resource "local_file" "kubeconfig_aws" {
  count           = local.is_aws ? 1 : 0
  content         = data.aws_ssm_parameter.kubeconfig[0].value
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"
}

# ===========================================================================
# Shared: expose the generated kubeconfig (written by whichever mode ran)
# ===========================================================================
data "local_file" "kubeconfig" {
  depends_on = [null_resource.k3d_cluster, local_file.kubeconfig_aws]
  filename   = "${path.module}/kubeconfig.yaml"
}
