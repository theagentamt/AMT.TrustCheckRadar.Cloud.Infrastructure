import base64
import copy
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location('reregistration', SCRIPTS / 'prepare_account_reregistration_fixture.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ReregistrationFixtureTests(unittest.TestCase):
    def setUp(self):
        prefix, tags = m.fixture.identity('abc123def456')
        self.old = '11111111-1111-7111-8111-111111111111'
        self.new = '22222222-2222-7222-8222-222222222222'
        self.doc = dict(runId='abc123def456', account=m.fixture.ACCOUNT, region=m.fixture.REGION,
                        prefix=prefix, tags=tags, fixtureKind='all-components', realCognito=True,
                        prepared=True, role=prefix+'-role', function=prefix+'-runner',
                        sourceSha='a'*40, zipSha256='b'*64,
                        keyArn=f'arn:aws:kms:{m.fixture.REGION}:{m.fixture.ACCOUNT}:key/11111111-1111-1111-1111-111111111111',
                        cognitoPoolName=prefix+'-cognito', cognitoPoolId='us-east-1_Test123',
                        cognitoSubject=self.old, cognitoPoolCreateAttempted=True, cognitoUserCreateAttempted=True,
                        tables={k:prefix+'-'+k for k in m.fixture.table_kinds('all-components')})
        self.pool = {'Name':self.doc['cognitoPoolName'], 'Id':self.doc['cognitoPoolId'],
                     'Arn':m.fixture.cognito_pool_arn(self.doc['cognitoPoolId']), 'UserPoolTags':tags,
                     'UsernameAttributes':['email'], 'LambdaConfig':{}, 'AutoVerifiedAttributes':[],
                     'MfaConfiguration':'OFF', 'DeletionProtection':'INACTIVE',
                     'AdminCreateUserConfig':{'AllowAdminCreateUserOnly':True}}
        self.user = {'Username':self.new, 'Attributes':[{'Name':'sub','Value':self.new},
                    {'Name':'email','Value':'fixture-abc123def456@example.invalid'}]}
        self.config = {'FunctionName':self.doc['function'],
                       'FunctionArn':f"arn:aws:lambda:{m.fixture.REGION}:{m.fixture.ACCOUNT}:function:{self.doc['function']}",
                       'Role':f"arn:aws:iam::{m.fixture.ACCOUNT}:role/{self.doc['role']}",
                       'Handler':'cognito_qualification.lambda_handler', 'Runtime':'python3.14',
                       'Architectures':['arm64'], 'Version':'$LATEST', 'State':'Active', 'LastUpdateStatus':'Successful',
                       'CodeSha256':base64.b64encode(bytes.fromhex(self.doc['zipSha256'])).decode(),
                       'RevisionId':'original', 'Environment':{'Variables':m.expected_environment(self.doc)}}
        self.clients = {k:Mock() for k in ('sts','cognito-idp','lambda','dynamodb')}
        self.clients['sts'].get_caller_identity.return_value = {'Account':m.fixture.ACCOUNT}
        self.cognito = self.clients['cognito-idp']
        self.lam = self.clients['lambda']
        self.cognito.describe_user_pool.return_value = {'UserPool':self.pool}
        self.cognito.admin_create_user.return_value = {'User':self.user}
        self.cognito.admin_get_user.side_effect = [self.error('UserNotFoundException'), self.user,
                                                  self.error('UserNotFoundException')]
        self.lam.get_function.side_effect = lambda **kw: {'Configuration':copy.deepcopy(self.config), 'Tags':tags}
        self.lam.get_function_concurrency.return_value = {'ReservedConcurrentExecutions':1}
        def update(**kw):
            self.config['Environment'] = kw['Environment']
            self.config['RevisionId'] = 'new'
        self.lam.update_function_configuration.side_effect = update
        self.clients['dynamodb'].get_item.return_value = {'Item':{
            'status':{'S':'COMPLETE'}, 'accountId':{'S':self.old}}}
        self.saved = []

    @staticmethod
    def error(code):
        e = RuntimeError('synthetic')
        e.response = {'Error':{'Code':code}}
        return e

    def run_prepare(self):
        return m.prepare(self.doc, self.clients, lambda x:self.saved.append(copy.deepcopy(x)), sleep=lambda _:None)

    def test_same_email_new_subject_only_and_no_test_invocation(self):
        result = self.run_prepare()
        self.assertTrue(result['prepared'])
        self.assertFalse(result['testInvoked'])
        self.cognito.admin_create_user.assert_called_once_with(**m.fixture.cognito_user_request(self.doc))
        env = self.config['Environment']['Variables']
        self.assertEqual(env, m.expected_environment(self.doc) | {
            'QUALIFICATION_COGNITO_SUBJECT':self.new, 'QUALIFICATION_PREVIOUS_COGNITO_SUBJECT':self.old})
        self.assertTrue(self.saved[0]['createAttempted'])
        self.assertNotIn('newSubject', self.saved[0])
        self.assertEqual(self.saved[-1]['newSubject'], self.new)
        self.assertTrue(self.saved[-1]['prepared'])
        self.lam.invoke.assert_not_called()

    def test_foreign_account_or_application_table_rejected_before_create(self):
        self.clients['sts'].get_caller_identity.return_value = {'Account':'000000000000'}
        with self.assertRaises(ValueError): self.run_prepare()
        self.cognito.admin_create_user.assert_not_called()
        self.doc['tables']['users'] = 'trustcheckradar-dev-users'
        with self.assertRaises(ValueError): self.run_prepare()
        self.cognito.admin_create_user.assert_not_called()

    def test_pool_or_function_drift_rejected_before_create(self):
        for key,value in [('Role','unrelated'), ('CodeSha256','different'), ('Handler','other.handler')]:
            with self.subTest(key=key):
                original = self.config[key]; self.config[key] = value
                with self.assertRaises(ValueError): self.run_prepare()
                self.config[key] = original
        self.pool['UserPoolTags'] = {}
        with self.assertRaises(ValueError): self.run_prepare()
        self.cognito.admin_create_user.assert_not_called()

    def test_lambda_arn_uses_provider_colon_shape_and_rejects_other_resources(self):
        observed = 'arn:aws:lambda:us-east-1:107827791950:function:amt-campaign-completion-qual-abc123def456-runner'
        self.config['FunctionArn'] = observed
        m.validate_function({'Configuration':self.config,'Tags':self.doc['tags']}, self.doc)
        for bad in [observed.replace(':function:', ':function/'), observed+':42',
                    observed.replace('107827791950','000000000000'), observed.replace('us-east-1','us-west-2')]:
            self.config['FunctionArn'] = bad
            with self.assertRaises(ValueError):
                m.validate_function({'Configuration':self.config,'Tags':self.doc['tags']}, self.doc)

    def test_old_identity_present_or_access_denied_is_not_absence(self):
        for response in [self.user, self.error('AccessDeniedException')]:
            self.cognito.admin_get_user.side_effect = [response]
            with self.assertRaises((ValueError, RuntimeError)): self.run_prepare()
        self.cognito.admin_create_user.assert_not_called()

    def test_pending_or_wrong_subject_command_blocks_creation(self):
        for row in [{'status':{'S':'REQUESTED'},'accountId':{'S':self.old}},
                    {'status':{'S':'COMPLETE'},'accountId':{'S':self.new}}, {}]:
            self.cognito.admin_get_user.side_effect = [self.error('UserNotFoundException')]
            self.clients['dynamodb'].get_item.return_value = {'Item':row}
            with self.assertRaises(ValueError): self.run_prepare()
        self.cognito.admin_create_user.assert_not_called()

    def test_create_failure_records_intent_and_never_retries(self):
        self.cognito.admin_create_user.side_effect = self.error('InternalErrorException')
        with self.assertRaises(RuntimeError): self.run_prepare()
        self.assertTrue(self.saved[-1]['createAttempted'])
        self.assertFalse(self.saved[-1]['prepared'])
        self.cognito.admin_create_user.assert_called_once()
        self.lam.update_function_configuration.assert_not_called()

    def test_identity_reuse_or_wrong_email_blocks_config_update(self):
        for user in [self.user | {'Username':self.old, 'Attributes':[
                    {'Name':'sub','Value':self.old}, self.user['Attributes'][1]]},
                    self.user | {'Attributes':[self.user['Attributes'][0],{'Name':'email','Value':'other@example.invalid'}]}]:
            self.cognito.admin_get_user.side_effect = [self.error('UserNotFoundException')]
            self.cognito.admin_create_user.return_value = {'User':user}
            with self.assertRaises(ValueError): self.run_prepare()
        self.lam.update_function_configuration.assert_not_called()

    def test_revision_race_preserves_created_identity_journal_without_update(self):
        observations = 0
        def get(**kw):
            nonlocal observations
            observations += 1
            c = copy.deepcopy(self.config)
            if observations > 1: c['RevisionId'] = 'concurrent'
            return {'Configuration':c,'Tags':self.doc['tags']}
        self.lam.get_function.side_effect = get
        with self.assertRaisesRegex(ValueError, 'REVISION_CHANGED'): self.run_prepare()
        self.assertEqual(self.saved[-1]['newSubject'], self.new)
        self.lam.update_function_configuration.assert_not_called()

    def test_configuration_mismatch_never_reports_prepared(self):
        def update(**kw):
            self.config['Environment'] = {'Variables':{'unexpected':'value'}}
        self.lam.update_function_configuration.side_effect = update
        with self.assertRaisesRegex(ValueError, 'READBACK_MISMATCH'): self.run_prepare()
        self.assertTrue(self.saved[-1]['configurationAttempted'])
        self.assertFalse(self.saved[-1]['prepared'])

    def test_configuration_poll_is_bounded(self):
        self.lam.update_function_configuration.side_effect = lambda **kw:self.config.update(LastUpdateStatus='InProgress')
        times = iter([0,1,121])
        with self.assertRaises(TimeoutError):
            m.prepare(self.doc, self.clients, lambda x:self.saved.append(copy.deepcopy(x)),
                      now=lambda:next(times), sleep=lambda _:None)
        self.assertFalse(self.saved[-1]['prepared'])


if __name__ == '__main__': unittest.main()
