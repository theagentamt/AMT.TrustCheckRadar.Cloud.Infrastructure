import copy
import hashlib
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import billing_inventory_access as gate

REVISION = 'a' * 40
IDENTITY = {'Account': gate.ACCOUNT, 'Arn': f'arn:aws:sts::{gate.ACCOUNT}:assumed-role/{gate.ROLE}/test'}


def reader(calls, override=None):
    def read(service, operation, *args):
        calls.append((service, operation, args))
        if override and (service, operation) == override[0]:
            return override[1]
        if service == 'iam' and operation == 'get-role-policy':
            return {'PolicyDocument': gate.document()}
        if service == 'scheduler':
            if operation == 'get-schedule':
                name = args[args.index('--name') + 1]
                return {'Arn': f'arn:aws:scheduler:us-east-1:{gate.ACCOUNT}:schedule/{gate.GROUP}/{name}',
                        'Name': name, 'GroupName': gate.GROUP, 'State': 'ENABLED'}
            if operation == 'get-schedule-group':
                return {'Arn': f'arn:aws:scheduler:us-east-1:{gate.ACCOUNT}:schedule-group/{gate.GROUP}',
                        'Name': gate.GROUP, 'State': 'ACTIVE'}
            if operation == 'list-tags-for-resource':
                return {'Tags': [{'Key': 'private-tag', 'Value': 'private-value'}]}
        if service == 'kms':
            key = args[args.index('--key-id') + 1]
            if operation == 'describe-key':
                return {'KeyMetadata': {'Arn': key, 'KeyId': key.split('/')[-1],
                        'KeyManager': 'CUSTOMER' if key == gate.TOKEN_KEY else 'AWS',
                        'KeyState': 'Enabled', 'KeyUsage': 'ENCRYPT_DECRYPT'}}
            if key == gate.TOKEN_KEY:
                if operation == 'get-key-policy':
                    return {'Policy': json.dumps({'Version': '2012-10-17', 'Statement': [{'Sid': 'private-policy'}]})}
                if operation == 'get-key-rotation-status':
                    return {'KeyId': key, 'KeyRotationEnabled': True}
                if operation == 'list-resource-tags':
                    return {'Tags': [{'TagKey': 'private-tag', 'TagValue': 'private-value'}], 'Truncated': False}
        raise AssertionError('Unexpected API or key scope')
    return read


class ApprovedPolicyTests(unittest.TestCase):
    def test_exact_document_matches_owner_approved_proposal(self):
        digest = hashlib.sha256(json.dumps(gate.document(), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(digest, 'a85c886cd1eaf7513a22cf4eea0c44ad508e19f2e85018fe9d4313a224e33b3e')

    def test_fresh_policy_drift_and_wrong_caller_stop_before_write(self):
        altered = copy.deepcopy(gate.previous_document())
        altered['Statement'][0]['Action'].append('backup:DeleteBackupPlan')
        for identity, policy in ((IDENTITY, altered), ({'Account': gate.ACCOUNT, 'Arn': 'private-other-role'}, gate.previous_document())):
            def read(service, operation, *args):
                return identity if service == 'sts' else {'PolicyDocument': policy}
            argv = ['test', '--revision', REVISION, '--mode', 'apply', '--expected-digest', gate.digest(REVISION)]
            with self.subTest(identity=identity['Arn']), patch.object(sys, 'argv', argv), patch.object(gate, 'aws', read), patch.object(gate.subprocess, 'run', return_value=SimpleNamespace(stdout=REVISION + '\n')) as command:
                with self.assertRaises(SystemExit):
                    gate.main()
                self.assertEqual(command.call_count, 1)

    def test_identical_installed_policy_is_idempotent_without_write(self):
        def read(service, operation, *args):
            return IDENTITY if service == 'sts' else {'PolicyDocument': gate.document()}
        argv = ['test', '--revision', REVISION, '--mode', 'apply', '--expected-digest', gate.digest(REVISION)]
        output = io.StringIO()
        with patch.object(sys, 'argv', argv), patch.object(gate, 'aws', read), patch.object(gate.subprocess, 'run', return_value=SimpleNamespace(stdout=REVISION + '\n')) as command, redirect_stdout(output):
            gate.main()
        self.assertEqual(command.call_count, 1)
        self.assertFalse(json.loads(output.getvalue())['policyChanged'])


class ActualRoleQualificationBoundaryTests(unittest.TestCase):
    def test_qualification_calls_only_five_exact_key_metadata_reads(self):
        calls = []
        with patch.object(gate, 'aws', reader(calls)):
            value = gate.qualify(IDENTITY)
        kms = [(operation, args[args.index('--key-id') + 1]) for service, operation, args in calls if service == 'kms']
        self.assertEqual(kms, [('describe-key', gate.TOKEN_KEY), ('describe-key', gate.TABLE_KEY),
                              ('get-key-policy', gate.TOKEN_KEY), ('get-key-rotation-status', gate.TOKEN_KEY),
                              ('list-resource-tags', gate.TOKEN_KEY)])
        tag_reads = [args for service, operation, args in calls if service == 'kms' and operation == 'list-resource-tags']
        self.assertEqual(tag_reads, [('--key-id', gate.TOKEN_KEY, '--no-paginate')])
        self.assertEqual(value['kmsMetadataReadCount'], 5)
        self.assertEqual(value['schedulerMetadataReadCount'], 4)
        self.assertNotIn('private', json.dumps(value))

    def test_wrong_role_and_installed_policy_are_rejected(self):
        calls = []
        with patch.object(gate, 'aws', reader(calls)), self.assertRaises(ValueError):
            gate.qualify({'Account': gate.ACCOUNT, 'Arn': 'private-other-role'})
        self.assertEqual(calls, [])
        with patch.object(gate, 'aws', reader([], (('iam', 'get-role-policy'), {'PolicyDocument': gate.previous_document()}))), self.assertRaises(ValueError):
            gate.qualify(IDENTITY)

    def test_mismatched_key_and_incomplete_metadata_are_rejected(self):
        cases = [
            ('describe-key', {'KeyMetadata': {'Arn': 'private-other-key'}}),
            ('get-key-policy', {'Policy': json.dumps({'Version': '2012-10-17', 'Statement': 'private'})}),
            ('get-key-rotation-status', {'KeyId': gate.TABLE_KEY, 'KeyRotationEnabled': True}),
            ('list-resource-tags', {'Tags': [], 'Truncated': True}),
            ('list-resource-tags', {'Tags': []}),
        ]
        for operation, response in cases:
            with self.subTest(operation=operation), patch.object(gate, 'aws', reader([], (('kms', operation), response))), self.assertRaises(ValueError):
                gate.qualify(IDENTITY)
