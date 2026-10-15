import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "complimentary_transition",
    Path(__file__).resolve().parents[1] / "verify_complimentary_operator_transition.py",
)
transition = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transition)
REVISION = "b" * 40
LAMBDA_RELEASE = "c" * 40
SECRET = (
    f"arn:aws:secretsmanager:{transition.REGION}:{transition.ACCOUNT}:"
    "secret:trustcheckradar/dev/v1-authority-hmac-Test123"
)
BODY = b"entitlements-package"
ARTIFACT = {
    "bucket": transition.BUCKET,
    "key": f"releases/{LAMBDA_RELEASE}/v1_entitlements.zip",
    "object_version": "version-232",
    "source_hash": base64.b64encode(hashlib.sha256(BODY).digest()).decode(),
}


def fixture():
    variables = {
        "environment": "dev",
        "aws_region": transition.REGION,
        "project_name": "trustcheckradar",
        "enabled": True,
        "activate_engineering": False,
        "activate_access_engineering": False,
        "activate_trial_engineering": False,
        "engineering_subjects": [],
        "authority_configuration": {
            "operation_validity_seconds": 300,
            "worker_settlement_seconds": 60,
            "reconciliation_seconds": 3600,
            "counter_retention_seconds": 604800,
        },
        "api_gateway": {
            "api_id": transition.API_ID,
            "execution_arn": f"arn:aws:execute-api:{transition.REGION}:{transition.ACCOUNT}:{transition.API_ID}",
        },
        "complimentary_operator": {
            "active": True,
            "trusted_assumer_arn": transition.TRUSTED_ASSUMER,
            "api_stage_name": "$default",
            "approval_reference": "SECUR4ALL-232 owner-approved operator control and one-year audit retention",
        },
        "entitlements_artifact_override": {
            "source_sha": LAMBDA_RELEASE,
            "provenance_reference": "docs/evidence/sec232-complimentary-operator-publication.json",
            "artifact": copy.deepcopy(ARTIFACT),
        },
        "deployment": {
            "cognito_issuer": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
            "cognito_app_client_id": "5kvl9a8jo4fr1qqnci27tdabk4",
        },
    }
    role_trust = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "ExactReviewedAdministrator", "Effect": "Allow", "Action": "sts:AssumeRole",
            "Principal": {"AWS": transition.TRUSTED_ASSUMER},
        }],
    }
    role_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "InvokeExactOperatorRoute", "Effect": "Allow",
            "Action": "execute-api:Invoke", "Resource": transition.ROUTE_ARN,
        }],
    }
    environment = transition._expected_environment(variables, SECRET)
    changes = [
        {"mode": "managed", "address": "aws_iam_role.complimentary_operator[0]", "change": {
            "actions": ["create"], "after": {"name": f"{transition.PREFIX}-complimentary-operator",
                                                "max_session_duration": 3600,
                                                "assume_role_policy": json.dumps(role_trust)}}},
        {"mode": "managed", "address": "aws_iam_role_policy.complimentary_operator[0]", "change": {
            "actions": ["create"], "after": {"policy": json.dumps(role_policy)}}},
        {"mode": "managed", "address": "aws_apigatewayv2_route.complimentary_operator[0]", "change": {
            "actions": ["create"], "after": {"api_id": transition.API_ID,
                                                "route_key": "POST /v1/operator/complimentary-access",
                                                "authorization_type": "AWS_IAM"}}},
        {"mode": "managed", "address": "aws_lambda_permission.complimentary_operator[0]", "change": {
            "actions": ["create"], "after": {
                "action": "lambda:InvokeFunction", "function_name": f"{transition.PREFIX}-v1-entitlements",
                "qualifier": "live", "principal": "apigateway.amazonaws.com",
                "source_account": transition.ACCOUNT, "source_arn": transition.ROUTE_ARN,
            }}},
        {"mode": "managed", "address": 'aws_lambda_function.runtime["entitlements"]', "change": {
            "actions": ["update"], "after": {
                "function_name": f"{transition.PREFIX}-v1-entitlements", "runtime": "python3.14",
                "architectures": ["arm64"], "reserved_concurrent_executions": 2,
                "memory_size": 256, "timeout": 10, "handler": "v1_entitlements.app.lambda_handler",
                "publish": True,
                "role": f"arn:aws:iam::{transition.ACCOUNT}:role/{transition.PREFIX}-v1-entitlements-execution",
                "s3_bucket": ARTIFACT["bucket"], "s3_key": ARTIFACT["key"],
                "s3_object_version": ARTIFACT["object_version"], "source_code_hash": ARTIFACT["source_hash"],
                "environment": [{"variables": environment}],
            }}},
        {"mode": "managed", "address": 'aws_lambda_alias.runtime["entitlements"]', "change": {
            "actions": ["update"], "after": {"name": "live",
                                                "function_name": f"{transition.PREFIX}-v1-entitlements",
                                                "routing_config": []}}},
    ]
    contract = {
        "provisioned": True, "consumer_enabled": False, "recovery_enabled": False,
        "access_enabled": False, "deletion_enabled": True, "trial_activation_enabled": False,
        "access_only_engineering": False, "trial_only_engineering": False,
        "complimentary_operator_provisioned": True, "complimentary_operator_active": True,
        "complimentary_operator_role_arn": transition.OPERATOR_ROLE,
        "complimentary_operator_route": "POST /v1/operator/complimentary-access",
        "general_customer_access": False, "engineering_subject_count": 0,
        "secret_value_in_state": False,
    }
    return {
        "complete": True, "errored": False, "terraform_version": "1.12.1",
        "variables": {key: {"value": value} for key, value in variables.items()},
        "resource_changes": changes,
        "output_changes": {"candidate_contract": {"after": contract}},
    }


class ComplimentaryOperatorTransitionTests(unittest.TestCase):
    def test_exact_transition_is_accepted(self):
        artifact, digest, count = transition.review(fixture(), REVISION, LAMBDA_RELEASE)
        self.assertEqual(artifact, ARTIFACT)
        self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertEqual(count, 6)

    def test_unexpected_resource_or_mobile_gate_is_rejected(self):
        unexpected = fixture()
        unexpected["resource_changes"].append({
            "mode": "managed", "address": "aws_dynamodb_table.unreviewed",
            "change": {"actions": ["create"], "after": {}},
        })
        mobile = fixture()
        mobile["variables"]["activate_engineering"]["value"] = True
        for plan in (unexpected, mobile):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, LAMBDA_RELEASE)

    def test_wildcard_policy_or_jwt_route_is_rejected(self):
        wildcard = fixture()
        policy = wildcard["resource_changes"][1]["change"]["after"]
        decoded = json.loads(policy["policy"])
        decoded["Statement"][0]["Resource"] = decoded["Statement"][0]["Resource"].replace("/$default/POST/", "/*/*/")
        policy["policy"] = json.dumps(decoded)
        jwt = fixture()
        jwt["resource_changes"][2]["change"]["after"]["authorization_type"] = "JWT"
        for plan in (wildcard, jwt):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, LAMBDA_RELEASE)

    def test_wrong_artifact_or_open_trial_is_rejected(self):
        wrong_artifact = fixture()
        wrong_artifact["variables"]["entitlements_artifact_override"]["value"]["artifact"]["key"] = "releases/x/v1_entitlements.zip"
        trial = fixture()
        function = trial["resource_changes"][4]["change"]["after"]
        function["environment"][0]["variables"]["TRIAL_AUTHORITY_RETENTION_APPROVED"] = "true"
        for plan in (wrong_artifact, trial):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, LAMBDA_RELEASE)

    def test_artifact_bytes_are_verified_and_temp_file_removed(self):
        paths = []
        def read(*args):
            if args[0] == "sts":
                return {"Account": transition.ACCOUNT}
            path = Path(args[-1])
            paths.append(path)
            path.write_bytes(BODY)
            return {"VersionId": ARTIFACT["object_version"]}
        transition.verify_artifact(ARTIFACT, read)
        self.assertTrue(all(not path.exists() for path in paths))


if __name__ == "__main__":
    unittest.main()
