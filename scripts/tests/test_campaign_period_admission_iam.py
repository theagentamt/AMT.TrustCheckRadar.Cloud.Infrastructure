"""Offline source/containment tests; Moto proves expressions, never IAM enforcement."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('period_iam',Path(__file__).resolve().parents[1]/'qualify_campaign_period_admission_iam.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)


def base_policy(kind):
    statements=[]
    for sid,s in q.w.SPECS[kind].items():
        st={'Sid':sid,'Effect':'Allow','Action':sorted(s['actions']),'Resource':sorted(s['resources'])}
        if s['conditions']:st['Condition']=copy.deepcopy(s['conditions'])
        statements.append(st)
    return {'Version':'2012-10-17','Statement':statements}


def candidate(kind):
    conditions={'ForAllValues:StringLike':{'dynamodb:LeadingKeys':'PERIOD#*'},'StringEqualsIfExists':{'dynamodb:ReturnValues':'NONE'}}
    statements=[{'Sid':q.PERIOD_CHECK,'Effect':'Allow','Action':'dynamodb:ConditionCheckItem','Resource':q.PIPELINE,'Condition':copy.deepcopy(conditions)}]
    if kind=='lifecycle':
        conditions['ForAnyValue:StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
        statements.append({'Sid':q.CLOSE,'Effect':'Allow','Action':'dynamodb:UpdateItem','Resource':q.PIPELINE,'Condition':conditions})
    return {'Version':'2012-10-17','Statement':statements}


def world():
    audit={'observedAtUtc':'2026-09-25T04:00:00+00:00','roles':{}};plan={'resource_changes':[]}
    for kind in q.KINDS:
        name=q.ROLE_NAMES[kind];base=base_policy(kind);after=copy.deepcopy(base)
        if kind=='lifecycle':next(s for s in after['Statement'] if s['Sid']==q.NARROW_SID)['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=q.NEW_KEYS
        audit['roles'][name]={'arn':f'arn:aws:iam::{q.w.ACCOUNT}:role/{name}','managed':{},'permissionsBoundary':None,'inline':{kind+'-runtime':base,'content-free-logging':{'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':'logs:PutLogEvents','Resource':'*'},{'Effect':'Allow','Action':'cloudwatch:PutMetricData','Resource':'*'}]}}}
        def resource(address,action,before,after):return {'address':address,'mode':'managed','type':'aws_iam_role_policy','change':{'actions':[action],'before':before,'after':after,'after_unknown':{}}}
        plan['resource_changes'].append(resource(f'aws_iam_role_policy.{kind}_runtime[0]','update' if kind=='lifecycle' else 'no-op',{'policy':json.dumps(base)},{'name':kind+'-runtime','role':name,'policy':json.dumps(after)}))
        plan['resource_changes'].append(resource(f'aws_iam_role_policy.period_admission["{kind}"]','create',None,{'name':'campaign-period-admission','role':name,'policy':json.dumps(candidate(kind))}))
    return plan,audit


class AwsError(Exception):
    def __init__(self,code,reasons=None):
        self.response={'Error':{'Code':code}}
        if reasons is not None:self.response['CancellationReasons']=reasons


def raises(code,reasons=None):
    def call():raise AwsError(code,reasons)
    return call


class PeriodIamTests(unittest.TestCase):
    def load(self,p,a):
        with tempfile.TemporaryDirectory() as d:
            pp=Path(d)/'plan';ap=Path(d)/'audit';pp.write_text(json.dumps(p));ap.write_text(json.dumps(a));return q.load_union(pp,ap)
    def test_exact_union_preserves_other_families_removes_old_period(self):
        p,a=world();u,o,e=self.load(p,a)
        self.assertEqual({k:len(v['Statement']) for k,v in u.items()},{'publisher':9,'cluster':13,'lifecycle':7})
        broad=next(s for s in u['lifecycle']['Statement'] if s['Sid']==q.NARROW_SID)
        self.assertEqual(set(q.w.patterns(broad)),set(q.NEW_KEYS))
        writes=[s['Sid'] for s in u['lifecycle']['Statement'] if set(q.seq(s['Action']))&q.w.MUTATIONS and 'PERIOD#*' in q.w.patterns(s)]
        self.assertEqual(writes,[q.CLOSE]);self.assertEqual(len(e['helperSha256']),64)
    def test_old_overlap_or_other_narrowing_rejected(self):
        for keys in (q.OLD_KEYS,q.NEW_KEYS[:-1],q.NEW_KEYS+['*']):
            p,a=world();policy=json.loads(p['resource_changes'][4]['change']['after']['policy'])
            next(s for s in policy['Statement'] if s['Sid']==q.NARROW_SID)['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=keys
            p['resource_changes'][4]['change']['after']['policy']=json.dumps(policy)
            with self.assertRaises(Exception):self.load(p,a)
    def test_other_lifecycle_diff_rejected(self):
        p,a=world();policy=json.loads(p['resource_changes'][4]['change']['after']['policy']);policy['Statement'][0]['Action'].append('dynamodb:Scan');p['resource_changes'][4]['change']['after']['policy']=json.dumps(policy)
        with self.assertRaises(Exception):self.load(p,a)
    def test_extra_identity_policy_boundary_or_managed_refused(self):
        for field in ('inline','managed','permissionsBoundary'):
            p,a=world();r=a['roles'][q.ROLE_NAMES['lifecycle']]
            if field=='permissionsBoundary':r[field]={'arn':'extra'}
            else:r[field]['extra']=candidate('lifecycle')
            with self.assertRaises(Exception):self.load(p,a)
    def test_mixed_logging_or_unknown_allow_cannot_hide_overlap(self):
        for mode in ('mixed','notaction','unknown'):
            p,a=world();r=a['roles'][q.ROLE_NAMES['publisher']]
            if mode=='mixed':r['inline']['content-free-logging']['Statement'][0]['Action']=['logs:PutLogEvents','dynamodb:PutItem']
            elif mode=='notaction':r['inline']['content-free-logging']['Statement'][0]['NotAction']='logs:*'
            else:r['inline']['publisher-runtime']['Statement'].append(candidate('publisher')['Statement'][0])
            with self.assertRaises(Exception):self.load(p,a)
    def test_check_context_resource_and_returnvalues_strict(self):
        for edit in ({'Resource':'*'},{'Action':['dynamodb:ConditionCheckItem','dynamodb:UpdateItem']},{'NotResource':'*'}):
            p=candidate('publisher');p['Statement'][0].update(edit)
            with self.assertRaises(Exception):q.admission_policy(p,'publisher')
        for condition in ({'StringEquals':{'dynamodb:EnclosingOperation':'TransactWriteItems'}},{'StringEqualsIfExists':{'dynamodb:ReturnValues':'ALL_OLD'}}):
            p=candidate('publisher');p['Statement'][0]['Condition'].update(condition)
            with self.assertRaises(Exception):q.admission_policy(p,'publisher')
    def test_closure_requires_transaction_and_none(self):
        for remove in ('ForAnyValue:StringEquals','StringEqualsIfExists'):
            p=candidate('lifecycle');del p['Statement'][1]['Condition'][remove]
            with self.assertRaises(Exception):q.admission_policy(p,'lifecycle')
    def test_missing_duplicate_statement_rejected(self):
        for mode in ('missing','duplicate'):
            p=candidate('lifecycle')
            if mode=='missing':p['Statement'].pop()
            else:p['Statement'].append(copy.deepcopy(p['Statement'][0]))
            with self.assertRaises(Exception):q.admission_policy(p,'lifecycle')
    def test_plan_audit_binding_and_exact_role_required(self):
        for mode in ('role','before','unknown','action'):
            p,a=world();change=p['resource_changes'][1]['change']
            if mode=='role':change['after']['role']='other'
            elif mode=='before':change['before']={}
            elif mode=='unknown':change['after_unknown']['policy']=True
            else:change['actions']=['update']
            with self.assertRaises(Exception):self.load(p,a)
    def test_audited_before_not_substituted(self):
        p,a=world();p['resource_changes'][0]['change']['before']['policy']=json.dumps(candidate('publisher'))
        with self.assertRaises(Exception):self.load(p,a)
    def test_only_owned_resource_substitutions(self):
        p,a=world();u,_,_=self.load(p,a);suffixes=('pipeline','intelligence','outbox','users','ledger');names={k:'amt-campaign-qual-'+'a'*32+'-'+s for k,s in zip(q.w.TABLES,suffixes)}
        for policy in u.values():self.assertNotIn('trustcheckradar-dev-',q.canonical(q.w.fixture_policy(policy,names)))
        names['campaign-pipeline']='trustcheckradar-dev-campaign-pipeline'
        with self.assertRaises(Exception):q.w.fixture_policy(u['lifecycle'],names)
    def test_only_accessdenied_proves_denial(self):
        q.w.denied(raises('AccessDeniedException'))
        for code in ('TransactionCanceledException','ValidationException','ThrottlingException'):
            with self.assertRaises(Exception):q.w.denied(raises(code))
        with self.assertRaises(Exception):q.w.denied(lambda:None)
    def test_cancel_requires_expected_guard_and_no_returned_item(self):
        q.w.canceled_without_item(raises('TransactionCanceledException',[{'Code':'None'},{'Code':'ConditionalCheckFailed'}]),1)
        for reasons in ([{'Code':'None'},{'Code':'ConditionalCheckFailed','Item':{'PK':{'S':'secret'}}}],[{'Code':'ConditionalCheckFailed'},{'Code':'None'}],[]):
            with self.assertRaises(Exception):q.w.canceled_without_item(raises('TransactionCanceledException',reasons),1)


class LocalExpressionTests(unittest.TestCase):
    def test_all_positive_fixture_calls_and_atomic_cases_are_valid_sdk_shapes(self):
        # Denial calls are intentionally skipped: Moto is not IAM evidence.
        try:
            import boto3
            from moto import mock_aws
            from unittest.mock import patch
        except ImportError:self.skipTest('Moto unavailable')
        p,a=world()
        with tempfile.TemporaryDirectory() as d:
            pp=Path(d)/'plan';ap=Path(d)/'audit';pp.write_text(json.dumps(p));ap.write_text(json.dumps(a));policies,_,_=q.load_union(pp,ap)
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.w.REGION,aws_access_key_id='testing',aws_secret_access_key='testing')
            names={k:'fixture-'+k for k in q.w.TABLES}
            for table in names.values():
                c.create_table(TableName=table,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':k,'KeyType':v} for k,v in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            for kind in q.KINDS:
                report={'cases':[]}
                with patch.object(q.w,'denied',lambda call:None):q.exercise(kind,c,c,policies[kind],names,report)
                self.assertIn(kind+':closing_guard_race_atomic_without_item',report['cases'])
                if kind=='lifecycle':self.assertIn(kind+':inventory_guard_race_keeps_period_open',report['cases'])

    def test_guard_race_rolls_back_write(self):
        try:
            import boto3
            from moto import mock_aws
        except ImportError:self.skipTest('Moto unavailable')
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.w.REGION,aws_access_key_id='testing',aws_secret_access_key='testing');table='fixture-pipeline'
            c.create_table(TableName=table,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':k,'KeyType':v} for k,v in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            period='PERIOD#fixture';event='EVENT#fixture';c.put_item(TableName=table,Item={**q.w.key(period),'admissionState':{'S':'OPEN'},'revision':{'N':'1'}})
            c.transact_write_items(TransactItems=[q.check(table,period),q.w.tx_action('dynamodb:PutItem',table,event)])
            before=c.get_item(TableName=table,Key=q.w.key(event))['Item']
            for field,value in [('admissionState',{'S':'CLOSING'}),('revision',{'N':'2'})]:
                c.update_item(TableName=table,Key=q.w.key(period),UpdateExpression='SET admissionState = :s, revision = :r',ExpressionAttributeValues={':s':{'S':'OPEN'},':r':{'N':'1'}})
                c.update_item(TableName=table,Key=q.w.key(period),UpdateExpression='SET '+field+' = :v',ExpressionAttributeValues={':v':value})
                mutation=q.w.tx_action('dynamodb:DeleteItem',table,event)
                q.w.canceled_without_item(lambda:c.transact_write_items(TransactItems=[mutation,q.check(table,period)]),1)
                self.assertEqual(c.get_item(TableName=table,Key=q.w.key(event))['Item'],before)

if __name__=='__main__':unittest.main()
