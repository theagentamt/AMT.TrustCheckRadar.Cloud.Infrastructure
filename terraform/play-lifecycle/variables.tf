variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type = string
}
variable "project_name" {
  type    = string
  default = "trustcheckradar"
}
variable "enabled" {
  description = "Provision Dev lifecycle foundation; never activates a runtime."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar")
    error_message = "Only the reviewed Dev account/region/project is supported."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "backup_role_names" {
  description = "All actual AWS Backup execution roles identified by the account-wide selection audit; receive an exact-table backup deny."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for role in var.backup_role_names : can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", role))])
    error_message = "Supply verified IAM role names, not ARNs or wildcards."
  }
}
