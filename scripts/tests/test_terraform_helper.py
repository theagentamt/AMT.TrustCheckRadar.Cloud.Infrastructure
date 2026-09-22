import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class TerraformHelperTests(unittest.TestCase):
    """Test orchestration with a fake executable; no provider, state or AWS calls."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        directory = Path(self.temp.name)
        self.log = directory / "calls.jsonl"
        self.environment_log = directory / "environment.json"
        executable = directory / "terraform"
        executable.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "with open(os.environ['TF_TEST_LOG'], 'a') as log:\n"
            "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "with open(os.environ['TF_TEST_ENV_LOG'], 'w') as log:\n"
            "    json.dump({key: value for key, value in os.environ.items() if key.startswith('TF_VAR_')}, log)\n",
            encoding="utf-8",
        )
        executable.chmod(0o755)
        self.env = {
            "PATH": str(directory) + os.pathsep + os.environ.get("PATH", ""),
            "TF_TEST_LOG": str(self.log),
            "TF_TEST_ENV_LOG": str(self.environment_log),
            "TF_STATE_BUCKET": "synthetic-state-bucket",
            "AWS_REGION": "us-east-1",
        }

    def invoke(self, *args):
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/terraform.sh"), *args],
            cwd=ROOT,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        calls = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists()
            else []
        )
        return result, calls

    def test_history_plan_is_environment_scoped_and_never_applies(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "history-data")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertEqual(calls[0][:3], ["-chdir=terraform/history-data", "init", "-reconfigure"])
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/history-data.tfstate", calls[0])
                self.assertIn("-backend-config=bucket=synthetic-state-bucket", calls[0])
                self.assertIn("-backend-config=encrypt=true", calls[0])
                self.assertIn("-backend-config=use_lockfile=true", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/history-data", "plan", f"-var-file=../../environments/{environment}/history-data.tfvars"])

    def test_assessment_plan_uses_independent_state_without_legacy_artifacts(self):
        result, calls = self.invoke("plan", "dev", "url-assessment")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertIn("-backend-config=key=trustcheckradar/dev/url-assessment.tfstate", calls[0])
        self.assertEqual(calls[1], ["-chdir=terraform/url-assessment", "plan", "-var-file=../../environments/dev/url-assessment.tfvars"])
        self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_consumer_candidate_never_routes_to_legacy_state(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "url-consumer")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/url-consumer.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/url-consumer", "plan", f"-var-file=../../environments/{environment}/url-consumer.tfvars"])
                self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_message_candidate_has_independent_state_without_legacy_artifacts(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "message-consumer")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/message-consumer.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/message-consumer", "plan", f"-var-file=../../environments/{environment}/message-consumer.tfvars"])
                self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_recovery_candidate_has_separate_state_and_no_legacy_artifact(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "recovery-consumer")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/recovery-consumer.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/recovery-consumer", "plan", f"-var-file=../../environments/{environment}/recovery-consumer.tfvars"])
                self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_custom_state_prefix_and_region_are_used(self):
        self.env.update(TF_STATE_KEY_PREFIX="isolated", AWS_REGION="us-west-2")
        result, calls = self.invoke("plan", "uat", "history-data")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-backend-config=key=isolated/uat/history-data.tfstate", calls[0])
        self.assertIn("-backend-config=region=us-west-2", calls[0])
        exported = json.loads(self.environment_log.read_text())
        self.assertEqual(exported["TF_VAR_state_key_prefix"], "isolated")
        self.assertEqual(exported["TF_VAR_state_bucket_region"], "us-west-2")

    def test_history_processing_plan_routes_each_environment_without_legacy_artifact(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "history-processing")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/history-processing.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/history-processing", "plan", f"-var-file=../../environments/{environment}/history-processing.tfvars"])

    def test_feedback_has_isolated_state(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "result-feedback")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/result-feedback.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/result-feedback", "plan", f"-var-file=../../environments/{environment}/result-feedback.tfvars"])

    def test_play_verification_is_isolated_and_never_uses_legacy_release(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "play-verification")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/play-verification.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/play-verification", "plan", f"-var-file=../../environments/{environment}/play-verification.tfvars"])
                self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_output_does_not_need_a_lambda_artifact(self):
        result, calls = self.invoke("output", "dev", "history-data")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[-1], ["-chdir=terraform/history-data", "output"])

    def test_resolver_has_separate_state_and_no_legacy_analyzer_release(self):
        for environment in ("dev", "uat", "prod"):
            with self.subTest(environment=environment):
                self.log.unlink(missing_ok=True)
                result, calls = self.invoke("plan", environment, "url-resolver")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"-backend-config=key=trustcheckradar/{environment}/url-resolver.tfstate", calls[0])
                self.assertEqual(calls[1], ["-chdir=terraform/url-resolver", "plan", f"-var-file=../../environments/{environment}/url-resolver.tfvars"])
                self.assertNotIn("TF_VAR_artifact_release", json.loads(self.environment_log.read_text()))

    def test_invalid_operation_environment_or_stack_never_runs_terraform(self):
        for args in (("destroy", "dev", "history-data"), ("plan", "live", "history-data"), ("plan", "dev", "unknown")):
            with self.subTest(args=args):
                result, calls = self.invoke(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(calls, [])

    def test_missing_state_bucket_never_runs_terraform(self):
        del self.env["TF_STATE_BUCKET"]
        result, calls = self.invoke("plan", "dev", "history-data")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_existing_api_still_requires_an_artifact(self):
        result, calls = self.invoke("plan", "dev", "api")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("artifact", result.stderr.lower())
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
