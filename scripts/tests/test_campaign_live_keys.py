import importlib.util
from pathlib import Path
import unittest
from boto3.dynamodb.types import TypeSerializer

spec=importlib.util.spec_from_file_location('audit',Path(__file__).parents[1]/'audit_campaign_live_keys.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)

class Fake:
    def __init__(self,rows=None,cursor=False,foreign=False):
        self.rows=rows or [];self.cursor=cursor;self.foreign=foreign;self.calls=[]
    def describe_table(self,**kwargs):
        account='000000000000' if self.foreign else audit.ACCOUNT
        return {'Table':{'TableArn':f'arn:aws:dynamodb:{audit.REGION}:{account}:table/'+kwargs['TableName']}}
    def scan(self,**kwargs):
        self.calls.append(kwargs)
        rows=self.rows if kwargs['TableName']==audit.TABLES[0] else []
        ser=TypeSerializer();result={'Items':[{k:ser.serialize(v) for k,v in r.items()} for r in rows],'Count':len(rows)}
        if self.cursor:result['LastEvaluatedKey']={'PK':{'S':'PRIVATE_CURSOR'}}
        return result

class AuditTests(unittest.TestCase):
    def registry(self):
        return {'PK':'PERIOD#1478','SK':'HMAC_KEY','periodId':1478,'status':'RETIRED','keyArn':f'arn:aws:kms:{audit.REGION}:{audit.ACCOUNT}:key/11111111-1111-1111-1111-111111111111','retireAfterEpoch':1479*audit.PERIOD+604800,'retiredAtEpoch':1479*audit.PERIOD+604801}
    def test_exact_metadata_only(self):
        f=Fake([self.registry()]);r=audit.collect(f)
        self.assertTrue(r['onlyRecognizedControlKeysObserved'])
        self.assertFalse(r['erasureVerified']);self.assertFalse(r['inventoryApproved'])
        for call in f.calls:
            self.assertTrue(call['ConsistentRead']);self.assertNotIn('FilterExpression',call)
            self.assertEqual(set(call['ExpressionAttributeNames'].values()),set(audit.FIELDS))
        self.assertNotIn('11111111',str(r));self.assertNotIn('PERIOD#1478',str(r))
    def test_inconsistent_registry_blocks(self):
        for change in ({'periodId':1479},{'status':'CLOSING'},{'retiredAtEpoch':0},{'schemaVersion':1}):
            with self.subTest(change=change):
                r=audit.collect(Fake([self.registry()|change]));self.assertFalse(r['onlyRecognizedControlKeysObserved'])
    def test_every_other_key_blocks_even_expired_or_protective(self):
        for row in ({'PK':'EVENT#private','SK':'CLUSTERED'},{'PK':'CONTRIB#1478#private','SK':'TOMBSTONE'},{'PK':'CANDIDATE#private','SK':'DELETION_RECOMPUTE'}):
            with self.subTest(row=row):
                r=audit.collect(Fake([row]));self.assertFalse(r['onlyRecognizedControlKeysObserved']);self.assertNotIn('private',str(r))
    def test_cursor_bounds_never_claim_complete(self):
        f=Fake(cursor=True);r=audit.collect(f,max_pages=1)
        self.assertFalse(r['allTraversalsComplete']);self.assertFalse(r['onlyRecognizedControlKeysObserved']);self.assertEqual(len(f.calls),3);self.assertNotIn('PRIVATE_CURSOR',str(r))
    def test_wrong_identity_prevents_scan(self):
        f=Fake(foreign=True);r=audit.collect(f);self.assertFalse(r['allTraversalsComplete']);self.assertEqual(f.calls,[])
    def test_deadline_and_fixed_target(self):
        values=iter([0,61,61,61]);f=Fake();r=audit.collect(f,clock=lambda:next(values));self.assertFalse(r['allTraversalsComplete']);self.assertEqual(f.calls,[])
        with self.assertRaises(ValueError):audit.collect(f,target=1479)

if __name__=='__main__':unittest.main()
