variable "demographic_research_monitoring" {
  description = "Optional same-account/Region SNS destination for demographic-research operational alarms. Delivery must be verified for support@andmorethings.com before activation."
  type        = object({ alarm_topic_arn = string })
  default     = null
  validation {
    condition = var.demographic_research_monitoring == null ? true : try(
      var.demographic_research_deployment != null &&
      split(":", local.users_table_arn)[4] == data.aws_caller_identity.account_fence[0].account_id &&
      can(regex("^arn:aws:sns:${var.aws_region}:${split(":", local.users_table_arn)[4]}:[A-Za-z0-9_-]+$", var.demographic_research_monitoring.alarm_topic_arn)), false
    )
    error_message = "Demographic-research monitoring requires its pinned candidate and an exact same-account/Region standard SNS topic."
  }
}

resource "aws_cloudwatch_metric_alarm" "demographic_research_runtime" {
  for_each            = var.demographic_research_monitoring == null || var.demographic_research_deployment == null ? toset([]) : toset(["Errors", "Throttles"])
  alarm_name          = "${local.demographic_research_name}-${lower(each.key)}"
  alarm_description   = "Demographic-research runtime failure; investigate without logging, copying or replaying profile values."
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = aws_lambda_function.demographic_research[0].function_name }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.demographic_research_monitoring.alarm_topic_arn]
  ok_actions          = [var.demographic_research_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "demographic_research_internal_error" {
  for_each            = var.demographic_research_monitoring == null || var.demographic_research_deployment == null ? toset([]) : toset(["get", "enroll", "update", "withdraw", "unknown"])
  alarm_name          = "${local.demographic_research_name}-${each.key}-internal-error"
  alarm_description   = "Demographic-research ${each.key} reported an internal error. The metric contains no account or demographic dimension."
  namespace           = "TrustCheckRadar/DemographicResearch"
  metric_name         = "InternalError"
  dimensions          = { Environment = var.environment, Operation = each.key }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.demographic_research_monitoring.alarm_topic_arn]
  ok_actions          = [var.demographic_research_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}
