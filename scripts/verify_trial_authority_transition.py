#!/usr/bin/env python3
"""Validate the bounded Dev trial-authority transition used by SECUR4ALL-230."""

import argparse
import base64
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path
from uuid import UUID


ACCOUNT = "107827791950"
REGION = "us-east-1"
PREFIX = "trustcheckradar-dev"
BUCKET = f"{PREFIX}-{ACCOUNT}-artifacts"
FUNCTIONS = {"entitlements", "recovery", "deletion"}
TRANSITION_ADDRESSES = {
    *(f'aws_lambda_function.runtime["{name}"]' for name in FUNCTIONS),
    *(f'aws_lambda_alias.runtime["{name}"]' for name in FUNCTIONS),
    'aws_cloudwatch_event_rule.maintenance["recovery"]',
    'aws_cloudwatch_metric_alarm.worker_heartbeat["recovery"]',
    'aws_cloudwatch_metric_alarm.expiry_overdue[0]',
}


def _canonical_uuid(value):
    try:
        return isinstance(value, str) and str(UUID(value)) == value
    except (AttributeError, ValueError):
        return False


def _variables(plan):
    return {key: value.get("value") for key, value in plan.get("variables", {}).items()}


def _artifact(variables, name):
    override = variables.get(f"{name}_artifact_override")
    return (override or {}).get("artifact") or variables["deployment"]["artifacts"][name]


def _review_artifacts(variables):
    artifacts = {name: _artifact(variables, name) for name in FUNCTIONS}
    for name, artifact in artifacts.items():
        expected_file = {
            "entitlements": "v1_entitlements.zip",
            "recovery": "url_lease_recovery.zip",
            "deletion": "v1_authority_deletion.zip",
        }[name]
        if artifact.get("bucket") != BUCKET or not re.fullmatch(
            rf"releases/[0-9a-f]{{40}}/{expected_file}", artifact.get("key", "")
        ):
            raise ValueError(f"Invalid {name} artifact location.")
        if not artifact.get("object_version") or artifact["object_version"] == "null":
            raise ValueError(f"Exact {name} object version is required.")
        try:
            decoded = base64.b64decode(artifact.get("source_hash"), validate=True)
        except (TypeError, ValueError) as exc:
            raise ValueError(f"Invalid {name} artifact SHA256.") from exc
        if len(decoded) != 32:
            raise ValueError(f"Invalid {name} artifact SHA256.")
    return artifacts


def _expected_environment(name, variables, active, secret_arn):
    authority = variables["authority_configuration"]
    common = {
        "STAGE": "dev",
        "AUTHORITY_TABLE_NAME": f"{PREFIX}-purchase-entitlements",
    }
    if name == "recovery":
        return common | {"LEASE_SWEEP_ENABLED": str(active).lower()}
    if name == "deletion":
        deletion_subjects = set((variables.get("deletion_activation") or {}).get("subjects") or [])
        deletion_subjects.update(variables.get("engineering_subjects") or [])
        return common | {
            "V1_AUTHORITY_DELETION_ENABLED": "true",
            "DEV_SUBJECT_ALLOWLIST_JSON": json.dumps(sorted(deletion_subjects), separators=(",", ":")),
            "DELETION_LEDGER_TABLE_NAME": f"{PREFIX}-deletion-ledger",
            "DELETION_LEDGER_STREAM_ARN": variables["deletion_stream_arn"],
            "AUTHORITY_HMAC_SECRET_ARN": secret_arn,
            "DELETION_RECEIPT_RETENTION_SECONDS": "10368000",
        }
    return common | {
        "CONSUMER_ENABLED": "false",
        "AUTHORITY_ENABLED": str(active).lower(),
        "V1_ENTITLEMENTS_ENABLED": str(active).lower(),
        "TRIAL_AUTHORITY_RETENTION_APPROVED": str(active).lower(),
        "USERS_TABLE_NAME": f"{PREFIX}-users",
        "DEVICE_BINDINGS_TABLE_NAME": f"{PREFIX}-device-bindings",
        "DELETION_LEDGER_TABLE_NAME": f"{PREFIX}-deletion-ledger",
        "COGNITO_ISSUER": variables["deployment"]["cognito_issuer"],
        "COGNITO_APP_CLIENT_ID": variables["deployment"]["cognito_app_client_id"],
        "COGNITO_REQUIRED_SCOPE": "aws.cognito.signin.user.admin",
        "AUTHORITY_HMAC_SECRET_ARN": secret_arn,
        "AUTHORITY_POLICY_VERSION": "owner-2026-09-20-v1",
        "DEV_SUBJECT_ALLOWLIST_JSON": json.dumps(sorted(variables.get("engineering_subjects") or []), separators=(",", ":")),
        "OPERATION_VALIDITY_SECONDS": str(authority["operation_validity_seconds"]),
        "WORKER_SETTLEMENT_SECONDS": str(authority["worker_settlement_seconds"]),
        "RECONCILIATION_SECONDS": str(authority["reconciliation_seconds"]),
        "RECEIPT_RETENTION_SECONDS": "604800",
        "COUNTER_RETENTION_SECONDS": str(authority["counter_retention_seconds"]),
        "ATTEMPT_WINDOW_SECONDS": "60",
        "ATTEMPTS_PER_WINDOW": "20",
        "MAX_INFLIGHT": "2",
    }


def review(plan, revision, mode):
    if mode not in {"inactive", "trial"}:
        raise ValueError("Unknown transition mode.")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full reviewed Git commit SHA is required.")
    if plan.get("errored") or plan.get("complete") is not True:
        raise ValueError("Only a complete, successful plan can be reviewed.")
    variables = _variables(plan)
    active = mode == "trial"
    subjects = sorted(variables.get("engineering_subjects") or [])
    if (
        variables.get("environment") != "dev"
        or variables.get("aws_region") != REGION
        or variables.get("project_name") != "trustcheckradar"
        or variables.get("enabled") is not True
        or variables.get("activate_engineering") is not False
        or variables.get("activate_access_engineering") is not False
        or variables.get("activate_trial_engineering") is not active
    ):
        raise ValueError("Transition must target only the selected Dev trial-authority mode.")
    if active:
        if len(subjects) != 1 or not _canonical_uuid(subjects[0]):
            raise ValueError("Trial activation requires exactly one synthetic Cognito UUID subject.")
        if variables.get("access_qualification_reference") != "SECUR4ALL-230 reviewed synthetic Dev qualification":
            raise ValueError("Trial activation requires the exact reviewed qualification reference.")
    elif subjects:
        raise ValueError("Inactive mode requires an empty subject allowlist.")
    if variables.get("authority_configuration") != {
        "operation_validity_seconds": 300,
        "worker_settlement_seconds": 60,
        "reconciliation_seconds": 3600,
        "counter_retention_seconds": 604800,
    }:
        raise ValueError("Authority horizons do not match the approved receipt policy.")
    if variables.get("api_gateway") != {
        "api_id": "icuak34th9",
        "execution_arn": f"arn:aws:execute-api:{REGION}:{ACCOUNT}:icuak34th9",
    }:
        raise ValueError("Transition must reuse the reviewed Dev API.")
    if variables.get("alert_topic_arn") != f"arn:aws:sns:{REGION}:{ACCOUNT}:{PREFIX}-url-resolver-alerts":
        raise ValueError("Transition must retain the confirmed Dev alert topic.")
    deletion = variables.get("deletion_activation") or {}
    if deletion.get("source_sha") != "9123459a5c2bc9503d56235b2cb1f1e162c00da1" or not deletion.get("subjects"):
        raise ValueError("Existing reviewed deletion qualification must remain active.")
    artifacts = _review_artifacts(variables)

    changes = {
        item["address"]: item
        for item in plan.get("resource_changes", [])
        if item.get("mode") == "managed" and item.get("change", {}).get("actions") != ["no-op"]
    }
    if not set(changes).issubset(TRANSITION_ADDRESSES):
        raise ValueError(f"Unexpected transition resource set: {sorted(changes)}.")
    for address, resource in changes.items():
        if resource.get("change", {}).get("actions") != ["update"]:
            raise ValueError(f"Transition may update only the reviewed resource: {address}.")

    expected_runtime = {
        "entitlements": ("v1-entitlements", 10, 2, "v1_entitlements.app.lambda_handler"),
        "recovery": ("url-lease-recovery", 15, 1, "app.lambda_handler"),
        "deletion": ("v1-authority-deletion", 30, 1, "v1_authority_deletion.app.lambda_handler"),
    }
    for name in FUNCTIONS:
        function_address = f'aws_lambda_function.runtime["{name}"]'
        if function_address in changes:
            function = changes[function_address]["change"]["after"]
            suffix, timeout, concurrency, handler = expected_runtime[name]
            artifact = artifacts[name]
            expected = {
                "function_name": f"{PREFIX}-{suffix}", "runtime": "python3.14",
                "architectures": ["arm64"], "reserved_concurrent_executions": concurrency,
                "memory_size": 256, "timeout": timeout, "handler": handler, "publish": True,
                "role": f"arn:aws:iam::{ACCOUNT}:role/{PREFIX}-{suffix}-execution",
                "s3_bucket": artifact["bucket"], "s3_key": artifact["key"],
                "s3_object_version": artifact["object_version"], "source_code_hash": artifact["source_hash"],
            }
            if any(function.get(key) != value for key, value in expected.items()):
                raise ValueError(f"The planned {name} runtime exceeds the reviewed boundary.")
            environment = function.get("environment", [{}])[0].get("variables", {})
            secret_arn = environment.get("AUTHORITY_HMAC_SECRET_ARN", "")
            if name != "recovery" and not re.fullmatch(
                rf"arn:aws:secretsmanager:{REGION}:{ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]+",
                secret_arn,
            ):
                raise ValueError("Transition must reference the existing Dev authority key ring by ARN.")
            if environment != _expected_environment(name, variables, active, secret_arn):
                raise ValueError(f"The planned {name} environment does not match the selected mode.")
        alias_address = f'aws_lambda_alias.runtime["{name}"]'
        if alias_address in changes:
            alias = changes[alias_address]["change"]["after"]
            suffix = expected_runtime[name][0]
            if alias.get("name") != "live" or alias.get("function_name") != f"{PREFIX}-{suffix}" or alias.get("routing_config") not in (None, []):
                raise ValueError(f"The planned {name} alias is outside the reviewed boundary.")

    desired = {
        'aws_cloudwatch_event_rule.maintenance["recovery"]': {"state": "ENABLED" if active else "DISABLED"},
        'aws_cloudwatch_metric_alarm.worker_heartbeat["recovery"]': {"actions_enabled": active, "treat_missing_data": "breaching" if active else "notBreaching"},
        'aws_cloudwatch_metric_alarm.expiry_overdue[0]': {"actions_enabled": active},
    }
    for address, expected in desired.items():
        if address in changes and any(changes[address]["change"]["after"].get(key) != value for key, value in expected.items()):
            raise ValueError(f"The planned operational control is outside the selected mode: {address}.")

    contract = plan.get("output_changes", {}).get("candidate_contract", {}).get("after") or {}
    expected_contract = {
        "provisioned": True, "consumer_enabled": False, "recovery_enabled": active,
        "access_enabled": active, "deletion_enabled": True, "trial_activation_enabled": active,
        "access_only_engineering": False, "trial_only_engineering": active,
        "general_customer_access": False, "engineering_subject_count": len(subjects),
        "secret_value_in_state": False,
    }
    if any(contract.get(key) != value for key, value in expected_contract.items()):
        raise ValueError("Candidate output does not match the selected bounded mode.")

    reviewed = {key: plan.get(key) for key in ("terraform_version", "variables", "output_changes", "checks")}
    for key in ("resource_changes", "resource_drift"):
        reviewed[key] = [item for item in plan.get(key, []) if item.get("mode") == "managed"]
    reviewed.update(revision=revision, mode=mode)
    fingerprint = hashlib.sha256(json.dumps(reviewed, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return artifacts, fingerprint, len(changes), len(subjects)


def aws(*args):
    result = subprocess.run(["aws", *args, "--region", REGION, "--output", "json"], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def verify_artifacts(artifacts, read=aws):
    if read("sts", "get-caller-identity").get("Account") != ACCOUNT:
        raise ValueError("Unexpected AWS account; no artifact read performed.")
    with tempfile.TemporaryDirectory(prefix="trial-authority-transition-") as directory:
        for name, artifact in artifacts.items():
            path = Path(directory) / f"{name}.zip"
            metadata = read("s3api", "get-object", "--bucket", artifact["bucket"], "--key", artifact["key"], "--version-id", artifact["object_version"], str(path))
            if metadata.get("VersionId") != artifact["object_version"]:
                raise ValueError(f"Downloaded {name} artifact version does not match.")
            actual = base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode()
            if actual != artifact["source_hash"]:
                raise ValueError(f"Downloaded {name} artifact SHA256 does not match.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--mode", choices=("inactive", "trial"), required=True)
    parser.add_argument("--expected-digest")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    artifacts, fingerprint, changes, subjects = review(json.loads(args.plan.read_text()), args.revision, args.mode)
    if args.apply and (not args.expected_digest or args.expected_digest != fingerprint):
        raise ValueError("Apply requires the exact digest from the reviewed plan at this revision.")
    verify_artifacts(artifacts)
    print(json.dumps({"reviewedPlanDigest": fingerprint, "revision": args.revision, "resourceUpdates": changes, "engineeringSubjectCount": subjects, "mode": args.mode, "scope": "bounded-dev-trial-authority-transition"}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        detail = exc if isinstance(exc, ValueError) else type(exc).__name__
        raise SystemExit(f"Trial authority transition rejected: {detail}")
