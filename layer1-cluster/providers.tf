terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    # Only exercised when cluster_mode = "aws-ec2"; harmless in k3d mode since
    # all AWS resources/data sources are count-gated to zero.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "central-infra"
      ManagedBy = "terraform"
      Layer     = "1-cluster"
    }
  }
}
