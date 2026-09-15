import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "audit_account_data_storage.py"
SPEC = importlib.util.spec_from_file_location("account_storage_audit", SCRIPT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class StorageAuditTests(unittest.TestCase):
    def run_audit(self, read):
        return audit.collect_inventory(
            read, expected_account="107827791950", environment="dev",
            region="us-east-1", project="trustcheckradar",
        )

    def test_wrong_account_stops_before_storage_access(self):
        calls = []
        def read(*args):
            calls.append(args)
            return {"Account": "999999999999"}
        with self.assertRaises(audit.AwsReadError):
            self.run_audit(read)
        self.assertEqual(calls, [("sts", "get-caller-identity")])

    def test_all_declared_table_names_and_no_application_reads(self):
        calls = []
        def read(service, operation, *args):
            calls.append((service, operation, args))
            if service == "sts":
                return {"Account": "107827791950"}
            if service == "logs":
                return {"logGroups": []}
            return None
        report = self.run_audit(read)
        self.assertEqual(len(report["tables"]), 12)
        self.assertTrue(all(not table["present"] for table in report["tables"]))
        self.assertFalse(report["deletionReadinessVerified"])
        self.assertEqual({(service, operation) for service, operation, _ in calls}, {
            ("sts", "get-caller-identity"), ("dynamodb", "describe-table"),
            ("logs", "describe-log-groups"),
        })

    def test_missing_retention_is_unknown_not_zero_and_logs_are_bounded(self):
        def read(service, operation, *args):
            if service == "sts":
                return {"Account": "107827791950"}
            if service == "logs":
                self.assertEqual(args[-2:], ("--max-items", "100"))
                return {"logGroups": [{"logGroupName": "/aws/lambda/trustcheckradar-dev-post-confirmation"}], "NextToken": "more"}
            name = args[1]
            if operation == "describe-table":
                return {"Table": {"TableArn": f"arn:aws:dynamodb:us-east-1:107827791950:table/{name}"}}
            if operation == "describe-time-to-live":
                return {"TimeToLiveDescription": {"TimeToLiveStatus": "ENABLED", "AttributeName": "expiresAt"}}
            return {"ContinuousBackupsDescription": {"PointInTimeRecoveryDescription": {"PointInTimeRecoveryStatus": "ENABLED"}}}
        report = self.run_audit(read)
        self.assertTrue(all(table["recoveryPeriodInDays"] is None for table in report["tables"]))
        self.assertTrue(report["postConfirmationLogGroupObserved"])
        self.assertFalse(report["logGroups"][0]["retentionExplicit"])
        self.assertTrue(any("truncated" in note for note in report["limitations"]))

    def test_wrong_table_arn_is_rejected(self):
        def read(service, operation, *args):
            if service == "sts":
                return {"Account": "107827791950"}
            return {"Table": {"TableArn": "arn:aws:dynamodb:us-east-1:999999999999:table/users"}}
        with self.assertRaises(audit.AwsReadError):
            self.run_audit(read)

    def test_table_disappearing_during_audit_is_not_reported_complete(self):
        def read(service, operation, *args):
            if service == "sts":
                return {"Account": "107827791950"}
            if operation == "describe-table":
                return {"Table": {"TableArn": f"arn:aws:dynamodb:us-east-1:107827791950:table/{args[1]}"}}
            return None
        with self.assertRaises(audit.AwsReadError):
            self.run_audit(read)


if __name__ == "__main__":
    unittest.main()
