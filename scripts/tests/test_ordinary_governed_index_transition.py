import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('ordinary_index_guard', Path(__file__).resolve().parents[1] / 'reject_ordinary_governed_index_transition.py')
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
INDEX = {'name': 'GSI2', 'hash_key': 'GSI2PK', 'range_key': 'GSI2SK', 'projection_type': 'INCLUDE', 'non_key_attributes': ['recordType', 'state', 'governedHistory', 'expiresAt']}


def fixture(present=True):
    value = {'global_secondary_index': [INDEX] if present else [], 'attribute': [{'name': k, 'type': 'S'} for k in ('GSI2PK', 'GSI2SK')] if present else [], 'ttl': [{'enabled': True}]}
    return {'complete': True, 'errored': False, 'resource_changes': [{'address': 'aws_dynamodb_table.purchase_entitlements', 'mode': 'managed', 'change': {'actions': ['update'], 'before': copy.deepcopy(value), 'after': copy.deepcopy(value)}}]}


class OrdinaryIndexGuardTests(unittest.TestCase):
    def test_unchanged_index_and_unrelated_foundation_change_are_allowed(self):
        for present in (True, False):
            plan = fixture(present); plan['resource_changes'][0]['change']['after']['ttl'] = [{'enabled': True, 'attribute_name': 'expiresAt'}]
            self.assertFalse(v.review(plan)['governedHistoryIndexTransition'])

    def test_add_remove_projection_key_changes_and_replacement_are_rejected(self):
        for mutation in ('add', 'remove', 'projection', 'key', 'replace'):
            plan = fixture(mutation != 'add'); change = plan['resource_changes'][0]['change']
            if mutation == 'add': change['after'] = fixture(True)['resource_changes'][0]['change']['after']
            if mutation == 'remove': change['after']['global_secondary_index'] = []; change['after']['attribute'] = []
            if mutation == 'projection': change['after']['global_secondary_index'][0]['projection_type'] = 'ALL'
            if mutation == 'key': change['after']['attribute'][0]['type'] = 'N'
            if mutation == 'replace': change['actions'] = ['delete', 'create']
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): v.review(plan)
