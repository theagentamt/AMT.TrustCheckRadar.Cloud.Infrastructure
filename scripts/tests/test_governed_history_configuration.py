import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_governed_history_configuration import build, derive_partitions


class ConfigurationTests(unittest.TestCase):
    def test_access_scope_is_separate_and_has_no_deployment_or_cleanup_override(self):
        subject = '11111111-1111-4111-8111-111111111111'
        self.assertEqual(build('access', 'trial', {}, [subject], False), {'governed_trial_subjects': [subject]})
        self.assertEqual(build('access', 'inactive', {}, [], False), {'governed_trial_subjects': []})
        for args in [('access', 'both', {}, [subject], False), ('access', 'trial', {}, ['*'], False), ('access', 'trial', {}, [], False), ('access', 'inactive', {}, [subject], False)]:
            with self.subTest(args=args), self.assertRaises(ValueError): build(*args)

    def test_scope_modes_do_not_leak_subjects_to_index_or_open_unrelated_gates(self):
        self.assertEqual(build('index', 'active', {}, [], False), {'governed_history_index_enabled': True})
        reader = build('reader', 'list', {'artifact': 'metadata'}, ['11111111-1111-4111-8111-111111111111'], True, ['V1#test#' + 'a' * 64])
        self.assertTrue(reader['list_enabled']); self.assertFalse(reader['detail_enabled'])
        message = build('message', 'rules-only', {'artifact': 'metadata'}, ['11111111-1111-4111-8111-111111111111'], False)
        self.assertTrue(message['candidate3_rules_only_enabled']); self.assertFalse(message['governed_history_settlement_enabled'])
        self.assertFalse(any(k.startswith(('HISTORY_', 'EXPORT_', 'BILLING_', 'DELETION_')) for k in reader))

    def test_invalid_mode_missing_index_or_subjects_and_empty_pins_are_rejected(self):
        cases = [('index', 'both', {}, [], True), ('reader', 'active', {'pin': 1}, ['subject'], True), ('reader', 'both', {'pin': 1}, [], True), ('reader', 'both', {'pin': 1}, ['subject'], False), ('message', 'rules-only-history', {'pin': 1}, ['subject'], False), ('reader', 'inactive', {}, [], False), ('message', 'inactive', {'pin': 1}, ['subject'], False)]
        for args in cases:
            with self.subTest(args=args), self.assertRaises(ValueError): build(*args)

    def test_partition_derivation_reads_only_one_exact_secret_and_logs_no_key(self):
        import base64, json
        from unittest.mock import Mock
        subject = '11111111-1111-4111-8111-111111111111'
        read = Mock(return_value={'SecretString': json.dumps({'activeKeyId': 'test', 'keys': {'test': base64.b64encode(b'a' * 32).decode()}})})
        dep = {'authority_hmac_secret_arn': 'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123'}
        partitions = derive_partitions(dep, [subject], read)
        self.assertRegex(partitions[0], '^V1#test#[a-f0-9]{64}$')
        self.assertNotIn(subject, str(partitions))
        read.assert_called_once_with('secretsmanager', 'get-secret-value', '--secret-id', dep['authority_hmac_secret_arn'], '--version-stage', 'AWSCURRENT')
        read.reset_mock()
        with self.assertRaises(ValueError): derive_partitions({'authority_hmac_secret_arn': 'provider-secret'}, [subject], read)
        read.assert_not_called()

    def test_duplicate_oversized_and_malformed_keyrings_fail_closed(self):
        import json
        from unittest.mock import Mock
        dep = {'authority_hmac_secret_arn': 'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123'}
        subject = ['11111111-1111-4111-8111-111111111111']
        cases = ['{"activeKeyId":"x","keys":{"x":"bad","x":"bad"}}', 'x' * 4097, json.dumps({'activeKeyId': 'x', 'keys': {'x': 'bad'}}), json.dumps({'activeKeyId': 'x', 'keys': {str(k): 'bad' for k in range(5)}}), json.dumps({'activeKeyId': 'missing', 'keys': {'x': 'bad'}})]
        for raw in cases:
            with self.subTest(size=len(raw)), self.assertRaises(ValueError):
                derive_partitions(dep, subject, Mock(return_value={'SecretString': raw}))
