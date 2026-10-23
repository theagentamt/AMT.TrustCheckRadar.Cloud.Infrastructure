#!/usr/bin/env python3
"""Validate a bounded Dev message-consumer update or engineering activation."""

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
PROJECT = "trustcheckradar"
PREFIX = f"{PROJECT}-dev"
BUCKET = f"{PREFIX}-{ACCOUNT}-artifacts"
TRANSITION_ADDRESSES = {
    'aws_lambda_alias.runtime["consumer"]',
    'aws_lambda_alias.runtime["evaluator"]',
    'aws_lambda_function.runtime["consumer"]',
    'aws_lambda_function.runtime["evaluator"]',
}


def _canonical_uuid(value):
    try:
        return isinstance(value, str) and str(UUID(value)) == value
    except (AttributeError, ValueError):
        return False


def _variables(plan):
    return {key: value.get("value") for key, value in plan.get("variables", {}).items()}


def _terraform_bool(value):
    """Normalize only Terraform's typed boolean and exact CLI boolean literals."""
    if value is True or value == "true":
        return True
    if value is False or value == "false":
        return False
    raise ValueError("Invalid Terraform boolean value.")


def _decode_hash(value):
    try:
        decoded = base64.b64decode(value, validate=True)
    except (TypeError, ValueError) as exc:
        raise ValueError("Invalid artifact SHA256.") from exc
    if len(decoded) != 32:
        raise ValueError("Invalid artifact SHA256.")


def _review_maintenance(variables):
    """Validate configuration only; trusted runtime/IAM readback is a rollout gate."""
    contract = variables.get("authority_maintenance")
    fields = {
        "schema_version", "environment", "authority_table_arn", "recovery_alias_arn",
        "recovery_version", "recovery_code_sha256", "worker_enabled",
        "schedule_enabled", "heartbeat_enforced", "provider_access_added",
    }
    if type(contract) is not dict or set(contract) != fields:
        raise ValueError("Exact shared maintenance configuration is required before admission.")
    if (
        type(contract["schema_version"]) is not int or contract["schema_version"] != 1
        or contract["environment"] != "dev"
        or contract["authority_table_arn"] != variables["deployment"]["authority_table_arn"]
        or contract["recovery_alias_arn"] != f"arn:aws:lambda:{REGION}:{ACCOUNT}:function:{PREFIX}-url-lease-recovery:live"
        or not isinstance(contract["recovery_version"], str)
        or not re.fullmatch(r"[1-9][0-9]*", contract["recovery_version"])
        or any(contract[key] is not True for key in ("worker_enabled", "schedule_enabled", "heartbeat_enforced"))
        or contract["provider_access_added"] is not False
    ):
        raise ValueError("Shared maintenance must be enabled, versioned, same-table and provider-free.")
    _decode_hash(contract["recovery_code_sha256"])


def _review_artifacts(deployment):
    artifacts = deployment.get("artifacts") or {}
    if set(artifacts) != {"consumer", "evaluator"}:
        raise ValueError("Exactly the consumer and evaluator artifacts are required.")
    releases = set()
    for name, artifact in artifacts.items():
        match = re.fullmatch(
            rf"releases/([0-9a-f]{{40}})/message_{name}\.zip", artifact.get("key", "")
        )
        if artifact.get("bucket") != BUCKET or not match:
            raise ValueError(f"Invalid {name} artifact location.")
        if not artifact.get("object_version") or artifact["object_version"] == "null":
            raise ValueError(f"Exact {name} S3 object version is required.")
        _decode_hash(artifact.get("source_hash"))
        releases.add(match.group(1))
    if len(releases) != 1:
        raise ValueError("Message artifacts must come from one immutable Lambda release.")
    return artifacts, releases.pop()


def _expected_environment(name, variables, active):
    deployment = variables["deployment"]
    authority = variables["authority_configuration"]
    budget = variables["provider_budget"]
    common = {
        "STAGE": "dev",
        "MESSAGE_POLICY_VERSION": "message-rules-2026-09-20-v1",
        "MESSAGE_POLICY_APPROVAL_SHA256": "0367140fbdbaef36dd59ba81030f3e35e04e78dbbed4129277c9cb0758971a80",
        "MESSAGE_AI_ENABLED": "false",
        "MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED": "false",
        "MESSAGE_AI_POLICY_VERSION": "message-ai-2026-09-21-v1",
        "MESSAGE_AI_POLICY_APPROVAL_SHA256": "d6e9fff12225540bef9ba7833cce457cca4b9c791af3b49dd8a4f1601d204349",
    }
    if name == "evaluator":
        return common | {
            "MESSAGE_EVALUATOR_ENABLED": str(active).lower(),
            "MESSAGE_PROPOSER_ENABLED": "false",
            "MESSAGE_AI_QUALIFIED": "false",
            "URL_ASSESSMENT_FUNCTION_ARN": deployment["assessment_alias_arn"],
        }
    return common | {
        "MESSAGE_CONSUMER_ENABLED": str(active).lower(),
        "GOVERNED_HISTORY_SETTLEMENT_ENABLED": "false",
        "AUTHORITY_ENABLED": str(active).lower(),
        "AUTHORITY_TABLE_NAME": f"{PREFIX}-purchase-entitlements",
        "USERS_TABLE_NAME": f"{PREFIX}-users",
        "DEVICE_BINDINGS_TABLE_NAME": f"{PREFIX}-device-bindings",
        "DELETION_LEDGER_TABLE_NAME": f"{PREFIX}-deletion-ledger",
        "COGNITO_ISSUER": deployment["cognito_issuer"],
        "COGNITO_APP_CLIENT_ID": deployment["cognito_app_client_id"],
        "COGNITO_REQUIRED_SCOPE": "aws.cognito.signin.user.admin",
        "AUTHORITY_HMAC_SECRET_ARN": deployment["authority_hmac_secret_arn"],
        "AUTHORITY_POLICY_VERSION": "owner-2026-09-20-v1",
        "DEV_SUBJECT_ALLOWLIST_JSON": json.dumps(sorted(variables["engineering_subjects"]), separators=(",", ":")),
        "MESSAGE_EVALUATOR_FUNCTION_ARN": f"arn:aws:lambda:{REGION}:{ACCOUNT}:function:{PREFIX}-message-evaluator:live",
        "MESSAGE_PROVIDER_CIRCUIT_OPEN": str(not active).lower(),
        "OPERATION_VALIDITY_SECONDS": str(authority["operation_validity_seconds"]),
        "WORKER_SETTLEMENT_SECONDS": str(authority["worker_settlement_seconds"]),
        "RECONCILIATION_SECONDS": str(authority["reconciliation_seconds"]),
        "RECEIPT_RETENTION_SECONDS": "604800",
        "COUNTER_RETENTION_SECONDS": str(authority["counter_retention_seconds"]),
        "ATTEMPT_WINDOW_SECONDS": "60",
        "ATTEMPTS_PER_WINDOW": "20",
        "MAX_INFLIGHT": "2",
        "MESSAGE_PROVIDER_WINDOW_SECONDS": str(budget["window_seconds"]),
        "MESSAGE_PROVIDER_ATTEMPTS_PER_WINDOW": str(budget["max_attempts_per_window"]),
        "MESSAGE_PROVIDER_FAILURES_PER_WINDOW": str(budget["max_failures_per_window"]),
    }


def review(plan, revision, mode):
    if mode not in {"inactive", "engineering"}:
        raise ValueError("Unknown transition mode.")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full reviewed Git commit SHA is required.")
    if plan.get("errored") or plan.get("complete") is not True:
        raise ValueError("Only a complete, successful plan can be reviewed.")
    if any(check.get("status") != "pass" for check in plan.get("checks") or []):
        raise ValueError("Plan checks must have passed; failed or unknown checks cannot be reviewed.")

    variables = _variables(plan)
    if any(_terraform_bool(variables.get(key, False)) for key in ("candidate3_rules_only_enabled", "governed_history_settlement_enabled")):
        raise ValueError("This candidate.1 workflow cannot activate candidate.3 or governed History.")
    active = mode == "engineering"
    subjects = sorted(variables.get("engineering_subjects") or [])
    if (
        variables.get("environment") != "dev"
        or variables.get("aws_region") != REGION
        or variables.get("project_name") != PROJECT
        or variables.get("enabled") is not True
        or _terraform_bool(variables.get("activate_rules_engineering")) is not active
    ):
        raise ValueError("Transition must target only the selected Dev message mode.")
    if active:
        if len(subjects) != 1 or not _canonical_uuid(subjects[0]):
            raise ValueError("Engineering activation requires exactly one synthetic Cognito UUID subject.")
    elif subjects:
        raise ValueError("Inactive mode requires an empty subject allowlist.")

    if variables.get("authority_configuration") != {
        "operation_validity_seconds": 300,
        "worker_settlement_seconds": 60,
        "reconciliation_seconds": 3600,
        "counter_retention_seconds": 604800,
    }:
        raise ValueError("Authority horizons do not match the approved receipt policy.")
    if variables.get("provider_budget") != {
        "window_seconds": 3600,
        "max_attempts_per_window": 20,
        "max_failures_per_window": 5,
    }:
        raise ValueError("Provider limits do not match the reviewed Dev circuit budget.")
    if variables.get("api_gateway") != {
        "api_id": "icuak34th9",
        "execution_arn": f"arn:aws:execute-api:{REGION}:{ACCOUNT}:icuak34th9",
        "authorizer_id": "itms4b",
    }:
        raise ValueError("Transition must reuse the exact reviewed Dev API and authorizer.")

    deployment = variables.get("deployment") or {}
    required_dependencies = {
        "users_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-users",
        "devices_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-device-bindings",
        "deletion_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-deletion-ledger",
        "authority_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-purchase-entitlements",
        "assessment_alias_arn": f"arn:aws:lambda:{REGION}:{ACCOUNT}:function:{PREFIX}-url-assessment:live",
    }
    if any(deployment.get(key) != value for key, value in required_dependencies.items()):
        raise ValueError("Transition must reuse the exact Dev authority and assessment resources.")
    if not re.fullmatch(
        rf"arn:aws:secretsmanager:{REGION}:{ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]+",
        deployment.get("authority_hmac_secret_arn", ""),
    ):
        raise ValueError("Transition must reference the existing Dev authority key ring by ARN.")
    if deployment.get("cognito_issuer") != "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ" or deployment.get("cognito_app_client_id") != "5kvl9a8jo4fr1qqnci27tdabk4":
        raise ValueError("Transition must use the reviewed Dev Cognito authority.")
    artifacts, lambda_release = _review_artifacts(deployment)
    if active:
        _review_maintenance(variables)

    inventory = [item for item in plan.get("resource_changes", []) if item.get("mode") == "managed"]
    managed = {item["address"]: item for item in inventory}
    if len(managed) != len(inventory) or not TRANSITION_ADDRESSES <= set(managed):
        raise ValueError("Unique complete function and alias post-plan inventory is required.")
    if any(item.get("change", {}).get("actions") == ["no-op"] and item["change"].get("before") != item["change"].get("after") for item in inventory):
        raise ValueError("No-op readback must have identical before and after values.")
    planned_inventory = [item for item in plan.get("planned_values", {}).get("root_module", {}).get("resources", []) if item.get("mode") == "managed"]
    planned = {item["address"]: item.get("values") for item in planned_inventory}
    if len(planned) != len(planned_inventory) or set(planned) != set(managed) or any(planned[address] != item["change"].get("after") for address, item in managed.items()):
        raise ValueError("Complete consistent post-plan inventory is required.")
    if any(item.get("mode") == "managed" and item.get("change", {}).get("actions") != ["no-op"]
           for item in plan.get("resource_drift", [])):
        raise ValueError("Resolve unreviewed managed drift before transition.")
    changes = {
        address: item for address, item in managed.items()
        if item.get("change", {}).get("actions") != ["no-op"]
    }
    if set(changes) not in (set(), TRANSITION_ADDRESSES):
        raise ValueError(f"Unexpected transition resource set: {sorted(changes)}.")
    for address, resource in changes.items():
        if resource.get("change", {}).get("actions") != ["update"]:
            raise ValueError(f"Transition may update only the reviewed resource: {address}.")

    for name in ("consumer", "evaluator"):
        function_address = f'aws_lambda_function.runtime["{name}"]'
        if function_address in managed:
            function = managed[function_address]["change"]["after"]
            artifact = artifacts[name]
            expected = {
                "function_name": f"{PREFIX}-message-{name}",
                "runtime": "python3.14",
                "architectures": ["arm64"],
                "reserved_concurrent_executions": 2,
                "memory_size": 256,
                "timeout": 29 if name == "consumer" else 23,
                "handler": f"message_{name}.app.lambda_handler",
                "publish": True,
                "role": f"arn:aws:iam::{ACCOUNT}:role/{PREFIX}-message-{name}-execution",
                "s3_bucket": artifact["bucket"],
                "s3_key": artifact["key"],
                "s3_object_version": artifact["object_version"],
                "source_code_hash": artifact["source_hash"],
            }
            if any(function.get(key) != value for key, value in expected.items()):
                raise ValueError(f"The planned {name} runtime exceeds the reviewed boundary.")
            if any(function.get(key) for key in ("layers", "vpc_config", "dead_letter_config", "file_system_config", "image_uri")):
                raise ValueError("Unreviewed runtime attachments are forbidden.")
            environment = function.get("environment", [{}])[0].get("variables", {})
            if environment != _expected_environment(name, variables, active):
                raise ValueError(f"The planned {name} environment does not match the selected bounded mode.")
        alias_address = f'aws_lambda_alias.runtime["{name}"]'
        if alias_address in managed:
            alias = managed[alias_address]["change"]["after"]
            if alias.get("name") != "live" or alias.get("function_name") != f"{PREFIX}-message-{name}":
                raise ValueError(f"The planned {name} alias is not the reviewed live alias.")
            if alias.get("routing_config") not in (None, []):
                raise ValueError(f"The planned {name} alias may not use weighted routing.")
            function_version, alias_version = function.get("version"), alias.get("function_version")
            if function_version is not None and alias_version is not None:
                if not isinstance(alias_version, str) or not re.fullmatch(r"[1-9][0-9]*", alias_version) or function_version != alias_version:
                    raise ValueError("Alias must serve the exact reviewed published version.")
            else:
                configuration = {item["address"]: item for item in plan.get("configuration", {}).get("root_module", {}).get("resources", [])}
                references = configuration.get("aws_lambda_alias.runtime", {}).get("expressions", {}).get("function_version", {}).get("references", [])
                if (managed[alias_address]["change"].get("after_unknown", {}).get("function_version") is not True
                    or managed[function_address]["change"].get("after_unknown", {}).get("version") is not True
                    or not any(ref == "aws_lambda_function.runtime" or ref.startswith("aws_lambda_function.runtime.") or ref.startswith("aws_lambda_function.runtime[") for ref in references)):
                    raise ValueError("Unknown alias version must bind the version published by the reviewed function.")

    contract = plan.get("output_changes", {}).get("candidate_contract", {}).get("after") or {}
    expected_contract = {
        "provisioned": True,
        "consumer_enabled": active,
        "evaluator_enabled": active,
        "model_enabled": False,
        "ai_enabled": False,
        "ai_qualified": False,
        "engineering_subject_count": len(subjects),
        "provider_circuit_open": not active,
        "authority_reused": True,
        "secret_value_in_state": False,
        "daily_reporting_ready": False,
    }
    if any(contract.get(key) != value for key, value in expected_contract.items()):
        raise ValueError("Candidate output does not match the selected bounded mode.")

    reviewed = {key: plan.get(key) for key in ("terraform_version", "variables", "output_changes", "checks")}
    for key in ("resource_changes", "resource_drift"):
        reviewed[key] = [item for item in plan.get(key, []) if item.get("mode") == "managed"]
    reviewed["revision"] = revision
    reviewed["mode"] = mode
    fingerprint = hashlib.sha256(
        json.dumps(reviewed, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return artifacts, lambda_release, fingerprint, len(changes), len(subjects)


def aws(*args):
    result = subprocess.run(
        ["aws", *args, "--region", REGION, "--output", "json"],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def verify_artifacts(artifacts, read=aws):
    if read("sts", "get-caller-identity").get("Account") != ACCOUNT:
        raise ValueError("Unexpected AWS account; no artifact read performed.")
    with tempfile.TemporaryDirectory(prefix="message-transition-") as directory:
        for name, artifact in artifacts.items():
            path = Path(directory) / f"{name}.zip"
            metadata = read(
                "s3api", "get-object", "--bucket", artifact["bucket"], "--key", artifact["key"],
                "--version-id", artifact["object_version"], str(path),
            )
            if metadata.get("VersionId") != artifact["object_version"]:
                raise ValueError(f"Downloaded {name} artifact version does not match.")
            actual = base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode()
            if actual != artifact["source_hash"]:
                raise ValueError(f"Downloaded {name} artifact SHA256 does not match.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--mode", choices=("inactive", "engineering"), required=True)
    parser.add_argument("--expected-digest")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    artifacts, release, fingerprint, changes, subjects = review(
        json.loads(args.plan.read_text()), args.revision, args.mode
    )
    if args.apply and (not args.expected_digest or args.expected_digest != fingerprint):
        raise ValueError("Apply requires the exact digest from the reviewed plan at this revision.")
    verify_artifacts(artifacts)
    print(json.dumps({
        "reviewedPlanDigest": fingerprint,
        "revision": args.revision,
        "lambdaRelease": release,
        "resourceUpdates": changes,
        "engineeringSubjectCount": subjects,
        "mode": args.mode,
        "scope": "bounded-dev-message-transition",
    }))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        detail = exc if isinstance(exc, ValueError) else type(exc).__name__
        raise SystemExit(f"Message transition rejected: {detail}")
