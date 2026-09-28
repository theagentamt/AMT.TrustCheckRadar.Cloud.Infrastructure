terraform {
  required_version = "= 1.12.1"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.20, < 7.0" }
  }
}
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["107827791950"]
}
