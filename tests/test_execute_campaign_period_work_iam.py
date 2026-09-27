"""Offline containment/journal tests; Moto checks transaction expressions only."""
import copy
import contextlib
import io
import sys
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH=Path(__file__).resolve().parents[1]/'scripts/execute_campaign_period_work_iam.py'
spec=importlib.util.spec_from_file_location('execute_work',PATH);q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
RUN='a'*32

class AwsError(Exception):
    def __init__(self,code,reasons=None):
        self.response={'Error':{'Code':code}}
        if reasons is not None:self.response['CancellationReasons']=reasons


def evidence(run=RUN):
    return {'inputSha256':{'processingPlan':'1'*64,'apiPlan':'2'*64,'roleAudit':'3'*64},'fixtureRunId':run,
            'syntheticUnions':{k:q.v.synthetic(q.v.expected_new(k,'arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111'),run) for k in q.ROLE_SUFFIX if k not in q.v.API_KINDS}}


def safe_evidence():
    e=evidence();e['syntheticUnions']={}
    for kind in q.ROLE_SUFFIX:
        policy=q.v.expected_new(kind,'arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111')
        statements,_=q.v.project(policy,'fixture');e['syntheticUnions'][kind]=q.v.synthetic({'Version':'2012-10-17','Statement':statements},RUN)
    return e


class IAM:
    def __init__(self,exists=True,tagged=True,extra=False):self.exists=exists;self.tagged=tagged;self.extra=extra;self.deleted=[]
    def get_role(self,**kw):
        if not self.exists:raise AwsError('NoSuchEntity')
        return {'Role':{'Arn':'arn:aws:iam::107827791950:role/operator'}}
    def list_role_tags(self,**kw):return {'Tags':q.tag_list(RUN) if self.tagged else [{'Key':'QualificationRun','Value':'b'*32}]}
    def delete_role_policy(self,**kw):self.deleted.append('policy')
    def list_role_policies(self,**kw):return {'PolicyNames':['unrelated'] if self.extra else []}
    def list_attached_role_policies(self,**kw):return {'AttachedPolicies':[]}
    def delete_role(self,**kw):self.deleted.append('role');self.exists=False

class DDB:
    def __init__(self,exists=True,tagged=True):self.exists=exists;self.tagged=tagged;self.deleted=[]
    def describe_table(self,TableName):
        if not self.exists:raise AwsError('ResourceNotFoundException')
        return {'Table':{'TableArn':q.v.ROOT+TableName,'TableStatus':'ACTIVE'}}
    def list_tags_of_resource(self,**kw):return {'Tags':q.tag_list(RUN) if self.tagged else []}
    def delete_table(self,TableName):self.deleted.append(TableName);self.exists=False


class Safety(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'journal.json';self.e=safe_evidence();self.j=q.Journal(self.path,q.base_journal(RUN,self.e))
    def tearDown(self):self.tmp.cleanup()
    def test_names_tags_and_role_length_are_bounded(self):
        tables,roles=q.names(RUN);self.assertEqual(len(tables),2);self.assertEqual(len(roles),7);self.assertTrue(all(len(n)<=64 for n in roles.values()));self.assertEqual(q.tags(RUN)['Environment'],'dev')
    def test_journal_written_before_create_and_ack_persisted(self):
        name=q.names(RUN)[0]['pipeline']
        def create():
            disk=json.loads(self.path.read_text());self.assertTrue(disk['resources']['table'][name]['createAttempted']);self.assertFalse(disk['resources']['table'][name]['createAcknowledged']);return {'ok':True}
        self.assertEqual(q.create_recorded(self.j,'table',name,create),{'ok':True});self.assertTrue(json.loads(self.path.read_text())['resources']['table'][name]['createAcknowledged'])
    def test_real_symlink_parent_journal_create_and_replace(self):
        actual=Path(self.tmp.name)/'actual';actual.mkdir()
        alias=Path(self.tmp.name)/'directory-link';alias.symlink_to(actual,target_is_directory=True)
        journal=q.Journal(alias/'new.json',q.base_journal(RUN,self.e))
        self.assertEqual(journal.path,actual.resolve()/'new.json')
        name=q.names(RUN)[0]['pipeline'];journal.attempt('table',name)
        self.assertTrue(q.Journal(alias/'new.json').data['resources']['table'][name]['createAttempted'])
        target=actual/'target.json';target.write_text('preserve')
        (actual/'bad.json').symlink_to(target)
        with self.assertRaises(FileExistsError):q.Journal(alias/'bad.json',q.base_journal(RUN,self.e))
        self.assertEqual(target.read_text(),'preserve')
    def test_real_tmp_parent_journal_create_and_replace(self):
        import uuid
        path=Path('/tmp')/('amt-period-journal-test-'+uuid.uuid4().hex+'.json')
        try:
            journal=q.Journal(path,q.base_journal(RUN,self.e));journal.attempt('role',q.names(RUN)[1]['publisher'])
            self.assertEqual(q.Journal(path).data,journal.data)
        finally:
            if path.exists():path.unlink()
    def test_initial_journal_syncs_parent_after_file(self):
        path=Path(self.tmp.name)/'new.json';events=[];real_sync=q.os.fsync
        def file_sync(fd):events.append('file');real_sync(fd)
        def directory_sync(parent):
            self.assertEqual(parent,path.parent.resolve());self.assertEqual(json.loads(path.read_text()),self.j.data);events.append('directory')
        with patch.object(q.os,'fsync',side_effect=file_sync),patch.object(q,'fsync_directory',side_effect=directory_sync):q.Journal(path,self.j.data)
        self.assertEqual(events,['file','directory'])
    def test_save_syncs_parent_only_after_atomic_replace(self):
        events=[];real_replace=q.os.replace
        def replace(src,dst):events.append('replace');real_replace(src,dst)
        def directory_sync(parent):
            self.assertEqual(parent,self.path.parent.resolve());self.assertEqual(json.loads(self.path.read_text()),self.j.data);events.append('directory')
        with patch.object(q.os,'replace',side_effect=replace),patch.object(q,'fsync_directory',side_effect=directory_sync):self.j.attempt('table',q.names(RUN)[0]['pipeline'])
        self.assertEqual(events,['replace','directory'])
    def test_pre_replace_sync_failure_preserves_previous_journal(self):
        before=self.path.read_bytes();name=q.names(RUN)[0]['pipeline']
        with patch.object(q.os,'fsync',side_effect=OSError('injected_sync_failure')),patch.object(q.os,'replace') as replace:
            with self.assertRaises(OSError):self.j.attempt('table',name)
            replace.assert_not_called()
        self.assertEqual(self.path.read_bytes(),before);self.assertEqual(list(self.path.parent.glob('*.next-*')),[])
    def test_lost_create_ack_still_has_cleanup_intent(self):
        name=q.names(RUN)[0]['pipeline']
        with self.assertRaises(TimeoutError):q.create_recorded(self.j,'table',name,lambda:(_ for _ in ()).throw(TimeoutError()))
        self.assertTrue(q.Journal(self.path).data['resources']['table'][name]['createAttempted'])
        ddb=DDB();self.assertTrue(q.cleanup(self.j,IAM(False),ddb));self.assertEqual(ddb.deleted,[name])
    def test_ambiguous_missing_create_never_claims_cleanup(self):
        name=q.names(RUN)[1]['publisher'];self.j.attempt('role',name)
        self.assertFalse(q.cleanup(self.j,IAM(False),DDB(False)));self.assertFalse(self.j.data['resources']['role'][name]['absenceConfirmed'])
    def test_definitive_create_rejection_can_confirm_absence(self):
        name=q.names(RUN)[1]['publisher']
        with self.assertRaises(AwsError):q.create_recorded(self.j,'role',name,lambda:(_ for _ in ()).throw(AwsError('AccessDenied')))
        self.assertTrue(q.cleanup(self.j,IAM(False),DDB(False)))
    def test_cleanup_role_revoke_then_absence_readback(self):
        name=q.names(RUN)[1]['publisher'];self.j.attempt('role',name);iam=IAM()
        self.assertTrue(q.cleanup(self.j,iam,DDB(False)));self.assertEqual(iam.deleted,['policy','role']);self.assertTrue(self.j.data['resources']['role'][name]['absenceConfirmed'])
    def test_lost_delete_ack_reconciles_absence_on_cleanup_retry(self):
        name=q.names(RUN)[0]['pipeline'];self.j.attempt('table',name);self.j.acknowledged('table',name)
        class LostDelete(DDB):
            def delete_table(self,TableName):super().delete_table(TableName);raise TimeoutError()
        ddb=LostDelete();self.assertFalse(q.cleanup(self.j,IAM(False),ddb));self.assertTrue(q.cleanup(self.j,IAM(False),ddb));self.assertEqual(ddb.deleted,[name])
    def test_default_cli_validates_without_creating_journal_or_running_cloud(self):
        argv=['runner','--processing-plan','p','--api-plan','a','--role-audit','r']
        fake=safe_evidence()
        with patch.object(sys,'argv',argv),patch.object(q,'validate_inputs',return_value=fake),patch.object(q,'run') as run,patch.object(q,'Journal') as journal,contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(q.main(),0);run.assert_not_called();journal.assert_not_called()
    def test_output_must_not_overwrite_journal_or_existing_evidence(self):
        argv=['runner','--cleanup-only','--journal',str(self.path),'--output',str(self.path)]
        before=self.path.read_bytes()
        with patch.object(sys,'argv',argv),contextlib.redirect_stdout(io.StringIO()):self.assertEqual(q.main(),1)
        self.assertEqual(self.path.read_bytes(),before)
    def test_cleanup_wrong_tags_never_mutates(self):
        for kind in ('role','table'):
            with self.subTest(kind=kind):
                doc=q.base_journal(RUN,self.e);p=Path(self.tmp.name)/(kind+'.json');journal=q.Journal(p,doc);name=next(iter(q.names(RUN)[1 if kind=='role' else 0].values()));journal.attempt(kind,name)
                iam,ddb=IAM(tagged=False),DDB(tagged=False);self.assertFalse(q.cleanup(journal,iam,ddb));self.assertEqual(iam.deleted,[]);self.assertEqual(ddb.deleted,[])
    def test_cleanup_preserves_unexpected_policy_after_revoking_fixture(self):
        name=q.names(RUN)[1]['publisher'];self.j.attempt('role',name);iam=IAM(extra=True)
        self.assertFalse(q.cleanup(self.j,iam,DDB(False)));self.assertEqual(iam.deleted,['policy'])
    def test_journal_cannot_target_live_tables_or_roles(self):
        d=copy.deepcopy(self.j.data);d['tableNames']['pipeline']='trustcheckradar-dev-campaign-pipeline'
        with self.assertRaises(q.w.QualificationError):q.validate_journal(d)
        d=copy.deepcopy(self.j.data);d['resources']['role']['real-role']={'createAttempted':True}
        with self.assertRaises(q.w.QualificationError):q.validate_journal(d)
    def test_existing_journal_not_overwritten_or_symlinked(self):
        with self.assertRaises(FileExistsError):q.Journal(self.path,self.j.data)
        link=Path(self.tmp.name)/'link';link.symlink_to(self.path)
        with self.assertRaises(q.w.QualificationError):q.Journal(link)
    def test_namespace_or_policy_tampering_fails_before_resources(self):
        q.validate_fixture_evidence(self.e,self.j)
        bad=copy.deepcopy(self.e);bad['fixtureRunId']='b'*32
        with self.assertRaises(q.w.QualificationError):q.validate_fixture_evidence(bad,self.j)
        bad=copy.deepcopy(self.e);bad['syntheticUnions']['publisher']['Statement'][0]['Resource']=['*']
        with self.assertRaises(q.w.QualificationError):q.validate_fixture_evidence(bad,self.j)
    def test_negative_classification_does_not_accept_validation_or_throttle(self):
        for code in ('ValidationException','ThrottlingException','TransactionCanceledException'):
            with self.subTest(code=code),self.assertRaises(q.w.QualificationError):q.w.denied(lambda:(_ for _ in ()).throw(AwsError(code)))
        q.w.denied(lambda:(_ for _ in ()).throw(AwsError('AccessDeniedException')))
    def test_cancellation_must_be_exact_and_contain_no_returned_item(self):
        reasons=[{'Code':'None'},{'Code':'ConditionalCheckFailed'}];q.canceled(lambda:(_ for _ in ()).throw(AwsError('TransactionCanceledException',reasons)),1,2)
        reasons[1]['Item']={'secret':'synthetic'}
        with self.assertRaises(q.w.QualificationError):q.canceled(lambda:(_ for _ in ()).throw(AwsError('TransactionCanceledException',reasons)),1,2)
    def test_exact_principal_never_trusts_account_root(self):
        class STS:
            def __init__(self,arn):self.arn=arn
            def get_caller_identity(self):return {'Account':q.ACCOUNT,'Arn':self.arn}
        self.assertEqual(q.exact_principal(STS('arn:aws:sts::107827791950:assumed-role/operator/session'),IAM()),'arn:aws:iam::107827791950:role/operator')
        with self.assertRaises(q.w.QualificationError):q.exact_principal(STS('arn:aws:iam::107827791950:root'),IAM())
    def test_propagation_waits_for_inventory_get_without_retrying_cases(self):
        class Client:
            def __init__(self):self.describes=0;self.reads=0
            def describe_table(self,**kw):self.describes+=1
            def get_item(self,**kw):
                self.reads+=1
                self_outer.assertEqual(kw['Key'],q.key('INVENTORY#dev'))
                if self.reads<3:raise AwsError('AccessDeniedException')
        self_outer=self;client=Client()
        with patch.object(q.time,'sleep') as sleep:q.propagation_probe(client,'fixture')
        self.assertEqual((client.describes,client.reads,sleep.call_count),(3,3,2))
    def test_propagation_refuses_other_error_and_is_bounded(self):
        class Client:
            def __init__(self,error):self.error=error;self.calls=0
            def describe_table(self,**kw):self.calls+=1;raise AwsError(self.error)
        for code,expected in [('ThrottlingException',1),('AccessDeniedException',40)]:
            client=Client(code)
            with patch.object(q.time,'sleep'),self.assertRaises(AwsError) as observed:q.propagation_probe(client,'fixture')
            self.assertEqual(client.calls,expected)
            self.assertEqual(observed.exception.response['Error']['Code'],code)
            self.assertEqual(q.diagnostic(observed.exception)['awsErrorCode'],code)
    def test_unrecognized_credentials_retry_only_fresh_verified_window(self):
        class Client:
            def __init__(self):self.calls=0
            def describe_table(self,**kw):
                self.calls+=1
                if self.calls<2:raise AwsError('UnrecognizedClientException')
            def get_item(self,**kw):return {}
        for epoch in (None,0):
            client=Client()
            with patch.object(q.time,'monotonic',return_value=100),self.assertRaises(AwsError):q.propagation_probe(client,'fixture',verified_credentials_epoch=epoch)
            self.assertEqual(client.calls,1)
        client=Client()
        with patch.object(q.time,'monotonic',return_value=100),patch.object(q.time,'sleep'):
            report=q.propagation_probe(client,'fixture',verified_credentials_epoch=99)
        self.assertEqual(report,{'attempts':2,'retryCodes':{'UnrecognizedClientException':1}})
    def test_assumed_identity_requires_exact_account_role_and_session(self):
        class STS:
            def __init__(self,arn):self.arn=arn
            def get_caller_identity(self):return {'Account':q.ACCOUNT,'Arn':self.arn}
        arn=f'arn:aws:sts::{q.ACCOUNT}:assumed-role/fixture/period-work-qualification'
        q.verify_assumed_identity(STS(arn),'fixture')
        with self.assertRaises(q.w.QualificationError):q.verify_assumed_identity(STS(arn),'different')
    def test_denial_reason_classification_retains_no_service_message(self):
        error=AwsError('AccessDeniedException');error.response['Error']['Message']='arn:private secret because no identity-based policy allows action'
        result=q.diagnostic(error)
        self.assertEqual(result['authorizationReason'],'identity_allow_missing')
        self.assertNotIn('private',json.dumps(result));self.assertNotIn('secret',json.dumps(result))
        error.response['Error']['Message']='explicit deny in a service control policy'
        self.assertEqual(q.authorization_reason(error),'service_control_policy')
    def test_diagnostics_exclude_raw_error_text_responses_and_locals(self):
        try:
            error=AwsError('AccessDeniedException');error.response['secret']='must-not-appear';raise error
        except Exception as error:result=q.diagnostic(error)
        self.assertEqual(result['awsErrorCode'],'AccessDeniedException');self.assertNotIn('must-not-appear',json.dumps(result))
        self.assertTrue(result['frames']);self.assertEqual(set(result['frames'][-1]),{'file','function','line'})
    def test_tag_pagination_bound_is_not_silent_success(self):
        with self.assertRaises(q.w.QualificationError):q.collect_tags(lambda **kw:{'Tags':[],'NextToken':'again'})


try:
    import boto3
    from moto import mock_aws
    HAS_MOTO=True
except ImportError:HAS_MOTO=False

@unittest.skipUnless(HAS_MOTO,'Moto SDK expression coverage requires isolated SDK environment')
class TransactionExpressions(unittest.TestCase):
    def test_aggregate_cursor_uses_sdk_cas_without_partial_write(self):
        with mock_aws():
            d=boto3.client('dynamodb',region_name=q.REGION)
            d.create_table(TableName='pipeline',BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')])
            # Moto does not enforce IAM. Check negative call shapes in a stub;
            # exercise allowed transaction and rejected CAS on real SDK storage.
            denied=[]
            def record(call):denied.append(call)
            cases=[]
            with patch.object(q.w,'denied',side_effect=record):q.aggregate_cursor_cases(d,d,'pipeline',cases.append)
            self.assertEqual(len(denied),8);self.assertEqual(len(cases),5)
            self.assertEqual(q.read(d,'pipeline','AGGREGATE_SWEEP#dev'),q.row('AGGREGATE_SWEEP#dev',2))
    def test_pair_cas_and_races_use_real_sdk_and_no_partial_mutation(self):
        with mock_aws():
            d=boto3.client('dynamodb',region_name=q.REGION)
            d.create_table(TableName='pipeline',BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')])
            # Moto does not implement DynamoDB ClientRequestToken caching. This
            # adapter checks exact replay parameters and models only that layer;
            # the underlying transaction/CAS/races use SDK+Moto DynamoDB.
            class Replay:
                def __init__(self):self.cache={}
                def transact_write_items(self,**kw):
                    token=kw.get('ClientRequestToken')
                    if token and token in self.cache:
                        self_outer.assertEqual(self.cache[token],kw);return {}
                    result=d.transact_write_items(**kw)
                    if token:self.cache[token]=copy.deepcopy(kw)
                    return result
            self_outer=self;cases=[];q.positive_pairs('publisher',Replay(),d,{'pipeline':'pipeline'},cases.append)
            self.assertEqual(len(cases),7);self.assertTrue(all('race_atomic' in x for x in cases[2:]))

if __name__=='__main__':unittest.main()
