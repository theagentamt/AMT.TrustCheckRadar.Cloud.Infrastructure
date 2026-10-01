"""Local source/containment checks; mocks never establish AWS IAM acceptance."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
s=importlib.util.spec_from_file_location('q',Path(__file__).resolve().parents[1]/'qualify_campaign_account_cleanup_iam.py');q=importlib.util.module_from_spec(s);s.loader.exec_module(q)


def policy(kind):
    return {'Version':'2012-10-17','Statement':[{'Sid':sid,'Effect':'Allow','Action':action,'Resource':resource,'Condition':copy.deepcopy(condition)} for sid,(owner,action,resource,condition) in q.expected().items() if owner==kind]}


def plan():
    return {'resource_changes':[{'address':f'aws_iam_role_policy.account_cleanup["{k}"]','mode':'managed','type':'aws_iam_role_policy','change':{'actions':['create'],'before':None,'after':{'role':r,'name':'campaign-account-cleanup','policy':json.dumps(policy(k))},'after_unknown':{}}} for k,r in q.ROLES.items()]}


def audit():
    return {'observedAtUtc':'2026-09-26T14:00:00+00:00','roles':{name:{'arn':f'arn:aws:iam::{q.ACCOUNT}:role/{name}','permissionsBoundary':None,'inline':{'existing':{'Version':'2012-10-17','Statement':[{'Sid':'Logging','Effect':'Allow','Action':'logs:PutLogEvents','Resource':'*'}]}},'managed':{}} for name in q.ROLES.values()}}


class Tests(unittest.TestCase):
    def load(self,p,a=None):
        with tempfile.TemporaryDirectory() as d:
            pp=Path(d)/'plan';pp.write_text(json.dumps(p));ap=Path(d)/'audit'
            if a is not None:ap.write_text(json.dumps(a))
            return q.load(pp,ap if a is not None else None)
    def test_three_new_grants_and_explicit_limited_scope(self):
        p,e=self.load(plan(),audit());self.assertEqual(len(p['Statement']),3);self.assertEqual(e['possibleExistingNamespaceOverlaps'],[]);self.assertIn('not full-role',e['scope'])
    def test_no_audit_makes_no_overlap_claim(self):
        _,e=self.load(plan());self.assertIn('not supplied',e['roleAuditScope'])
    def test_extra_action_resource_or_context_refused(self):
        for change in ({'Action':'dynamodb:DeleteItem'},{'Resource':'*'},{'NotAction':'dynamodb:PutItem'},{'Condition':{}}):
            p=policy('deletion');p['Statement'][0].update(change)
            with self.assertRaises(Exception):q.validate(p,'deletion')
        p=policy('lifecycle');p['Statement'][0]['Condition']['StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
        with self.assertRaises(Exception):q.validate(p,'lifecycle')
    def test_duplicate_missing_and_wrong_role_refused(self):
        p=policy('deletion');p['Statement'].append(copy.deepcopy(p['Statement'][0]))
        with self.assertRaises(Exception):q.validate(p,'deletion')
        with self.assertRaises(Exception):q.validate(policy('deletion'),'lifecycle')
        p=plan();p['resource_changes'][0]['change']['after']['role']='other'
        with self.assertRaises(Exception):self.load(p)
    def test_fixture_can_only_have_two_owned_tables_and_no_mutation(self):
        p,_=self.load(plan());n={k:q.PREFIX+'a'*32+'-'+k for k in q.TABLES};mapped=q.remap(p,n);self.assertNotIn('trustcheckradar-dev-',q.canonical(mapped))
        with self.assertRaises(Exception):q.remap(p,n|{'pipeline':'trustcheckradar-dev-campaign-pipeline'})
        p['Statement'][0]['Action']='dynamodb:PutItem'
        with self.assertRaises(Exception):q.remap(p,n)
    def test_audit_wildcards_and_not_selectors_are_reported_not_ignored(self):
        for statement in ({'Effect':'Allow','Action':'dynamodb:*','Resource':'*'},{'Effect':'Deny','NotAction':'logs:*','NotResource':q.TABLES['pipeline']}):
            a=audit();a['roles'][q.ROLES['deletion']]['managed']['extra']={'Version':'2012-10-17','Statement':[statement]};_,e=self.load(plan(),a)
            self.assertEqual(len(e['possibleExistingNamespaceOverlaps']),2)
    def test_resource_variables_cannot_prove_disjointness(self):
        for selector in ('Resource','NotResource'):
            a=audit();a['roles'][q.ROLES['deletion']]['inline']['variable']={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':'dynamodb:*',selector:'arn:aws:dynamodb:${region}:${account}:table/${table}'}]}
            _,e=self.load(plan(),a);self.assertEqual(len(e['possibleExistingNamespaceOverlaps']),2)
    def test_only_proven_disjoint_namespace_is_excluded(self):
        for prefix,count in [('PERIOD#*',0),('CONTRIB#*',1),('*',1),('${variable}#*',1),('CON*',1)]:
            a=audit();st=policy('lifecycle')['Statement'][0];st['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=prefix;a['roles'][q.ROLES['lifecycle']]['inline']['other']={'Version':'2012-10-17','Statement':[st]};_,e=self.load(plan(),a);self.assertEqual(len(e['possibleExistingNamespaceOverlaps']),count)
    def test_ambiguous_audit_shapes_fail_closed(self):
        a=audit();a['roles'][q.ROLES['deletion']]['inline']['existing']['Statement'][0]['NotAction']='logs:*'
        with self.assertRaises(Exception):self.load(plan(),a)
        a=audit();a['roles'][q.ROLES['deletion']]['permissionsBoundary']={'arn':'unknown'}
        with self.assertRaises(Exception):self.load(plan(),a)
    def test_positive_sdk_shapes_and_check_cancellation(self):
        try:
            import boto3
            from moto import mock_aws
        except ImportError:self.skipTest('Moto unavailable')
        with mock_aws():
            c=boto3.client('dynamodb',region_name=q.REGION,aws_access_key_id='testing',aws_secret_access_key='testing');n={k:'fixture-'+k for k in q.TABLES}
            for t in n.values():c.create_table(TableName=t,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':k,'KeyType':v} for k,v in [('PK','HASH'),('SK','RANGE')]],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            report={'cases':[]}
            with patch.object(q.f,'denied',lambda call:None):q.exercise(c,c,n,report)
            self.assertEqual(len(report['cases']),14)

if __name__=='__main__':unittest.main()
