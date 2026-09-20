terraform {
  required_version = "= 1.12.1"
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.20.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
