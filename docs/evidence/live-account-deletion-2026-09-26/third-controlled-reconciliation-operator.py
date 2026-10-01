"""At most three real reconciliation ticks for the one already-accepted test command."""
import json, hashlib, time, boto3
from pathlib import Path
from botocore.config import Config
J = Path('/tmp/amt-dev-deletion-third-journal.json')
P = Path('/tmp/amt-dev-deletion-third-http-plan.json')
O = Path('/tmp/amt-dev-deletion-third-reconcile-result.json')
j = json.loads(J.read_text())
p = json.loads(P.read_text())
if not (j['stage'] == 'ACCEPTED' and j['poolId'] == 'us-east-1_wzN0wUSdQ' and (j['runId'] == p['runId']) and (j['email'] == 'deletion-qual-' + j['runId'] + '@example.invalid')):
    raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
if not not O.exists():
    raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
expected_plan = '607e0559a857ead7647ab56fbfa2fe507d92f097b8c8a81255f2125b6029a54f'
if not hashlib.sha256(P.read_bytes()).hexdigest() == expected_plan:
    raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
s = boto3.Session(profile_name='trustcheckradar', region_name='us-east-1')
cfg = Config(connect_timeout=3, read_timeout=120, retries={'total_max_attempts': 1})
d = s.client('dynamodb', config=cfg)
l = s.client('lambda', config=cfg)
sts = s.client('sts', config=cfg)
r = {'attempts': [], 'commandsInjected': 0, 'receiptsInjected': 0, 'maxInvocations': 3, 'operatorTriggered': True, 'terminalStatusObserved': False}
O.write_text(json.dumps(r))

def guard():
    c = l.get_function_configuration(FunctionName='trustcheckradar-dev-account-data-api')
    e = c['Environment']['Variables']
    if not (c['CodeSha256'] == p['apiCodeSha256'] and c['RevisionId'] == p['apiRevisionId'] and (c['LastUpdateStatus'] == 'Successful') and (e['APP_ENVIRONMENT'] == 'dev') and (json.loads(e['ACCOUNT_DELETION_HTTP_SUBJECTS_JSON']) == [j['subject']])):
        raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
    rows = []
    cursor = None
    deadline = time.monotonic() + 60
    for _ in range(100):
        if not time.monotonic() < deadline:
            raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
        args = {'TableName': 'trustcheckradar-dev-deletion-ledger', 'ConsistentRead': True, 'Limit': 100}
        if cursor:
            args['ExclusiveStartKey'] = cursor
        page = d.scan(**args)
        rows += page.get('Items', [])
        cursor = page.get('LastEvaluatedKey')
        if not cursor:
            break
    else:
        raise RuntimeError('INCOMPLETE_SCAN')
    target = None
    for x in rows:
        pk = x.get('PK', {}).get('S', '')
        sk = x.get('SK', {}).get('S', '')
        if sk == 'ACCOUNT_DELETION' or sk.startswith('CAMPAIGN_WITHDRAWAL#'):
            status = x.get('status', {}).get('S')
            if not status in ('REQUESTED', 'COMPLETE'):
                raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
            if pk == 'ACCOUNT#' + j['subject'] and sk == 'ACCOUNT_DELETION':
                if not (x['operationId']['S'] == j['operationId'] and x['accountId']['S'] == j['subject'] and (x['environment']['S'] == 'dev')):
                    raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
                target = status
            elif status != 'COMPLETE':
                raise RuntimeError('OTHER_PENDING_COMMAND')
    if not target is not None:
        raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
    return target
try:
    if not sts.get_caller_identity()['Account'] == '107827791950':
        raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
    for index in range(3):
        if guard() == 'COMPLETE':
            r['terminalStatusObserved'] = True
            break
        item = {'index': index + 1, 'attempted': True, 'verified': False}
        r['attempts'].append(item)
        O.write_text(json.dumps(r, indent=2) + '\n')
        response = l.invoke(FunctionName='trustcheckradar-dev-account-data-api', InvocationType='RequestResponse', LogType='None', Payload=b'{"schemaVersion":1,"operation":"reconcile-session-revocation"}')
        body = response['Payload']
        try:
            raw = body.read(65537)
        finally:
            body.close()
        if not (response['StatusCode'] == 200 and (not response.get('FunctionError')) and (response.get('ExecutedVersion') == '$LATEST') and (len(raw) <= 65536)):
            raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
        x = json.loads(raw)
        if not (x.get('schemaVersion') == 1 and x.get('operation') == 'reconcile-session-revocation' and (type(x.get('commandFailures')) is int) and (x['commandFailures'] == 0) and (x.get('passHadFailures') is False)):
            raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
        if not all((x.get(k) == 0 for k in ('analysisAbusePolicyBlocked', 'campaignOutboxPolicyBlocked', 'userProfilePolicyBlocked'))):
            raise RuntimeError('RECONCILIATION_BOUNDARY_FAILED')
        item.update(verified=True, counts={k: v for k, v in x.items() if type(v) in (int, bool) or v is None})
        r['terminalStatusObserved'] = guard() == 'COMPLETE'
        O.write_text(json.dumps(r, indent=2) + '\n')
        if r['terminalStatusObserved']:
            break
        time.sleep(6)
    O.write_text(json.dumps(r, indent=2) + '\n')
    print(json.dumps({'verifiedInvocations': sum((a['verified'] for a in r['attempts'])), 'terminalStatusObserved': r['terminalStatusObserved']}))
finally:
    for c in (d, l, sts):
        c.close()
