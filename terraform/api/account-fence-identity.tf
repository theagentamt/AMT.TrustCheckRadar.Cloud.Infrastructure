data "aws_caller_identity" "account_fence" {
  count = (
    var.account_data_deployment != null ||
    var.campaign_participation_fence_deployment != null ||
    var.purchase_handoff_fence_deployment != null
  ) ? 1 : 0
}
