# Permit one reviewed consumer correction without republishing unrelated workers.
variable "consumer_artifact_override" {
  description = "Optional Dev URL-consumer correction with exact baseline, immutable artifact and review reference. Does not activate any runtime."
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
    condition = var.consumer_artifact_override == null ? true : try(
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar" &&
      can(regex("^[a-f0-9]{40}$", var.consumer_artifact_override.baseline_source_sha)) &&
      var.deployment.artifacts.consumer.key == "releases/${var.consumer_artifact_override.baseline_source_sha}/url_consumer.zip" &&
      var.consumer_artifact_override.baseline_source_hash == var.deployment.artifacts.consumer.source_hash &&
      var.consumer_artifact_override.baseline_object_version == var.deployment.artifacts.consumer.object_version &&
      can(regex("^[a-f0-9]{40}$", var.consumer_artifact_override.source_sha)) &&
      var.consumer_artifact_override.source_sha != var.consumer_artifact_override.baseline_source_sha &&
      var.consumer_artifact_override.artifact.bucket == var.deployment.artifacts.consumer.bucket &&
      var.consumer_artifact_override.artifact.key == "releases/${var.consumer_artifact_override.source_sha}/url_consumer.zip" &&
      length(trimspace(var.consumer_artifact_override.artifact.object_version)) > 0 &&
      var.consumer_artifact_override.artifact.object_version == trimspace(var.consumer_artifact_override.artifact.object_version) &&
      var.consumer_artifact_override.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.consumer_artifact_override.artifact.source_hash)) &&
      var.consumer_artifact_override.artifact.source_hash != var.consumer_artifact_override.baseline_source_hash &&
      can(regex("^docs/evidence/[A-Za-z0-9_./-]+[.]json$", var.consumer_artifact_override.provenance_reference)) &&
    !contains(split("/", var.consumer_artifact_override.provenance_reference), ".."), false)
    error_message = "Consumer correction requires enabled Dev, an exact baseline source/hash/version, a different immutable consumer package in the same bucket and a review reference."
  }
}
