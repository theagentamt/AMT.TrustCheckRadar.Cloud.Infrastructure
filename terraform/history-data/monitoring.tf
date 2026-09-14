locals {
  monitoring_enabled = var.history_data_enabled && var.monitoring != null
  monitoring_tables  = local.monitoring_enabled ? aws_dynamodb_table.history : {}

  storage_metric_dimensions = merge(
    {
      for name, table in local.monitoring_tables : "${name}_base" => {
        TableName = table.name
      }
    },
    {
      for name, table in local.monitoring_tables : "${name}_expiry" => {
        TableName                = table.name
        GlobalSecondaryIndexName = "ExpirationIndex"
      }
    },
    local.monitoring_enabled ? {
      control_lifecycle = {
        TableName                = aws_dynamodb_table.history["control"].name
        GlobalSecondaryIndexName = "PendingLifecycleIndex"
      }
    } : {},
  )
  throttle_metrics = local.monitoring_enabled ? {
    read  = "ReadThrottleEvents"
    write = "WriteThrottleEvents"
  } : {}
}

resource "aws_cloudwatch_metric_alarm" "storage_throttles" {
  for_each = local.throttle_metrics

  alarm_name          = "${var.project_name}-${var.environment}-history-${each.key}-throttles"
  alarm_description   = "History table/index throttling. Inspect the History storage dashboard and runbook; never raise caps or replay scans automatically."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.monitoring.alarm_topic_arn]
  ok_actions          = [var.monitoring.alarm_topic_arn]

  # Table metrics exclude GSI events. Sum explicit series, never SEARCH or
  # account-wide metrics that could accidentally include another environment.
  dynamic "metric_query" {
    for_each = local.storage_metric_dimensions
    content {
      id          = "m_${metric_query.key}"
      return_data = false
      metric {
        namespace   = "AWS/DynamoDB"
        metric_name = each.value
        dimensions  = metric_query.value
        period      = 300
        stat        = "Sum"
      }
    }
  }

  metric_query {
    id          = "total"
    expression  = "SUM(METRICS())"
    label       = "History ${each.key} throttle events"
    return_data = true
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "history_storage" {
  count = local.monitoring_enabled ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-history-storage"
  dashboard_body = jsonencode({
    widgets = [
      for position, direction in ["read", "write"] : {
        type   = "metric"
        x      = position * 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "History ${direction} throttles by table/index"
          region  = var.aws_region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          stacked = false
          metrics = [
            for name, dimensions in local.storage_metric_dimensions : concat(
              ["AWS/DynamoDB", local.throttle_metrics[direction], "TableName", dimensions.TableName],
              try(["GlobalSecondaryIndexName", dimensions.GlobalSecondaryIndexName], []),
              [{ label = name }],
            )
          ]
        }
      }
    ]
  })
}
