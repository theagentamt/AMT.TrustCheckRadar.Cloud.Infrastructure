import copy
from datetime import datetime,timezone
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest.mock import patch
helper=Path(__file__).with_name('provision_campaign_period_key.py')
if not helper.exists():helper=Path(__file__).resolve().parents[1]/'provision_campaign_period_key.py'
spec=importlib.util.spec_from_file_location('p',helper);p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
NOW=1790424000
ARN=f'arn:aws:kms:{p.REGION}:{p.ACCOUNT}:key/11111111-1111-4111-8111-111111111111'
ARN2=ARN.replace('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222')

class Fake:
    def __init__(self):
        self.meta=SimpleNamespace(region_name=p.REGION);self.account=p.ACCOUNT;self.registry=None;self.keys={};self.create_calls=[];self.lost=False;self.fail_before=False;self.tags_incomplete=False;self.keys_incomplete=False;self.page=0
    def get_caller_identity(self):return {'Account':self.account}
    def get_item(self,**kwargs):
        if kwargs != {'TableName':p.TABLE,'Key':{'PK':{'S':f'PERIOD#{NOW//p.PERIOD_SECONDS}'},'SK':{'S':'HMAC_KEY'}},'ConsistentRead':True,'ProjectionExpression':'PK,SK'}:raise ValueError('bad-read')
        return {} if self.registry is None else {'Item':self.registry}
    def list_keys(self,**kwargs):
        self.page+=1
        if self.keys_incomplete:return {'Keys':[],'Truncated':True,'NextMarker':str(self.page)}
        return {'Keys':[{'KeyArn':arn} for arn in self.keys], 'Truncated':False}
    def list_resource_tags(self,KeyId,**kwargs):
        tags=self.keys[KeyId]['tags']
        return {'Tags':[],'Truncated':True,'NextMarker':'more'} if self.tags_incomplete else {'Tags':[{'TagKey':k,'TagValue':v} for k,v in tags.items()],'Truncated':False}
    def describe_key(self,KeyId):return {'KeyMetadata':{k:v for k,v in self.keys[KeyId].items() if k!='tags'}}
    def add(self,arn=ARN,**overrides):
        self.keys[arn]={'Arn':arn,'KeyId':arn.rsplit('/',1)[1],'KeyState':'Enabled','KeySpec':'HMAC_256','KeyUsage':'GENERATE_VERIFY_MAC','Origin':'AWS_KMS','KeyManager':'CUSTOMER','MultiRegion':False,'CreationDate':datetime.fromtimestamp(NOW,timezone.utc),'tags':p.tags_for(NOW//p.PERIOD_SECONDS),**overrides}
    def create_key(self,**kwargs):
        self.create_calls.append(kwargs)
        if self.fail_before:raise RuntimeError('connection uncertain')
        self.add()
        if self.lost:raise RuntimeError('acknowledgement lost')
        return self.describe_key(ARN)


class Tests(unittest.TestCase):
    def setup_operator(self):
        f=Fake();op=p.Operator(f,f,f,now=lambda:NOW,monotonic=lambda:0);return f,op
    def apply(self,op,plan,doc=None):
        digest=p.sha(p.canonical(plan).encode());doc=doc or p.fresh_journal(plan,digest);saves=[]
        result=op.apply(plan,digest,doc,lambda d:saves.append(copy.deepcopy(d)));return result,doc,saves
    def test_default_plan_derives_period_exact_tags_without_mutation(self):
        f,op=self.setup_operator();plan=op.plan();self.assertEqual(plan['periodId'],NOW//1209600);self.assertEqual(plan['tags'],p.tags_for(plan['periodId']));self.assertEqual(plan['mode'],'create');self.assertEqual(f.create_calls,[])
    def test_wrong_account_region_existing_registry_never_create(self):
        for mode in ('account','region','registry'):
            f,op=self.setup_operator()
            if mode=='account':f.account='999999999999'
            elif mode=='region':f.meta.region_name='us-west-2'
            else:f.registry={'PK':{'S':'PERIOD#old'}}
            with self.assertRaises(p.Unavailable):op.plan()
            self.assertEqual(f.create_calls,[])
    def test_existing_key_requires_explicit_exact_reuse(self):
        f,op=self.setup_operator();f.add();plan=op.plan();self.assertEqual(plan['mode'],'selection_required')
        with self.assertRaises(p.Unavailable):self.apply(op,plan)
        plan=op.plan(ARN);result,doc,saves=self.apply(op,plan);self.assertTrue(result['reusedExistingKey']);self.assertEqual(f.create_calls,[])
        with self.assertRaises(p.Unavailable):op.plan(ARN2)
    def test_duplicate_matching_keys_and_bad_metadata_refuse(self):
        f,op=self.setup_operator();f.add();f.add(ARN2)
        with self.assertRaises(p.Unavailable):op.plan()
        for field,bad in [('Origin','EXTERNAL'),('MultiRegion',True),('KeyState','PendingDeletion'),('KeySpec','SYMMETRIC_DEFAULT'),('KeyUsage','ENCRYPT_DECRYPT')]:
            f,op=self.setup_operator();f.add(**{field:bad})
            with self.assertRaises(p.Unavailable):op.plan()
            self.assertEqual(f.create_calls,[])
    def test_exact_tag_set_and_bounded_complete_discovery(self):
        f,op=self.setup_operator();f.add();f.keys[ARN]['tags']['Unreviewed']='extra'
        with self.assertRaises(p.Unavailable):op.plan()
        f,op=self.setup_operator();f.add();f.tags_incomplete=True
        with self.assertRaises(p.Unavailable):op.plan()
        f,op=self.setup_operator();f.keys_incomplete=True
        with self.assertRaises(p.Unavailable):op.plan()
        self.assertEqual(f.page,10);self.assertEqual(f.create_calls,[])
    def test_period_rollover_and_mutated_plan_target_refuse(self):
        for field,value in [('accountId','999999999999'),('region','us-west-2'),('periodId',True),('periodSeconds',1),('tags',{'Project':'other'})]:
            f,op=self.setup_operator();plan=op.plan();plan[field]=value
            with self.assertRaises(p.Unavailable):self.apply(op,plan)
            self.assertEqual(f.create_calls,[])
        f,op=self.setup_operator();plan=op.plan();op.now=lambda:(NOW//p.PERIOD_SECONDS+1)*p.PERIOD_SECONDS
        with self.assertRaises(p.Unavailable):self.apply(op,plan)
        self.assertEqual(f.create_calls,[])
    def test_journal_attempt_precedes_single_create_and_no_registry_write(self):
        f,op=self.setup_operator();plan=op.plan();digest=p.sha(p.canonical(plan).encode());doc=p.fresh_journal(plan,digest);saved=[];original=f.create_key
        def create(**kwargs):
            self.assertTrue(saved[-1]['createAttempted']);self.assertEqual(saved[-1]['status'],'create_attempted');return original(**kwargs)
        f.create_key=create;result=op.apply(plan,digest,doc,lambda d:saved.append(copy.deepcopy(d)))
        self.assertEqual(len(f.create_calls),1);self.assertFalse(result['registryWritten']);self.assertEqual(doc['status'],'verified')
        self.assertEqual(f.create_calls[0]['Tags'],[{'TagKey':k,'TagValue':v} for k,v in plan['tags'].items()]);self.assertFalse(f.create_calls[0]['MultiRegion'])
        op.apply(plan,digest,doc,lambda d:None);self.assertEqual(len(f.create_calls),1)
    def test_lost_ack_unique_discovery_recovers_without_second_create(self):
        f,op=self.setup_operator();plan=op.plan();f.lost=True;result,doc,saves=self.apply(op,plan)
        self.assertTrue(result['keyVerified']);self.assertEqual(len(f.create_calls),1);self.assertEqual(doc['keyArn'],ARN)
        self.apply(op,plan,doc);self.assertEqual(len(f.create_calls),1)
    def test_uncertain_create_with_no_key_stays_unresolved_no_retry(self):
        f,op=self.setup_operator();plan=op.plan();digest=p.sha(p.canonical(plan).encode());doc=p.fresh_journal(plan,digest);f.fail_before=True
        for _ in range(2):
            with self.assertRaises(p.Unavailable):op.apply(plan,digest,doc,lambda d:None)
        self.assertEqual(len(f.create_calls),1);self.assertTrue(doc['createAttempted']);self.assertEqual(doc['status'],'ambiguous')
    def test_new_collision_after_plan_never_creates_duplicate(self):
        f,op=self.setup_operator();plan=op.plan();f.add()
        with self.assertRaises(p.Unavailable):self.apply(op,plan)
        self.assertEqual(f.create_calls,[])
    def test_journal_hash_and_target_tampering_refused(self):
        f,op=self.setup_operator();plan=op.plan();digest='a'*64
        for change in [{'planSha256':'b'*64},{'periodId':plan['periodId']+1},{'tags':{}},{'createAttempted':'true'},{'keyArn':ARN}]:
            doc=p.fresh_journal(plan,digest)|change
            with self.assertRaises(p.Unavailable):p.validate_journal(doc,plan,digest)
        with self.assertRaises(p.Unavailable):p.strict_json(b'{"a":1,"a":2}')
    def test_lost_ack_cannot_claim_an_old_key(self):
        f,op=self.setup_operator();plan=op.plan();digest=p.sha(p.canonical(plan).encode());doc=p.fresh_journal(plan,digest)
        doc.update(createAttempted=True,attemptedAtEpoch=NOW,status='ambiguous');f.add(CreationDate=datetime.fromtimestamp(NOW-1000,timezone.utc))
        with self.assertRaises(p.Unavailable):op.apply(plan,digest,doc,lambda d:None)
        self.assertEqual(f.create_calls,[])
    def test_journal_persistence_is_atomic_and_preserves_attempt(self):
        f,op=self.setup_operator();plan=op.plan();doc=p.fresh_journal(plan,'a'*64)
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'journal';path.write_text('{}');p.save_journal(path,doc);self.assertEqual(json.loads(path.read_text()),doc)
            self.assertEqual(path.stat().st_mode&0o777,0o600);self.assertFalse(path.with_name('journal.pending').exists())
    def test_unrelated_multiregion_key_is_discovered_but_not_selected(self):
        f,op=self.setup_operator();arn=f'arn:aws:kms:{p.REGION}:{p.ACCOUNT}:key/mrk-'+('a'*32)
        f.add(arn,MultiRegion=True,tags={'Purpose':'unrelated'})
        self.assertEqual(op.plan()['mode'],'create')
        f.keys[arn]['tags']=p.tags_for(NOW//p.PERIOD_SECONDS)
        with self.assertRaises(p.Unavailable):op.plan()
        self.assertEqual(f.create_calls,[])
    def test_lost_ack_duplicate_discovery_stays_ambiguous(self):
        f,op=self.setup_operator();plan=op.plan();digest=p.sha(p.canonical(plan).encode());doc=p.fresh_journal(plan,digest)
        def create(**kwargs):
            f.create_calls.append(kwargs);f.add();f.add(ARN2);raise RuntimeError('lost')
        f.create_key=create
        with self.assertRaises(p.Unavailable):op.apply(plan,digest,doc,lambda d:None)
        self.assertEqual(len(f.create_calls),1);self.assertEqual(doc['status'],'ambiguous')
        with self.assertRaises(p.Unavailable):op.apply(plan,digest,doc,lambda d:None)
        self.assertEqual(len(f.create_calls),1)
    def test_rollover_after_create_keeps_arn_without_compensation(self):
        f,op=self.setup_operator();plan=op.plan();digest=p.sha(p.canonical(plan).encode());doc=p.fresh_journal(plan,digest);original=f.create_key
        def create(**kwargs):
            response=original(**kwargs);op.now=lambda:(NOW//p.PERIOD_SECONDS+1)*p.PERIOD_SECONDS;return response
        f.create_key=create
        with self.assertRaises(p.Unavailable):op.apply(plan,digest,doc,lambda d:None)
        self.assertEqual(doc['keyArn'],ARN);self.assertTrue(doc['createAttempted']);self.assertEqual(len(f.create_calls),1)
    def test_cli_requires_exact_reviewed_plan_bytes_before_aws(self):
        f,op=self.setup_operator();plan=op.plan()
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'plan';path.write_text(json.dumps(plan))
            with patch('boto3.Session') as session,redirect_stdout(StringIO()):
                code=p.main(['--apply-plan',str(path),'--plan-sha256','f'*64,'--journal',str(Path(d)/'journal')])
            self.assertEqual(code,1);session.assert_not_called();self.assertFalse((Path(d)/'journal').exists())
    def test_verified_aws_managed_key_skips_unavailable_tags(self):
        f,op=self.setup_operator();f.add(KeyManager='AWS',KeySpec='SYMMETRIC_DEFAULT',KeyUsage='ENCRYPT_DECRYPT')
        def denied(**kwargs):raise RuntimeError('AccessDeniedException')
        f.list_resource_tags=denied
        self.assertEqual(op.plan()['mode'],'create');self.assertEqual(f.create_calls,[])
    def test_customer_tag_denial_and_unknown_metadata_never_skip(self):
        f,op=self.setup_operator();f.add()
        def denied(**kwargs):raise RuntimeError('AccessDeniedException')
        f.list_resource_tags=denied
        with self.assertRaises(RuntimeError):op.plan()
        f,op=self.setup_operator();f.add(KeyManager=None)
        with self.assertRaises(p.Unavailable):op.plan()
        f,op=self.setup_operator();f.add();f.describe_key=denied
        with self.assertRaises(RuntimeError):op.plan()
        f,op=self.setup_operator();f.add(KeyManager='AWS',Arn=ARN2)
        with self.assertRaises(p.Unavailable):op.plan()
    def test_sdk_request_matches_create_key_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        f,op=self.setup_operator();self.apply(op,op.plan())
        validate_parameters(f.create_calls[0],botocore.session.get_session().get_service_model('kms').operation_model('CreateKey').input_shape)

if __name__=='__main__':unittest.main()
