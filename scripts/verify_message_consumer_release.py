#!/usr/bin/env python3
"""Validate the inactive Dev message-consumer installation plan."""

import argparse
import base64
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path


ACCOUNT = "107827791950"
REGION = "us-east-1"
PROJECT = "trustcheckradar"
PREFIX = f"{PROJECT}-dev"
BUCKET = f"{PREFIX}-{ACCOUNT}-artifacts"
EXPECTED_ADDRESSES = {
    "aws_apigatewayv2_integration.message[0]",
    'aws_apigatewayv2_route.message["prepare"]',
    'aws_apigatewayv2_route.message["reconcile"]',
    'aws_apigatewayv2_route.message["submit"]',
    'aws_cloudwatch_log_group.runtime["consumer"]',
    'aws_cloudwatch_log_group.runtime["evaluator"]',
    'aws_cloudwatch_metric_alarm.runtime["consumer-duration"]',
    'aws_cloudwatch_metric_alarm.runtime["consumer-errors"]',
    'aws_cloudwatch_metric_alarm.runtime["consumer-throttles"]',
    'aws_cloudwatch_metric_alarm.runtime["evaluator-duration"]',
    'aws_cloudwatch_metric_alarm.runtime["evaluator-errors"]',
    'aws_cloudwatch_metric_alarm.runtime["evaluator-throttles"]',
    'aws_iam_role.runtime["consumer"]',
    'aws_iam_role.runtime["evaluator"]',
    "aws_iam_role_policy.consumer[0]",
    "aws_iam_role_policy.evaluator[0]",
    'aws_lambda_alias.runtime["consumer"]',
    'aws_lambda_alias.runtime["evaluator"]',
    'aws_lambda_function.runtime["consumer"]',
    'aws_lambda_function.runtime["evaluator"]',
    'aws_lambda_function_event_invoke_config.no_async_retries["consumer"]',
    'aws_lambda_function_event_invoke_config.no_async_retries["evaluator"]',
    'aws_lambda_permission.message["prepare"]',
    'aws_lambda_permission.message["reconcile"]',
    'aws_lambda_permission.message["submit"]',
}
EXPECTED_ROUTES = {
    "POST /v1/message-checks",
    "POST /v1/message-checks/prepare",
    "POST /v1/message-checks/reconcile",
}


def _variables(plan):
    return {key: value.get("value") for key, value in plan.get("variables", {}).items()}


def _decode_hash(value):
    try:
        decoded = base64.b64decode(value, validate=True)
    except (TypeError, ValueError) as exc:
        raise ValueError("Invalid artifact SHA256.") from exc
    if len(decoded) != 32:
        raise ValueError("Invalid artifact SHA256.")
    return decoded


def review(plan, revision):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full reviewed Git commit SHA is required.")
    if plan.get("errored") or plan.get("complete") is not True:
        raise ValueError("Only a complete, successful plan can be installed.")

    variables = _variables(plan)
    if any(variables.get(key, False) is not False for key in ("candidate3_rules_only_enabled", "governed_history_settlement_enabled")):
        raise ValueError("This candidate.1 workflow cannot activate candidate.3 or governed History.")
    expected_identity = ("dev", REGION, PROJECT, True, False, [])
    actual_identity = (
        variables.get("environment"),
        variables.get("aws_region"),
        variables.get("project_name"),
        variables.get("enabled"),
        variables.get("activate_rules_engineering"),
        variables.get("engineering_subjects"),
    )
    if actual_identity != expected_identity:
        raise ValueError("Installation must target only inactive Dev with an empty subject allowlist.")

    deployment = variables.get("deployment") or {}
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

    required_dependencies = {
        "users_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-users",
        "devices_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-device-bindings",
        "deletion_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-deletion-ledger",
        "authority_table_arn": f"arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-purchase-entitlements",
        "assessment_alias_arn": f"arn:aws:lambda:{REGION}:{ACCOUNT}:function:{PREFIX}-url-assessment:live",
    }
    if any(deployment.get(key) != value for key, value in required_dependencies.items()):
        raise ValueError("The plan must reuse the exact existing Dev authority and assessment resources.")
    secret_arn = deployment.get("authority_hmac_secret_arn", "")
    if not re.fullmatch(
        rf"arn:aws:secretsmanager:{REGION}:{ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]+",
        secret_arn,
    ):
        raise ValueError("The plan must reference the existing Dev authority key ring by ARN.")

    changes = {
        resource["address"]: resource
        for resource in plan.get("resource_changes", [])
        if resource.get("mode") == "managed"
    }
    if set(changes) != EXPECTED_ADDRESSES:
        unexpected = sorted(set(changes) ^ EXPECTED_ADDRESSES)
        raise ValueError(f"Unexpected installation resource set: {unexpected}.")
    for address, resource in changes.items():
        if resource.get("change", {}).get("actions") != ["create"]:
            raise ValueError(f"Installation may only create the reviewed resource: {address}.")

    for name in ("consumer", "evaluator"):
        address = f'aws_lambda_function.runtime["{name}"]'
        function = changes[address]["change"]["after"]
        artifact = artifacts[name]
        if any(
            function.get(key) != value
            for key, value in {
                "function_name": f"{PREFIX}-message-{name}",
                "runtime": "python3.14",
                "architectures": ["arm64"],
                "reserved_concurrent_executions": 2,
                "s3_bucket": artifact["bucket"],
                "s3_key": artifact["key"],
                "s3_object_version": artifact["object_version"],
                "source_code_hash": artifact["source_hash"],
            }.items()
        ):
            raise ValueError(f"The planned {name} runtime does not match the reviewed boundary.")
        environment = function.get("environment", [{}])[0].get("variables", {})
        common_gates = {
            "MESSAGE_AI_ENABLED": "false",
            "MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED": "false",
            "MESSAGE_AI_POLICY_VERSION": "message-ai-2026-09-21-v1",
        }
        if any(environment.get(key) != value for key, value in common_gates.items()):
            raise ValueError(f"The planned {name} runtime does not keep AI disabled.")
        if name == "consumer":
            expected_gates = {
                "MESSAGE_CONSUMER_ENABLED": "false",
                "GOVERNED_HISTORY_SETTLEMENT_ENABLED": "false",
                "AUTHORITY_ENABLED": "false",
                "MESSAGE_PROVIDER_CIRCUIT_OPEN": "true",
                "DEV_SUBJECT_ALLOWLIST_JSON": "[]",
            }
        else:
            expected_gates = {
                "MESSAGE_EVALUATOR_ENABLED": "false",
                "MESSAGE_PROPOSER_ENABLED": "false",
                "MESSAGE_AI_QUALIFIED": "false",
            }
        if any(environment.get(key) != value for key, value in expected_gates.items()):
            raise ValueError(f"The planned {name} runtime is not fully inactive.")
        forbidden = {
            "MESSAGE_PROPOSER_SECRET_ARN",
            "MESSAGE_PROPOSER_MODEL",
            "MESSAGE_AI_QUALIFICATION_ID",
        }
        if forbidden & set(environment):
            raise ValueError(f"The inactive {name} runtime includes forbidden provider configuration.")

    routes = {
        resource["change"]["after"].get("route_key")
        for address, resource in changes.items()
        if address.startswith("aws_apigatewayv2_route.message")
    }
    if routes != EXPECTED_ROUTES:
        raise ValueError("The plan must install only the three reviewed message routes.")
    for address, resource in changes.items():
        if address.startswith("aws_apigatewayv2_route.message"):
            route = resource["change"]["after"]
            if route.get("authorization_type") != "JWT" or route.get("authorization_scopes") != [
                "aws.cognito.signin.user.admin"
            ]:
                raise ValueError("Every message route must use the existing authenticated scope.")

    contract = plan.get("output_changes", {}).get("candidate_contract", {}).get("after") or {}
    expected_contract = {
        "provisioned": True,
        "consumer_enabled": False,
        "evaluator_enabled": False,
        "model_enabled": False,
        "ai_enabled": False,
        "ai_qualified": False,
        "engineering_subject_count": 0,
        "provider_circuit_open": True,
        "authority_reused": True,
        "secret_value_in_state": False,
        "daily_reporting_ready": False,
    }
    if any(contract.get(key) != value for key, value in expected_contract.items()):
        raise ValueError("The candidate output does not prove a fully inactive installation.")
    if set(contract.get("consumer_routes", [])) != EXPECTED_ROUTES:
        raise ValueError("Candidate output does not match the reviewed routes.")

    reviewed = {key: plan.get(key) for key in ("terraform_version", "variables", "output_changes", "checks")}
    for key in ("resource_changes", "resource_drift"):
        reviewed[key] = [resource for resource in plan.get(key, []) if resource.get("mode") == "managed"]
    reviewed["revision"] = revision
    fingerprint = hashlib.sha256(
        json.dumps(reviewed, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return artifacts, releases.pop(), fingerprint


def aws(*args):
    result = subprocess.run(
        ["aws", *args, "--region", REGION, "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def verify_artifacts(artifacts, read=aws):
    if read("sts", "get-caller-identity").get("Account") != ACCOUNT:
        raise ValueError("Unexpected AWS account; no artifact read performed.")
    with tempfile.TemporaryDirectory(prefix="message-artifacts-") as directory:
        for name, artifact in artifacts.items():
            path = Path(directory) / f"{name}.zip"
            metadata = read(
                "s3api",
                "get-object",
                "--bucket",
                artifact["bucket"],
                "--key",
                artifact["key"],
                "--version-id",
                artifact["object_version"],
                str(path),
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
    parser.add_argument("--expected-digest")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    artifacts, release, fingerprint = review(json.loads(args.plan.read_text()), args.revision)
    if args.apply and (not args.expected_digest or args.expected_digest != fingerprint):
        raise ValueError(
            "Apply requires the exact digest from the reviewed plan at this revision. Run plan again if state changed."
        )
    verify_artifacts(artifacts)
    print(
        json.dumps(
            {
                "reviewedPlanDigest": fingerprint,
                "revision": args.revision,
                "lambdaRelease": release,
                "resourceCreates": len(EXPECTED_ADDRESSES),
                "scope": "inactive-dev-message-installation",
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        detail = exc if isinstance(exc, ValueError) else type(exc).__name__
        raise SystemExit(f"Message installation rejected: {detail}")
