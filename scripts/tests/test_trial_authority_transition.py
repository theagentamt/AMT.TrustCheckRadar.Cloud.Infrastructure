import base64
import copy
import hashlib
import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "trial_transition",
    Path(__file__).resolve().parents[1] / "verify_trial_authority_transition.py",
)
transition = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transition)
REVISION = "b" * 40
SUBJECT = "01997e3a-0000-7000-8000-000000000001"
EXISTING = "c4685448-1021-7014-8ef4-b326afee90ae"
SECRET = f"arn:aws:secretsmanager:{transition.REGION}:{transition.ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-Test123"


def artifact(name, filename):
    contents = name.encode()
    return {
        "bucket": transition.BUCKET,
        "key": f"releases/{'a' * 40}/{filename}",
        "object_version": f"{name}-version",
        "source_hash": base64.b64encode(hashlib.sha256(contents).digest()).decode(),
    }


ARTIFACTS = {
    "entitlements": artifact("entitlements", "v1_entitlements.zip"),
    "recovery": artifact("recovery", "url_lease_recovery.zip"),
    "deletion": artifact("deletion", "v1_authority_deletion.zip"),
}


def fixture(mode="trial"):
    active = mode == "trial"
    variables = {
        "environment": "dev",
        "aws_region": transition.REGION,
        "project_name": "trustcheckradar",
        "enabled": True,
        "activate_engineering": False,
        "activate_access_engineering": False,
        "activate_trial_engineering": active,
        "engineering_subjects": [SUBJECT] if active else [],
        "access_qualification_reference": "SECUR4ALL-230 reviewed synthetic Dev qualification" if active else "",
        "authority_configuration": {
            "operation_validity_seconds": 300,
            "worker_settlement_seconds": 60,
            "reconciliation_seconds": 3600,
            "counter_retention_seconds": 604800,
        },
        "api_gateway": {
            "api_id": "icuak34th9",
            "execution_arn": f"arn:aws:execute-api:{transition.REGION}:{transition.ACCOUNT}:icuak34th9",
        },
        "alert_topic_arn": f"arn:aws:sns:{transition.REGION}:{transition.ACCOUNT}:{transition.PREFIX}-url-resolver-alerts",
        "deletion_stream_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-deletion-ledger/stream/2026-09-06T23:20:47.091",
        "deletion_activation": {
            "source_sha": "9123459a5c2bc9503d56235b2cb1f1e162c00da1",
            "subjects": [EXISTING],
            "inventory_reference": "docs/evidence/live-account-deletion-2026-09-26/account-qualified-manifest.json",
            "runtime_reference": "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
            "permissions_reference": "docs/evidence/live-account-deletion-2026-09-26/account-writer-binding-review.md",
        },
        "deployment": {
            "artifacts": copy.deepcopy(ARTIFACTS),
            "users_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-users",
            "devices_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-device-bindings",
            "deletion_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-deletion-ledger",
            "authority_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-purchase-entitlements",
            "assessment_alias_arn": f"arn:aws:lambda:{transition.REGION}:{transition.ACCOUNT}:function:{transition.PREFIX}-url-assessment:live",
            "cognito_issuer": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
            "cognito_app_client_id": "5kvl9a8jo4fr1qqnci27tdabk4",
        },
    }
    changes = []
    for name in transition.FUNCTIONS:
        suffix, timeout, concurrency, handler = {
            "entitlements": ("v1-entitlements", 10, 2, "v1_entitlements.app.lambda_handler"),
            "recovery": ("url-lease-recovery", 15, 1, "app.lambda_handler"),
            "deletion": ("v1-authority-deletion", 30, 1, "v1_authority_deletion.app.lambda_handler"),
        }[name]
        changes.append({
            "mode": "managed",
            "address": f'aws_lambda_function.runtime["{name}"]',
            "change": {"actions": ["update"], "after": {
                "function_name": f"{transition.PREFIX}-{suffix}", "runtime": "python3.14",
                "architectures": ["arm64"], "reserved_concurrent_executions": concurrency,
                "memory_size": 256, "timeout": timeout, "handler": handler, "publish": True,
                "role": f"arn:aws:iam::{transition.ACCOUNT}:role/{transition.PREFIX}-{suffix}-execution",
                "s3_bucket": ARTIFACTS[name]["bucket"], "s3_key": ARTIFACTS[name]["key"],
                "s3_object_version": ARTIFACTS[name]["object_version"], "source_code_hash": ARTIFACTS[name]["source_hash"],
                "environment": [{"variables": transition._expected_environment(name, variables, active, SECRET if name != "recovery" else "")}],
            }},
        })
    contract = {
        "provisioned": True, "consumer_enabled": False, "recovery_enabled": active,
        "access_enabled": active, "deletion_enabled": True, "trial_activation_enabled": active,
        "access_only_engineering": False, "trial_only_engineering": active,
        "general_customer_access": False, "engineering_subject_count": 1 if active else 0,
        "secret_value_in_state": False,
    }
    return {
        "complete": True, "errored": False, "terraform_version": "1.12.1",
        "variables": {key: {"value": value} for key, value in variables.items()},
        "resource_changes": changes,
        "output_changes": {"candidate_contract": {"after": contract}},
    }


class TrialAuthorityTransitionTests(unittest.TestCase):
    def test_uuid7_trial_and_inactive_modes_are_accepted(self):
        self.assertEqual(transition.review(fixture("trial"), REVISION, "trial")[3], 1)
        self.assertEqual(transition.review(fixture("inactive"), REVISION, "inactive")[3], 0)

    def test_invalid_subject_or_trial_gate_is_rejected(self):
        invalid = fixture()
        invalid["variables"]["engineering_subjects"]["value"] = ["not-a-uuid"]
        wrong_gate = fixture()
        wrong_gate["variables"]["activate_engineering"]["value"] = True
        for plan in (invalid, wrong_gate):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, "trial")

    def test_unexpected_or_destructive_change_is_rejected(self):
        unexpected = fixture()
        unexpected["resource_changes"].append({"mode": "managed", "address": "aws_iam_role.unreviewed", "change": {"actions": ["update"], "after": {}}})
        destructive = fixture()
        destructive["resource_changes"][0]["change"]["actions"] = ["delete", "create"]
        for plan in (unexpected, destructive):
            with self.subTest(), self.assertRaises(ValueError):
                transition.review(plan, REVISION, "trial")

    def test_artifact_bytes_are_verified(self):
        paths = []

        def read(*args):
            if args[0] == "sts":
                return {"Account": transition.ACCOUNT}
            name = next(name for name in transition.FUNCTIONS if name in str(args[-1]))
            path = Path(args[-1])
            paths.append(path)
            path.write_bytes(name.encode())
            return {"VersionId": ARTIFACTS[name]["object_version"]}

        transition.verify_artifacts(ARTIFACTS, read)
        self.assertTrue(all(not path.exists() for path in paths))


if __name__ == "__main__":
    unittest.main()
