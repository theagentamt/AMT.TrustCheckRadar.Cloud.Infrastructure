import importlib.util
import io
import json
import logging
import sys
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from contextlib import redirect_stderr, redirect_stdout


SPEC = importlib.util.spec_from_file_location(
    "analysis_count_audit", Path(__file__).resolve().parents[1] / "audit_analysis_record_counts.py"
)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


def page(count=0, evaluated=0, units=0.5, key=None):
    result = {"Count": count, "ScannedCount": evaluated, "ConsumedCapacity": {"CapacityUnits": units}}
    if key:
        result["LastEvaluatedKey"] = key
    return result


class CountAuditTests(unittest.TestCase):
    def counter(self, read, **kwargs):
        return audit.Counter(read, sleep=lambda _: None, **kwargs)

    def test_wrong_account_prevents_any_table_read(self):
        calls = []
        def read(*args):
            calls.append(args)
            return {"Account": "000000000000"}
        with self.assertRaises(audit.AuditError):
            audit.collect(read)
        self.assertEqual(calls, [("sts", "get-caller-identity", {})])

    def test_wrong_table_prevents_scans(self):
        def read(service, operation, payload):
            if service == "sts":
                return {"Account": audit.ACCOUNT}
            self.assertEqual(operation, "describe-table")
            return {"Table": {"TableArn": "wrong"}}
        with self.assertRaises(audit.AuditError):
            audit.collect(read)

    def test_empty_inventory_is_bounded_count_only_and_skips_details(self):
        calls = []
        def read(service, operation, payload):
            calls.append((service, operation, payload))
            if service == "sts":
                return {"Account": audit.ACCOUNT}
            if operation == "describe-table":
                return {"Table": {"TableArn": f"arn:aws:dynamodb:{audit.REGION}:{audit.ACCOUNT}:table/{payload['TableName']}"}}
            self.assertEqual(operation, "scan")
            self.assertEqual(payload["Select"], "COUNT")
            self.assertEqual(payload["Limit"], 25)
            self.assertNotIn("ProjectionExpression", payload)
            return page()
        report = audit.collect(read, now=1000, counter=self.counter(read))
        self.assertTrue(report["complete"])
        self.assertFalse(report["deletionReadinessVerified"])
        self.assertEqual(report["scanCalls"], 5)
        self.assertTrue(all(v["detailsSkipped"] for v in report["analysis"].values()))
        self.assertEqual({c[2]["TableName"] for c in calls if c[0] == "dynamodb"}, set(audit.TABLES))

    def test_pagination_keys_are_passed_privately_but_never_reported(self):
        key = {"PK": {"S": "private-subject-hash"}, "SK": {"S": "private-request"}}
        calls = []
        def read(service, operation, payload):
            calls.append(payload)
            return page(1, 2, key=key) if len(calls) == 1 else page(2, 2)
        result = self.counter(read).count(audit.TABLES[0], "x", {}, {})
        self.assertEqual(result["count"], 3)
        self.assertEqual(calls[1]["ExclusiveStartKey"], key)
        self.assertNotIn("private", json.dumps(result))

    def test_unexpected_item_contents_fail_closed(self):
        def read(*_):
            return {**page(), "Items": [{"response": "SENSITIVE"}]}
        with self.assertRaises(audit.AuditError) as caught:
            self.counter(read).count(audit.TABLES[0], "x", {}, {})
        self.assertNotIn("SENSITIVE", str(caught.exception))

    def test_capacity_budget_stops_before_next_page(self):
        calls = []
        def read(*args):
            calls.append(args)
            return page(1, 1, units=1, key={"PK": {"S": "private"}, "SK": {"S": "key"}})
        result = self.counter(read, max_units=1).count(audit.TABLES[0], "x", {}, {})
        self.assertFalse(result["complete"])
        self.assertEqual(result["stoppedBecause"], "consumed_capacity_budget")
        self.assertEqual(len(calls), 1)

    def test_page_budget_marks_partial_count(self):
        result = self.counter(
            lambda *_: page(1, 1, key={"PK": {"S": "private"}, "SK": {"S": "key"}}), max_pages=1,
        ).count(audit.TABLES[0], "x", {}, {})
        self.assertFalse(result["complete"])
        self.assertEqual(result["stoppedBecause"], "per_aggregation_page_budget")

    def test_repeated_key_and_missing_capacity_are_rejected(self):
        for response in (page(key={"PK": {"S": "private"}, "SK": {"S": "key"}}), {"Count": 0, "ScannedCount": 0}):
            with self.subTest(response_shape=sorted(response)):
                with self.assertRaises(audit.AuditError):
                    self.counter(lambda *_: response).count(audit.TABLES[0], "x", {}, {})

    def test_sdk_uses_stdin_count_only_and_no_cli_history(self):
        payload = {"TableName": audit.TABLES[0], "Select": "COUNT", "Limit": 25,
                   "ConsistentRead": False, "ExclusiveStartKey": {"PK": {"S": "PRIVATE"}, "SK": {"S": "key"}}}
        with patch.object(audit, "sdk_python", return_value="/approved/python"):
            with patch.object(audit.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=json.dumps(page()), stderr="")) as run:
                audit.aws_reader("trustcheckradar")("dynamodb", "scan", payload)
        argv = run.call_args.args[0]
        self.assertEqual(argv, ["/approved/python", "-c", audit.SDK_WORKER])
        self.assertNotIn("PRIVATE", " ".join(argv))
        self.assertEqual(json.loads(run.call_args.kwargs["input"])["payload"], payload)
        self.assertEqual(run.call_args.kwargs["env"]["AWS_MAX_ATTEMPTS"], "1")

    def test_sdk_authentication_error_is_classified_without_raw_details(self):
        with patch.object(audit, "sdk_python", return_value="/approved/python"):
            with patch.object(audit.subprocess, "run", return_value=SimpleNamespace(
                    returncode=0, stdout='{"auditError":"aws_session_expired"}', stderr="PRIVATE")):
                with self.assertRaises(audit.AuditError) as caught:
                    audit.aws_reader("trustcheckradar")("sts", "get-caller-identity", {})
        self.assertEqual(caught.exception.code, "aws_session_expired")
        self.assertNotIn("PRIVATE", str(caught.exception))

    def run_sdk_worker(self, response):
        calls = []
        def config(**kwargs):
            self.assertEqual(kwargs["retries"], {"max_attempts": 1})
            return kwargs
        def api_call(operation, payload):
            calls.append((operation, payload))
            return response
        session = SimpleNamespace(create_client=lambda *args, **kwargs: SimpleNamespace(_make_api_call=api_call))
        modules = {
            "awscli.botocore.session": SimpleNamespace(Session=lambda **kwargs: session),
            "awscli.botocore.config": SimpleNamespace(Config=config),
        }
        request = {"profile": "test", "service": "dynamodb", "operation": "scan", "payload": {
            "TableName": audit.TABLES[0], "Select": "COUNT", "Limit": 25,
        }}
        output = io.StringIO()
        previous_logging = logging.root.manager.disable
        try:
            with patch.dict(sys.modules, modules), patch.object(sys, "stdin", io.StringIO(json.dumps(request))):
                with redirect_stdout(output):
                    exec(audit.SDK_WORKER, {})
        finally:
            logging.disable(previous_logging)
        self.assertEqual(calls[0][0], "Scan")
        return output.getvalue()

    def test_worker_suppresses_item_contents_before_parent_process(self):
        result = self.run_sdk_worker({**page(), "Items": [{"response": "PRIVATE"}]})
        self.assertNotIn("PRIVATE", result)
        self.assertEqual(json.loads(result), {"auditError": "aws_read_failed"})

    def test_worker_returns_counts_without_sdk_response_metadata(self):
        result = self.run_sdk_worker({**page(1, 1), "ResponseMetadata": {"RequestId": "PRIVATE"}})
        self.assertEqual(json.loads(result), page(1, 1))
        self.assertNotIn("PRIVATE", result)

    def test_mutation_wrong_table_and_full_scan_are_rejected_before_cli(self):
        with patch.object(audit.subprocess, "run") as run:
            for operation, payload in (("delete-item", {}), ("scan", {"TableName": "prod"}),
                                       ("scan", {"TableName": audit.TABLES[0], "Select": "ALL_ATTRIBUTES"})):
                with self.assertRaises(audit.AuditError):
                    audit.aws_reader("test")("dynamodb", operation, payload)
            run.assert_not_called()

    def test_main_suppresses_raw_error_details(self):
        output, error = io.StringIO(), io.StringIO()
        with patch.object(audit.sys, "argv", ["audit"]), patch.object(audit, "collect", side_effect=audit.AuditError("PRIVATE")):
            with redirect_stdout(output), redirect_stderr(error):
                self.assertEqual(audit.main(), 1)
        self.assertNotIn("PRIVATE", output.getvalue() + error.getvalue())

    def test_expiry_buckets_have_fixed_non_sensitive_labels(self):
        buckets = audit.expiry_filters(1000)
        self.assertEqual(len(buckets), 8)
        self.assertEqual(buckets[3][2], {":lower": {"N": "1000"}, ":upper": {"N": "1900"}})
        self.assertEqual(buckets[-1][2], {":lower": {"N": str(1000 + 120 * 86400)}})


if __name__ == "__main__":
    unittest.main()
