data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  count = var.enabled ? 1 : 0
  state = "available"
}

locals {
  name         = "${var.project_name}-${var.environment}-url-resolver"
  function_arn = "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.name}"
  tags         = merge(var.tags, { Project = var.project_name, Environment = var.environment, Stack = "url-resolver", ManagedBy = "terraform" })
  # Deliberately conservative; mirrors the Lambda IPv4 exclusion list. IPv6 has
  # no network route or SG grant in this initial version.
  denied_cidrs = [
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
    "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24",
    "192.88.99.0/24", "192.168.0.0/16", "198.18.0.0/15",
    "198.51.100.0/24", "203.0.113.0/24", "224.0.0.0/4", "240.0.0.0/4",
  ]
  denied_rules = var.enabled ? { for index, cidr in local.denied_cidrs : cidr => 100 + index } : {}
  eni_actions = [
    "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets",
    "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses",
  ]
}

# Dedicated VPC: no peering, endpoints, application data stores or inbound path.
resource "aws_vpc" "resolver" {
  count                = var.enabled ? 1 : 0
  cidr_block           = "10.254.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_subnet" "private" {
  count                   = var.enabled ? 1 : 0
  vpc_id                  = aws_vpc.resolver[0].id
  cidr_block              = "10.254.0.0/26"
  availability_zone       = data.aws_availability_zones.available[0].names[0]
  map_public_ip_on_launch = false
  tags                    = local.tags
}

resource "aws_subnet" "public" {
  count                   = var.enabled ? 1 : 0
  vpc_id                  = aws_vpc.resolver[0].id
  cidr_block              = "10.254.0.64/26"
  availability_zone       = data.aws_availability_zones.available[0].names[0]
  map_public_ip_on_launch = false
  tags                    = local.tags
}

resource "aws_internet_gateway" "resolver" {
  count  = var.enabled ? 1 : 0
  vpc_id = aws_vpc.resolver[0].id
  tags   = local.tags
}

resource "aws_eip" "nat" {
  count  = var.enabled ? 1 : 0
  domain = "vpc"
  tags   = local.tags
}

resource "aws_nat_gateway" "resolver" {
  count         = var.enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.resolver]
  tags          = local.tags
}

resource "aws_route_table" "public" {
  count  = var.enabled ? 1 : 0
  vpc_id = aws_vpc.resolver[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.resolver[0].id
  }
  tags = local.tags
}

resource "aws_route_table" "private" {
  count  = var.enabled ? 1 : 0
  vpc_id = aws_vpc.resolver[0].id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.resolver[0].id
  }
  tags = local.tags
}

resource "aws_route_table_association" "public" {
  count          = var.enabled ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.enabled ? 1 : 0
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_network_acl" "private" {
  count      = var.enabled ? 1 : 0
  vpc_id     = aws_vpc.resolver[0].id
  subnet_ids = [aws_subnet.private[0].id]
  tags       = local.tags
}

resource "aws_network_acl_rule" "deny_destinations" {
  for_each       = local.denied_rules
  network_acl_id = aws_network_acl.private[0].id
  rule_number    = each.value
  egress         = true
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = each.key
}

resource "aws_network_acl_rule" "http_egress" {
  for_each       = var.enabled ? toset(["80", "443"]) : toset([])
  network_acl_id = aws_network_acl.private[0].id
  rule_number    = each.key == "80" ? 200 : 201
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = tonumber(each.key)
  to_port        = tonumber(each.key)
}

resource "aws_network_acl_rule" "responses" {
  count          = var.enabled ? 1 : 0
  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_security_group" "resolver" {
  count       = var.enabled ? 1 : 0
  name        = local.name
  description = "No ingress; public web egress further restricted by subnet ACL and resolver"
  vpc_id      = aws_vpc.resolver[0].id
  dynamic "egress" {
    for_each = [80, 443]
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = local.tags
}

resource "aws_cloudwatch_log_group" "resolver" {
  count             = var.enabled ? 1 : 0
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_iam_role" "resolver" {
  count = var.enabled ? 1 : 0
  name  = "${local.name}-execution"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "execution" {
  count = var.enabled ? 1 : 0
  name  = "resolver-runtime"
  role  = aws_iam_role.resolver[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "${aws_cloudwatch_log_group.resolver[0].arn}:*"
      },
      { Sid = "LambdaENIManagement", Effect = "Allow", Action = local.eni_actions, Resource = "*" },
      {
        Sid       = "DenyENIAPIsFromFunctionCode", Effect = "Deny", Action = local.eni_actions, Resource = "*",
        Condition = { ArnEquals = { "lambda:SourceFunctionArn" = local.function_arn } }
      },
      {
        Sid    = "NoSecretsOrConsumerData", Effect = "Deny",
        Action = ["secretsmanager:*", "ssm:*", "dynamodb:*", "s3:*", "kms:*", "sts:AssumeRole"], Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "resolver" {
  count                          = var.enabled ? 1 : 0
  function_name                  = local.name
  role                           = aws_iam_role.resolver[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 12
  reserved_concurrent_executions = var.reserved_concurrency
  s3_bucket                      = var.artifact.bucket
  s3_key                         = var.artifact.key
  s3_object_version              = var.artifact.object_version
  source_code_hash               = var.artifact.source_hash
  publish                        = true
  vpc_config {
    subnet_ids                  = [aws_subnet.private[0].id]
    security_group_ids          = [aws_security_group.resolver[0].id]
    ipv6_allowed_for_dual_stack = false
  }
  depends_on = [aws_iam_role_policy.execution, aws_network_acl_rule.deny_destinations, aws_network_acl_rule.http_egress, aws_network_acl_rule.responses, aws_route_table_association.private, aws_route_table_association.public]
  tags       = local.tags
}

resource "aws_lambda_alias" "resolver" {
  count            = var.enabled ? 1 : 0
  name             = "live"
  function_name    = aws_lambda_function.resolver[0].function_name
  function_version = aws_lambda_function.resolver[0].version
}

resource "aws_lambda_function_event_invoke_config" "no_async_retries" {
  count                        = var.enabled ? 1 : 0
  function_name                = aws_lambda_function.resolver[0].function_name
  qualifier                    = aws_lambda_alias.resolver[0].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}

resource "aws_iam_role_policy" "caller" {
  for_each = var.enabled ? var.caller_role_names : toset([])
  name     = "${local.name}-invoke"
  role     = each.value
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.resolver[0].arn }]
  })
}

resource "aws_cloudwatch_log_metric_filter" "partial" {
  count          = var.enabled ? 1 : 0
  name           = "${local.name}-partial"
  log_group_name = aws_cloudwatch_log_group.resolver[0].name
  pattern        = "{ $.event = \"url_resolution\" && $.status = \"partial\" }"
  metric_transformation {
    name          = "PartialResolutions"
    namespace     = "AMT/URLResolver/${var.environment}"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "partial" {
  count               = var.enabled ? 1 : 0
  alarm_name          = "${local.name}-partial"
  namespace           = "AMT/URLResolver/${var.environment}"
  metric_name         = "PartialResolutions"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = var.enabled ? toset(["Errors", "Throttles"]) : toset([])
  alarm_name          = "${local.name}-${lower(each.key)}"
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = local.name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alert_actions
  ok_actions          = local.alert_actions
  tags                = local.tags
}
