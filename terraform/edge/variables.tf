variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project/application prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "state_bucket_name" {
  description = "S3 bucket containing the API remote state"
  type        = string
}

variable "state_bucket_region" {
  description = "AWS region containing the Terraform state bucket"
  type        = string
}

variable "state_key_prefix" {
  description = "Root key prefix used for Terraform state objects"
  type        = string
  default     = "trustcheckradar"
}

variable "domain_name" {
  description = "Environment-specific API hostname"
  type        = string
}

variable "route53_zone_name" {
  description = "Route 53 public hosted zone containing the API hostname"
  type        = string
}

variable "api_mapping_key" {
  description = "Optional base path under the custom domain; null maps the API at the domain root"
  type        = string
  default     = null
  nullable    = true
}

variable "api_mapping_enabled" {
  description = "Whether to map the custom domain to the environment API"
  type        = bool
  default     = true
}
