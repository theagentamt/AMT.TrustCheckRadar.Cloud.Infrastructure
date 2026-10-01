import unittest,json,hashlib,io,contextlib,runpy,re
from pathlib import Path
from unittest.mock import patch
import boto3
SOURCE=Path(__file__).with_name('third-controlled-reconciliation-operator.py').read_text()
class Test(unittest.TestCase):
 def run_case(self,case):
  subject='01959cef-9123-7abc-8def-0123456789ab';op='eb364aa4-21e0-4f44-89dd-503ad03b2fe4';run='0123456789ab'
  j={'stage':'ACCEPTED','subject':subject,'operationId':op,'poolId':'us-east-1_wzN0wUSdQ','runId':run,'email':'deletion-qual-'+run+'@example.invalid'}
  p={'runId':run,'apiCodeSha256':'fixed-code','apiRevisionId':'fixed-revision'};raw=json.dumps(p).encode();sha=hashlib.sha256(raw).hexdigest();calls=[];writes={};pending={'PK':{'S':'ACCOUNT#'+subject},'SK':{'S':'ACCOUNT_DELETION'},'operationId':{'S':op},'accountId':{'S':subject},'environment':{'S':'dev'},'status':{'S':'REQUESTED'}}
  class FPath:
   def __init__(self,name):self.name=name
   def read_text(self):return json.dumps(p if self.name.endswith("-http-plan.json") else j)
   def read_bytes(self):return raw
   def exists(self):return case=='already_attempted' or self.name in writes
   def write_text(self,data):writes[self.name]=data
  class Client:
   def get_caller_identity(self):return {'Account':'other' if case=='wrong_account' else '107827791950'}
   def get_function_configuration(self,**kw):return {'CodeSha256':'other' if case=='wrong_runtime' else p['apiCodeSha256'],'RevisionId':p['apiRevisionId'],'LastUpdateStatus':'Successful','Environment':{'Variables':{'APP_ENVIRONMENT':'dev','ACCOUNT_DELETION_HTTP_SUBJECTS_JSON':json.dumps([subject])}}}
   def scan(self,**kw):
    rows=[pending]
    if case=='other_pending':rows.append({**pending,'PK':{'S':'ACCOUNT#unrelated'}})
    return {'Items':rows}
   def invoke(self,**kw):
    calls.append(kw);data={'schemaVersion':1,'operation':'reconcile-session-revocation','commandFailures':0,'passHadFailures':False,'analysisAbusePolicyBlocked':0,'campaignOutboxPolicyBlocked':0,'userProfilePolicyBlocked':0}
    if case=='pending_prerequisite':data['userProfilePolicyBlocked']=1
    return {'StatusCode':200,'ExecutedVersion':'$LATEST','Payload':io.BytesIO(json.dumps(data).encode())}
   def close(self):pass
  client=Client()
  class Session:
   def client(self,*args,**kw):return client
  code=re.sub(r"expected_plan = '[^']+'", "expected_plan = '"+('wrong' if case=='wrong_plan' else sha)+"'", SOURCE)
  failed=False
  with patch('pathlib.Path',FPath),patch('boto3.Session',return_value=Session()),patch('time.sleep'),contextlib.redirect_stdout(io.StringIO()):
   try:exec(compile(code,'reviewed-operator','exec'),{})
   except RuntimeError:failed=True
  return calls,failed,writes
 def test_wrong_plan_prevents_invocation(self):self.assertEqual(self.run_case('wrong_plan')[:2],([],True))
 def test_wrong_account_prevents_invocation(self):self.assertEqual(self.run_case('wrong_account')[:2],([],True))
 def test_runtime_drift_prevents_invocation(self):self.assertEqual(self.run_case('wrong_runtime')[:2],([],True))
 def test_other_pending_command_prevents_invocation(self):self.assertEqual(self.run_case('other_pending')[:2],([],True))
 def test_existing_attempt_journal_prevents_repeat(self):self.assertEqual(self.run_case('already_attempted')[:2],([],True))
 def test_pending_prerequisite_stops_without_claiming_completion(self):
  calls,failed,writes=self.run_case('pending_prerequisite');self.assertTrue(failed);self.assertEqual(len(calls),1);report=json.loads(next(reversed(writes.values())));self.assertFalse(report['attempts'][0]['verified']);self.assertFalse(report['terminalStatusObserved'])
 def test_incomplete_work_is_limited_to_three_real_ticks(self):
  calls,failed,writes=self.run_case('pending');self.assertFalse(failed);self.assertEqual(len(calls),3);self.assertTrue(all(json.loads(c['Payload'])=={'schemaVersion':1,'operation':'reconcile-session-revocation'} for c in calls));report=json.loads(next(reversed(writes.values())));self.assertEqual(len(report['attempts']),3);self.assertFalse(report['terminalStatusObserved']);self.assertEqual(report['commandsInjected'],0);self.assertEqual(report['receiptsInjected'],0)
if __name__=='__main__':unittest.main()
