variable "account_deletion_terminal_activation" {
  description = "Reviewed Dev activation of terminal-safe History cleanup; null leaves preparation inactive. No retention override or proof is inferred."
  type = object({
    source_sha            = string
    runtime_reference     = string
    permissions_reference = string
  })
  default = null
  validation {
    condition = var.account_deletion_terminal_activation == null ? true : try(
      var.environment == "dev" && var.account_deletion_terminal_candidate &&
      var.lifecycle_active &&
      can(regex("^[0-9a-f]{40}$", var.account_deletion_terminal_activation.source_sha)) &&
      var.account_deletion_terminal_activation.source_sha == var.artifact.release_id &&
      var.account_deletion_terminal_activation.source_sha == var.account_deletion_artifact.release_id &&
      length(trimspace(var.account_deletion_terminal_activation.runtime_reference)) > 0 &&
      length(trimspace(var.account_deletion_terminal_activation.permissions_reference)) > 0,
      false
    )
    error_message = "Terminal-safe activation requires exact reviewed Dev source and runtime/permission evidence with both cleanup workers enabled."
  }
}
