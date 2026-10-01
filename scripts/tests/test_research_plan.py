import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("research_plan", Path(__file__).resolve().parents[1] / "summarize_research_plan.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ResearchPlanTest(unittest.TestCase):
    def setUp(self):
        self.plan = {"complete": True, "variables": {k: {"value": v} for k, v in {
            "environment": "dev", "aws_region": "us-east-1", "project_name": "trustcheckradar",
            "research_consent_migration": True}.items()}, "resource_changes": [
                {"mode": "managed", "address": "aws_lambda_function.worker[\"publisher\"]", "change": {
                    "actions": ["update"], "before": {"private": "SECRET-SENTINEL"}, "after": {"private": "OTHER-SENTINEL"}}}]}

    def test_minimized_report_contains_no_state_values(self):
        result = module.summarize(self.plan, "a" * 40, "campaign-processing")
        self.assertTrue(result["candidateSelected"])
        self.assertFalse(result["applyAuthorizedByThisReport"])
        self.assertNotIn("SENTINEL", json.dumps(result))
        self.assertEqual(len(result["changes"]), 1)

    def test_identity_and_completeness_fail_closed(self):
        for key, value in [("environment", "prod"), ("aws_region", "us-west-2"), ("project_name", "other")]:
            plan = copy.deepcopy(self.plan)
            plan["variables"][key]["value"] = value
            with self.assertRaises(ValueError):
                module.summarize(plan, "a" * 40, "api")
        self.plan["complete"] = False
        with self.assertRaises(ValueError):
            module.summarize(self.plan, "a" * 40, "api")

    def test_bad_revision_or_scope_rejected(self):
        for revision, stack in [("main", "api"), ("a" * 40, "foundation")]:
            with self.assertRaises(ValueError):
                module.summarize(self.plan, revision, stack)

    def test_baseline_and_drift_remain_visible(self):
        result = module.summarize(self.plan, "a" * 40, "api")
        self.assertFalse(result["candidateSelected"])
        altered = copy.deepcopy(self.plan)
        altered["resource_changes"][0]["change"]["before"]["private"] = "changed"
        self.assertNotEqual(result["planSha256"], module.summarize(altered, "a" * 40, "api")["planSha256"])


if __name__ == "__main__":
    unittest.main()
