#!/usr/bin/env python3
"""Build bounded inline policies for the Dev deployment role."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


OBSERVABILITY_SID = "ManageEnvironmentObservability"


def environment_observability(account_id: str, region: str, project: str, environment: str) -> dict:
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": OBSERVABILITY_SID,
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:DeleteAlarms",
                    "cloudwatch:DeleteDashboards",
                    "cloudwatch:GetDashboard",
                    "cloudwatch:ListTagsForResource",
                    "cloudwatch:PutDashboard",
                    "cloudwatch:PutMetricAlarm",
                    "cloudwatch:TagResource",
                    "cloudwatch:UntagResource",
                ],
                "Resource": [
                    f"arn:aws:cloudwatch:{region}:{account_id}:alarm:{project}-{environment}-*",
                    f"arn:aws:cloudwatch::{account_id}:dashboard/{project}-{environment}-*",
                ],
            }
        ],
    }


def account_reconciliation(account_id: str, region: str, project: str, environment: str) -> dict:
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "ManageAccountDeletionReconciliationRule",
                "Effect": "Allow",
                "Action": [
                    "events:DescribeRule",
                    "events:ListTagsForResource",
                    "events:ListTargetsByRule",
                    "events:PutRule",
                    "events:PutTargets",
                    "events:RemoveTargets",
                    "events:DeleteRule",
                    "events:EnableRule",
                    "events:DisableRule",
                    "events:TagResource",
                    "events:UntagResource",
                ],
                "Resource": (
                    f"arn:aws:events:{region}:{account_id}:rule/"
                    f"{project}-{environment}-account-deletion-reconcile"
                ),
            }
        ],
    }


def write_policy(path: Path, policy: dict) -> None:
    path.write_text(json.dumps(policy, separators=(",", ":")), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--observability-policy-output", type=Path, required=True)
    parser.add_argument("--account-policy-output", type=Path, required=True)
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--project", default="trustcheckradar")
    parser.add_argument("--environment", choices=("dev",), default="dev")
    args = parser.parse_args()

    if not (args.account_id.isdigit() and len(args.account_id) == 12):
        raise ValueError("account ID must contain exactly 12 digits")
    observability = environment_observability(
        args.account_id, args.region, args.project, args.environment
    )
    write_policy(args.observability_policy_output, observability)
    write_policy(
        args.account_policy_output,
        account_reconciliation(args.account_id, args.region, args.project, args.environment),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
