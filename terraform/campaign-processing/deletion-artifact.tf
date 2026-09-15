variable "deletion_bridge_artifact" {
  description = "Optional immutable deletion-bridge patch, allowing shared-ledger compatibility without replacing other campaign workers."
  type        = object({ release_id = string, object_version = string, source_hash = string })
  default     = null
  validation {
    condition = var.deletion_bridge_artifact == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.deletion_bridge_artifact.release_id)) &&
      length(trimspace(var.deletion_bridge_artifact.object_version)) > 0 && var.deletion_bridge_artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.deletion_bridge_artifact.source_hash)), false
    )
    error_message = "A deletion-bridge override needs an immutable release, S3 object version and base64 SHA-256."
  }
}
