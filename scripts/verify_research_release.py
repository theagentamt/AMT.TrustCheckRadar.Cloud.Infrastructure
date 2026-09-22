#!/usr/bin/env python3
"""Verify an exact Dev research migration plan and immutable artifacts; never apply."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ACCOUNT = '107827791950'
REGION = 'us-east-1'
BUCKET = f'trustcheckradar-dev-{ACCOUNT}-artifacts'
PREFIX = 'trustcheckradar-dev-'
MANIFEST = Path(__file__).resolve().parents[1] / 'docs/evidence/dev-research-actions-publication.json'
CAMPAIGN = {'publisher': 'campaign_observation_publisher', 'cluster': 'campaign_cluster_aggregator',
            'deletion': 'campaign_deletion_bridge', 'lifecycle': 'campaign_lifecycle'}
API = {'analysis': 'conversation_analysis', 'participation': 'campaign_participation',
       'snapshot': 'entitlement_snapshot', 'web_risk': 'web_risk_communication', 'purchase': 'purchase_handoff'}
API_ADDRESSES = {'analysis': 'aws_lambda_function.analysis', 'participation': 'aws_lambda_function.campaign_participation',
                 'snapshot': 'aws_lambda_function.entitlement_snapshot', 'web_risk': 'aws_lambda_function.web_risk_communication[0]',
                 'purchase': 'aws_lambda_function.purchase_handoff'}
COMPUTED_CODE = {'last_modified', 'version', 'qualified_arn', 'qualified_invoke_arn', 'code_sha256', 'source_code_size'}
FUNCTION_FIELDS = COMPUTED_CODE | {'s3_bucket', 's3_key', 's3_object_version', 'source_code_hash', 'runtime', 'environment', 'reserved_concurrent_executions'}
COMMON_ENV = {'USERS_TABLE_NAME': PREFIX+'users', 'DELETION_LEDGER_TABLE_NAME': PREFIX+'deletion-ledger',
              'CAMPAIGN_PARTICIPATION_NOTICE_VERSION': 'research-consent-2026-09-21-v2',
              'CAMPAIGN_PARTICIPATION_POLICY_VERSION': 'independent-research-v1'}
LOCATOR_ENV = {'CAMPAIGN_LOCATOR_MANIFEST_SHA256': '', 'CAMPAIGN_LOCATOR_INVENTORY_REVISION': '0'}
ANALYSIS_ENV = {'APP_ENVIRONMENT': 'dev', 'COGNITO_REQUIRED_SCOPE': 'aws.cognito.signin.user.admin',
                'HISTORY_MAX_SUMMARY_BYTES': '4096', 'HISTORY_MAX_LIST_ITEMS': '20',
                'HISTORY_MAX_TEXT_FIELD_BYTES': '1024', 'HISTORY_MAX_RESPONSE_BYTES': '262144',
                'DELETION_LEDGER_TABLE_NAME': PREFIX+'deletion-ledger', 'HISTORY_WRITES_ENABLED': 'false',
                'HISTORY_DURABLE_REPLAY_ENABLED': 'false', 'RECOGNITION_ENABLED': 'false'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unknown(value):
    if isinstance(value, dict):
        return any(unknown(v) for v in value.values())
    if isinstance(value, list):
        return any(unknown(v) for v in value)
    return value is True


def changed_fields(change):
    before, after = change.get('before') or {}, change.get('after') or {}
    return ({k for k in before.keys() | after.keys() if before.get(k) != after.get(k)} |
            {k for k, v in (change.get('after_unknown') or {}).items() if unknown(v)})


def environment(value):
    blocks = value.get('environment')
    require(isinstance(blocks, list) and len(blocks) == 1 and isinstance(blocks[0].get('variables'), dict), 'Unknown function environment')
    return blocks[0]['variables']


def artifacts_for(manifest, stack, selected):
    mapping = CAMPAIGN if stack == 'campaign-processing' else API
    require(manifest.get('scope') == 'research_candidate' and manifest.get('environment') == 'dev' and
            manifest.get('publicationComplete') is True and manifest.get('runtimeUpdated') is False and
            manifest.get('activationApproved') is False, 'Invalid publication evidence')
    release = manifest.get('sourceSha')
    require(isinstance(release, str) and re.fullmatch('[0-9a-f]{40}', release), 'Invalid artifact source revision')
    rows = manifest.get('artifacts')
    require(isinstance(rows, list) and len(rows) == 9 and {r.get('function') for r in rows} == set(CAMPAIGN.values()) | set(API.values()), 'Incomplete publication evidence')
    by_function = {r['function']: r for r in rows}
    pins = selected.get('workers' if stack == 'campaign-processing' else 'artifacts')
    require(selected.get('release_id') == release and isinstance(pins, dict) and set(pins) == set(mapping), 'Unreviewed artifact selection')
    require(selected.get('promotion_approved') is False and isinstance(selected.get('approval_reference'), str) and selected['approval_reference'].strip(), 'Missing Dev rollout reference')
    result = {}
    for worker, function in mapping.items():
        row = by_function[function]
        require(row.get('artifact') == function+'.zip' and row.get('bucket') == BUCKET and
                row.get('key') == f'releases/{release}/{function}.zip' and row.get('runtime') == 'python3.14' and
                row.get('architecture') == 'arm64' and row.get('handler') == 'app.lambda_handler', 'Invalid published artifact identity')
        version, sha = row.get('versionId'), row.get('sourceCodeHash')
        require(isinstance(version, str) and version and version != 'null', 'Missing immutable object version')
        require(isinstance(sha, str) and re.fullmatch('[A-Za-z0-9+/]{43}=', sha), 'Invalid artifact checksum')
        raw = base64.b64decode(sha, validate=True)
        require(len(raw) == 32 and raw.hex() == row.get('sha256'), 'Inconsistent artifact checksum')
        require(pins[worker] == {'object_version': version, 'source_hash': sha}, 'Selection differs from published evidence')
        result[worker] = {'function': function, 'bucket': BUCKET, 'key': row['key'], 'object_version': version, 'source_hash': sha}
    return result


def function_environment(worker, stack, before, after):
    old, new = environment(before), environment(after)
    if stack == 'campaign-processing':
        allowed = COMMON_ENV | LOCATOR_ENV
        required = dict(LOCATOR_ENV)
        if worker == 'lifecycle':
            allowed['CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED'] = 'false'
            required['CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED'] = 'false'
        if worker in {'publisher', 'cluster'}:
            required.update(COMMON_ENV)
    elif worker == 'analysis':
        allowed, required = dict(ANALYSIS_ENV), dict(ANALYSIS_ENV)
        # These are public Cognito identifiers; preserve exact planned values in
        # the private digest, never include them in the minimized report.
        require(isinstance(new.get('COGNITO_ISSUER'), str) and re.fullmatch(r'https://cognito-idp\.us-east-1\.amazonaws\.com/us-east-1_[A-Za-z0-9]+', new['COGNITO_ISSUER']), 'Invalid replay Cognito issuer')
        require(isinstance(new.get('COGNITO_APP_CLIENT_ID'), str) and re.fullmatch('[A-Za-z0-9]{1,128}', new['COGNITO_APP_CLIENT_ID']), 'Invalid replay Cognito client')
        allowed.update({k: new[k] for k in ('COGNITO_ISSUER', 'COGNITO_APP_CLIENT_ID')})
    elif worker == 'participation':
        allowed = {k:v for k,v in COMMON_ENV.items() if k.startswith('CAMPAIGN_')} | {'CONSENT_INDEPENDENCE_ENABLED': 'false'}
        required = dict(allowed)
    elif worker == 'purchase':
        allowed = {'DELETION_LEDGER_TABLE_NAME': PREFIX+'deletion-ledger', 'PURCHASE_OWNERSHIP_CANDIDATE_ENABLED': 'false'}
        required = dict(allowed)
    else:
        allowed, required = {}, {}
    require(all(new.get(k) == v for k,v in required.items()), 'A required closed runtime gate or identity is missing')
    changed = {k for k in old.keys() | new.keys() if old.get(k) != new.get(k)}
    require(changed <= set(allowed) and all(new.get(k) == allowed[k] for k in changed), 'Out-of-scope environment change')
    return sorted(changed)


def scheduler_document_proof(plan):
    configs = {r.get('address'):r for r in plan.get('configuration',{}).get('root_module',{}).get('resources',[])}
    policy = configs.get('aws_iam_role_policy.scheduler_invoke', {})
    document = configs.get('data.aws_iam_policy_document.scheduler_invoke', {})
    require(policy.get('expressions') == {
        'name': {'constant_value':'invoke-lifecycle'},
        'policy': {'references':['data.aws_iam_policy_document.scheduler_invoke[0].json','data.aws_iam_policy_document.scheduler_invoke[0]','data.aws_iam_policy_document.scheduler_invoke']},
        'role': {'references':['aws_iam_role.scheduler[0].id','aws_iam_role.scheduler[0]','aws_iam_role.scheduler']},
    }, 'Unknown scheduler policy lacks exact source binding')
    require(document.get('expressions') == {'statement':[{
        'actions':{'constant_value':['lambda:InvokeFunction']}, 'effect':{'constant_value':'Allow'},
        'resources':{'references':['aws_lambda_function.worker["lifecycle"].arn','aws_lambda_function.worker["lifecycle"]','aws_lambda_function.worker']},
        'sid':{'constant_value':'InvokeLifecycle'},
    }]}, 'Unknown scheduler policy is not the exact lifecycle-only document')
    return [policy,document]


def review(plan, revision, stack, manifest=None):
    require(isinstance(revision, str) and re.fullmatch('[0-9a-f]{40}', revision), 'Exact infrastructure revision required')
    require(stack in {'campaign-processing', 'api'}, 'Unsupported stack')
    require(isinstance(plan, dict) and plan.get('complete') is True and not plan.get('errored'), 'Incomplete or failed plan')
    variables = {k:v.get('value') for k,v in plan.get('variables', {}).items()}
    require(tuple(variables.get(k) for k in ('environment', 'aws_region', 'project_name')) == ('dev', REGION, 'trustcheckradar'), 'Wrong environment identity')
    if stack == 'campaign-processing':
        require(variables.get('research_consent_migration') is True and variables.get('kill_switch_enabled') is True and variables.get('campaign_processing_enabled') is True, 'Campaign migration must remain paused')
        selected = variables.get('account_privacy_artifacts')
        require(variables.get('publisher_fence_artifact') is None and variables.get('deletion_bridge_artifact') is None, 'Conflicting candidate inputs')
    else:
        selected = variables.get('research_consent_migration_deployment')
        require(isinstance(selected, dict) and selected.get('consent_enabled') is False, 'Consent must remain disabled')
        require(variables.get('campaign_participation_fence_deployment') is None and variables.get('purchase_handoff_fence_deployment') is None, 'Conflicting API inputs')
        history = variables.get('history_features') or {}
        require(all(history.get(k) is False for k in ('writes','recognition','durable_replay')), 'Legacy History writes must remain disabled')
        require(variables.get('enable_web_risk_communication') is True, 'The existing retired endpoint must remain present')
    require(isinstance(selected, dict), 'Migration candidate not selected')
    artifacts = artifacts_for(manifest if manifest is not None else json.loads(MANIFEST.read_text()), stack, selected)
    functions = {f'aws_lambda_function.worker["{k}"]':k for k in CAMPAIGN} if stack == 'campaign-processing' else {v:k for k,v in API_ADDRESSES.items()}
    mappings = {f'aws_lambda_event_source_mapping.{k}[0]' for k in ('publisher','cluster','deletion')} if stack == 'campaign-processing' else set()
    schedules = {f'aws_scheduler_schedule.lifecycle["{k}"]' for k in ('expire_transient','finalize_periods','manage_keys')} if stack == 'campaign-processing' else set()
    policies = ({f'aws_iam_role_policy.{k}_runtime[0]' for k in CAMPAIGN} | {'aws_iam_role_policy.scheduler_invoke[0]'}) if stack == 'campaign-processing' else {f'aws_iam_policy.{k}_runtime' for k in ('analysis','purchase_handoff','entitlement_snapshot','campaign_participation')} | {'aws_iam_policy.web_risk_communication_runtime[0]'}
    boundaries = {f'aws_iam_role_policy.research_migration_boundary["{k}"]':k for k in API} if stack == 'api' else {}
    cutover = 'terraform_data.research_migration_cutover[0]'
    allowed = set(functions) | mappings | schedules | policies | set(boundaries) | ({cutover} if stack == 'api' else set())
    needed = set(functions) | mappings | schedules | set(boundaries) | ({cutover} if stack == 'api' else set())
    seen, changes, managed, configuration_proofs = set(), [], [], []
    for resource in plan.get('resource_changes', []):
        if resource.get('mode') != 'managed':
            continue
        address, change = resource['address'], resource['change']
        require(address not in seen, 'Duplicate managed resource')
        seen.add(address); managed.append(resource)
        actions = change['actions']; before, after = change.get('before') or {}, change.get('after') or {}
        require(actions == ['no-op'] or (address in allowed and (actions == ['update'] or (actions == ['create'] and (address in boundaries or address == cutover)))), 'Out-of-scope resource action')
        fields = changed_fields(change); env_fields = []
        if address in functions:
            worker = functions[address]; artifact = artifacts[worker]
            name = PREFIX + artifact['function'].replace('_','-')
            arn = f'arn:aws:lambda:{REGION}:{ACCOUNT}:function:{name}'
            require(before.get('function_name') == name and after.get('function_name') == name and before.get('arn') == arn and after.get('arn') == arn, 'Wrong existing function/account')
            maximum_concurrency = 2 if stack == 'campaign-processing' else 5
            concurrency_var = 'reserved_concurrency' if stack == 'campaign-processing' else {
                'analysis':'analysis', 'participation':'campaign_participation', 'snapshot':'entitlement_snapshot',
                'web_risk':'web_risk_communication', 'purchase':'purchase_handoff'}[worker] + '_lambda_reserved_concurrency'
            expected_concurrency = variables.get(concurrency_var)
            require(type(expected_concurrency) is int and expected_concurrency in (0,maximum_concurrency) and
                    type(before.get('reserved_concurrent_executions')) is int and before['reserved_concurrent_executions'] in (0,maximum_concurrency) and
                    type(after.get('reserved_concurrent_executions')) is int and after.get('reserved_concurrent_executions') == expected_concurrency, 'Unexpected concurrency selection')
            require(after.get('runtime') == 'python3.14' and after.get('architectures') == ['arm64'] and after.get('handler') == 'app.lambda_handler', 'Wrong function runtime')
            expected = {'s3_bucket':BUCKET, 's3_key':artifact['key'], 's3_object_version':artifact['object_version'], 'source_code_hash':artifact['source_hash']}
            require(all(after.get(k) == v for k,v in expected.items()), 'Planned code differs from immutable pins')
            if expected_concurrency > 0:
                require(all(before.get(k) == v for k,v in expected.items()) and before.get('runtime') == 'python3.14',
                        'Install selected code at zero concurrency before restoring access')
            require(fields <= FUNCTION_FIELDS, 'Out-of-scope function configuration change')
            require(not unknown((change.get('after_unknown') or {}).get('environment')), 'Unknown runtime environment')
            env_fields = function_environment(worker, stack, before, after)
        elif address in mappings:
            require(after.get('enabled') is False and fields <= {'enabled','last_modified','last_processing_result','state','state_transition_reason'}, 'Campaign source must remain disabled and unchanged')
        elif address in schedules:
            require(after.get('state') == 'DISABLED' and fields <= {'state'}, 'Campaign schedule must remain disabled and unchanged')
        elif address in policies:
            require(fields <= {'policy'}, 'Out-of-scope runtime policy change')
            if not isinstance(after.get('policy'), str):
                require(stack == 'campaign-processing' and address == 'aws_iam_role_policy.scheduler_invoke[0]' and
                        (change.get('after_unknown') or {}).get('policy') is True, 'Unknown runtime policy')
                configuration_proofs = scheduler_document_proof(plan)
        elif address in boundaries:
            name = PREFIX+artifacts[boundaries[address]]['function'].replace('_','-')
            require(after.get('name') == PREFIX+'research-migration-'+boundaries[address] and after.get('role') == name+'-role' and isinstance(after.get('policy'), str), 'Invalid migration boundary identity')
            require(fields <= ({'name','role','policy','id'} if actions == ['create'] else {'policy'}), 'Out-of-scope boundary change')
        elif address == cutover and stack == 'api':
            require(after.get('input') == selected['release_id'] and fields <= {'input','output','id'}, 'Invalid campaign cutover evidence')
        if actions != ['no-op']:
            changes.append({'address':address, 'actions':actions, 'changedFields':sorted(fields), 'changedEnvironmentFields':env_fields})
    require(needed <= seen, 'Required migration resources absent from plan')
    require(not any(c.get('status') == 'fail' for c in plan.get('checks', [])), 'Failed plan check')
    stable = {'revision':revision, 'stack':stack, 'terraform_version':plan.get('terraform_version'), 'variables':plan.get('variables'),
              'managed':sorted(managed,key=lambda r:r['address']), 'configurationProofs':configuration_proofs,
              'managedDrift':sorted((r for r in plan.get('resource_drift',[]) if r.get('mode')=='managed'),key=lambda r:r['address'])}
    fingerprint = hashlib.sha256(json.dumps(stable,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return {'revision':revision, 'environment':'dev', 'stack':stack, 'scope':'research-migration-flags-off',
            'reviewedPlanDigest':fingerprint, 'changes':sorted(changes,key=lambda r:r['address']),
            'artifacts':[artifacts[k] for k in sorted(artifacts)], 'consentEnabled':False, 'campaignConsumersEnabled':False}


def aws(*args):
    result = subprocess.run(['aws', *args, '--region', REGION, '--output', 'json'], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def verify_artifacts(artifacts, read=aws):
    require(read('sts','get-caller-identity').get('Account') == ACCOUNT, 'Wrong AWS account')
    with tempfile.TemporaryDirectory(prefix='research-artifacts-') as directory:
        for artifact in artifacts:
            path = Path(directory)/(artifact['function']+'.zip')
            metadata = read('s3api','get-object','--bucket',artifact['bucket'],'--key',artifact['key'],'--version-id',artifact['object_version'],str(path))
            require(metadata.get('VersionId') == artifact['object_version'], 'Downloaded version differs')
            actual = base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode()
            require(actual == artifact['source_hash'], 'Downloaded checksum differs')


def authorize_digest(report, expected, apply):
    require(not apply or (isinstance(expected,str) and expected == report['reviewedPlanDigest']), 'Apply requires the reviewed digest at this exact revision')
    if expected is not None:
        require(expected == report['reviewedPlanDigest'], 'Reviewed digest differs')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan',type=Path);parser.add_argument('--revision',required=True)
    parser.add_argument('--stack',required=True);parser.add_argument('--expected-digest');parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    report=review(json.loads(args.plan.read_text()),args.revision,args.stack)
    authorize_digest(report,args.expected_digest,args.apply)
    verify_artifacts(report['artifacts'])
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # Never print raw plan, environment/policy values, SDK errors or content.
        raise SystemExit('Research release rejected; inspect protected evidence locally.') from None
