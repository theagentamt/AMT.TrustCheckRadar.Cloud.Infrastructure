"""Offline safety/refusal tests. No AWS credentials or API calls are used."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT=Path(__file__).resolve().parents[1]/'qualify_campaign_producer_iam.py'
spec=importlib.util.spec_from_file_location('producer_iam',SCRIPT)
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)

def source(role):
    statements=[]
    for sid,expected in q.SPECS[role].items():
        st={'Sid':sid,'Effect':'Allow','Action':sorted(expected['actions']),'Resource':expected['table']}
        if expected['conditions']:st['Condition']=copy.deepcopy(expected['conditions'])
        statements.append(st)
    return {'Version':'2012-10-17','Statement':statements}

def audit_and_plan():
    roles={};changes=[]
    for role,address in q.ADDRESSES.items():
        name='trustcheckradar-dev-'+('account-data-api-role' if role=='account_data' else 'campaign-participation-role')
        before=source(role);after=source(role)
        after_record={'policy':json.dumps(after)}
        entry={'arn':f'arn:aws:iam::{q.ACCOUNT}:role/{name}','permissionsBoundary':None,'inline':{},'managed':{}}
        if role=='account_data':
            entry['inline']['account-data-runtime']=before
            after_record.update(role=name,name='account-data-runtime')
        else:
            runtime=f'arn:aws:iam::{q.ACCOUNT}:policy/trustcheckradar-dev-campaign-participation-runtime'
            entry['managed'][runtime]=before;after_record['arn']=runtime
            entry['managed']['arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole']={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['logs:CreateLogGroup','logs:CreateLogStream','logs:PutLogEvents'],'Resource':'*'}]}
            entry['inline']['trustcheckradar-dev-research-migration-participation']={'Version':'2012-10-17','Statement':[
              {'Sid':'DenyProviderCredentialsAndDispatch','Effect':'Deny','Action':['ssm:GetParametersByPath','ssm:GetParameters','ssm:GetParameter','secretsmanager:GetSecretValue','lambda:InvokeFunction'],'Resource':'*'},
              {'Sid':'DenyConsentEntitlementAccess','Effect':'Deny','Action':'dynamodb:*','Resource':[q.ROOT+'trustcheckradar-dev-purchase-entitlements',q.ROOT+'trustcheckradar-dev-purchase-entitlements/index/*']}]}
        roles[name]=entry
        changes.append({'address':address,'mode':'managed','type':'aws_iam_role_policy' if role=='account_data' else 'aws_iam_policy','change':{'actions':['update'],'before':{'policy':json.dumps(before)},'after':after_record,'after_unknown':{}}})
    return {'observedAtUtc':'2026-09-25T00:00:00+00:00','roles':roles},{'resource_changes':changes}

class AwsError(Exception):
    def __init__(self,error,reasons=None):
        self.response={'Error':{'Code':error}}
        if reasons is not None:self.response['CancellationReasons']=reasons

def raises(error,reasons=None):
    def call():raise AwsError(error,reasons)
    return call

class ProducerIamTests(unittest.TestCase):
    def audit(self,a,p):
        with tempfile.TemporaryDirectory() as d:
            ap=Path(d)/'audit.json';pp=Path(d)/'plan.json'
            ap.write_text(json.dumps(a));pp.write_text(json.dumps(p))
            return q.validate_role_audit(pp,ap)

    def test_projection_preserves_legacy_ledger_union(self):
        projected,_=q.project_policy(source('account_data'),'account_data')
        bysid={s['Sid']:s for s in projected['Statement']}
        self.assertNotIn('Condition',bysid['ReconcileMissedRevocations'])
        self.assertEqual(set(bysid['ReadCommandAndWriteRevocationReceipt']['Action']),{'dynamodb:GetItem','dynamodb:PutItem','dynamodb:DeleteItem'})
        self.assertEqual(len(projected['Statement']),9)
        self.assertEqual(bysid['PersistOwnReconciliationCheckpoint']['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys'],'LIFECYCLE#dev')

    def test_unknown_overlap_and_duplicate_are_not_cherrypicked(self):
        for mutation in ('extra','duplicate'):
            p=source('participation');st=copy.deepcopy(p['Statement'][0])
            if mutation=='extra':st['Sid']='UnexpectedBroadAllow'
            p['Statement'].append(st)
            with self.assertRaises(q.QualificationError):q.project_policy(p,'participation')

    def test_wrong_region_wildcard_and_other_index_cannot_leak(self):
        for resource in ('*',q.LEDGER+'*',q.USERS+'/index/*',q.LEDGER.replace('us-east-1','us-west-2')):
            p=source('participation');p['Statement'][0]['Resource']=resource
            with self.assertRaises(q.QualificationError):q.project_policy(p,'participation')

    def test_conditions_preserve_transaction_and_no_returned_item(self):
        for sid,condition in [('UpdateCampaignRecoveryControlTransaction',{}),('CheckParticipationAuthorityLedger',{'ForAllValues:StringLike':{'dynamodb:LeadingKeys':'ACCOUNT#*'},'StringEquals':{'dynamodb:EnclosingOperation':'TransactWriteItems'}})]:
            p=source('participation');next(s for s in p['Statement'] if s['Sid']==sid)['Condition']=condition
            with self.assertRaises(q.QualificationError):q.project_policy(p,'participation')

    def test_mixed_resource_and_explicit_target_deny_require_review(self):
        for change in ({'Resource':[q.LEDGER,next(iter(q.OTHER_TABLES))]},{'Effect':'Deny'},{'NotAction':'dynamodb:PutItem'}):
            p=source('participation');p['Statement'][0].update(change)
            with self.assertRaises(q.QualificationError):q.project_policy(p,'participation')

    def test_stream_discovery_requires_exact_action_and_region(self):
        p=source('account_data');s={'Sid':'DiscoverDeletionStreamsInRegion','Effect':'Allow','Action':'dynamodb:ListStreams','Resource':'*','Condition':{'StringEquals':{'aws:RequestedRegion':q.REGION}}};p['Statement'].append(s)
        projected,omitted=q.project_policy(p,'account_data');self.assertEqual(len(projected['Statement']),9);self.assertEqual(len(omitted),1)
        s['Action']=['dynamodb:ListStreams','dynamodb:Scan']
        with self.assertRaises(q.QualificationError):q.project_policy(p,'account_data')

    def test_exact_disjoint_tables_are_explicitly_omitted(self):
        p=source('participation');p['Statement'].append({'Sid':'Other','Effect':'Allow','Action':'dynamodb:GetItem','Resource':next(iter(q.OTHER_TABLES))})
        projected,omitted=q.project_policy(p,'participation');self.assertEqual(len(projected['Statement']),8);self.assertEqual(omitted[0]['reason'],'exact_disjoint_table_resource')

    def test_fixture_mapping_only_owned_tables_and_defensive_copy(self):
        p=source('account_data');names={k:q.PREFIX+'a'*32+'-'+k for k in ('users','ledger')}
        result=q.remap(p,names)
        self.assertNotIn('trustcheckradar-dev-',q.canonical(result))
        for st in result['Statement']:self.assertIn(st['Resource'],{q.ROOT+x for x in names.values()})
        self.assertIn(q.LEDGER,q.canonical(p))
        for bad in ({**names,'users':'trustcheckradar-dev-users'},{**names,'users':names['ledger']}):
            with self.assertRaises(q.QualificationError):q.remap(p,bad)
        p['Statement'][0]['Resource']='*'
        with self.assertRaises(q.QualificationError):q.remap(p,names)

    def test_role_audit_exact_sources_and_before_binding(self):
        a,p=audit_and_plan();result=self.audit(a,p)
        self.assertEqual(len(result['omittedAncillaryPolicies']),2)
        self.assertEqual(len(result['sourceRoleAuditSha256']),64)
        p['resource_changes'][0]['change']['before']['policy']=json.dumps(source('participation'))
        with self.assertRaises(q.QualificationError):self.audit(a,p)

    def test_audit_order_independent(self):
        a,p=audit_and_plan();a['roles']['trustcheckradar-dev-account-data-api-role']['inline']['account-data-runtime']['Statement'].reverse()
        self.audit(a,p)

    def test_audit_extra_policy_boundary_and_wrong_identity_rejected(self):
        for mutation in ('extra','boundary','identity'):
            a,p=audit_and_plan();entry=a['roles']['trustcheckradar-dev-account-data-api-role']
            if mutation=='extra':entry['inline']['extra']=source('account_data')
            elif mutation=='boundary':entry['permissionsBoundary']={'PermissionsBoundaryArn':'anything'}
            else:entry['arn']=entry['arn'].replace(q.ACCOUNT,'000000000000')
            with self.assertRaises(q.QualificationError):self.audit(a,p)

    def test_audit_disjoint_denies_cannot_target_users_ledger_or_wildcard(self):
        for resource in (q.USERS,q.LEDGER,'*'):
            a,p=audit_and_plan();entry=a['roles']['trustcheckradar-dev-campaign-participation-role']
            entry['inline']['trustcheckradar-dev-research-migration-participation']['Statement'][1]['Resource']=resource
            with self.assertRaises(q.QualificationError):self.audit(a,p)

    def test_audit_logging_cannot_grant_dynamodb(self):
        a,p=audit_and_plan();entry=a['roles']['trustcheckradar-dev-campaign-participation-role'];basic=entry['managed']['arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole']
        basic['Statement'][0]['Action'].append('dynamodb:*')
        with self.assertRaises(q.QualificationError):self.audit(a,p)

    def test_only_access_denied_is_authorization_evidence(self):
        q.denied(raises('AccessDeniedException'))
        for error in ('ValidationException','TransactionCanceledException','ThrottlingException'):
            with self.assertRaises(q.QualificationError):q.denied(raises(error))
        with self.assertRaises(q.QualificationError):q.denied(lambda:None)

    def test_conditional_cancellation_requires_no_returned_item(self):
        q.canceled(raises('TransactionCanceledException',[{'Code':'ConditionalCheckFailed'}]))
        for reasons in ([],[{'Code':'AccessDenied'}],[{'Code':'ConditionalCheckFailed','Item':{'PK':'secret'}}]):
            with self.assertRaises(q.QualificationError):q.canceled(raises('TransactionCanceledException',reasons))

    def test_transaction_never_targets_same_item_twice(self):
        names={'ledger':'fixture-ledger','users':'fixture-users'}
        for role in q.ADDRESSES:
            for existing in (False,True):
                actions,_=q.transaction(names,role,'synthetic',existing)
                items=[]
                for action in actions:
                    op=next(iter(action.values()));item=op.get('Key',op.get('Item'));items.append((op['TableName'],item['PK']['S'],item['SK']['S']))
                self.assertEqual(len(items),len(set(items)))
                self.assertEqual(next(iter(actions[2])),'Update' if existing else 'Put')

class ProducerTransactionShapesTests(unittest.TestCase):
    def test_local_dynamodb_transactions_and_race_rollbacks(self):
        # Moto checks expression validity/atomic shapes only; it is not IAM evidence.
        try:
            import boto3
            from moto import mock_aws
        except ImportError:self.skipTest('Moto runtime not installed')
        with mock_aws():
            client=boto3.client('dynamodb',region_name=q.REGION,aws_access_key_id='testing',aws_secret_access_key='testing')
            names={'users':'fixture-users','ledger':'fixture-ledger'}
            for table in names.values():
                client.create_table(TableName=table,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            for role in q.ADDRESSES:
                for existing in (False,True):
                    for failed_guard in (None,'receipt','profile','control','inventory' if role=='account_data' else 'fence'):
                        subject,pk,upk=q.prepare(client,names,role,str(existing)+str(failed_guard),existing)
                        client.put_item(TableName=names['ledger'],Item={**q.key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'),'fixture':{'BOOL':True}})
                        actions,sk=q.transaction(names,role,subject,existing)
                        if failed_guard=='receipt':client.put_item(TableName=names['ledger'],Item=q.key(pk,'ACCOUNT_DELETION#CAMPAIGN'))
                        elif failed_guard=='profile':client.delete_item(TableName=names['users'],Key=q.key(upk,'PROFILE'))
                        elif failed_guard=='control':client.put_item(TableName=names['ledger'],Item={**q.key(pk,'CAMPAIGN_RECOVERY_CONTROL'),'revision':{'N':'99'}})
                        elif failed_guard=='inventory':client.delete_item(TableName=names['ledger'],Key=q.key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'))
                        elif failed_guard=='fence':client.put_item(TableName=names['ledger'],Item=q.key(pk,'ACCOUNT_DELETION'))
                        before=q.read(client,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL')
                        if failed_guard:
                            q.canceled(lambda:client.transact_write_items(TransactItems=actions))
                            self.assertEqual(q.read(client,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL'),before)
                            self.assertIsNone(q.read(client,names['ledger'],pk,sk))
                            self.assertIsNone(q.read(client,names['ledger'],pk,'CAMPAIGN_RECOVERY#fixture'))
                        else:
                            client.transact_write_items(TransactItems=actions)
                            self.assertEqual(q.read(client,names['ledger'],pk,'CAMPAIGN_RECOVERY_CONTROL')['pendingJobs'],{'N':'2' if existing else '1'})
                            self.assertIsNotNone(q.read(client,names['ledger'],pk,sk))

if __name__=='__main__':unittest.main()
