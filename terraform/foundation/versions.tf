terraform {
  required_version = "= 1.12.1"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = var.governed_history_index_enabled ? ["107827791950"] : null
}
