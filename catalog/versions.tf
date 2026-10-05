terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial configuration: bucket, key and region come from backend.hcl
  # (see backend.hcl.example), so no account-specific value lives in the code.
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = var.project
      Layer     = "catalog"
      ManagedBy = "Terraform"
    }
  }
}
