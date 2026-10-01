"""Offline exact union/containment tests; optional Moto is expression evidence only."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('completion_iam',Path(__file__).resolve().parents[1]/'qualify_campaign_completion_iam.py');q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)

def candidate():
    return {'Version':'2012-10-17','Statement':[{'Sid':sid,'Effect':'Allow','Action':sorted(actions),'Resource':resource,'Condition':copy.deepcopy(condition)} for sid,(actions,resource,condition) in q.specifications().items()]}

def world():
    deletion={'Version':'2012-10-17','Statement':[]}
    for sid,s in q.writer.SPECS['deletion'].items():
        row={'Sid':sid,'Effect':'Allow','Action':sorted(s['actions']),'Resource':sorted(s['resources'])}
        if s['conditions']:row['Condition']=copy.deepcopy(s['conditions'])
        deletion['Statement'].append(row)
    recovery={'Version':'2012-10-17','Statement':[{'Sid':sid,'Effect':'Allow','Action':action,'Resource':resource,'Condition':copy.deepcopy(condition)} for sid,(action,resource,condition) in q.recovery.expected().items()]}
    role={'arn':f'arn:aws:iam::{q.ACCOUNT}:role/{q.ROLE}','permissionsBoundary':None,'managed':{},'inline':{'deletion-runtime':deletion,'campaign-recovery-candidate':recovery,'content-free-logging':{'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':'logs:PutLogEvents','Resource':'*'},{'Effect':'Allow','Action':'cloudwatch:PutMetricData','Resource':'*'}]}}}
    audit={'observedAtUtc':'2026-09-25T03:00:00+00:00','roles':{q.ROLE:role}}
    plan={'resource_changes':[{'address':q.ADDRESS,'mode':'managed','type':'aws_iam_role_policy','change':{'actions':['create'],'before':None,'after':{'name':'campaign-completion-candidate','role':q.ROLE,'policy':json.dumps(candidate())},'after_unknown':{}}}]}
    return plan,audit

class AwsError(Exception):
    def __init__(self,code,reasons=None):
        self.response={'Error':{'Code':code}}
        if reasons is not None:self.response['CancellationReasons']=reasons

def raises(code,reasons=None):
    def call():raise AwsError(code,reasons)
    return call

class CompletionIamTests(unittest.TestCase):
    def load(self,p,a):
        with tempfile.TemporaryDirectory() as d:
            pp=Path(d)/'plan';ap=Path(d)/'audit';pp.write_text(json.dumps(p));ap.write_text(json.dumps(a));return q.load_union(pp,ap)
    def test_exact_complete_identity_union_preserves_old_update(self):
        p,a=world();u,e=self.load(p,a);self.assertEqual(len(u['Statement']),10)
        old=next(s for s in u['Statement'] if s['Sid']=='AdvanceOwnedRecoveryRetryTransaction')
        self.assertNotIn('StringEqualsIfExists',old['Condition'])
        self.assertTrue(e['omittedStatements']);self.assertEqual(len(e['helperSha256']),2)
    def test_candidate_changes_are_rejected(self):
        for change in ({'Resource':'*'},{'Effect':'Deny'},{'Action':'dynamodb:Scan'},{'Condition':{}},{'NotResource':'anything'}):
            p=candidate();p['Statement'][0].update(change)
            with self.assertRaises(Exception):q.validate_candidate(p)
    def test_duplicate_missing_and_unsupported_check_context_rejected(self):
        for mode in ('duplicate','missing','check'):
            p=candidate()
            if mode=='duplicate':p['Statement'].append(copy.deepcopy(p['Statement'][0]))
            elif mode=='missing':p['Statement'].pop()
            else:p['Statement'][-1]['Condition']['StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
            with self.assertRaises(Exception):q.validate_candidate(p)
    def test_extra_attached_inline_or_boundary_refused(self):
        for mode in ('managed','inline','boundary'):
            p,a=world();role=a['roles'][q.ROLE]
            if mode=='managed':role['managed']['extra']=candidate()
            elif mode=='inline':role['inline']['extra']=candidate()
            else:role['permissionsBoundary']={'arn':'anything'}
            with self.assertRaises(Exception):self.load(p,a)
    def test_logging_wildcard_action_or_notaction_cannot_hide_overlap(self):
        for edit in ({'Action':'*'},{'Action':'dynamodb:*'},{'NotAction':'logs:*'}):
            p,a=world();a['roles'][q.ROLE]['inline']['content-free-logging']['Statement'][0].update(edit)
            with self.assertRaises(Exception):self.load(p,a)
    def test_unrecognized_ledger_grant_never_cherry_picked(self):
        p,a=world();a['roles'][q.ROLE]['inline']['deletion-runtime']['Statement'].append({'Sid':'Unexpected','Effect':'Allow','Action':'dynamodb:Scan','Resource':q.TABLES['ledger']})
        with self.assertRaises(Exception):self.load(p,a)
    def test_foreign_or_broadened_recovery_resource_rejected(self):
        for resource in ('*',q.TABLES['ledger']+'*',q.TABLES['ledger'].replace('us-east-1','us-west-2')):
            p,a=world();a['roles'][q.ROLE]['inline']['campaign-recovery-candidate']['Statement'][0]['Resource']=resource
            with self.assertRaises(Exception):self.load(p,a)
    def test_plan_must_bind_known_policy_to_exact_role(self):
        for mode in ('address','unknown','update','role'):
            p,a=world();r=p['resource_changes'][0]
            if mode=='address':r['address']='something_else'
            elif mode=='unknown':r['change']['after_unknown']['policy']=True
            elif mode=='update':r['change']['actions']=['update']
            else:r['change']['after']['role']='different'
            with self.assertRaises(Exception):self.load(p,a)
    def test_only_owned_fixture_names_resources_are_mapped(self):
        p,a=world();u,_=self.load(p,a);names={k:q.PREFIX+'a'*32+'-'+k for k in q.TABLES};result=q.remap(u,names)
        self.assertNotIn('trustcheckradar-dev-',q.canonical(result));self.assertIn('trustcheckradar-dev-',q.canonical(u))
        for changes in ({'ledger':'trustcheckradar-dev-deletion-ledger'},{'users':names['ledger']}):
            with self.assertRaises(q.QualificationError):q.remap(u,names|changes)
        u['Statement'][0]['Resource']='*'
        with self.assertRaises(q.QualificationError):q.remap(u,names)
    def test_denial_requires_authorization_failure(self):
        q.denied(raises('AccessDeniedException'))
        for error in ('ValidationException','TransactionCanceledException','ThrottlingException'):
            with self.assertRaises(q.QualificationError):q.denied(raises(error))
        with self.assertRaises(q.QualificationError):q.denied(lambda:None)
    def test_rollback_requires_exact_guard_without_returned_item(self):
        q.canceled(raises('TransactionCanceledException',[{'Code':'None'},{'Code':'ConditionalCheckFailed'}]),1)
        for reasons in ([],[{'Code':'None'}],[{'Code':'ConditionalCheckFailed','Item':{'anything':'secret'}}]):
            with self.assertRaises(q.QualificationError):q.canceled(raises('TransactionCanceledException',reasons))
    def test_transaction_targets_are_distinct_and_no_full_handler_claim(self):
        for withdrawal in (False,True):
            actions=q.transaction({'ledger':'ledger','users':'users'},'synthetic',withdrawal);keys=[]
            for x in actions:
                op=next(iter(x.values()));k=op.get('Key',op.get('Item'));keys.append((op['TableName'],k['PK']['S'],k['SK']['S']))
            self.assertEqual(len(keys),len(set(keys)))

class LocalExpressionTests(unittest.TestCase):
    def test_moto_positive_and_race_transaction_shapes(self):
        try:
            import boto3
            from moto import mock_aws
        except ImportError:self.skipTest('Moto not installed')
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.REGION,aws_access_key_id='testing',aws_secret_access_key='testing');names={'ledger':'fixture-ledger','users':'fixture-users'}
            for name in names.values():c.create_table(TableName=name,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':x,'KeyType':t} for x,t in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')])
            for withdrawal in (False,True):
                for failure,index in [(None,None),('control',2),('profile',3),('inventory',4)]:
                    subject=str(withdrawal)+str(failure);q.prepare(c,names,subject);actions=q.transaction(names,subject,withdrawal);pk='ACCOUNT#'+subject
                    if failure:
                        table,k,sk=(names['users'],'USER#'+subject,'PROFILE') if failure=='profile' else (names['ledger'],'INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY') if failure=='inventory' else (names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL')
                        c.update_item(TableName=table,Key=q.key(k,sk),UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'99'}})
                        before=q.read(c,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL');q.canceled(lambda:c.transact_write_items(TransactItems=actions),index)
                        self.assertEqual(before,q.read(c,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL'));self.assertIsNotNone(q.read(c,names['ledger'],pk,'CAMPAIGN_RECOVERY#job'));self.assertIsNone(q.read(c,names['ledger'],pk,'ACCOUNT_DELETION#CAMPAIGN'))
                    else:
                        c.transact_write_items(TransactItems=actions);self.assertIsNone(q.read(c,names['ledger'],pk,'CAMPAIGN_RECOVERY#job'))
                        self.assertEqual(q.read(c,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL')['pendingJobs'],{'N':'0'})
                        q.canceled(lambda:c.transact_write_items(TransactItems=actions))

if __name__=='__main__':unittest.main()
