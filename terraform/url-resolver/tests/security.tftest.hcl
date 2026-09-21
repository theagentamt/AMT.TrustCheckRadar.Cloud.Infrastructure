mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/resolver-execution" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:trustcheckradar-dev-url-resolver:live" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:trustcheckradar-dev-url-resolver-alerts" }
  }
}

variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
}

run "disabled_is_empty" {
  command = plan
  assert {
    condition = (
      !output.downstream_contract.enabled && output.downstream_contract.invoke_arn == null &&
      length(aws_lambda_function.resolver) == 0 && length(aws_vpc.resolver) == 0 &&
      length(aws_iam_role_policy.caller) == 0 && length(aws_nat_gateway.resolver) == 0 &&
      length(aws_sns_topic.operations) == 0 && length(aws_iam_role.dev_test) == 0
    )
    error_message = "Disabled stack must not create network costs, functions or invocation grants."
  }
}

run "enabled_requires_pinned_artifact" {
  command = plan
  variables { enabled = true }
  expect_failures = [var.enabled]
}

run "wildcard_caller_rejected" {
  command = plan
  variables { caller_role_names = ["*"] }
  expect_failures = [var.caller_role_names]
}

run "invalid_artifact_rejected" {
  command = plan
  variables {
    artifact = {
      bucket         = "test-artifacts"
      key            = "releases/test/url_redirect_resolver.zip"
      object_version = "null"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }
  expect_failures = [var.artifact]
}

run "security_boundary" {
  command = apply
  variables {
    enabled = true
    artifact = {
      bucket         = "test-artifacts"
      key            = "releases/test/url_redirect_resolver.zip"
      object_version = "immutable-test-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
    caller_role_names = ["test-resolver-caller"]
  }
  assert {
    condition = (
      aws_lambda_function.resolver[0].runtime == "python3.14" &&
      aws_lambda_function.resolver[0].timeout == 12 &&
      aws_lambda_function.resolver[0].reserved_concurrent_executions == 5 &&
      aws_lambda_function.resolver[0].s3_object_version == "immutable-test-version" &&
      !aws_lambda_function.resolver[0].vpc_config[0].ipv6_allowed_for_dual_stack &&
      aws_lambda_function_event_invoke_config.no_async_retries[0].maximum_retry_attempts == 0
    )
    error_message = "Resolver must be version pinned, bounded, IPv4-only, and have no asynchronous error retries."
  }
  assert {
    condition = (
      length(aws_security_group.resolver[0].ingress) == 0 &&
      length(aws_security_group.resolver[0].egress) == 2 &&
      alltrue([for rule in aws_security_group.resolver[0].egress : contains([80, 443], rule.to_port) && rule.from_port == rule.to_port && length(coalesce(rule.ipv6_cidr_blocks, [])) == 0]) &&
      alltrue([for rule in aws_network_acl_rule.deny_destinations : rule.egress && rule.rule_action == "deny" && rule.rule_number < 200]) &&
      length(aws_network_acl_rule.deny_destinations) == 15 &&
      aws_network_acl_rule.deny_destinations["169.254.0.0/16"].rule_action == "deny"
    )
    error_message = "The isolated subnet must deny non-public destination ranges before allowing web ports."
  }
  assert {
    condition = (
      jsondecode(aws_iam_role_policy.execution[0].policy).Statement[0].Action == ["logs:CreateLogStream", "logs:PutLogEvents"] &&
      jsondecode(aws_iam_role_policy.execution[0].policy).Statement[2].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.execution[0].policy).Statement[2].Condition.ArnEquals["lambda:SourceFunctionArn"] == "arn:aws:lambda:us-east-1:123456789012:function:trustcheckradar-dev-url-resolver" &&
      contains(jsondecode(aws_iam_role_policy.execution[0].policy).Statement[3].Action, "secretsmanager:*") &&
      jsondecode(aws_iam_role_policy.execution[0].policy).Statement[3].Effect == "Deny"
    )
    error_message = "Execution role must log only to its group, deny function-code ENI changes, and deny secrets/data access."
  }
  assert {
    condition = (
      length(aws_iam_role_policy.caller) == 1 &&
      jsondecode(aws_iam_role_policy.caller["test-resolver-caller"].policy).Statement[0].Resource == output.downstream_contract.invoke_arn &&
      jsondecode(aws_iam_role_policy.caller["test-resolver-caller"].policy).Statement[0].Action == "lambda:InvokeFunction" &&
      contains(aws_cloudwatch_metric_alarm.partial[0].alarm_actions, output.downstream_contract.alert_topic_arn) &&
      !output.downstream_contract.email_subscription_configured
    )
    error_message = "Caller grant must target only the resolver alias; alarms must target the dedicated topic without inventing an email subscriber."
  }
}

run "dev_operations_and_caller" {
  command = apply
  variables {
    enabled = true
    artifact = {
      bucket         = "test-artifacts"
      key            = "releases/test/url_redirect_resolver.zip"
      object_version = "immutable-test-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
    dev_test_principal_arn = "arn:aws:iam::123456789012:role/test-deployer"
    notification_email     = "test@example.com"
  }
  assert {
    condition = (
      length(aws_iam_role.dev_test) == 1 &&
      jsondecode(aws_iam_role.dev_test[0].assume_role_policy).Statement[0].Principal.AWS == var.dev_test_principal_arn &&
      jsondecode(aws_iam_role_policy.dev_test[0].policy).Statement[0].Resource == output.downstream_contract.invoke_arn &&
      jsondecode(aws_iam_role_policy.dev_test[0].policy).Statement[0].Action == "lambda:InvokeFunction" &&
      aws_sns_topic_subscription.email[0].endpoint == "test@example.com"
    )
    error_message = "Dev tests require an explicit role principal, alias-only invocation, and the owner-selected email."
  }
  assert {
    condition = (
      !contains(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[0].Action, "sns:*") &&
      length(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[0].Action) == 8 &&
      jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Principal.Service == "cloudwatch.amazonaws.com" &&
      jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.StringEquals["aws:SourceAccount"] == "123456789012" &&
      length(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"]) == 3 &&
      alltrue([for arn in jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"] : startswith(arn, "arn:aws:cloudwatch:us-east-1:123456789012:alarm:trustcheckradar-dev-url-resolver-")])
    )
    error_message = "Only this account's three resolver alarm ARNs may publish as CloudWatch."
  }
}

run "no_prod_smoke_role" {
  command = plan
  variables {
    environment            = "prod"
    dev_test_principal_arn = "arn:aws:iam::123456789012:role/test-deployer"
  }
  expect_failures = [var.dev_test_principal_arn]
}

run "no_root_smoke_principal" {
  command = plan
  variables {
    dev_test_principal_arn = "arn:aws:iam::123456789012:root"
  }
  expect_failures = [var.dev_test_principal_arn]
}

run "assessment_topic_grant_is_exact_and_optional" {
  command = apply
  variables {
    enabled                                = true
    assessment_alarm_notifications_enabled = true
    artifact = {
      bucket         = "test-bucket"
      key            = "releases/test/url_redirect_resolver.zip"
      object_version = "test-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }
  assert {
    condition     = length(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"]) == 6 && contains(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"], "arn:aws:cloudwatch:us-east-1:123456789012:alarm:trustcheckradar-dev-url-assessment-dependency-failures")
    error_message = "Shared topic must allow exactly the existing resolver alarms and three named assessment alarms."
  }
}

run "consumer_topic_grant_is_exact_and_optional" {
  command = apply
  variables {
    enabled                              = true
    consumer_alarm_notifications_enabled = true
    artifact = {
      bucket         = "test-bucket"
      key            = "releases/test/url_redirect_resolver.zip"
      object_version = "test-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }
  assert {
    condition     = length(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"]) == 18 && contains(jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"], "arn:aws:cloudwatch:us-east-1:123456789012:alarm:trustcheckradar-dev-url-lease-recovery-expiry-overdue") && alltrue([for arn in jsondecode(aws_sns_topic_policy.operations[0].policy).Statement[1].Condition.ArnEquals["aws:SourceArn"] : !strcontains(arn, "*")])
    error_message = "Support topic must accept only three resolver and fifteen explicit V1 alarms, without wildcard publishers."
  }
}
