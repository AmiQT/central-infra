terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Bootstrap layer keeps LOCAL state on purpose: it creates the very S3 bucket
  # and DynamoDB table that every other layer will use as a remote backend.
  # You cannot store this layer's state in a bucket that doesn't exist yet.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "central-infra"
      ManagedBy = "terraform"
      Layer     = "0-bootstrap"
    }
  }
}
