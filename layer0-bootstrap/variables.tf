variable "aws_region" {
  description = "AWS region for all foundation resources"
  type        = string
  default     = "ap-southeast-1" # Singapore — closest low-latency region to Malaysia
}

variable "state_bucket_prefix" {
  description = "Prefix for the S3 bucket holding Terraform remote state. The AWS account ID is appended for global uniqueness."
  type        = string
  default     = "central-infra-tfstate"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "central-infra-tf-locks"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository for the talent-api application image"
  type        = string
  default     = "central-infra/talent-api"
}

variable "github_repository" {
  description = "The GitHub org/repo allowed to assume the CI role via OIDC (no static keys)"
  type        = string
  default     = "AmiQT/central-infra"
}
