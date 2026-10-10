import importlib.util
import json
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "report_failure",
    Path(__file__).resolve().parents[1] / "report_terraform_failure.py",
)
report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(report)


class TerraformFailureReportTests(unittest.TestCase):
    def test_lifecycle_denial_retains_only_fixed_operation_names(self):
        value = report.classify(
            'operation error Scheduler: GetScheduleGroup, AccessDeniedException: '
            'not authorized to perform: scheduler:GetScheduleGroup on private-subject '
            'token=private-password'
        )
        self.assertEqual(value['awsActions'], ['scheduler:GetScheduleGroup'])
        self.assertEqual(value['awsOperations'], ['Scheduler:GetScheduleGroup'])
        self.assertNotIn('private', json.dumps(value))

    def test_missing_input_and_condition_failure_do_not_echo_values(self):
        missing = report.classify('No value for required variable in variable "deployment": private')
        condition = report.classify('Resource precondition failed: subject=private')
        self.assertEqual(missing['category'], 'REQUIRED_VARIABLE_MISSING')
        self.assertEqual(missing['terraformVariables'], ['deployment'])
        self.assertEqual(condition['category'], 'RESOURCE_CONDITION_FAILED')
        self.assertNotIn('private', json.dumps([missing, condition]))

    def test_access_denial_reports_only_action_and_operation(self):
        sensitive = (
            "operation error Lambda: GetFunction, api error AccessDeniedException: "
            "User arn:aws:sts::107827791950:assumed-role/private/session is not authorized "
            "to perform: lambda:GetFunction on resource arn:aws:lambda:us-east-1:107827791950:"
            "function:private-01997e3a-0000-7000-8000-000000000001 password=hunter2"
        )
        value = report.classify(sensitive)
        self.assertEqual(value["category"], "AWS_ACCESS_DENIED")
        self.assertEqual(value["awsActions"], ["lambda:GetFunction"])
        self.assertEqual(value["awsOperations"], ["Lambda:GetFunction"])
        encoded = json.dumps(value)
        for forbidden in ("01997e3a", "hunter2", "107827791950", "private/session"):
            self.assertNotIn(forbidden, encoded)

    def test_lock_and_variable_failures_are_bounded(self):
        locked = report.classify("Error acquiring the state lock: private details")
        invalid = report.classify('Invalid value for variable on x.tf in variable "activate_trial_engineering": secret')
        self.assertEqual(locked["category"], "STATE_LOCK_UNAVAILABLE")
        self.assertEqual(invalid["category"], "VARIABLE_VALIDATION_FAILED")
        self.assertEqual(invalid["terraformVariables"], ["activate_trial_engineering"])
        self.assertNotIn("private", json.dumps(locked))
        self.assertNotIn("secret", json.dumps(invalid))

    def test_unknown_failure_emits_no_source_text(self):
        value = report.classify("email@example.invalid token=abc message content")
        self.assertEqual(value["category"], "TERRAFORM_PLAN_FAILED_REDACTED")
        self.assertEqual(value["awsActions"], [])
        self.assertEqual(value["awsOperations"], [])
        self.assertEqual(value["terraformVariables"], [])
        self.assertNotIn("example", json.dumps(value))

    def test_capture_positions_are_allowlisted_and_output_is_bounded(self):
        hostile = (
            "AccessDenied: not authorized to perform: 107827791950:BearerSecret "
            "operation error PrivateSubject: TokenValue "
            'in variable "private_account_identifier" '
            + " not authorized to perform: x:" + "A" * 1000
            + " operation error X:" + "B" * 1000
            + ' in variable "' + "C" * 1000 + '"'
        )
        value = report.classify(hostile)
        self.assertEqual(value["category"], "AWS_ACCESS_DENIED")
        self.assertEqual(value["awsActions"], [])
        self.assertEqual(value["awsOperations"], [])
        self.assertEqual(value["terraformVariables"], [])
        encoded = json.dumps(value)
        self.assertLess(len(encoded), 256)
        for forbidden in ("BearerSecret", "TokenValue", "private_account_identifier", "107827791950"):
            self.assertNotIn(forbidden, encoded)


if __name__ == "__main__":
    unittest.main()
