import base64
import copy
import hashlib
import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "message_release",
    Path(__file__).resolve().parents[1] / "verify_message_consumer_release.py",
)
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
REVISION = "b" * 40
LAMBDA_RELEASE = "a" * 40


def artifact(name, contents):
    return {
        "bucket": release.BUCKET,
        "key": f"releases/{LAMBDA_RELEASE}/message_{name}.zip",
        "object_version": f"{name}-version",
        "source_hash": base64.b64encode(hashlib.sha256(contents).digest()).decode(),
    }


ARTIFACTS = {
    "consumer": artifact("consumer", b"consumer"),
    "evaluator": artifact("evaluator", b"evaluator"),
}


def fixture():
    variables = {
        "environment": "dev",
        "aws_region": release.REGION,
        "project_name": release.PROJECT,
        "enabled": True,
        "activate_rules_engineering": False,
        "engineering_subjects": [],
        "deployment": {
            "artifacts": copy.deepcopy(ARTIFACTS),
            "users_table_arn": f"arn:aws:dynamodb:{release.REGION}:{release.ACCOUNT}:table/{release.PREFIX}-users",
            "devices_table_arn": f"arn:aws:dynamodb:{release.REGION}:{release.ACCOUNT}:table/{release.PREFIX}-device-bindings",
            "deletion_table_arn": f"arn:aws:dynamodb:{release.REGION}:{release.ACCOUNT}:table/{release.PREFIX}-deletion-ledger",
            "authority_table_arn": f"arn:aws:dynamodb:{release.REGION}:{release.ACCOUNT}:table/{release.PREFIX}-purchase-entitlements",
            "authority_hmac_secret_arn": f"arn:aws:secretsmanager:{release.REGION}:{release.ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-Test123",
            "assessment_alias_arn": f"arn:aws:lambda:{release.REGION}:{release.ACCOUNT}:function:{release.PREFIX}-url-assessment:live",
        },
    }
    resources = []
    for address in sorted(release.EXPECTED_ADDRESSES):
        after = {}
        if address.startswith("aws_apigatewayv2_route.message"):
            name = address.split('"')[1]
            suffix = {"prepare": "/prepare", "reconcile": "/reconcile", "submit": ""}[name]
            after = {
                "route_key": f"POST /v1/message-checks{suffix}",
                "authorization_type": "JWT",
                "authorization_scopes": ["aws.cognito.signin.user.admin"],
            }
        if address.startswith("aws_lambda_function.runtime"):
            name = address.split('"')[1]
            environment = {
                "MESSAGE_AI_ENABLED": "false",
                "MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED": "false",
                "MESSAGE_AI_POLICY_VERSION": "message-ai-2026-09-21-v1",
            }
            if name == "consumer":
                environment.update(
                    {
                        "MESSAGE_CONSUMER_ENABLED": "false",
                        "GOVERNED_HISTORY_SETTLEMENT_ENABLED": "false",
                        "AUTHORITY_ENABLED": "false",
                        "MESSAGE_PROVIDER_CIRCUIT_OPEN": "true",
                        "DEV_SUBJECT_ALLOWLIST_JSON": "[]",
                    }
                )
            else:
                environment.update(
                    {
                        "MESSAGE_EVALUATOR_ENABLED": "false",
                        "MESSAGE_PROPOSER_ENABLED": "false",
                        "MESSAGE_AI_QUALIFIED": "false",
                    }
                )
            after = {
                "function_name": f"{release.PREFIX}-message-{name}",
                "runtime": "python3.14",
                "architectures": ["arm64"],
                "reserved_concurrent_executions": 2,
                "s3_bucket": ARTIFACTS[name]["bucket"],
                "s3_key": ARTIFACTS[name]["key"],
                "s3_object_version": ARTIFACTS[name]["object_version"],
                "source_code_hash": ARTIFACTS[name]["source_hash"],
                "environment": [{"variables": environment}],
            }
        resources.append(
            {
                "mode": "managed",
                "address": address,
                "change": {"actions": ["create"], "before": None, "after": after},
            }
        )
    contract = {
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
        "consumer_routes": sorted(release.EXPECTED_ROUTES),
    }
    return {
        "complete": True,
        "errored": False,
        "terraform_version": "1.12.1",
        "variables": {key: {"value": value} for key, value in variables.items()},
        "resource_changes": resources,
        "output_changes": {"candidate_contract": {"after": contract}},
    }


class MessageConsumerReleaseTests(unittest.TestCase):
    def test_existing_workflow_rejects_new_history_or_candidate3_activation(self):
        for gate in ("candidate3_rules_only_enabled", "governed_history_settlement_enabled"):
            for value in (True, "true", 1, None):
                with self.subTest(gate=gate, value=value):
                    plan = fixture()
                    plan["variables"][gate] = {"value": value}
                    with self.assertRaises(ValueError):
                        release.review(plan, REVISION)

    def test_exact_inactive_installation_and_digest_are_accepted(self):
        plan = fixture()
        artifacts, lambda_release, digest = release.review(plan, REVISION)
        self.assertEqual(artifacts, ARTIFACTS)
        self.assertEqual(lambda_release, LAMBDA_RELEASE)
        self.assertEqual(len(digest), 64)
        plan["timestamp"] = "ignored"
        self.assertEqual(release.review(plan, REVISION)[2], digest)

    def test_activation_provider_configuration_and_mutation_are_rejected(self):
        cases = []
        activated = fixture()
        activated["variables"]["activate_rules_engineering"]["value"] = True
        cases.append(activated)
        provider = fixture()
        function = next(
            item
            for item in provider["resource_changes"]
            if item["address"] == 'aws_lambda_function.runtime["evaluator"]'
        )
        function["change"]["after"]["environment"][0]["variables"]["MESSAGE_PROPOSER_SECRET_ARN"] = "secret"
        cases.append(provider)
        mutation = fixture()
        mutation["resource_changes"][0]["change"]["actions"] = ["update"]
        cases.append(mutation)
        for plan in cases:
            with self.subTest(plan=plan), self.assertRaises(ValueError):
                release.review(plan, REVISION)

    def test_unexpected_resource_route_and_mixed_release_are_rejected(self):
        unexpected = fixture()
        unexpected["resource_changes"].append(
            {
                "mode": "managed",
                "address": "aws_s3_bucket.unreviewed",
                "change": {"actions": ["create"], "before": None, "after": {}},
            }
        )
        bad_route = fixture()
        route = next(
            item for item in bad_route["resource_changes"] if item["address"].startswith("aws_apigatewayv2_route")
        )
        route["change"]["after"]["authorization_type"] = "NONE"
        mixed = fixture()
        mixed["variables"]["deployment"]["value"]["artifacts"]["evaluator"]["key"] = (
            f"releases/{'c' * 40}/message_evaluator.zip"
        )
        for plan in (unexpected, bad_route, mixed):
            with self.subTest(plan=plan), self.assertRaises(ValueError):
                release.review(plan, REVISION)

    def test_artifact_versions_and_bytes_are_verified(self):
        paths = []

        def read(*args):
            if args[0] == "sts":
                return {"Account": release.ACCOUNT}
            name = "consumer" if any("message_consumer.zip" in str(arg) for arg in args) else "evaluator"
            path = Path(args[-1])
            paths.append(path)
            path.write_bytes(name.encode())
            return {"VersionId": ARTIFACTS[name]["object_version"]}

        release.verify_artifacts(ARTIFACTS, read)
        self.assertTrue(all(not path.exists() for path in paths))
        with self.assertRaises(ValueError):
            release.verify_artifacts(ARTIFACTS, lambda *args: {"Account": "999999999999"})


if __name__ == "__main__":
    unittest.main()
