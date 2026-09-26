import importlib.util
from pathlib import Path
import unittest
import copy
import time
from unittest.mock import Mock

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

    def test_component_scope_is_exact_and_opt_in(self):
        doc=self.doc();prefix=doc['prefix']
        doc['fixtureKind']='all-components'
        doc['tables']={k:prefix+'-'+k for k in m.table_kinds('all-components')}
        self.assertEqual(len(doc['tables']),12)
        self.assertEqual(m.fixture_timeout('campaign'),60)
        self.assertEqual(m.fixture_timeout('all-components'),120)
        with self.assertRaises(ValueError):m.fixture_timeout('other')
        self.assertIs(m.validate_journal(doc,doc['runId']),doc)
        for changes in [{'fixtureKind':'other'}, {'fixtureKind':'campaign'},
                        {'tables':dict(doc['tables'],tokens='trustcheckradar-dev-play-tokens')},
                        {'tables':dict(doc['tables'],extra=prefix+'-extra')}]:
            with self.assertRaises(ValueError):m.validate_journal(doc|changes,doc['runId'])
        env=m.table_environment(doc['tables'])
        self.assertIn('QUALIFICATION_HISTORY_CONTROL_TABLE',env)
        self.assertIn('QUALIFICATION_HISTORY_CONTENT_TABLE',env)
        self.assertFalse(any('-' in key for key in env))
        policy=m.runtime_policy(doc['tables'],doc['keyArn'])
        resources=policy['Statement'][0]['Resource']
        self.assertEqual(len(resources),12)
        self.assertTrue(all('/'+prefix+'-' in arn for arn in resources))
        self.assertFalse(any('*' in arn for arn in resources))
        self.assertFalse(any(action.startswith(('cognito','secretsmanager','s3:','kms:Decrypt')) for statement in policy['Statement'] for action in statement['Action']))
        for kind,name in doc['tables'].items():
            request=m.table_request(name,kind,doc['tags'])
            self.assertNotIn('StreamSpecification',request)
            self.assertNotIn('RestoreSourceTableArn',request)
            if kind!='ledger':self.assertNotIn('GlobalSecondaryIndexes',request)

class CognitoFixtureTests(unittest.TestCase):
    doc = FixtureTests.doc
    def identity_doc(self):
        doc=self.doc();doc.update(fixtureKind='all-components',realCognito=True,
            cognitoPoolName=doc['prefix']+'-cognito',cognitoPoolId='us-east-1_Test123',
            cognitoSubject='00000000-0000-4000-8000-000000000001',cognitoPoolCreateAttempted=True,cognitoUserCreateAttempted=True)
        doc['tables']={k:doc['prefix']+'-'+k for k in m.table_kinds('all-components')}
        return doc
    def pool(self,doc):
        return {'Name':doc['cognitoPoolName'],'Id':doc['cognitoPoolId'],
            'Arn':m.cognito_pool_arn(doc['cognitoPoolId']),'UserPoolTags':doc['tags'],
            'UsernameAttributes':['email'],'LambdaConfig':{},'AutoVerifiedAttributes':[],
            'MfaConfiguration':'OFF','DeletionProtection':'INACTIVE',
            'AdminCreateUserConfig':{'AllowAdminCreateUserOnly':True}}
    def user(self,doc):
        return {'Username':doc['cognitoSubject'],'Attributes':[{'Name':'sub','Value':doc['cognitoSubject']},
            {'Name':'email','Value':'fixture-'+doc['runId']+'@example.invalid'}]}
    def error(self,code):
        error=Exception('synthetic failure');error.response={'Error':{'Code':code}};return error
    def test_real_cognito_journal_requires_exact_opt_in(self):
        doc=self.identity_doc();self.assertIs(m.validate_journal(doc,doc['runId']),doc)
        for changes in [{'realCognito':False},{'realCognito':'true'},{'fixtureKind':'campaign'},
            {'cognitoPoolName':'existing-pool'},{'cognitoPoolId':'us-west-2_Test123'},
            {'cognitoSubject':'someone@example.invalid'},{'cognitoPoolId':None},
            {'cognitoPoolCreateAttempted':'yes'},{'cognitoPoolCreateAttempted':False},{'cognitoUserCreateAttempted':False}]:
            with self.assertRaises(ValueError):m.validate_journal(doc|changes,doc['runId'])
    def test_pool_and_user_requests_never_send_messages_or_hook_other_functions(self):
        doc=self.identity_doc();pool=m.cognito_pool_request(doc['runId']);user=m.cognito_user_request(doc)
        self.assertEqual(pool['UsernameAttributes'],['email']);self.assertEqual(pool['LambdaConfig'],{})
        self.assertEqual(pool['AutoVerifiedAttributes'],[]);self.assertTrue(pool['AdminCreateUserConfig']['AllowAdminCreateUserOnly'])
        self.assertEqual(user['MessageAction'],'SUPPRESS');self.assertFalse(user['ForceAliasCreation'])
        self.assertTrue(user['Username'].endswith('@example.invalid'))
        import botocore.session
        from botocore.validate import validate_parameters
        model=botocore.session.get_session().get_service_model('cognito-idp')
        validate_parameters(pool,model.operation_model('CreateUserPool').input_shape)
        validate_parameters(user,model.operation_model('AdminCreateUser').input_shape)
    def test_runtime_has_only_exact_pool_four_actions(self):
        doc=self.identity_doc();old=m.runtime_policy(doc['tables'],doc['keyArn']);new=m.runtime_policy(doc['tables'],doc['keyArn'],doc['cognitoPoolId'])
        self.assertEqual(new['Statement'][:-1],old['Statement'])
        statement=new['Statement'][-1];self.assertEqual(statement['Resource'],m.cognito_pool_arn(doc['cognitoPoolId']))
        self.assertEqual(set(statement['Action']),{'cognito-idp:DescribeUserPool','cognito-idp:AdminGetUser','cognito-idp:AdminUserGlobalSignOut','cognito-idp:AdminDeleteUser'})
        for pool_id in ['*','us-west-2_Test123','us-east-1_Test/*']:
            with self.assertRaises(ValueError):m.runtime_policy(doc['tables'],doc['keyArn'],pool_id)
    def test_pool_and_subject_response_boundaries_fail_closed(self):
        doc=self.identity_doc();pool=self.pool(doc);user=self.user(doc)
        self.assertEqual(m.validate_cognito_pool(pool,doc),doc['cognitoPoolId']);self.assertEqual(m.validate_cognito_user(user,doc),doc['cognitoSubject'])
        for changes in [{'Name':'existing'},{'UserPoolTags':{}},{'Id':'us-east-1_Other'},
            {'Arn':'arn:aws:cognito-idp:us-east-1:999999999999:userpool/us-east-1_Test123'},
            {'UsernameAttributes':[]},{'LambdaConfig':{'PreSignUp':'existing'}},
            {'AutoVerifiedAttributes':['email']},{'AliasAttributes':['email']},{'DeletionProtection':'ACTIVE'}]:
            with self.assertRaises(ValueError):m.validate_cognito_pool(pool|changes,doc)
        for changes in [{'Username':'fixture@example.invalid'},{'Attributes':[{'Name':'sub','Value':doc['cognitoSubject']}]},
            {'Attributes':user['Attributes']+[{'Name':'sub','Value':doc['cognitoSubject']}]}]:
            with self.assertRaises(ValueError):m.validate_cognito_user(user|changes,doc)
    def test_cleanup_checks_ownership_before_identity_mutation(self):
        doc=self.identity_doc();client=Mock();client.describe_user_pool.return_value={'UserPool':self.pool(doc)|{'UserPoolTags':{}}}
        with self.assertRaises(ValueError):m.cleanup_cognito(client,doc,Mock(),Mock(),time.monotonic()+60)
        client.admin_delete_user.assert_not_called();client.delete_user_pool.assert_not_called()
        client.describe_user_pool.return_value={'UserPool':self.pool(doc)};client.admin_get_user.return_value=self.user(doc)|{'Username':'foreign'}
        with self.assertRaises(ValueError):m.cleanup_cognito(client,doc,Mock(),Mock(),time.monotonic()+60)
        client.admin_delete_user.assert_not_called();client.delete_user_pool.assert_not_called()
    def test_cleanup_identity_absence_requires_pool_readback(self):
        doc=self.identity_doc();client=Mock();client.describe_user_pool.side_effect=[{'UserPool':self.pool(doc)},self.error('ResourceNotFoundException')]
        client.admin_get_user.return_value=self.user(doc)
        result=m.cleanup_cognito(client,doc,Mock(),lambda fn,predicate:self.assertTrue(predicate(fn())),time.monotonic()+60)
        self.assertTrue(result['poolAbsent']);self.assertTrue(result['subjectAbsentWithPool'])
        client.admin_delete_user.assert_called_once_with(UserPoolId=doc['cognitoPoolId'],Username=doc['cognitoSubject']);client.delete_user_pool.assert_called_once_with(UserPoolId=doc['cognitoPoolId'])
    def test_cleanup_lost_user_create_response_deletes_only_owned_pool(self):
        doc=self.identity_doc();pool=self.pool(doc);del doc['cognitoSubject'];client=Mock()
        client.describe_user_pool.side_effect=[{'UserPool':pool},self.error('ResourceNotFoundException')]
        result=m.cleanup_cognito(client,doc,Mock(),lambda fn,predicate:self.assertTrue(predicate(fn())),time.monotonic()+60)
        self.assertTrue(result['poolAbsent']);client.admin_get_user.assert_not_called();client.admin_delete_user.assert_not_called()
    def test_ambiguous_pool_create_discovery_is_complete_bounded_and_exact(self):
        doc=self.identity_doc();pool=self.pool(doc);del doc['cognitoPoolId'];del doc['cognitoSubject'];client=Mock()
        client.list_user_pools.return_value={'UserPools':[{'Id':pool['Id'],'Name':pool['Name']}]};client.describe_user_pool.return_value={'UserPool':pool}
        self.assertEqual(m.discover_cognito_pool(client,doc,time.monotonic()+60),pool['Id'])
        for rows in [[],[{'Id':pool['Id'],'Name':pool['Name']}]*2]:
            client.list_user_pools.return_value={'UserPools':rows}
            with self.assertRaises(ValueError):m.discover_cognito_pool(client,doc,time.monotonic()+60)
        client.list_user_pools.return_value={'UserPools':[],'NextToken':'more'};client.list_user_pools.reset_mock()
        with self.assertRaises(ValueError):m.discover_cognito_pool(client,doc,time.monotonic()+60)
        self.assertEqual(client.list_user_pools.call_count,10)
        client.list_user_pools.reset_mock()
        with self.assertRaises(TimeoutError):m.discover_cognito_pool(client,doc,time.monotonic()-1)
        client.list_user_pools.assert_not_called()
    def test_access_denied_is_never_identity_absence(self):
        doc=self.identity_doc();client=Mock();client.describe_user_pool.side_effect=self.error('AccessDeniedException')
        with self.assertRaises(Exception):m.cleanup_cognito(client,doc,Mock(),Mock(),time.monotonic()+60)
        client.delete_user_pool.assert_not_called()

if __name__=='__main__':unittest.main()
