"""Offline binding and synthetic SDK-shape tests, never mock IAM acceptance."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('q',Path(__file__).resolve().parents[1]/'qualify_account_deletion_iam.py');q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)


def policy():
    return {'Version':'2012-10-17','Statement':[{'Sid':sid,'Effect':'Allow','Action':sorted(s['actions']),'Resource':s['table'],**({'Condition':s['conditions']} if s['conditions'] else {})} for sid,s in q.specifications().items()]}


def world():
    doc=policy();row={'name':'account-data-runtime','role':q.ROLE,'policy':json.dumps(doc)}
    return {'resource_changes':[{'address':q.ADDRESS,'mode':'managed','type':'aws_iam_role_policy','change':{'actions':['update'],'before':row,'after':copy.deepcopy(row),'after_unknown':{}}}]},{'observedAtUtc':'2026-09-26T20:00:00+00:00','roles':{q.ROLE:{'arn':f'arn:aws:iam::{q.ACCOUNT}:role/{q.ROLE}','permissionsBoundary':None,'managed':{},'inline':{'account-data-runtime':doc}}}}


class Error(Exception):
    def __init__(self,code,reasons=None):
        self.response={'Error':{'Code':code}}
        if reasons is not None:self.response['CancellationReasons']=reasons


def raises(code,reasons=None):
    def call():raise Error(code,reasons)
    return call


class Tests(unittest.TestCase):
    def load(self,plan,audit):
        with tempfile.TemporaryDirectory() as d:
            a=Path(d)/'plan';b=Path(d)/'audit';a.write_text(json.dumps(plan));b.write_text(json.dumps(audit));return q.load_union(a,b)
    def test_complete_three_table_union_and_source_binding(self):
        p,a=world();u,e=self.load(p,a);self.assertEqual(len(u['Statement']),13);self.assertEqual(len(e['helperSha256']),4)
        self.assertIn('ReconcileMissedRevocations',[s['Sid'] for s in u['Statement']])
    def test_old_mutation_context_and_missing_none_rejected(self):
        for sid in ('TransactionallyFenceAuthoritativeProfile','EraseOwnedPurchaseTransaction'):
            for mode in ('context','none'):
                p=policy();s=next(s for s in p['Statement'] if s['Sid']==sid)
                if mode=='context':s['Condition']['StringEquals']=s['Condition'].pop('ForAnyValue:StringEquals')
                else:del s['Condition']['StringEqualsIfExists']
                with self.assertRaises(Exception):q.project(p)
    def test_check_enclosingoperation_and_all_old_rejected(self):
        for sid in ('CheckPurchaseCleanupInventory','CheckDeletionProofTransaction'):
            for mode in ('enclosing','all_old'):
                p=policy();s=next(s for s in p['Statement'] if s['Sid']==sid)
                if mode=='enclosing':s['Condition']['StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
                else:s['Condition']['StringEqualsIfExists']['dynamodb:ReturnValues']='ALL_OLD'
                with self.assertRaises(Exception):q.project(p)
    def test_extra_wildcard_mixed_or_target_statement_never_omitted(self):
        for resources,actions in [('*',['dynamodb:*']),([q.TABLES['purchase']+'*'],['dynamodb:DeleteItem']),([q.TABLES['users']],["dynamodb:PutItem"]),([q.ROOT+'trustcheckradar-dev-device-bindings'],['logs:PutLogEvents','dynamodb:DeleteItem'])]:
            p=policy();p['Statement'].append({'Sid':'extra','Effect':'Allow','Resource':resources,'Action':actions})
            with self.assertRaises(Exception):q.project(p)
    def test_disjoint_omission_is_explicit(self):
        p=policy();p['Statement'].append({'Sid':'DeviceCleanup','Effect':'Allow','Resource':q.ROOT+'trustcheckradar-dev-device-bindings','Action':['dynamodb:DeleteItem']});u,o=q.project(p)
        self.assertEqual(len(u['Statement']),13);self.assertEqual(o[0]['reason'],'exact_disjoint_table_resource')
    def test_full_role_audit_no_extra_identity_authority(self):
        for field in ('managed','inline','permissionsBoundary'):
            p,a=world();r=a['roles'][q.ROLE]
            if field=='permissionsBoundary':r[field]={'arn':'extra'}
            else:r[field]['extra']=policy()
            with self.assertRaises(Exception):self.load(p,a)
    def test_plan_binding_and_before_snapshot_are_exact(self):
        for mode in ('before','role','unknown','delete'):
            p,a=world();change=p['resource_changes'][0]['change']
            if mode=='before':change['before']['policy']='{}'
            elif mode=='role':change['after']['role']='other'
            elif mode=='unknown':change['after_unknown']['policy']=True
            else:change['actions']=['delete']
            with self.assertRaises(Exception):self.load(p,a)
    def test_safe_resource_substitution_only(self):
        names={k:q.PREFIX+'a'*32+'-'+k for k in q.TABLES};mapped=q.remap(policy(),names)
        self.assertNotIn('trustcheckradar-dev-',q.canonical(mapped))
        for edit in ({'purchase':'trustcheckradar-dev-purchase-entitlements'},{'purchase':names['users']}):
            with self.assertRaises(Exception):q.remap(policy(),names|edit)
        p=policy();p['Statement'][0]['Resource']='*'
        with self.assertRaises(Exception):q.remap(p,names)
    def test_denial_and_atomic_failures_not_confused(self):
        q.f.denied(raises('AccessDeniedException'))
        for code in ('ValidationException','ThrottlingException','TransactionCanceledException'):
            with self.assertRaises(Exception):q.f.denied(raises(code))
        q.f.canceled(raises('TransactionCanceledException',[{'Code':'None'},{'Code':'ConditionalCheckFailed'}]),1)
        with self.assertRaises(Exception):q.f.canceled(raises('TransactionCanceledException',[{'Code':'ConditionalCheckFailed','Item':{'PK':{'S':'test'}}}]),0)
    def test_transaction_targets_distinct_and_returns_none(self):
        actions=q.transaction({k:k for k in q.TABLES},'test');targets=[]
        for action in actions:
            op=next(iter(action.values()));key=op.get('Key',op.get('Item'));targets.append((op['TableName'],key['PK']['S'],key['SK']['S']));self.assertEqual(op['ReturnValuesOnConditionCheckFailure'],'NONE')
        self.assertEqual(len(targets),len(set(targets)))
    def test_all_positive_sdk_shapes_and_rollbacks_with_moto(self):
        try:
            import boto3
            from moto import mock_aws
        except ImportError:self.skipTest('Moto unavailable')
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.REGION,aws_access_key_id='testing',aws_secret_access_key='testing');names={k:'fixture-'+k for k in q.TABLES}
            for t in names.values():c.create_table(TableName=t,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':k,'KeyType':v} for k,v in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            report={'runId':'a'*32,'cases':[]}
            # Moto does not prove IAM denials. Validate their SDK shapes separately.
            with patch.object(q.f,'denied',lambda call:None):q.exercise(c,c,names,report)
            self.assertEqual(len(report['cases']),13)

if __name__=='__main__':unittest.main()
