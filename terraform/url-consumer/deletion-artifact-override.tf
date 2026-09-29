# Separate reviewed correction provenance preserves unrelated baseline packages.
variable "deletion_artifact_override" {
  description = "Optional Dev deletion-only correction: exact baseline hash, reviewed patch source, immutable artifact and provenance. Does not activate cleanup."
  type = object({
    source_sha           = string
    baseline_source_hash = string
    baseline_source_sha  = string
    provenance_reference = string
    artifact = object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    })
  })
  default = null
  validation {
    condition = var.deletion_artifact_override == null ? true : try(
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar" &&
      can(regex("^[a-f0-9]{40}$", var.deletion_artifact_override.baseline_source_sha)) &&
      var.deployment.artifacts.deletion.key == "releases/${var.deletion_artifact_override.baseline_source_sha}/v1_authority_deletion.zip" &&
      var.deletion_artifact_override.baseline_source_hash == var.deployment.artifacts.deletion.source_hash &&
      can(regex("^[a-f0-9]{40}$", var.deletion_artifact_override.source_sha)) &&
      var.deletion_artifact_override.artifact.bucket == var.deployment.artifacts.deletion.bucket &&
      var.deletion_artifact_override.artifact.key == "releases/${var.deletion_artifact_override.source_sha}/v1_authority_deletion.zip" &&
      length(trimspace(var.deletion_artifact_override.artifact.object_version)) > 0 && var.deletion_artifact_override.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.deletion_artifact_override.artifact.source_hash)) &&
      var.deletion_artifact_override.artifact.source_hash != var.deletion_artifact_override.baseline_source_hash &&
    can(regex("^docs/evidence/[A-Za-z0-9_./-]+[.]json$", var.deletion_artifact_override.provenance_reference)), false)
    error_message = "A deletion-only correction requires enabled Dev, exact baseline hash, immutable matching patch artifact and reviewed package provenance; unrelated packages remain pinned."
  }
}
locals {
  runtime_artifacts = var.deployment == null ? {} : merge(var.deployment.artifacts,
    var.deletion_artifact_override == null ? {} : { deletion = var.deletion_artifact_override.artifact },
    var.consumer_artifact_override == null ? {} : { consumer = var.consumer_artifact_override.artifact },
  var.entitlements_artifact_override == null ? {} : { entitlements = var.entitlements_artifact_override.artifact })
}
