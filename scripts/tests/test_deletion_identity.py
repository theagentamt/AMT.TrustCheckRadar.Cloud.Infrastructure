import importlib.util
import json
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('audit',Path(__file__).parents[1]/'audit_deletion_identity.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
SUB='11111111-1111-4111-8111-111111111111'
class Fake:
    def __init__(self):
        self.users=[{'Username':SUB,'Attributes':[{'Name':'sub','Value':SUB}]}]
        self.rows=[{'PK':{'S':'USER#'+SUB},'SK':{'S':'PROFILE'},'sub':{'S':SUB}}]
        self.cursor=False;self.foreign=False;self.calls=[]
    def describe_user_pool(self,**kw):return {'UserPool':{'Arn':f'arn:aws:cognito-idp:{audit.REGION}:{audit.ACCOUNT}:userpool/{audit.POOL}'}}
    def describe_table(self,**kw):return {'Table':{'TableArn':f'arn:aws:dynamodb:{audit.REGION}:{"000000000000" if self.foreign else audit.ACCOUNT}:table/{audit.TABLE}'}}
    def list_users(self,**kw):
        self.calls.append(kw)
        return {'Users':self.users,**({'PaginationToken':'PRIVATE_CURSOR'} if self.cursor else {})}
    def scan(self,**kw):
        self.calls.append(kw)
        return {'Items':self.rows,**({'LastEvaluatedKey':{'PK':{'S':'PRIVATE_CURSOR'}}} if self.cursor else {})}
class Tests(unittest.TestCase):
    def test_valid_join_reports_no_identifiers(self):
        f=Fake();r=audit.collect(f,f)
        self.assertTrue(r['currentMappingConsistent']);self.assertFalse(r['inventoryApproved'])
        self.assertNotIn(SUB,json.dumps(r));self.assertEqual(f.calls[0]['AttributesToGet'],['sub'])
        self.assertTrue(f.calls[1]['ConsistentRead']);self.assertNotIn('FilterExpression',f.calls[1])
    def test_mismatch_duplicate_and_invalid_fail_closed(self):
        for kind in ('username','duplicate','missing','invalidprofile','orphan'):
            f=Fake()
            if kind=='username':f.users[0]['Username']='private-email'
            if kind=='duplicate':f.users*=2
            if kind=='missing':f.rows=[]
            if kind=='invalidprofile':f.rows[0]['sub']={'S':'other'}
            if kind=='orphan':f.users=[]
            with self.subTest(kind=kind):
                r=audit.collect(f,f);self.assertFalse(r['currentMappingConsistent']);self.assertNotIn('private-email',json.dumps(r))
    def test_partial_enumeration_never_claims_join(self):
        f=Fake();f.cursor=True;r=audit.collect(f,f,max_pages=1)
        self.assertFalse(r['cognitoComplete']);self.assertFalse(r['profilesComplete']);self.assertIsNone(r['profileWithoutIdentity']);self.assertNotIn('PRIVATE_CURSOR',json.dumps(r))
    def test_identity_checked_before_reading_users(self):
        f=Fake();f.foreign=True;r=audit.collect(f,f)
        self.assertEqual(f.calls,[]);self.assertFalse(r['currentMappingConsistent'])
    def test_time_and_bounds(self):
        f=Fake();ticks=iter([0,61]);r=audit.collect(f,f,clock=lambda:next(ticks));self.assertFalse(r['cognitoComplete']);self.assertEqual(f.calls,[])
        with self.assertRaises(ValueError):audit.collect(f,f,max_pages=11)
if __name__=='__main__':unittest.main()
