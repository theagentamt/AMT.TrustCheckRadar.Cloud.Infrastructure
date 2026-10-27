"""Evaluate production HCL membership checks and byte selection without providers."""
import json
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


class MessageAllowlistSerializationTests(unittest.TestCase):
    def test_preserved_bytes_keep_membership_and_admission_checks(self):
        root = Path(__file__).resolve().parents[2] / 'terraform/message-consumer'
        source = (root / 'variables.tf').read_text()
        declarations = []
        for name in ('engineering_subjects', 'preserved_engineering_subjects_json', 'candidate3_rules_only_enabled'):
            declarations.append('variable "' + name + '"' + source.split('variable "' + name + '"', 1)[1].split('\nvariable ', 1)[0])
        declarations.extend(['variable "enabled" { default = true }',
                             'variable "environment" { default = "dev" }',
                             'variable "message_ai_primary_enabled" { default = false }',
                             'variable "activate_rules_engineering" { default = true }'])
        expression = re.search(r'^\s*DEV_SUBJECT_ALLOWLIST_JSON\s*=\s*(.+)$', (root / 'main.tf').read_text(), re.M).group(1)
        subject = '11111111-1111-4111-8111-111111111111'
        other = '22222222-2222-4222-8222-222222222222'
        third = '33333333-3333-4333-8333-333333333333'
        # Unit fixture only: substitute the private cohort's digest in this
        # temporary providerless module; production UUIDs are never committed.
        pin = 'ea905c7184be88586e8a0a5745319bf0fdeef29734b57af80c9c048cd8e353d1'
        self.assertIn(pin, source)
        fixture_pin = hashlib.sha256(json.dumps([subject, other], separators=(',', ':')).encode()).hexdigest()
        declarations = [value.replace(pin, fixture_pin) for value in declarations]
        raw = '[\n "' + other + '", "' + subject + '"\n]'
        valid = {'engineering_subjects': [subject, other], 'candidate3_rules_only_enabled': True}
        cases = [('default', {}, json.dumps([subject, other], separators=(',', ':'))),
                 ('singleton_default', {'engineering_subjects': [subject]}, json.dumps([subject], separators=(',', ':'))),
                 ('preserved_spacing', {'preserved_engineering_subjects_json': raw}, raw),
                 ('different_subject', {'preserved_engineering_subjects_json': json.dumps([subject, third])}, None),
                 ('extra_subject', {'preserved_engineering_subjects_json': json.dumps([subject, other, third])}, None),
                 ('different_two_subject_cohort', {'engineering_subjects': [subject, third],
                  'preserved_engineering_subjects_json': json.dumps([third, subject])}, None),
                 ('singleton_override', {'engineering_subjects': [subject],
                  'preserved_engineering_subjects_json': json.dumps([subject])}, None),
                 ('duplicate', {'preserved_engineering_subjects_json': json.dumps([subject, subject])}, None),
                 ('object', {'preserved_engineering_subjects_json': json.dumps({'subject': subject})}, None),
                 ('null', {'preserved_engineering_subjects_json': 'null'}, None),
                 ('malformed', {'preserved_engineering_subjects_json': '['}, None),
                 ('oversized', {'preserved_engineering_subjects_json': ' ' * 512 + raw}, None),
                 ('ai_enabled', {'preserved_engineering_subjects_json': raw, 'message_ai_primary_enabled': True}, None),
                 ('not_rules_only', {'preserved_engineering_subjects_json': raw, 'candidate3_rules_only_enabled': False}, None),
                 ('production', {'preserved_engineering_subjects_json': raw, 'environment': 'prod'}, None),
                 ('disabled', {'preserved_engineering_subjects_json': raw, 'enabled': False}, None)]
        env = {k: v for k, v in os.environ.items() if not k.startswith(('AWS_', 'TF_CLI_ARGS')) and k != 'TF_DATA_DIR'}
        env.update(CHECKPOINT_DISABLE='1', TF_INPUT='false', TF_IN_AUTOMATION='true',
                   AWS_CONFIG_FILE='/dev/null', AWS_SHARED_CREDENTIALS_FILE='/dev/null', AWS_EC2_METADATA_DISABLED='true')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'main.tf').write_text('\n'.join(declarations) + '\noutput "selected_allowlist" { value = ' + expression + ' }\n')
            initialized = subprocess.run(['terraform', '-chdir=' + directory, 'init', '-backend=false', '-input=false', '-no-color'],
                                         text=True, capture_output=True, env=env, timeout=30)
            self.assertEqual(initialized.returncode, 0, initialized.stderr)
            for name, changes, expected in cases:
                with self.subTest(name=name):
                    (path / 'inputs.tfvars.json').write_text(json.dumps(dict(valid, **changes)))
                    result = subprocess.run(['terraform', '-chdir=' + directory, 'plan', '-no-color', '-input=false',
                                             '-var-file=inputs.tfvars.json', '-out=unit.tfplan'],
                                            text=True, capture_output=True, env=env, timeout=30)
                    if expected is None:
                        self.assertNotEqual(result.returncode, 0)
                    else:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        shown = subprocess.run(['terraform', '-chdir=' + directory, 'show', '-json', 'unit.tfplan'],
                                               text=True, capture_output=True, env=env, timeout=30)
                        self.assertEqual(shown.returncode, 0, shown.stderr)
                        self.assertEqual(json.loads(shown.stdout)['planned_values']['outputs']['selected_allowlist']['value'], expected)


if __name__ == '__main__': unittest.main()
