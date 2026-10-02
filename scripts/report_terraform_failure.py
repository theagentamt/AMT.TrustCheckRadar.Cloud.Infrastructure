#!/usr/bin/env python3
"""Emit a bounded, privacy-safe classification for a failed Terraform command."""

import argparse
import json
import re
from pathlib import Path


MAX_LOG_BYTES = 2_000_000
MAX_CAPTURE_LENGTH = 64
ALLOWED_AWS_ACTIONS = frozenset({
    "apigateway:GET",
    "cloudwatch:DescribeAlarms",
    "events:DescribeRule",
    "events:ListTargetsByRule",
    "iam:GetRole",
    "iam:GetRolePolicy",
    "iam:ListAttachedRolePolicies",
    "iam:ListRolePolicies",
    "lambda:GetAlias",
    "lambda:GetEventSourceMapping",
    "lambda:GetFunction",
    "lambda:GetFunctionCodeSigningConfig",
    "lambda:GetFunctionEventInvokeConfig",
    "lambda:GetPolicy",
    "lambda:ListVersionsByFunction",
    "logs:DescribeLogGroups",
    "logs:DescribeMetricFilters",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetResourcePolicy",
    "sts:GetCallerIdentity",
})
ALLOWED_AWS_OPERATIONS = frozenset({
    "APIGatewayV2:GetAuthorizer",
    "APIGatewayV2:GetIntegration",
    "APIGatewayV2:GetRoute",
    "CloudWatch:DescribeAlarms",
    "EventBridge:DescribeRule",
    "EventBridge:ListTargetsByRule",
    "IAM:GetRole",
    "IAM:GetRolePolicy",
    "IAM:ListAttachedRolePolicies",
    "IAM:ListRolePolicies",
    "Lambda:GetAlias",
    "Lambda:GetEventSourceMapping",
    "Lambda:GetFunction",
    "Lambda:GetFunctionCodeSigningConfig",
    "Lambda:GetFunctionEventInvokeConfig",
    "Lambda:GetPolicy",
    "Lambda:ListVersionsByFunction",
    "CloudWatchLogs:DescribeLogGroups",
    "CloudWatchLogs:DescribeMetricFilters",
    "SecretsManager:DescribeSecret",
    "SecretsManager:GetResourcePolicy",
    "STS:GetCallerIdentity",
})
ALLOWED_TERRAFORM_VARIABLES = frozenset({
    "access_qualification_reference",
    "activate_access_engineering",
    "activate_engineering",
    "activate_rules_engineering",
    "activate_trial_engineering",
    "authority_configuration",
    "deletion_activation",
    "engineering_subjects",
    "provider_budget",
})


def _allow(values, allowed):
    return sorted({value for value in values if len(value) <= MAX_CAPTURE_LENGTH and value in allowed})[:10]


def classify(text):
    lowered = text.lower()
    if "accessdenied" in lowered or "not authorized to perform" in lowered:
        category = "AWS_ACCESS_DENIED"
    elif "error acquiring the state lock" in lowered or "conditionalcheckfailedexception" in lowered:
        category = "STATE_LOCK_UNAVAILABLE"
    elif "invalid value for variable" in lowered or "unsuitable value for" in lowered:
        category = "VARIABLE_VALIDATION_FAILED"
    elif "backend initialization required" in lowered or "failed to get existing workspaces" in lowered:
        category = "BACKEND_CONFIGURATION_FAILED"
    else:
        category = "TERRAFORM_PLAN_FAILED_REDACTED"

    actions = _allow(
        re.findall(
            r"(?:perform(?:\s+the\s+action)?\s*:\s*)([a-z0-9-]+:[A-Za-z0-9*]+)",
            text,
            flags=re.IGNORECASE,
        ),
        ALLOWED_AWS_ACTIONS,
    )
    operations = _allow(
        (f"{service}:{operation}" for service, operation in re.findall(
            r"operation error\s+([A-Za-z0-9]+)\s*:\s*([A-Za-z0-9]+)", text
        )),
        ALLOWED_AWS_OPERATIONS,
    )
    variables = _allow(
        re.findall(r'variable\s+"([A-Za-z0-9_]+)"', text),
        ALLOWED_TERRAFORM_VARIABLES,
    )
    return {
        "category": category,
        "awsActions": actions,
        "awsOperations": operations,
        "terraformVariables": variables,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    data = args.log.read_bytes()
    if len(data) > MAX_LOG_BYTES:
        data = data[-MAX_LOG_BYTES:]
    text = data.decode("utf-8", errors="replace")
    print(json.dumps(classify(text), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
