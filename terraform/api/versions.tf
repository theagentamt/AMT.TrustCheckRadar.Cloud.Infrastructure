terraform {
  required_version = "= 1.12.1"

  backend "s3" {}

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Python 3.14 is first supported by the AWS provider in 6.20.
      version = ">= 6.20, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
