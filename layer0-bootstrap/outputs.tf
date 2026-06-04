output "state_bucket_name" {
  description = "S3 bucket name to use in every other layer's backend block"
  value       = aws_s3_bucket.tf_state.id
}

output "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.tf_locks.name
}

output "ecr_repository_url" {
  description = "ECR repository URL to tag/push the talent-api image against"
  value       = aws_ecr_repository.talent_api.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC (set as a repo variable / used in aws-actions/configure-aws-credentials)"
  value       = aws_iam_role.github_actions.arn
}
