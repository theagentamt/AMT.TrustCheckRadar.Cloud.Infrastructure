import copy
import importlib.util
from pathlib import Path
import unittest
import json
import tempfile
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('fixture',Path(__file__).resolve().parents[1]/'scripts/campaign_period_retirement_fixture.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)

class Boundaries(unittest.TestCase):
    def setUp(self):
        self.run='123456789abc';prefix,tags=f.identity(self.run)
        self.doc={'schemaVersion':1,'runId':self.run,'account':f.ACCOUNT,'region':f.REGION,
          'prefix':prefix,'tags':tags,'period':1477,'keyTags':f.key_tags(1477),
          'tables':{k:prefix+'-'+k for k in ('pipeline','outbox')},
          'keyArn':f'arn:aws:kms:{f.REGION}:{f.ACCOUNT}:key/11111111-1111-4111-8111-111111111111'}
        self.key={'Arn':self.doc['keyArn'],'Description':prefix,'KeySpec':'HMAC_256','KeyUsage':'GENERATE_VERIFY_MAC','KeyManager':'CUSTOMER','Origin':'AWS_KMS','MultiRegion':False}
        self.tags={'Tags':[{'TagKey':k,'TagValue':v} for k,v in self.doc['keyTags'].items()]}
    def test_owned_fixture_is_accepted(self):
        self.assertEqual(f.validate(self.doc,self.run),self.doc)
        self.assertEqual(f.verify_key(self.key,self.tags,self.doc),self.key)
    def test_names_cannot_escape_to_application_tables(self):
        for field,value in [('account','000000000000'),('region','us-west-2'),('schemaVersion',True),('prefix','trustcheckradar-dev'),('tables',{'pipeline':'trustcheckradar-dev-campaign-pipeline','outbox':'trustcheckradar-dev-campaign-outbox'}),('keyArn',self.doc['keyArn'].replace(f.ACCOUNT,'000000000000'))]:
            with self.subTest(field=field),self.assertRaises(ValueError):f.validate(self.doc|{field:value},self.run)
    def test_a_valid_period_tag_cannot_adopt_an_application_key(self):
        for field,value in [('Description','normal-period-key'),('Arn',self.key['Arn'].replace('11111111','22222222')),('KeySpec','SYMMETRIC_DEFAULT'),('Origin','EXTERNAL'),('MultiRegion',True),('KeyManager','AWS')]:
            with self.subTest(field=field),self.assertRaises(ValueError):f.verify_key(self.key|{field:value},self.tags,self.doc)
    def test_wrong_or_partial_tags_are_rejected(self):
        variants=[{'Tags':self.tags['Tags'][:-1]},self.tags|{'Truncated':True},self.tags|{'NextMarker':'unread'}, {'Tags':self.tags['Tags']+[self.tags['Tags'][0]]}]
        wrong=copy.deepcopy(self.tags);wrong['Tags'][-1]['TagValue']='1478';variants.append(wrong)
        for value in variants:
            with self.subTest(value=value),self.assertRaises(ValueError):f.verify_key(self.key,value,self.doc)
    def test_noncanonical_run_identifiers_and_periods_rejected(self):
        for run in ('../123456789a','123456789ABC','x'*12,'','0'*32):
            with self.subTest(run=run),self.assertRaises(ValueError):f.identity(run)
        for period in (True,-1,'1477'):
            with self.subTest(period=period),self.assertRaises(ValueError):f.key_tags(period)

class JournalDurability(unittest.TestCase):
    def test_interrupted_replace_preserves_prior_owned_key(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'journal.json'
            initial={'keyArn':'owned-fixture-key','keyCreateAttempted':True}
            f.durable_journal(path,initial,create=True)
            with patch.object(f.os,'replace',side_effect=OSError('injected interruption')):
                with self.assertRaises(OSError):f.durable_journal(path,initial|{'prepared':True})
            self.assertEqual(json.loads(path.read_text()),initial)
            self.assertEqual(list(Path(folder).iterdir()),[path])
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
    def test_initial_intent_is_exclusive_and_updates_are_complete(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'journal.json';f.durable_journal(path,{'attempt':True},create=True)
            with self.assertRaises(FileExistsError):f.durable_journal(path,{'attempt':False},create=True)
            f.durable_journal(path,{'attempt':True,'keyArn':'owned-key'})
            self.assertEqual(json.loads(path.read_text()),{'attempt':True,'keyArn':'owned-key'})
            self.assertEqual(path.stat().st_mode & 0o777,0o600)

if __name__=='__main__':unittest.main()
