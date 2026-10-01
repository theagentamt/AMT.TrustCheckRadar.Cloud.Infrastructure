"""Offline source binding/SDK atomicity; never claims mocked IAM evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
helper=Path(__file__).with_name('qualify_history_deletion_iam.py')
if not helper.exists():helper=Path(__file__).resolve().parents[1]/'qualify_history_deletion_iam.py'
spec=importlib.util.spec_from_file_location('q',helper);q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)


def policy(kind):
    result=[]
    for i,encoded in enumerate(q.expected(kind)):
        actions,resources,conditions=json.loads(encoded)
        result.append({'Sid':'Case'+str(i),'Effect':'Allow','Action':actions,'Resource':resources,**({'Condition':conditions} if conditions else {})})
    return {'Version':'2012-10-17','Statement':result}


def world(kind):
    role,name,address=q.ROLES[kind];doc=policy(kind);row={'name':name,'role':role,'policy':json.dumps(doc)}
    return {'resource_changes':[{'address':address,'mode':'managed','type':'aws_iam_role_policy','change':{'actions':['update'],'before':row,'after':copy.deepcopy(row),'after_unknown':{}}}]},{'observedAtUtc':'2026-09-26T14:00:00+00:00','roles':{role:{'arn':f'arn:aws:iam::{q.ACCOUNT}:role/{role}','permissionsBoundary':None,'managed':{},'inline':{name:doc}}}}


class Error(Exception):
    def __init__(self,code,reasons=None):
        self.response={'Error':{'Code':code}}
        if reasons is not None:self.response['CancellationReasons']=reasons

def raises(code,reasons=None):
    def call():raise Error(code,reasons)
    return call


class Tests(unittest.TestCase):
    def load(self,p,a,kind):
        with tempfile.TemporaryDirectory() as d:
            x=Path(d)/'plan';y=Path(d)/'audit';x.write_text(json.dumps(p));y.write_text(json.dumps(a));return q.load_union(x,y,kind)
    def test_complete_role_unions_and_exact_binding(self):
        for kind,count in [('lifecycle',7),('bridge',8)]:
            p,a=world(kind);u,e=self.load(p,a,kind);self.assertEqual(len(u['Statement']),count);self.assertEqual(e['roleKind'],kind)
    def test_unsupported_check_context_and_widened_return_values_rejected(self):
        for mode in ('enclosing','all_old'):
            doc=policy('bridge');st=doc['Statement'][0]
            if mode=='enclosing':st['Condition']['StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
            else:st['Condition']['StringEqualsIfExists']['dynamodb:ReturnValues']=['ALL_OLD']
            with self.assertRaises(Exception):q.project(doc,'bridge')
    def test_transaction_context_and_return_none_required(self):
        for mode in ('context','none'):
            doc=policy('bridge');st=doc['Statement'][-1]
            if mode=='context':st['Condition']['StringEquals']=st['Condition'].pop('ForAnyValue:StringEquals')
            else:del st['Condition']['StringEqualsIfExists']
            with self.assertRaises(Exception):q.project(doc,'bridge')
    def test_extra_broad_overlap_cannot_hide_in_ancillary_policy(self):
        p,a=world('bridge');role=q.ROLES['bridge'][0]
        a['roles'][role]['inline']['extra']={'Version':'2012-10-17','Statement':[{'Sid':'Extra','Effect':'Allow','Action':'dynamodb:PutItem','Resource':q.TABLES['control']}]}
        with self.assertRaises(Exception):self.load(p,a,'bridge')
    def test_wildcard_mixed_resource_and_deny_fail_closed(self):
        for extra in [
            {'Effect':'Allow','Action':'dynamodb:*','Resource':'*'},
            {'Effect':'Allow','Action':'dynamodb:PutItem','Resource':q.TABLES['control']+'*'},
            {'Effect':'Allow','Action':'dynamodb:PutItem','Resource':[q.TABLES['control'],q.ROOT+'other']},
            {'Effect':'Deny','Action':'dynamodb:PutItem','Resource':q.TABLES['control']}]:
            doc=policy('bridge');doc['Statement'].append({'Sid':'Extra',**extra})
            with self.assertRaises(Exception):q.project(doc,'bridge')
    def test_exact_disjoint_index_and_logging_explicit(self):
        doc=policy('lifecycle');doc['Statement'].append({'Sid':'Index','Effect':'Allow','Action':'dynamodb:Query','Resource':q.TABLES['control']+'/index/PendingLifecycleIndex','Condition':q.condition(['HISTORY#*','CONTROL#*','PENDING#*'])})
        u,e=q.project(doc,'lifecycle');self.assertEqual(len(u['Statement']),7);self.assertEqual(e[0]['reason'],'exact_index_arns_do_not_authorize_base_table_operations')
        doc['Statement'][-1]['Resource']=q.TABLES['control']
        with self.assertRaises(Exception):q.project(doc,'lifecycle')
    def test_split_stream_permissions_are_explicit_and_action_disjoint(self):
        doc=policy('bridge')
        doc['Statement'].extend([
            {'Sid':'Stream','Effect':'Allow','Action':['dynamodb:DescribeStream','dynamodb:GetRecords','dynamodb:GetShardIterator'],'Resource':q.TABLES['ledger']+'/stream/2026-09-04T02:19:27.000'},
            {'Sid':'List','Effect':'Allow','Action':'dynamodb:ListStreams','Resource':'*','Condition':{'StringEquals':{'aws:RequestedRegion':q.REGION}}}])
        u,e=q.project(doc,'bridge');self.assertEqual(len(u['Statement']),8);self.assertEqual(len(e),2)
        for change in ('region','action','condition'):
            bad=copy.deepcopy(doc);st=bad['Statement'][-1]
            if change=='region':st['Condition']['StringEquals']['aws:RequestedRegion']='us-west-2'
            elif change=='action':st['Action']=['dynamodb:ListStreams','dynamodb:Scan']
            else:del st['Condition']
            with self.assertRaises(Exception):q.project(bad,'bridge')
    def test_managed_boundary_unknown_policy_and_wrong_role_rejected(self):
        for mode in ('managed','boundary','before','role','unknown'):
            p,a=world('bridge');r=a['roles'][q.ROLES['bridge'][0]];c=p['resource_changes'][0]['change']
            if mode=='managed':r['managed']={'extra':{}}
            elif mode=='boundary':r['permissionsBoundary']={'arn':'extra'}
            elif mode=='before':c['before']['policy']='{}'
            elif mode=='role':c['after']['role']='wrong'
            else:c['after_unknown']['policy']=True
            with self.assertRaises(Exception):self.load(p,a,'bridge')
    def test_only_owned_fixture_arns(self):
        names={k:q.PREFIX+'a'*32+'-'+k for k in q.TABLES};mapped=q.remap(policy('bridge'),names)
        self.assertNotIn('trustcheckradar-dev-',q.canonical(mapped))
        for wrong in ({'control':'trustcheckradar-dev-history-control'},{'ledger':names['control']}):
            with self.assertRaises(Exception):q.remap(policy('bridge'),names|wrong)
        doc=policy('bridge');doc['Statement'][0]['Resource']='*'
        with self.assertRaises(Exception):q.remap(doc,names)
    def test_distinct_transaction_keys_all_none(self):
        actions=q.transaction({k:k for k in q.TABLES},'USER#fixture','ACCOUNT#fixture');targets=[]
        for action in actions:
            op=next(iter(action.values()));key=op.get('Key',op.get('Item'));targets.append((op['TableName'],key['PK']['S'],key['SK']['S']));self.assertEqual(op['ReturnValuesOnConditionCheckFailure'],'NONE')
        self.assertEqual(len(targets),len(set(targets)))
    def test_denials_and_rollbacks_are_not_conflated(self):
        q.f.denied(raises('AccessDeniedException'))
        for code in ('ValidationException','ThrottlingException','TransactionCanceledException'):
            with self.assertRaises(Exception):q.f.denied(raises(code))
        q.f.canceled(raises('TransactionCanceledException',[{'Code':'ConditionalCheckFailed'}]),0)
        with self.assertRaises(Exception):q.f.canceled(raises('TransactionCanceledException',[{'Code':'ConditionalCheckFailed','Item':{'PK':{'S':'x'}}}]),0)
    def test_synthetic_transaction_sdk_shape_and_atomic_races(self):
        import boto3
        from moto import mock_aws
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.REGION,aws_access_key_id='testing',aws_secret_access_key='testing');names={k:'fixture-'+k for k in q.TABLES}
            for t in names.values():c.create_table(TableName=t,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':k,'KeyType':v} for k,v in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            pk,account=q.seed(c,names,'positive');c.transact_write_items(TransactItems=q.transaction(names,pk,account));self.assertEqual(q.snapshot(c,names,pk,account)[0]['revision'],{'N':'2'})
            for index in (0,1):
                pk,account=q.seed(c,names,str(index));actions=q.transaction(names,pk,account);op=actions[index]['ConditionCheck']
                c.update_item(TableName=op['TableName'],Key=op['Key'],UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'9'}})
                before=q.snapshot(c,names,pk,account);q.f.canceled(lambda:c.transact_write_items(TransactItems=actions),index);self.assertEqual(before,q.snapshot(c,names,pk,account))

if __name__=='__main__':unittest.main()
