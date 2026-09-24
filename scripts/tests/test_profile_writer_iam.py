import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('qualification', Path(__file__).resolve().parents[1] / 'qualify_profile_writer_iam.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def policy(kind):
    return {'Version': '2012-10-17', 'Statement': [
        {'Effect': 'Allow', 'Action': m.POLICIES[kind][1], 'Resource': m.SOURCE_USERS, 'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': 'USER#*'}, 'ForAnyValue:StringEquals': {'dynamodb:EnclosingOperation': 'TransactWriteItems'}}},
        {'Effect': 'Allow', 'Action': 'dynamodb:ConditionCheckItem', 'Resource': m.SOURCE_LEDGER, 'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': 'ACCOUNT#*'}, 'StringEqualsIfExists': {'dynamodb:ReturnValues': 'NONE'}}},
    ]}


class Tests(unittest.TestCase):
    def load(self, p, kind='post_confirmation', unknown=False):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'plan.json'
            path.write_text(json.dumps({'resource_changes': [{'address':m.POLICIES[kind][0], 'change': {'after': {'policy':json.dumps(p)},'after_unknown':{'policy':unknown}}}]}))
            return m.load_policy(path, kind)

    def test_final_two_policies_and_only_resource_substitution(self):
        for kind in m.POLICIES:
            p=policy(kind)
            self.assertEqual(self.load(p,kind),p)
            replaced=m.fixture_policy(p,'synthetic-users','synthetic-ledger')
            expected=copy.deepcopy(p)
            expected['Statement'][0]['Resource']=m.TABLE_PREFIX+'synthetic-users'
            expected['Statement'][1]['Resource']=m.TABLE_PREFIX+'synthetic-ledger'
            self.assertEqual(replaced,expected)
            self.assertEqual(p,policy(kind))

    def test_refuse_wrong_resource_transition_and_missing_guards(self):
        for mutation in ('resource','legacy_read','transaction','return_values','ledger_context'):
            with self.subTest(mutation=mutation):
                p=policy('post_confirmation')
                if mutation=='resource':p['Statement'][0]['Resource']=m.SOURCE_USERS.replace('-dev-','-prod-')
                if mutation=='legacy_read':p['Statement'][0]['Action']=['dynamodb:PutItem','dynamodb:GetItem']
                if mutation=='transaction':del p['Statement'][0]['Condition']['ForAnyValue:StringEquals']
                if mutation=='return_values':del p['Statement'][1]['Condition']['StringEqualsIfExists']
                if mutation=='ledger_context':p['Statement'][1]['Condition']['StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
                with self.assertRaises(m.QualificationError):self.load(p)

    def test_refuse_unknown_policy(self):
        with self.assertRaises(m.QualificationError):self.load(policy('post_confirmation'),unknown=True)

    def test_absence_guard_and_no_returned_attributes(self):
        for kind in m.POLICIES:
            tx=m.transaction(kind,'fixture-users','fixture-ledger','USER#fixture','ACCOUNT#fixture','NONE')
            check=tx[1]['ConditionCheck']
            self.assertEqual(check['ConditionExpression'],'attribute_not_exists(PK)')
            self.assertEqual(check['ReturnValuesOnConditionCheckFailure'],'NONE')
            self.assertEqual(check['TableName'],'fixture-ledger')
            self.assertEqual(check['Key']['SK'], {'S':'ACCOUNT_DELETION'})

    def test_denial_is_not_generic_failure(self):
        class Denial(Exception):
            response={'Error':{'Code':'AccessDeniedException'}}
        def denied():raise Denial('sensitive provider text not used')
        m.denied(denied)
        with self.assertRaises(m.QualificationError):m.denied(lambda:None)
        def broken():raise RuntimeError('sensitive provider text not used')
        with self.assertRaisesRegex(m.QualificationError,'unexpected_denial_type'):m.denied(broken)

if __name__=='__main__':unittest.main()
