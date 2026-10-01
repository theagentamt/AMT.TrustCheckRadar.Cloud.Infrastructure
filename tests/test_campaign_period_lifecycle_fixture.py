import importlib.util,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import campaign_period_lifecycle_fixture as m
class Boundaries(unittest.TestCase):
 def journal(self):
  run='0123456789ab';p,t=m.shape(run)
  return {'schemaVersion':1,'runId':run,'prefix':p,'tags':t,'account':m.ACCOUNT,'region':m.REGION,'period':100,
   'keyTags':{'Project':'trustcheckradar','Environment':'dev','Purpose':'campaign-contributor-token','PeriodId':'100'},'tables':{f:p+'-'+f for f in m.FAMILIES}}
 def test_exact_five_families(self):
  j=self.journal();self.assertEqual(m.validate(j,j['runId']),j)
  for field,value in [('account','other'),('region','us-west-2'),('prefix','trustcheckradar-dev'),('schemaVersion',True)]:
   with self.subTest(field=field),self.assertRaises(ValueError):m.validate(j|{field:value},j['runId'])
 def test_foreign_table_or_key_rejected(self):
  j=self.journal()
  for change in [{'tables':j['tables']|{'pipeline':'trustcheckradar-dev-campaign-pipeline'}},{'keyArn':'arn:aws:kms:us-east-1:000000000000:key/11111111-1111-4111-8111-111111111111'}]:
   with self.subTest(change=change),self.assertRaises(ValueError):m.validate(j|change,j['runId'])
 def test_resource_shapes_and_no_streams(self):
  for family in m.FAMILIES:
   spec=m.table_spec(family);self.assertEqual(spec['StreamSpecification'],{'StreamEnabled':False})
  spec=m.table_spec('intelligence');indexes={x['IndexName']:x for x in spec['GlobalSecondaryIndexes']}
  self.assertEqual(indexes['ExpirationIndex']['Projection'],{'ProjectionType':'KEYS_ONLY'})
  self.assertEqual(indexes['ExpirationIndex']['KeySchema'],[{'AttributeName':'expiryPartition','KeyType':'HASH'},{'AttributeName':'expiresAt','KeyType':'RANGE'}])
  self.assertEqual(m.table_spec('pipeline')['GlobalSecondaryIndexes'][0]['IndexName'],'CandidateBucketIndex')
  with self.assertRaises(ValueError):m.table_spec('application')
 def test_unsafe_namespace_refused(self):
  for run in ('../live','trustcheckradar','0123456789abc','A123456789ab',None):
   with self.subTest(run=run),self.assertRaises(ValueError):m.shape(run)
if __name__=='__main__':unittest.main()
