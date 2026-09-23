resource "aws_iam_role_policy" "deletion" {
  count = local.deletion_provisioned ? 1 : 0
  name  = "v1-authority-deletion-only"
  role  = aws_iam_role.runtime["deletion"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["deletion"].arn}:*" },
      { Sid = "ReadV1Authority", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:ConditionCheckItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] } } },
      { Sid = "AtomicV1Deletion", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "DeleteAccountRowsOnly", Effect = "Allow", Action = ["dynamodb:DeleteItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "ReadDeletionCommands", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Scan"], Resource = var.deployment.deletion_table_arn },
      { Sid = "AtomicDeletionProgress", Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"], Resource = var.deployment.deletion_table_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["ACCOUNT#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "CheckDeletionProgress", Effect = "Allow", Action = ["dynamodb:ConditionCheckItem"], Resource = var.deployment.deletion_table_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["ACCOUNT#*"] } } },
      { Sid = "UpdateDeletionCheckpoint", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = var.deployment.deletion_table_arn,
        Condition = {
          "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["V1#CONTROL"], "dynamodb:Attributes" = ["PK", "SK", "cursor", "revision", "scanStartedAtEpoch", "lastFullPassAtEpoch"] }
          "ForAnyValue:StringEquals"  = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] }
          "Null"                      = { "dynamodb:Attributes" = "false" }
        }
      },
      { Sid = "ReadCommandStream", Effect = "Allow", Action = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"], Resource = var.deletion_stream_arn },
      { Sid = "OneRetainedKeyRing", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.authority_hmac[0].arn,
      Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      { Sid = "NoProviderOrIdentityMutation", Effect = "Deny", Action = ["lambda:InvokeFunction", "cognito-idp:*", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
  lifecycle {
    precondition {
      condition     = var.deletion_stream_arn != "" && startswith(var.deletion_stream_arn, "${var.deployment.deletion_table_arn}/stream/")
      error_message = "Deletion worker requires the verified deletion-ledger stream."
    }
  }
}
resource "aws_lambda_event_source_mapping" "v1_deletion" {
  count                          = local.deletion_provisioned ? 1 : 0
  event_source_arn               = var.deletion_stream_arn
  function_name                  = aws_lambda_alias.runtime["deletion"].arn
  enabled                        = local.authority_engineering_active
  starting_position              = "LATEST"
  batch_size                     = 5
  parallelization_factor         = 1
  bisect_batch_on_function_error = true
  maximum_retry_attempts         = 3
  maximum_record_age_in_seconds  = 3600
  function_response_types        = ["ReportBatchItemFailures"]
  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT", "MODIFY"], dynamodb = { NewImage = {
        PK            = { S = [{ prefix = "ACCOUNT#" }] }, SK = { S = ["ACCOUNT_DELETION"] },
        eventType     = { S = ["account.deletion.requested"] }, environment = { S = ["dev"] },
        schemaVersion = { N = ["1"] }, status = { S = ["REQUESTED"] }
      } } })
    }
  }
  depends_on = [aws_iam_role_policy.deletion]
}
locals {
  schedules = var.enabled && var.alert_topic_arn != null ? merge({
    recovery = { suffix = "url-lease-recovery", input_json = jsonencode({ schemaVersion = 1 }) }
    }, local.deletion_provisioned ? {
    deletion = { suffix = "v1-authority-deletion", input_json = jsonencode({ schemaVersion = 1, operation = "reconcile-v1-authority-deletion" }) }
  } : {}) : {}
}
resource "aws_cloudwatch_event_rule" "maintenance" {
  for_each            = local.schedules
  name                = "${local.prefix}-${each.value.suffix}"
  schedule_expression = "rate(1 minute)"
  state               = local.authority_engineering_active ? "ENABLED" : "DISABLED"
  tags                = var.tags
}
resource "aws_cloudwatch_event_target" "maintenance" {
  for_each = local.schedules
  rule     = aws_cloudwatch_event_rule.maintenance[each.key].name
  arn      = aws_lambda_alias.runtime[each.key].arn
  input    = each.value.input_json
  retry_policy {
    maximum_event_age_in_seconds = 60
    maximum_retry_attempts       = 0
  }
}
resource "aws_lambda_permission" "maintenance" {
  for_each       = local.schedules
  statement_id   = "AllowMaintenanceSchedule"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime[each.key].function_name
  qualifier      = aws_lambda_alias.runtime[each.key].name
  principal      = "events.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_cloudwatch_event_rule.maintenance[each.key].arn
}
