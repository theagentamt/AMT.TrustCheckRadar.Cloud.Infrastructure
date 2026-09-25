import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('fixture',Path(__file__).resolve().parents[1]/'campaign_completion_fixture.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class FixtureTests(unittest.TestCase):
    def doc(self):
        run='abc123def456';prefix,tags=m.identity(run)
        return {'runId':run,'account':m.ACCOUNT,'region':m.REGION,'prefix':prefix,'tags':tags,'tables':{x:prefix+'-'+x for x in ['pipeline','ledger','users']},'role':prefix+'-role','function':prefix+'-runner','keyArn':f'arn:aws:kms:{m.REGION}:{m.ACCOUNT}:key/11111111-1111-1111-1111-111111111111'}
    def test_fixed_run_scope(self):
        for value in ['dev','../abc','ABC123DEF456','abc123def4567']:
            with self.assertRaises(ValueError):m.identity(value)
    def test_cleanup_rejects_foreign_journal(self):
        doc=self.doc();self.assertIs(m.validate_journal(doc,doc['runId']),doc)
        for changes in [{'account':'999999999999'},{'function':'trustcheckradar-dev-campaign-deletion-bridge'},{'tables':dict(doc['tables'],pipeline='trustcheckradar-dev-campaign-pipeline')},{'keyArn':'arn:aws:kms:us-west-2:107827791950:key/11111111-1111-1111-1111-111111111111'},{'tags':{}}]:
            with self.assertRaises(ValueError):m.validate_journal(doc|changes,doc['runId'])
    def test_runtime_policy_has_only_exact_fixture_resources(self):
        doc=self.doc();p=m.runtime_policy(doc['tables'],doc['keyArn']);resources=[]
        for statement in p['Statement']:
            resources.extend(statement['Resource'] if isinstance(statement['Resource'],list) else [statement['Resource']])
            self.assertNotIn('*',statement['Action'])
            self.assertFalse(any(x.startswith(('cognito','secretsmanager','s3:','dynamodb:Restore','kms:Decrypt')) for x in statement['Action']))
        self.assertEqual(len(resources),5);self.assertFalse(any('*' in x for x in resources))
        self.assertTrue(all(doc['prefix'] in x or x==doc['keyArn'] for x in resources))
        self.assertEqual(p['Statement'][1]['Action'],['dynamodb:Query'])
        self.assertEqual(p['Statement'][1]['Resource'],f'arn:aws:dynamodb:{m.REGION}:{m.ACCOUNT}:table/'+doc['tables']['ledger']+'/index/CampaignRecoveryDueIndex')
    def test_recovery_index_only_on_ledger(self):
        doc=self.doc()
        for kind,name in doc['tables'].items():
            request=m.table_request(name,kind,doc['tags'])
            if kind!='ledger':self.assertNotIn('GlobalSecondaryIndexes',request);continue
            index=request['GlobalSecondaryIndexes'][0]
            self.assertEqual(index['Projection'],{'ProjectionType':'KEYS_ONLY'})
            self.assertEqual(index['KeySchema'],[{'AttributeName':'campaignRecoveryPartition','KeyType':'HASH'},{'AttributeName':'nextAttemptAtEpoch','KeyType':'RANGE'}])
            self.assertIn({'AttributeName':'nextAttemptAtEpoch','AttributeType':'N'},request['AttributeDefinitions'])

if __name__=='__main__':unittest.main()
