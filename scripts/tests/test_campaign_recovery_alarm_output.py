"""Evaluate the actual output expression with isolated non-runtime Terraform values."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


class CampaignRecoveryAlarmOutputTests(unittest.TestCase):
    def test_active_worker_does_not_imply_alarm_actions(self):
        source = (Path(__file__).resolve().parents[2] / 'terraform/campaign-processing/recovery.tf').read_text()
        output = source.split('output "campaign_recovery_preparation_contract"', 1)[1]
        expression = re.search(r'^\s*alarm_actions_enabled\s*=\s*(.+)$', output, re.M).group(1)
        # Evaluate the production expression, replacing only its resource namespace.
        expression = expression.replace('aws_cloudwatch_metric_alarm.recovery', 'var.alarms')
        env = {k: v for k, v in os.environ.items() if not k.startswith(('AWS_', 'TF_CLI_ARGS')) and k != 'TF_DATA_DIR'}
        env.update(CHECKPOINT_DISABLE='1', TF_INPUT='false', TF_IN_AUTOMATION='true',
                   AWS_CONFIG_FILE='/dev/null', AWS_SHARED_CREDENTIALS_FILE='/dev/null',
                   AWS_EC2_METADATA_DISABLED='true')
        cases = [('absent', {}, False),
                 ('present_disabled', {'a': {'actions_enabled': False}}, False),
                 ('present_enabled', {'a': {'actions_enabled': True}}, True),
                 ('mixed', {'a': {'actions_enabled': False}, 'b': {'actions_enabled': True}}, True)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'main.tf').write_text('variable "alarms" { type = map(object({ actions_enabled = bool })) }\n'
                                         'locals { campaign_deletion_active = true }\n')
            for name, alarms, expected in cases:
                with self.subTest(name=name):
                    (root / 'inputs.tfvars.json').write_text(json.dumps({'alarms': alarms}))
                    result = subprocess.run(['terraform', '-chdir=' + directory, 'console', '-no-color',
                                             '-var-file=inputs.tfvars.json'], input=expression + '\n',
                                            text=True, capture_output=True, env=env, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), str(expected).lower())


if __name__ == '__main__': unittest.main()
