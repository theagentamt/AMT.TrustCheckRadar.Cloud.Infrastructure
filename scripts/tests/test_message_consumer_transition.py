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
SUBJECT = "01997e3a-0000-7000-8000-000000000001"


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
        "authority_maintenance": {
            "schema_version": 1, "environment": "dev",
            "authority_table_arn": f"arn:aws:dynamodb:{transition.REGION}:{transition.ACCOUNT}:table/{transition.PREFIX}-purchase-entitlements",
            "recovery_alias_arn": f"arn:aws:lambda:{transition.REGION}:{transition.ACCOUNT}:function:{transition.PREFIX}-url-lease-recovery:live",
            "recovery_version": "11", "recovery_code_sha256": "A" * 43 + "=",
            "worker_enabled": True, "schedule_enabled": True, "heartbeat_enforced": True,
            "provider_access_added": False,
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
    for name in ("consumer", "evaluator"):
        resources.append({
            "mode": "managed",
            "address": f'aws_lambda_function.runtime["{name}"]',
            "change": {
                "actions": ["update"] if changes else ["no-op"],
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
                    "version": "7",
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
                "actions": ["update"] if changes else ["no-op"],
                "before": {},
                "after": {
                    "name": "live",
                    "function_name": f"{transition.PREFIX}-message-{name}",
                    "function_version": "7",
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
    for item in resources:
        if item['change']['actions'] == ['no-op']:
            item['change']['before'] = copy.deepcopy(item['change']['after'])
    return {
        "planned_values": {"root_module": {"resources": [{"address": item['address'], "mode": "managed", "values": copy.deepcopy(item['change']['after'])} for item in resources]}},
        "complete": True,
        "errored": False,
        "terraform_version": "1.12.1",
        "variables": {key: {"value": value} for key, value in variables.items()},
        "resource_changes": resources,
        "output_changes": {"candidate_contract": {"after": contract}},
    }


class MessageConsumerTransitionTests(unittest.TestCase):
    def test_existing_workflow_rejects_new_history_or_candidate3_activation(self):
        for gate in ("candidate3_rules_only_enabled", "governed_history_settlement_enabled"):
            for value in (True, "true", 1, None):
                with self.subTest(gate=gate, value=value):
                    plan = fixture()
                    plan["variables"][gate] = {"value": value}
                    with self.assertRaises(ValueError):
                        transition.review(plan, REVISION, "inactive")

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

    def test_exact_terraform_cli_boolean_literal_is_accepted(self):
        plan = fixture("engineering")
        plan["variables"]["activate_rules_engineering"]["value"] = "true"
        self.assertEqual(
            transition.review(plan, REVISION, "engineering")[3:],
            (4, 1),
        )

    def test_noncanonical_terraform_cli_boolean_is_rejected(self):
        for value in ("TRUE", "1", 1, None):
            plan = fixture("engineering")
            plan["variables"]["activate_rules_engineering"]["value"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                transition.review(plan, REVISION, "engineering")

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

    def test_active_and_inactive_noop_runtime_alias_inventory_is_checked(self):
        for mode in ("inactive", "engineering"):
            for mutation in ("environment", "runtime", "handler", "weighted", "version", "missing", "duplicate", "drift"):
                plan = fixture(mode, changes=False)
                function, alias = plan["resource_changes"][:2]
                if mutation == "environment": function["change"]["after"]["environment"][0]["variables"]["MESSAGE_AI_ENABLED"] = "true"
                if mutation == "runtime": function["change"]["after"]["runtime"] = "python3.13"
                if mutation == "handler": function["change"]["after"]["handler"] = "unreviewed.handler"
                if mutation == "weighted": alias["change"]["after"]["routing_config"] = [{"additional_version_weights": {"8": 0.1}}]
                if mutation == "version": alias["change"]["after"]["function_version"] = "8"
                if mutation == "missing": plan["resource_changes"].pop()
                if mutation == "duplicate": plan["resource_changes"].append(copy.deepcopy(function))
                if mutation == "drift": plan["resource_drift"] = [{"mode": "managed", "change": {"actions": ["update"]}}]
                if mutation in ("environment", "runtime", "handler", "weighted", "version"):
                    for item in plan['resource_changes']:
                        item['change']['before'] = copy.deepcopy(item['change']['after'])
                    plan['planned_values']['root_module']['resources'] = [{'address': item['address'], 'mode': 'managed', 'values': copy.deepcopy(item['change']['after'])} for item in plan['resource_changes']]
                with self.subTest(mode=mode, mutation=mutation), self.assertRaises(ValueError):
                    transition.review(plan, REVISION, mode)

    def test_maintenance_is_required_for_every_active_plan_even_noop(self):
        for changes in (False, True):
            for mutation in ("missing", "extra", "schema_bool", "env", "table", "alias", "version", "hash", "worker", "schedule", "heartbeat", "provider", "numeric", "text"):
                plan = fixture("engineering", changes=changes)
                contract = plan["variables"]["authority_maintenance"]["value"]
                if mutation == "missing": plan["variables"].pop("authority_maintenance")
                if mutation == "extra": contract["unqualified"] = True
                if mutation == "schema_bool": contract["schema_version"] = True
                if mutation == "env": contract["environment"] = "production"
                if mutation == "table": contract["authority_table_arn"] += "-wrong"
                if mutation == "alias": contract["recovery_alias_arn"] += "-wrong"
                if mutation == "version": contract["recovery_version"] = "$LATEST"
                if mutation == "hash": contract["recovery_code_sha256"] = "invalid"
                if mutation == "worker": contract["worker_enabled"] = False
                if mutation == "schedule": contract["schedule_enabled"] = False
                if mutation == "heartbeat": contract["heartbeat_enforced"] = False
                if mutation == "provider": contract["provider_access_added"] = True
                if mutation == "numeric": contract["worker_enabled"] = 1
                if mutation == "text": contract["worker_enabled"] = "true"
                with self.subTest(changes=changes, mutation=mutation), self.assertRaises(ValueError):
                    transition.review(plan, REVISION, "engineering")

    def test_inactive_rollback_does_not_require_running_maintenance(self):
        plan = fixture("inactive", changes=False)
        plan["variables"].pop("authority_maintenance")
        self.assertEqual(transition.review(plan, REVISION, "inactive")[3], 0)

    def test_unknown_versions_require_both_unknown_markers_and_source_binding(self):
        plan = fixture("engineering")
        for item in plan["resource_changes"]:
            field = "function_version" if "aws_lambda_alias." in item["address"] else "version"
            item["change"]["after"][field] = None
            item["change"]["after_unknown"] = {field: True}
        plan["configuration"] = {"root_module": {"resources": [{"address": "aws_lambda_alias.runtime", "expressions": {"function_version": {"references": ["aws_lambda_function.runtime"]}}}]}}
        plan['planned_values']['root_module']['resources'] = [{'address': item['address'], 'mode': 'managed', 'values': copy.deepcopy(item['change']['after'])} for item in plan['resource_changes']]
        transition.review(plan, REVISION, "engineering")
        for mutation in ("function_marker", "alias_marker", "source_binding"):
            invalid = copy.deepcopy(plan)
            if mutation == "function_marker": invalid["resource_changes"][0]["change"].pop("after_unknown")
            if mutation == "alias_marker": invalid["resource_changes"][1]["change"].pop("after_unknown")
            if mutation == "source_binding": invalid.pop("configuration")
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                transition.review(invalid, REVISION, "engineering")

    def test_legacy_runtime_attachments_checks_and_inconsistent_inventory_rejected(self):
        for mode in ('inactive', 'engineering'):
            for mutation in ('layers', 'vpc_config', 'dead_letter_config', 'file_system_config', 'image_uri', 'check_fail', 'check_unknown', 'inconsistent_noop', 'missing_planned', 'mismatched_planned'):
                plan = fixture(mode, changes=False)
                if mutation in ('layers', 'vpc_config', 'dead_letter_config', 'file_system_config', 'image_uri'):
                    plan['resource_changes'][0]['change']['after'][mutation] = ['unexpected']
                    plan['resource_changes'][0]['change']['before'] = copy.deepcopy(plan['resource_changes'][0]['change']['after'])
                    plan['planned_values']['root_module']['resources'][0]['values'] = copy.deepcopy(plan['resource_changes'][0]['change']['after'])
                if mutation == 'check_fail': plan['checks'] = [{'status': 'fail'}]
                if mutation == 'check_unknown': plan['checks'] = [{'status': 'unknown'}]
                if mutation == 'inconsistent_noop': plan['resource_changes'][0]['change']['before'] = {}
                if mutation == 'missing_planned': plan.pop('planned_values')
                if mutation == 'mismatched_planned': plan['planned_values']['root_module']['resources'][0]['values']['runtime'] = 'python3.13'
                with self.subTest(mode=mode, mutation=mutation), self.assertRaises(ValueError):
                    transition.review(plan, REVISION, mode)

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
