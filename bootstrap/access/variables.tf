variable "aws_region" {
  description = "AWS region used by the infrastructure pipeline"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket used for Terraform remote state"
  type        = string
}

variable "state_key_prefix" {
  description = "Root key prefix used for Terraform state objects"
  type        = string
  default     = "trustcheckradar"
}

variable "project_name" {
  description = "Resource prefix managed by the deployment roles"
  type        = string
  default     = "trustcheckradar"
}

variable "github_organization" {
  description = "GitHub organization that owns the infrastructure repository"
  type        = string
  default     = "theagentamt"
}

variable "github_repository" {
  description = "GitHub repository trusted by AWS OIDC"
  type        = string
  default     = "AMT.TrustCheckRadar.Cloud.Infrastructure"
}

variable "environments" {
  description = "GitHub environments allowed to deploy infrastructure"
  type        = set(string)
  default     = ["dev", "staging", "prod"]
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN; when null, this stack creates one"
  type        = string
  default     = null
}

variable "github_oidc_thumbprints" {
  description = "SHA-1 thumbprints accepted by the GitHub Actions OIDC provider"
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "tags" {
  description = "Tags applied to bootstrap resources"
  type        = map(string)
  default     = {}
}
