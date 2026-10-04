# Retirement is permanent: generic releases and old History overrides cannot
# restore a dispatcher. A newly qualified archive needs a reviewed catalog edit.
variable "analysis_retirement_deployment" {
  description = "Independent immutable replay-only legacy artifact. Null uses the reviewed research-migration selection, or rejects planning when neither is selected."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.analysis_retirement_deployment == null ? true : (
      can(regex("^[0-9a-f]{40}$", var.analysis_retirement_deployment.release_id)) &&
      length(trimspace(var.analysis_retirement_deployment.object_version)) > 0 && var.analysis_retirement_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.analysis_retirement_deployment.source_hash)) &&
      length(trimspace(var.analysis_retirement_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.analysis_retirement_deployment.promotion_approved) &&
      (var.research_consent_migration_deployment == null ? true : try(
        var.analysis_retirement_deployment.release_id == var.research_consent_migration_deployment.release_id &&
        var.analysis_retirement_deployment.object_version == var.research_consent_migration_deployment.artifacts["analysis"].object_version &&
      var.analysis_retirement_deployment.source_hash == var.research_consent_migration_deployment.artifacts["analysis"].source_hash, false))
    )
    error_message = "Replay retirement requires exact immutable pins, review and UAT/Prod promotion approval; dual retirement sources must match exactly."
  }
}

locals {
  # Qualified by the historical retirement acceptance/publication record in
  # docs/evidence/dev-research-actions-publication.json, not a caller assertion.
  analysis_retirement_catalog = jsondecode(file("${path.module}/analysis-retirement-catalog.json"))
  analysis_retirement = var.analysis_retirement_deployment != null ? var.analysis_retirement_deployment : (
    var.research_consent_migration_deployment == null ? null : {
      release_id         = var.research_consent_migration_deployment.release_id
      object_version     = var.research_consent_migration_deployment.artifacts["analysis"].object_version
      source_hash        = var.research_consent_migration_deployment.artifacts["analysis"].source_hash
      approval_reference = var.research_consent_migration_deployment.approval_reference
      promotion_approved = var.research_consent_migration_deployment.promotion_approved
    }
  )
  analysis_retirement_selected         = local.analysis_retirement != null
  analysis_replay_history_content_name = var.history_deployment == null ? "${local.name_prefix}-history-content" : local.history_data.content_table_name
  analysis_replay_history_control_name = var.history_deployment == null ? "${local.name_prefix}-history-control" : local.history_data.control_table_name
  analysis_replay_reads = merge({
    profile  = { arn = local.users_table_arn, keys = ["USER#*"] }
    deletion = { arn = local.deletion_ledger_table_arn, keys = ["ACCOUNT#*"] }
    device   = { arn = local.device_bindings_table_arn, keys = ["USER#*"] }
    evidence = { arn = local.analysis_abuse_control_table_arn, keys = ["ANALYSIS#REQUEST#*", "ANALYSIS#CONSUMPTION#*"] }
    }, var.history_deployment == null ? {
    historycontent = { arn = "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.analysis_replay_history_content_name}", keys = ["USER#*"] }
    historycontrol = { arn = "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.analysis_replay_history_control_name}", keys = ["USER#*"] }
  } : {})
  analysis_replay_env = merge({
    APP_ENVIRONMENT                = var.environment
    COGNITO_ISSUER                 = local.jwt_issuer
    COGNITO_APP_CLIENT_ID          = local.cognito_app_client_id
    COGNITO_REQUIRED_SCOPE         = "aws.cognito.signin.user.admin"
    USERS_TABLE_NAME               = local.users_table_name
    DEVICE_BINDINGS_TABLE_NAME     = local.device_bindings_table_name
    ANALYSIS_ABUSE_TABLE_NAME      = local.analysis_abuse_control_table_name
    DELETION_LEDGER_TABLE_NAME     = local.deletion_ledger_table_name
    HISTORY_MAX_SUMMARY_BYTES      = "4096"
    HISTORY_MAX_LIST_ITEMS         = "20"
    HISTORY_MAX_TEXT_FIELD_BYTES   = "1024"
    HISTORY_MAX_RESPONSE_BYTES     = "262144"
    HISTORY_WRITES_ENABLED         = "false"
    HISTORY_DURABLE_REPLAY_ENABLED = "false"
    RECOGNITION_ENABLED            = "false"
    HISTORY_CONTENT_TABLE_NAME     = local.analysis_replay_history_content_name
    HISTORY_CONTROL_TABLE_NAME     = local.analysis_replay_history_control_name
  }, local.period_work_closed_env)
}

resource "aws_lambda_alias" "analysis_retired" {
  count            = local.analysis_retirement_selected ? 1 : 0
  name             = "retired"
  description      = "Pinned read-only compatibility; no new analysis or accounting."
  function_name    = aws_lambda_function.analysis.function_name
  function_version = aws_lambda_function.analysis.version
}

output "analysis_retirement_contract" {
  description = "Source retirement boundary; selection does not claim deployment qualification."
  value = {
    selected                           = local.analysis_retirement_selected
    planning_blocked_without_selection = !local.analysis_retirement_selected
    immutable_replay_route_configured  = local.analysis_retirement_selected
    new_dispatch                       = false
    provider_access                    = false
    accounting_writes                  = false
    live_qualified                     = false
  }
}
