# This one reviewed Dev rollout uses CAS operations for code/publication/alias.
# Historical deployment.artifacts remain inert; their single-release guard stays
# intact. This profile is for refresh-only accounting and zero-change plans,
# never for an ordinary root apply or for writing environments.
variable "dev_ocr_preservation" {
  description = "Exact dc0fc7b OCR release accounting and existing staged configuration; no AI activation or environment-write authority."
  type = object({
    phase                  = string
    evaluator_live_version = string
    artifact = object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    })
    recorded_consumer_artifact = object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    })
    environments = object({
      consumer  = map(string)
      evaluator = map(string)
    })
  })
  sensitive = true
  default   = null
  validation {
    condition = var.dev_ocr_preservation == null ? true : try(
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar" &&
      var.activate_rules_engineering && var.candidate3_rules_only_enabled && var.governed_history_settlement_enabled &&
      !var.message_ai_primary_enabled && !var.url_assessment_enabled &&
      contains(["baseline", "staged", "live"], var.dev_ocr_preservation.phase) &&
      (var.dev_ocr_preservation.phase == "live" ? (
        can(regex("^[1-9][0-9]*$", var.dev_ocr_preservation.evaluator_live_version)) && tonumber(var.dev_ocr_preservation.evaluator_live_version) > 7
      ) : var.dev_ocr_preservation.evaluator_live_version == "7") &&
      var.dev_ocr_preservation.artifact == {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/dc0fc7b22b8201299bf6a448dfbb9a539b9055dd/message_evaluator.zip"
        object_version = "Qz3S9pWTSg0yef9ZaLqS6DDAy26VT7RZ"
        source_hash    = "72rKZjvnUBZgE8w0Lw++4vMox/QrfuekUruifEQoUeM="
      } &&
      var.dev_ocr_preservation.recorded_consumer_artifact == {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/ae17a53b783b74e0e70cc2b314cd86f0b29dcf7b/message_consumer.zip"
        object_version = "U9UzSSorYYU67oPYe.EC_ZpIC.1Q0rDE"
        source_hash    = "kgUck3tzaq0RSVSuWbS1OW2Q8hNZx6shc2BzEaDa1vU="
      } &&
      var.deployment.artifacts.consumer == {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/6d9ae503b7d4e36a16a4cfc6bee2c939b988c723/message_consumer.zip"
        object_version = "Exz6MG1Co_IrtzWPLvfF9hWXXD3EqCLO"
        source_hash    = "UbXMvj46spsxhd2P0rPATFWiqjGUbti4rv0fCALa2Xo="
      } &&
      var.deployment.artifacts.evaluator == {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/6d9ae503b7d4e36a16a4cfc6bee2c939b988c723/message_evaluator.zip"
        object_version = "XOot9peLSF7kirfnRUAyO2hRN2RX.Zj."
        source_hash    = "4t6hHXE5RybaI7o4qTFqcWZgK0TaOdnN1uAZ+nctBj0="
      } &&
      sha256(jsonencode(var.dev_ocr_preservation.environments.consumer)) == "9655f704305f7f15387c29f36aab8e641ac4fe27705d1a5d3a72ab916c4f4875" &&
      sha256(jsonencode(var.dev_ocr_preservation.environments.evaluator)) == "585748d38472e224ef2ec2380c757d864b9b23b000658d0f73164e5afbc8fb79" &&
      var.dev_ocr_preservation.environments.consumer.MESSAGE_AI_ENABLED == "false" &&
      var.dev_ocr_preservation.environments.consumer.MESSAGE_AI_PRIMARY_ENABLED == "false" &&
      var.dev_ocr_preservation.environments.consumer.MESSAGE_PROVIDER_CIRCUIT_OPEN == "true" &&
      var.dev_ocr_preservation.environments.evaluator.MESSAGE_AI_ENABLED == "false" &&
      var.dev_ocr_preservation.environments.evaluator.MESSAGE_AI_QUALIFIED == "false" &&
      var.dev_ocr_preservation.environments.evaluator.MESSAGE_AI_PRIMARY_ENABLED == "false" &&
      var.dev_ocr_preservation.environments.evaluator.MESSAGE_AI_DEV_EXCEPTION_ENABLED == "false" &&
    var.dev_ocr_preservation.environments.evaluator.MESSAGE_PROPOSER_ENABLED == "false", false)
    error_message = "Only the exact reviewed Dev OCR artifact, staged inactive environments and baseline/staged7 or verified live version are permitted."
  }
}

locals {
  ocr_preservation_enabled = try(nonsensitive(var.dev_ocr_preservation != null), var.dev_ocr_preservation != null)
  ocr_evaluator_code_hash  = !local.ocr_preservation_enabled ? null : (var.dev_ocr_preservation.phase == "baseline" ? "6vzJ0oDuNdQq3gja0Qeod5TOcRxALiPDWYuKnaXlx0o=" : "72rKZjvnUBZgE8w0Lw++4vMox/QrfuekUruifEQoUeM=")
}
