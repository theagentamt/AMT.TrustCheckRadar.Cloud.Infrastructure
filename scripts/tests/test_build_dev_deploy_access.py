import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "build_dev_deploy_access.py"
SPEC = importlib.util.spec_from_file_location("build_dev_deploy_access", SCRIPT)
POLICIES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICIES)


class DeployAccessTests(unittest.TestCase):
    def test_observability_is_exactly_dev_scoped(self):
        policy = POLICIES.environment_observability(
            "107827791950", "us-east-1", "trustcheckradar", "dev"
        )
        statement = policy["Statement"][0]
        self.assertEqual(statement["Sid"], POLICIES.OBSERVABILITY_SID)
        self.assertNotIn("*", statement["Resource"])
        self.assertTrue(all("trustcheckradar-dev-" in arn for arn in statement["Resource"]))

    def test_account_rule_is_exactly_dev_scoped(self):
        policy = POLICIES.account_reconciliation(
            "107827791950", "us-east-1", "trustcheckradar", "dev"
        )
        statement = policy["Statement"][0]
        self.assertEqual(
            statement["Resource"],
            "arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-dev-account-deletion-reconcile",
        )
        self.assertNotIn("*", statement["Resource"])


if __name__ == "__main__":
    unittest.main()
