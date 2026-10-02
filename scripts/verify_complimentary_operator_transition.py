#!/usr/bin/env python3
"""Validate the exact Dev complimentary-access operator transition."""
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
PREFIX = "trustcheckradar-dev"
BUCKET = f"{PREFIX}-{ACCOUNT}-artifacts"
API_ID = "icuak34th9"
OPERATOR_ROLE = f"arn:aws:iam::{ACCOUNT}:role/{PREFIX}-complimentary-operator"
TRUSTED_ASSUMER = (
    f"arn:aws:iam::{ACCOUNT}:role/aws-reserved/sso.amazonaws.com/"
    "AWSReservedSSO_AdministratorAccess_6659317f1273c022"
)
ROUTE_ARN = f"arn:aws:execute-api:{REGION}:{ACCOUNT}:{API_ID}/$default/POST/v1/operator/complimentary-access"
ALLOWED_CHANGES = {
    "aws_iam_role.complimentary_operator[0]": ["create"],
    "aws_iam_role_policy.complimentary_operator[0]": ["create"],
    "aws_apigatewayv2_route.complimentary_operator[0]": ["create"],
    "aws_lambda_permission.complimentary_operator[0]": ["create"],
    'aws_lambda_function.runtime["entitlements"]': ["update"],
    'aws_lambda_alias.runtime["entitlements"]': ["update"],
}


def _variables(plan):
    return {key: value.get("value") for key, value in plan.get("variables", {}).items()}


def _canonical_json(value):
    return json.loads(value) if isinstance(value, str) else value


def _artifact(variables, release):
    override = variables.get("entitlements_artifact_override") or {}
    artifact = override.get("artifact") or {}
    if override.get("source_sha") != release:
        raise ValueError("Entitlements override must identify the reviewed Lambda release.")
    if artifact.get("bucket") != BUCKET or artifact.get("key") != f"releases/{release}/v1_entitlements.zip":
        raise ValueError("Entitlements artifact must use the exact immutable Dev release object.")
    if not artifact.get("object_version") or artifact.get("object_version") == "null":
        raise ValueError("An exact entitlements object version is required.")
    try:
        digest = base64.b64decode(artifact.get("source_hash"), validate=True)
    except (TypeError, ValueError) as exc:
        raise ValueError("Invalid entitlements source hash.") from exc
    if len(digest) != 32:
        raise ValueError("Invalid entitlements source hash.")
    if override.get("provenance_reference") != "docs/evidence/sec232-complimentary-operator-publication.json":
        raise ValueError("Exact SECUR4ALL-232 publication provenance is required.")
    return artifact


def _expected_environment(variables, secret_arn):
    authority = variables["authority_configuration"]
    return {
        "STAGE": "dev",
        "AUTHORITY_TABLE_NAME": f"{PREFIX}-purchase-entitlements",
        "CONSUMER_ENABLED": "false",
        "AUTHORITY_ENABLED": "true",
        "V1_ENTITLEMENTS_ENABLED": "true",
        "TRIAL_AUTHORITY_RETENTION_APPROVED": "false",
        "USERS_TABLE_NAME": f"{PREFIX}-users",
        "DEVICE_BINDINGS_TABLE_NAME": f"{PREFIX}-device-bindings",
        "DELETION_LEDGER_TABLE_NAME": f"{PREFIX}-deletion-ledger",
        "COGNITO_ISSUER": variables["deployment"]["cognito_issuer"],
        "COGNITO_APP_CLIENT_ID": variables["deployment"]["cognito_app_client_id"],
        "COGNITO_REQUIRED_SCOPE": "aws.cognito.signin.user.admin",
        "AUTHORITY_HMAC_SECRET_ARN": secret_arn,
        "AUTHORITY_POLICY_VERSION": "owner-2026-09-20-v1",
        "DEV_SUBJECT_ALLOWLIST_JSON": "[]",
        "COMPLIMENTARY_OPERATOR_ENABLED": "true",
        "COMPLIMENTARY_AUDIT_RETENTION_SECONDS": "31536000",
        "COMPLIMENTARY_OPERATOR_PRINCIPAL_ARNS_JSON": json.dumps([OPERATOR_ROLE], separators=(",", ":")),
        "OPERATION_VALIDITY_SECONDS": str(authority["operation_validity_seconds"]),
        "WORKER_SETTLEMENT_SECONDS": str(authority["worker_settlement_seconds"]),
        "RECONCILIATION_SECONDS": str(authority["reconciliation_seconds"]),
        "RECEIPT_RETENTION_SECONDS": "604800",
        "COUNTER_RETENTION_SECONDS": str(authority["counter_retention_seconds"]),
        "ATTEMPT_WINDOW_SECONDS": "60",
        "ATTEMPTS_PER_WINDOW": "20",
        "MAX_INFLIGHT": "2",
    }


def review(plan, revision, lambda_release):
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or not re.fullmatch(r"[0-9a-f]{40}", lambda_release):
        raise ValueError("Full infrastructure and Lambda commit IDs are required.")
    if plan.get("errored") or plan.get("complete") is not True:
        raise ValueError("Only a complete successful plan can be reviewed.")
    variables = _variables(plan)
    if any(variables.get(key) != value for key, value in {
        "environment": "dev", "aws_region": REGION, "project_name": "trustcheckradar", "enabled": True,
        "activate_engineering": False, "activate_access_engineering": False,
        "activate_trial_engineering": False, "engineering_subjects": [],
    }.items()):
        raise ValueError("Consumer and mobile engineering gates must remain closed.")
    if variables.get("authority_configuration") != {
        "operation_validity_seconds": 300, "worker_settlement_seconds": 60,
        "reconciliation_seconds": 3600, "counter_retention_seconds": 604800,
    }:
        raise ValueError("Authority horizons do not match the approved policy.")
    if variables.get("api_gateway") != {
        "api_id": API_ID, "execution_arn": f"arn:aws:execute-api:{REGION}:{ACCOUNT}:{API_ID}",
    }:
        raise ValueError("The operator must use the reviewed Dev API.")
    operator = variables.get("complimentary_operator") or {}
    if operator != {
        "active": True,
        "trusted_assumer_arn": TRUSTED_ASSUMER,
        "api_stage_name": "$default",
        "approval_reference": "SECUR4ALL-232 owner-approved operator control and one-year audit retention",
    }:
        raise ValueError("Complimentary operator configuration does not match the reviewed control.")
    artifact = _artifact(variables, lambda_release)

    changes = {
        item["address"]: item for item in plan.get("resource_changes", [])
        if item.get("mode") == "managed" and item.get("change", {}).get("actions") != ["no-op"]
    }
    if set(changes) != set(ALLOWED_CHANGES):
        raise ValueError(f"Unexpected operator transition resource set: {sorted(changes)}.")
    for address, actions in ALLOWED_CHANGES.items():
        if changes[address]["change"].get("actions") != actions:
            raise ValueError(f"Unexpected action for {address}.")

    role = changes["aws_iam_role.complimentary_operator[0]"]["change"]["after"]
    trust = _canonical_json(role.get("assume_role_policy"))
    if (role.get("name") != f"{PREFIX}-complimentary-operator" or role.get("max_session_duration") != 3600
            or trust != {"Version": "2012-10-17", "Statement": [{
                "Sid": "ExactReviewedAdministrator", "Effect": "Allow", "Action": "sts:AssumeRole",
                "Principal": {"AWS": TRUSTED_ASSUMER},
            }]}):
        raise ValueError("Operator role trust or session boundary changed.")

    policy = _canonical_json(changes["aws_iam_role_policy.complimentary_operator[0]"]["change"]["after"].get("policy"))
    if policy != {"Version": "2012-10-17", "Statement": [{
        "Sid": "InvokeExactOperatorRoute", "Effect": "Allow",
        "Action": "execute-api:Invoke", "Resource": ROUTE_ARN,
    }]}:
        raise ValueError("Operator policy exceeds the exact route.")

    route = changes["aws_apigatewayv2_route.complimentary_operator[0]"]["change"]["after"]
    if route.get("api_id") != API_ID or route.get("route_key") != "POST /v1/operator/complimentary-access" or route.get("authorization_type") != "AWS_IAM":
        raise ValueError("Operator route must be the exact AWS_IAM path.")
    permission = changes["aws_lambda_permission.complimentary_operator[0]"]["change"]["after"]
    if any(permission.get(key) != value for key, value in {
        "action": "lambda:InvokeFunction", "function_name": f"{PREFIX}-v1-entitlements",
        "qualifier": "live", "principal": "apigateway.amazonaws.com",
        "source_account": ACCOUNT, "source_arn": ROUTE_ARN,
    }.items()):
        raise ValueError("Lambda invoke permission exceeds the exact API route.")

    function = changes['aws_lambda_function.runtime["entitlements"]']["change"]["after"]
    expected_function = {
        "function_name": f"{PREFIX}-v1-entitlements", "runtime": "python3.14",
        "architectures": ["arm64"], "reserved_concurrent_executions": 2,
        "memory_size": 256, "timeout": 10, "handler": "v1_entitlements.app.lambda_handler",
        "publish": True, "role": f"arn:aws:iam::{ACCOUNT}:role/{PREFIX}-v1-entitlements-execution",
        "s3_bucket": artifact["bucket"], "s3_key": artifact["key"],
        "s3_object_version": artifact["object_version"], "source_code_hash": artifact["source_hash"],
    }
    if any(function.get(key) != value for key, value in expected_function.items()):
        raise ValueError("Entitlements runtime exceeds the reviewed artifact/configuration boundary.")
    environment = function.get("environment", [{}])[0].get("variables", {})
    secret_arn = environment.get("AUTHORITY_HMAC_SECRET_ARN", "")
    if not re.fullmatch(rf"arn:aws:secretsmanager:{REGION}:{ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]+", secret_arn):
        raise ValueError("The existing exact Dev authority key ring is required.")
    if environment != _expected_environment(variables, secret_arn):
        raise ValueError("Entitlements environment does not match the reviewed operator gate.")
    alias = changes['aws_lambda_alias.runtime["entitlements"]']["change"]["after"]
    if alias.get("name") != "live" or alias.get("function_name") != f"{PREFIX}-v1-entitlements" or alias.get("routing_config") not in (None, []):
        raise ValueError("Entitlements alias transition is outside the reviewed boundary.")

    contract = plan.get("output_changes", {}).get("candidate_contract", {}).get("after") or {}
    expected_contract = {
        "provisioned": True, "consumer_enabled": False, "recovery_enabled": False,
        "access_enabled": False, "deletion_enabled": True, "trial_activation_enabled": False,
        "access_only_engineering": False, "trial_only_engineering": False,
        "complimentary_operator_provisioned": True, "complimentary_operator_active": True,
        "complimentary_operator_role_arn": OPERATOR_ROLE,
        "complimentary_operator_route": "POST /v1/operator/complimentary-access",
        "general_customer_access": False, "engineering_subject_count": 0,
        "secret_value_in_state": False,
    }
    if any(contract.get(key) != value for key, value in expected_contract.items()):
        raise ValueError("Candidate output does not match the operator-only activation.")

    reviewed = {key: plan.get(key) for key in ("terraform_version", "variables", "output_changes", "checks")}
    for key in ("resource_changes", "resource_drift"):
        reviewed[key] = [item for item in plan.get(key, []) if item.get("mode") == "managed"]
    reviewed.update(revision=revision, lambdaRelease=lambda_release)
    digest = hashlib.sha256(json.dumps(reviewed, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return artifact, digest, len(changes)


def aws(*args):
    result = subprocess.run(["aws", *args, "--region", REGION, "--output", "json"], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def verify_artifact(artifact, read=aws):
    if read("sts", "get-caller-identity").get("Account") != ACCOUNT:
        raise ValueError("Unexpected AWS account.")
    with tempfile.TemporaryDirectory(prefix="sec232-entitlements-") as directory:
        path = Path(directory) / "v1_entitlements.zip"
        metadata = read("s3api", "get-object", "--bucket", artifact["bucket"], "--key", artifact["key"],
                        "--version-id", artifact["object_version"], str(path))
        if metadata.get("VersionId") != artifact["object_version"]:
            raise ValueError("Downloaded artifact version does not match.")
        actual = base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode()
        if actual != artifact["source_hash"]:
            raise ValueError("Downloaded artifact checksum does not match.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--lambda-release", required=True)
    parser.add_argument("--expected-digest")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    artifact, digest, changes = review(json.loads(args.plan.read_text()), args.revision, args.lambda_release)
    if args.apply and (not args.expected_digest or args.expected_digest != digest):
        raise ValueError("Apply requires the exact reviewed plan digest at this revision.")
    verify_artifact(artifact)
    print(json.dumps({"reviewedPlanDigest": digest, "revision": args.revision,
                      "lambdaRelease": args.lambda_release, "resourceChanges": changes,
                      "scope": "dev-complimentary-access-operator"}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        detail = exc if isinstance(exc, ValueError) else type(exc).__name__
        raise SystemExit(f"Complimentary operator transition rejected: {detail}")
