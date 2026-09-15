#!/usr/bin/env python3
"""Inspect configuration metadata only; never read application records or log events."""

import argparse
import json
import re
import subprocess
import sys


TABLE_SUFFIXES = (
    "users", "deletion-ledger", "analysis-abuse-control", "device-bindings",
    "purchase-entitlements", "web-risk-cache", "device-recovery-control",
    "campaign-outbox", "campaign-pipeline", "campaign-intelligence",
    "history-content", "history-control",
)


class AwsReadError(RuntimeError):
    pass


def aws_reader(profile, region):
    def read(service, operation, *arguments):
        command = [
            "aws", "--profile", profile, "--region", region, "--no-cli-pager",
            service, operation, *arguments, "--output", "json",
        ]
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        if result.returncode:
            if service == "dynamodb" and "ResourceNotFoundException" in result.stderr:
                return None
            raise AwsReadError(f"{service} {operation} failed; check CLI authentication and read permissions.")
        return json.loads(result.stdout)
    return read


def collect_inventory(read, *, expected_account, environment, region, project):
    identity = read("sts", "get-caller-identity")
    if identity.get("Account") != expected_account:
        raise AwsReadError("AWS account does not match the expected account; no storage queries were made.")
    prefix = f"{project}-{environment}"
    report = {
        "schemaVersion": 1,
        "accountId": expected_account,
        "environment": environment,
        "region": region,
        "scope": "configuration-metadata-only",
        "deletionReadinessVerified": False,
        "tables": [],
        "logGroups": [],
        "limitations": [
            "Names follow repository defaults; custom resource names require separate inspection.",
            "No item values, expiry coverage, user ownership, logs, queue messages or secrets were read.",
            "PITR metadata is not an inventory of on-demand, AWS Backup or exported backups.",
            "No Cognito Username/sub identity mapping or deployed erasure behavior was verified.",
            "Queue, S3 object/version, external-provider and mobile copies require separate inventory.",
        ],
    }
    for suffix in TABLE_SUFFIXES:
        name = f"{prefix}-{suffix}"
        description = read("dynamodb", "describe-table", "--table-name", name)
        if description is None:
            report["tables"].append({"name": name, "present": False})
            continue
        table = description["Table"]
        expected_arn = f"arn:aws:dynamodb:{region}:{expected_account}:table/{name}"
        if table.get("TableArn") != expected_arn:
            raise AwsReadError(f"Unexpected table identity for {name}.")
        ttl = read("dynamodb", "describe-time-to-live", "--table-name", name)
        backups = read("dynamodb", "describe-continuous-backups", "--table-name", name)
        if ttl is None or backups is None:
            raise AwsReadError(f"Table {name} changed during the audit; rerun for a consistent metadata inventory.")
        pitr = backups.get("ContinuousBackupsDescription", {}).get("PointInTimeRecoveryDescription", {})
        report["tables"].append({
            "name": name,
            "present": True,
            "arn": table["TableArn"],
            "status": table.get("TableStatus"),
            "keySchema": table.get("KeySchema", []),
            "indexes": [{"name": index.get("IndexName"), "keySchema": index.get("KeySchema", [])}
                        for index in table.get("GlobalSecondaryIndexes", [])],
            "ttl": ttl.get("TimeToLiveDescription", {}),
            "pointInTimeRecoveryStatus": pitr.get("PointInTimeRecoveryStatus"),
            "recoveryPeriodInDays": pitr.get("RecoveryPeriodInDays"),
            "stream": table.get("StreamSpecification", {}),
            "deletionProtectionEnabled": table.get("DeletionProtectionEnabled"),
        })
    for group_prefix in (f"/aws/lambda/{prefix}-", f"/aws/apigateway/{prefix}-"):
        response = read("logs", "describe-log-groups", "--log-group-name-prefix", group_prefix, "--max-items", "100")
        groups = response.get("logGroups", [])
        report["logGroups"].extend({
            "name": group["logGroupName"],
            "retentionInDays": group.get("retentionInDays"),
            "retentionExplicit": "retentionInDays" in group,
        } for group in groups)
        if response.get("NextToken") or response.get("nextToken"):
            report["limitations"].append(f"Log-group metadata for {group_prefix} was truncated at 100 groups.")
    post_confirmation = f"/aws/lambda/{prefix}-post-confirmation"
    report["postConfirmationLogGroupObserved"] = any(
        group["name"] == post_confirmation for group in report["logGroups"]
    )
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="trustcheckradar")
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--expected-account", default="107827791950")
    parser.add_argument("--project", default="trustcheckradar")
    parser.add_argument("--environment", required=True, choices=("dev", "uat", "prod"))
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]{12}", args.expected_account):
        parser.error("--expected-account must contain exactly 12 digits")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.project):
        parser.error("--project must be a lowercase resource-name prefix")
    try:
        report = collect_inventory(
            aws_reader(args.profile, args.region), expected_account=args.expected_account,
            environment=args.environment, region=args.region, project=args.project,
        )
    except (AwsReadError, OSError, subprocess.TimeoutExpired, ValueError, KeyError) as error:
        print(f"Metadata audit failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
