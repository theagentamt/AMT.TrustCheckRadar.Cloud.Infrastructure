import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('audit_periods', Path(__file__).resolve().parents[1] / 'audit_campaign_period_registry.py')
audit = importlib.util.module_from_spec(spec); spec.loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def world(self, rows=(), repeat=False):
        from boto3.dynamodb.types import TypeSerializer
        serializer = TypeSerializer()
        ddb, kms = Mock(), Mock()
        ddb.describe_table.return_value = {'Table': {'TableArn': f'arn:aws:dynamodb:{audit.REGION}:{audit.ACCOUNT}:table/{audit.TABLE}'}}
        ddb.scan.return_value = {'ScannedCount': 2, 'Items': [{k: serializer.serialize(v) for k,v in r.items()} for r in rows]}
        if repeat: ddb.scan.return_value['LastEvaluatedKey'] = {'PK': {'S': 'never-persist'}}
        return ddb, kms

    def record(self):
        return {'PK': 'PERIOD#1', 'SK': 'HMAC_KEY', 'periodId': 1, 'status': 'ENABLED',
                'keyArn': 'arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111',
                'retireAfterEpoch': 2*audit.PERIOD+audit.RECOVERY}

    def test_empty_registry_is_not_erasure_approval(self):
        ddb,kms=self.world(); r=audit.collect(ddb,kms)
        self.assertTrue(r['traversalComplete']); self.assertEqual(r['registryRows'],0)
        self.assertFalse(r['inventoryApproved']); self.assertFalse(r['erasureVerified'])
        self.assertEqual(kms.mock_calls, [])
        request=ddb.scan.call_args.kwargs
        self.assertEqual(set(request['ExpressionAttributeNames'].values()),set(audit.FIELDS))
        self.assertEqual(request['Select'],'SPECIFIC_ATTRIBUTES')
        self.assertTrue(request['ConsistentRead'])

    def test_foreign_arn_or_unexpected_fields_never_reach_kms_or_report(self):
        for change in ({'keyArn':'foreign-sensitive-value'}, {'extra':'private-value'}):
            ddb,kms=self.world([self.record()|change]); r=audit.collect(ddb,kms)
            self.assertFalse(r['metadataComplete']); self.assertEqual(kms.mock_calls,[])
            self.assertNotIn('private-value',str(r)); self.assertNotIn('foreign-sensitive-value',str(r))

    def test_only_expected_tag_match_booleans_are_retained(self):
        row=self.record(); ddb,kms=self.world([row])
        kms.describe_key.return_value={'KeyMetadata':{'Arn':row['keyArn'],'AWSAccountId':audit.ACCOUNT,
           'KeySpec':'HMAC_256','KeyUsage':'GENERATE_VERIFY_MAC','KeyState':'Enabled'}}
        kms.list_resource_tags.return_value={'Tags':[{'TagKey':'Other','TagValue':'private-tag-value'}]}
        r=audit.collect(ddb,kms); self.assertFalse(r['metadataComplete'])
        self.assertNotIn('private-tag-value',str(r))
        self.assertEqual([x[0] for x in kms.mock_calls],['describe_key','list_resource_tags'])

    def test_malformed_retirement_metadata_is_not_normalized(self):
        for change in ({'status':'RETIRED', 'retiredAtEpoch': True},
                       {'status':'RETIRED', 'retiredAtEpoch':1},
                       {'status':'RETIRED'}, {'retiredAtEpoch':99}):
            ddb,kms=self.world([self.record()|change]); r=audit.collect(ddb,kms)
            self.assertFalse(r['metadataComplete']); self.assertEqual(kms.mock_calls,[])

    def test_bounded_scan_and_deadline_do_not_look_complete(self):
        ddb,kms=self.world(repeat=True); r=audit.collect(ddb,kms,max_pages=2)
        self.assertFalse(r['traversalComplete']); self.assertNotIn('never-persist',str(r))
        self.assertEqual(ddb.scan.call_count,2)
        ddb,kms=self.world(); times=iter([0,2])
        r=audit.collect(ddb,kms,seconds=1,monotonic=lambda:next(times))
        self.assertFalse(r['metadataComplete']); self.assertEqual(ddb.mock_calls,[])


if __name__=='__main__':unittest.main()
