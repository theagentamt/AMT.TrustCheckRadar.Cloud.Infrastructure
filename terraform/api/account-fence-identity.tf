data "aws_caller_identity" "account_fence" {
  count = (
    var.research_consent_migration_deployment != null ||
    var.account_data_deployment != null ||
    var.account_export_deployment != null ||
    var.campaign_participation_fence_deployment != null ||
    var.purchase_handoff_fence_deployment != null ||
    local.profile_fence_configured
  ) ? 1 : 0
}
