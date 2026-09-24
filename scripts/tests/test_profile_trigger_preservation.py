import importlib.util
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("trigger_update", Path(__file__).resolve().parents[2] / "terraform/identity-workflows/scripts/update_user_pool_lambda_config.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class TriggerPreservationTests(unittest.TestCase):
    def run_update(self, existing, overrides=None):
        calls = []
        writes = []
        def aws(args, env):
            calls.append(args)
            if args[1] == "describe-user-pool":
                return json.dumps({"UserPool": {"LambdaConfig": existing, "MfaConfiguration":"OPTIONAL", "UserPoolTags":{"fixture":"true"}}})
            path = Path(args[3].removeprefix("file://"))
            writes.append(json.loads(path.read_text()))
            return "{}"
        argv = ["script", "--user-pool-id", "synthetic-pool", "--post-confirmation-arn", "same-arn", "--region", "us-east-1"]
        if overrides is not None:
            argv += ["--overrides-json", json.dumps(overrides)]
        with patch.object(sys, "argv", argv), patch.object(m, "run_aws", aws):
            m.main()
        return calls, writes

    def test_matching_trigger_skips_mutation_and_preserves_unmodeled_fields(self):
        calls,writes=self.run_update({"PostConfirmation":"same-arn", "PreSignUp":"other-arn"})
        self.assertEqual(len(calls),1)
        self.assertEqual(writes,[])

    def test_changed_trigger_retains_existing_other_triggers(self):
        calls,writes=self.run_update({"PostConfirmation":"old-arn", "PreSignUp":"other-arn"})
        self.assertEqual(len(calls),2)
        self.assertEqual(writes[0]["LambdaConfig"],{"PostConfirmation":"same-arn","PreSignUp":"other-arn"})
        self.assertEqual(writes[0]["MfaConfiguration"],"OPTIONAL")

    def test_explicit_override_is_not_skipped(self):
        _,writes=self.run_update({"PostConfirmation":"same-arn"},{"PreSignUp":"other-arn"})
        self.assertEqual(writes[0]["LambdaConfig"],{"PostConfirmation":"same-arn","PreSignUp":"other-arn"})

if __name__ == "__main__":
    unittest.main()
