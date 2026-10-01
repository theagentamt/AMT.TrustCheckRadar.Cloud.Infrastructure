output "candidate_contract" {
  value = {
    provisioned               = var.enabled
    feedback_enabled          = false
    endpoint                  = null
    policy_version            = "private-result-feedback-2026-09-21-v1"
    policy_approval_sha256    = "9e3485588daeae698b139cb070b4de16bb9298348135271e7d9adafd9968bee6"
    authority_reused          = true
    retention                 = "original_receipt_deadline_with_existing_backups"
    function_aliases          = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    runtime_alarm_names       = [for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_name]
    backup_inventory_verified = false
    live_qualified            = false
  }
}
