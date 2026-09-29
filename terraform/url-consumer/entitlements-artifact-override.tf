# Permit one reviewed entitlement-reader correction without republishing unrelated workers.
variable "entitlements_artifact_override" {
  description = "Optional Dev entitlement-reader correction with exact baseline, immutable artifact and review reference. Does not activate any runtime."
  type = object({
    source_sha              = string
    baseline_source_sha     = string
    baseline_source_hash    = string
    baseline_object_version = string
    provenance_reference    = string
    artifact = object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    })
  })
  default = null
  validation {
    condition = var.entitlements_artifact_override == null ? true : try(
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar" &&
      can(regex("^[a-f0-9]{40}$", var.entitlements_artifact_override.baseline_source_sha)) &&
      var.deployment.artifacts.entitlements.key == "releases/${var.entitlements_artifact_override.baseline_source_sha}/v1_entitlements.zip" &&
      var.entitlements_artifact_override.baseline_source_hash == var.deployment.artifacts.entitlements.source_hash &&
      var.entitlements_artifact_override.baseline_object_version == var.deployment.artifacts.entitlements.object_version &&
      can(regex("^[a-f0-9]{40}$", var.entitlements_artifact_override.source_sha)) &&
      var.entitlements_artifact_override.source_sha != var.entitlements_artifact_override.baseline_source_sha &&
      var.entitlements_artifact_override.artifact.bucket == var.deployment.artifacts.entitlements.bucket &&
      var.entitlements_artifact_override.artifact.key == "releases/${var.entitlements_artifact_override.source_sha}/v1_entitlements.zip" &&
      length(trimspace(var.entitlements_artifact_override.artifact.object_version)) > 0 &&
      var.entitlements_artifact_override.artifact.object_version == trimspace(var.entitlements_artifact_override.artifact.object_version) &&
      var.entitlements_artifact_override.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.entitlements_artifact_override.artifact.source_hash)) &&
      var.entitlements_artifact_override.artifact.source_hash != var.entitlements_artifact_override.baseline_source_hash &&
      can(regex("^docs/evidence/[A-Za-z0-9_./-]+[.]json$", var.entitlements_artifact_override.provenance_reference)) &&
    !contains(split("/", var.entitlements_artifact_override.provenance_reference), ".."), false)
    error_message = "Entitlement-reader correction requires enabled Dev, an exact baseline source/hash/version, a different immutable entitlement package in the same bucket and a review reference."
  }
}
