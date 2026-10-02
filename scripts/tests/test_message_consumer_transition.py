import base64
import copy
import hashlib
import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "message_transition",
    Path(__file__).resolve().parents[1] / "verify_message_consumer_transition.py",
)
transition = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transition)
REVISION = "b" * 40
RELEASE = "a" * 40
SUBJECT = "11111111-1111-4111-8111-111111111111"


def artifact(name, contents):
    return {
        "bucket": transition.BUCKET,
        "key": f"releases/{RELEASE}/message_{name}.zip",
        "object_version": f"{name}-version",
        "source_hash": base64.b64encode(hashlib.sha256(contents).digest()).decode(),
    }


ARTIFACTS = {
    "consumer": artifact("consumer", b"consumer"),
    "evaluator": artifact("evaluator", b"evaluator"),
}


def fixture(mode="inactive", changes=True):
    active = mode == "engineering"
    variables = {
        "environment": "dev",
        "aws_region": transition.REGION,
        "project_name": transition.PROJECT,
        "enabled": True,
        "activate_rules_engineering": active,
        "engineering_subjects": [SUBJECT] if active else [],
        "authority_configuration": {
            "operation_validity_seconds": 300,
            "worker_settlement_seconds": 60,
            "reconciliation_seconds": 3600,
            "counter_retention_seconds": 604800,
        },
        "provider_budget": {
            "window_seconds": 3600,
            "max_attempts_per_window": 20,
            "max_failures_per_window": 5,
        },
        "api_gateway": {
            "api_id": "icuak34th9",
            "execution_arn": f"arn:aws:execute-api:{transition.REGION}:{transition.ACCOUNT}:icuak34th9",
            "authorizer_id": "itms4b",
        },
        "deployment": {
            "artifacts": copy.deepcopy(ARTIFACTS),
            "users_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-users",
            "devices_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-device-bindings",
            "deletion_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-deletion-ledger",
            "authority_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-purchase-entitlements",
            "authority_hmac_secret_arn": f"arn:aws:secretsmanager:{transition.REGION}:{transition.ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-Test123",
            "assessment_alias_arn": f"arn:aws:lambda:{transition.REGION}:{transition.ACCOUNT}:function:{transition.PREFIX}-url-assessment:live",
            "cognito_issuer": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
            "cognito_app_client_id": "5kvl9a8jo4fr1qqnci27tdabk4",
        },
    }
    resources = []
    if changes:
        for name in ("consumer", "evaluator"):
            resources.append({
                "mode": "managed",
                "address": f'aws_lambda_function.runtime["{name}"]',
                "change": {
                    "actions": ["update"],
                    "before": {},
                    "after": {
                        "function_name": f"{transition.PREFIX}-message-{name}",
                        "runtime": "python3.14",
                        "architectures": ["arm64"],
                        "reserved_concurrent_executions": 2,
                        "memory_size": 256,
                        "timeout": 29 if name == "consumer" else 23,
                        "handler": f"message_{name}.app.lambda_handler",
                        "publish": True,
                        "role": f"arn:aws:iam::{transition.ACCOUNT}:role/{transition.PREFIX}-message-{name}-execution",
                        "s3_bucket": ARTIFACTS[name]["bucket"],
                        "s3_key": ARTIFACTS[name]["key"],
                        "s3_object_version": ARTIFACTS[name]["object_version"],
                        "source_code_hash": ARTIFACTS[name]["source_hash"],
                        "environment": [{"variables": transition._expected_environment(name, variables, active)}],
                    },
                },
            })
            resources.append({
                "mode": "managed",
                "address": f'aws_lambda_alias.runtime["{name}"]',
                "change": {
                    "actions": ["update"],
                    "before": {},
                    "after": {
                        "name": "live",
                        "function_name": f"{transition.PREFIX}-message-{name}",
                        "function_version": None,
                        "routing_config": [],
                    },
                },
            })
    contract = {
        "provisioned": True,
        "consumer_enabled": active,
        "evaluator_enabled": active,
        "model_enabled": False,
        "ai_enabled": False,
        "ai_qualified": False,
        "engineering_subject_count": 1 if active else 0,
        "provider_circuit_open": not active,
        "authority_reused": True,
        "secret_value_in_state": False,
        "daily_reporting_ready": False,
    }
    return {
        "complete": True,
        "errored": False,
        "terraform_version": "1.12.1",
        "variables": {key: {"value": value} for key, value in variables.items()},
        "resource_changes": resources,
        "output_changes": {"candidate_contract": {"after": contract}},
    }


class MessageConsumerTransitionTests(unittest.TestCase):
    def test_exact_inactive_update_and_noop_are_accepted(self):
        for changes in (True, False):
            with self.subTest(changes=changes):
                result = transition.review(fixture("inactive", changes), REVISION, "inactive")
                self.assertEqual(result[1], RELEASE)
                self.assertEqual(result[3], 4 if changes else 0)
                self.assertEqual(result[4], 0)

    def test_one_subject_engineering_activation_is_accepted(self):
        result = transition.review(fixture("engineering"), REVISION, "engineering")
        self.assertEqual(result[1], RELEASE)
        self.assertEqual(result[3:], (4, 1))

    def test_wrong_subject_budget_and_ai_configuration_are_rejected(self):
        two_subjects = fixture("engineering")
        two_subjects["variables"]["engineering_subjects"]["value"].append(
            "22222222-2222-4222-8222-222222222222"
        )
        budget = fixture("engineering")
        budget["variables"]["provider_budget"]["value"]["max_attempts_per_window"] = 200
        ai = fixture("engineering")
        consumer = next(item for item in ai["resource_changes"] if item["address"] == 'aws_lambda_function.runtime["consumer"]')
        consumer["change"]["after"]["environment"][0]["variables"]["MESSAGE_AI_ENABLED"] = "true"
        for plan in (two_subjects, budget, ai):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, "engineering")

    def test_partial_unexpected_and_destructive_changes_are_rejected(self):
        partial = fixture("engineering")
        partial["resource_changes"].pop()
        unexpected = fixture("engineering")
        unexpected["resource_changes"].append({
            "mode": "managed",
            "address": "aws_iam_role_policy.unreviewed",
            "change": {"actions": ["update"], "before": {}, "after": {}},
        })
        destructive = fixture("engineering")
        destructive["resource_changes"][0]["change"]["actions"] = ["delete", "create"]
        for plan in (partial, unexpected, destructive):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, "engineering")

    def test_artifact_versions_and_bytes_are_verified(self):
        paths = []

        def read(*args):
            if args[0] == "sts":
                return {"Account": transition.ACCOUNT}
            name = "consumer" if any("message_consumer.zip" in str(arg) for arg in args) else "evaluator"
            path = Path(args[-1])
            paths.append(path)
            path.write_bytes(name.encode())
            return {"VersionId": ARTIFACTS[name]["object_version"]}

        transition.verify_artifacts(ARTIFACTS, read)
        self.assertTrue(all(not path.exists() for path in paths))


if __name__ == "__main__":
    unittest.main()
