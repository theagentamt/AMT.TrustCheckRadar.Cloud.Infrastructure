variable "research_consent_migration_deployment" {
  description = "Coordinated immutable legacy-access retirement and independent-consent release. Null preserves deployed legacy inputs; selecting it is a reviewed cutover, not a data migration or activation proof."
  type = object({
    release_id                 = string
    approval_reference         = string
    promotion_approved         = bool
    consent_enabled            = optional(bool, false)
    consent_approval_reference = optional(string, "")
    artifacts = map(object({
      object_version = string
      source_hash    = string
    }))
  })
  default = null
  validation {
    condition = var.research_consent_migration_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.research_consent_migration_deployment.release_id)) &&
      length(trimspace(var.research_consent_migration_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.research_consent_migration_deployment.promotion_approved) &&
      (!var.research_consent_migration_deployment.consent_enabled || length(trimspace(var.research_consent_migration_deployment.consent_approval_reference)) > 0) &&
      toset(keys(var.research_consent_migration_deployment.artifacts)) == toset(["analysis", "participation", "snapshot", "web_risk", "purchase"]) &&
      alltrue([for artifact in var.research_consent_migration_deployment.artifacts :
        length(trimspace(artifact.object_version)) > 0 && artifact.object_version != "null" && can(regex("^[A-Za-z0-9+/]{43}=$", artifact.source_hash))
      ]) && var.campaign_participation_fence_deployment == null && var.purchase_handoff_fence_deployment == null &&
      !var.history_features.writes && !var.history_features.recognition && !var.history_features.durable_replay,
      false
    )
    error_message = "Migration requires five immutable artifacts, rollout review, separate consent activation review and UAT/Prod promotion approval; conflicting participation/purchase overrides or active History writers/replay must be reconciled first."
  }
}

locals {
  research_purchase_fenced    = var.purchase_handoff_fence_deployment != null || var.research_consent_migration_deployment != null
  research_migration_selected = var.research_consent_migration_deployment != null
  research_migration_consent_env = local.research_migration_selected ? {
    CONSENT_INDEPENDENCE_ENABLED          = tostring(var.research_consent_migration_deployment.consent_enabled)
    CAMPAIGN_PARTICIPATION_NOTICE_VERSION = "research-consent-2026-09-21-v2"
    CAMPAIGN_PARTICIPATION_POLICY_VERSION = "independent-research-v1"
  } : {}
  research_migration_replay_env = local.research_migration_selected ? {
    APP_ENVIRONMENT                = var.environment
    COGNITO_ISSUER                 = local.jwt_issuer
    COGNITO_APP_CLIENT_ID          = local.cognito_app_client_id
    COGNITO_REQUIRED_SCOPE         = "aws.cognito.signin.user.admin"
    HISTORY_MAX_SUMMARY_BYTES      = "4096"
    HISTORY_MAX_LIST_ITEMS         = "20"
    HISTORY_MAX_TEXT_FIELD_BYTES   = "1024"
    HISTORY_MAX_RESPONSE_BYTES     = "262144"
    DELETION_LEDGER_TABLE_NAME     = local.deletion_ledger_table_name
    HISTORY_WRITES_ENABLED         = "false"
    HISTORY_DURABLE_REPLAY_ENABLED = "false"
    RECOGNITION_ENABLED            = "false"
  } : {}
  research_migration_roles = local.research_migration_selected ? merge({
    analysis      = aws_iam_role.analysis.name
    snapshot      = aws_iam_role.entitlement_snapshot.name
    participation = aws_iam_role.campaign_participation.name
    purchase      = aws_iam_role.purchase_handoff.name
  }, var.enable_web_risk_communication ? { web_risk = aws_iam_role.web_risk_communication[0].name } : {}) : {}
}

# Existing supplementary History policies must not permit the retired legacy
# endpoint to write/settle/publish. IAM cannot prove HTTP egress or runtime behavior.
data "aws_iam_policy_document" "research_migration_boundary" {
  for_each = local.research_migration_roles
  statement {
    sid       = "DenyProviderCredentialsAndDispatch"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "lambda:InvokeFunction"]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = each.key == "participation" ? [] : [1]
    content {
      sid       = "DenyLegacySettlementAndWrites"
      effect    = "Deny"
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem", "dynamodb:PartiQLInsert", "dynamodb:PartiQLUpdate", "dynamodb:PartiQLDelete"]
      resources = ["*"]
    }
  }
  dynamic "statement" {
    for_each = each.key == "participation" ? [1] : []
    content {
      sid       = "DenyConsentEntitlementAccess"
      effect    = "Deny"
      actions   = ["dynamodb:*"]
      resources = [local.purchase_entitlements_table_arn, "${local.purchase_entitlements_table_arn}/index/*", local.analysis_entitlements_table_arn, "${local.analysis_entitlements_table_arn}/index/*"]
    }
  }
  dynamic "statement" {
    for_each = each.key == "web_risk" ? [1] : []
    content {
      sid       = "DenyRetiredDirectLookupDataAccess"
      effect    = "Deny"
      actions   = ["dynamodb:*"]
      resources = ["*"]
    }
  }
  dynamic "statement" {
    for_each = each.key == "analysis" ? [1] : []
    content {
      sid       = "ReadReplayAccountDeletionFence"
      actions   = ["dynamodb:GetItem"]
      resources = [local.deletion_ledger_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*"]
      }
    }
  }
}

resource "aws_iam_role_policy" "research_migration_boundary" {
  for_each = local.research_migration_roles
  name     = "${local.name_prefix}-research-migration-${each.key}"
  role     = each.value
  policy   = data.aws_iam_policy_document.research_migration_boundary[each.key].json
}

output "research_consent_migration_contract" {
  description = "Candidate composition only. No inventory approval, item migration or successful consent/erasure is inferred."
  value = {
    selected                      = local.research_migration_selected
    release_id                    = try(var.research_consent_migration_deployment.release_id, null)
    schema_version                = 2
    notice_version                = "research-consent-2026-09-21-v2"
    policy_version                = "independent-research-v1"
    consent_enabled               = try(var.research_consent_migration_deployment.consent_enabled, false)
    legacy_new_dispatch           = local.research_migration_selected ? "denied_by_candidate" : "unchanged_requires_inventory"
    live_qualified                = false
    inventory_approved            = false
    runtime_can_approve_migration = false
  }
}

# Read the applied worker contract, not a caller-provided claim about deployment.
data "terraform_remote_state" "research_campaign_processing" {
  count   = local.research_migration_selected ? 1 : 0
  backend = "s3"
  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/campaign-processing.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

resource "terraform_data" "research_migration_cutover" {
  count = local.research_migration_selected ? 1 : 0
  input = var.research_consent_migration_deployment.release_id
  lifecycle {
    precondition {
      condition = try(
        data.terraform_remote_state.research_campaign_processing[0].outputs.research_consent_migration_contract.environment == var.environment &&
        data.terraform_remote_state.research_campaign_processing[0].outputs.research_consent_migration_contract.release_id == var.research_consent_migration_deployment.release_id &&
        data.terraform_remote_state.research_campaign_processing[0].outputs.research_consent_migration_contract.selected &&
        data.terraform_remote_state.research_campaign_processing[0].outputs.research_consent_migration_contract.consumers_paused &&
        data.terraform_remote_state.research_campaign_processing[0].outputs.research_consent_migration_contract.account_id == data.aws_caller_identity.account_fence[0].account_id,
        false
      )
      error_message = "Apply the same-release research campaign candidate with all consumers paused in this account/environment before cutting over the API. Applied state is composition evidence, not live qualification."
    }
    precondition {
      condition     = local.purchase_entitlements_table_name == "${local.name_prefix}-purchase-entitlements" && local.purchase_entitlements_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.account_fence[0].account_id}:table/${local.name_prefix}-purchase-entitlements"
      error_message = "Research migration requires the exact same-account/Region/environment entitlement table."
    }
  }
}
