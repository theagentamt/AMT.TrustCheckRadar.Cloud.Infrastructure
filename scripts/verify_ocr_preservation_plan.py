#!/usr/bin/env python3
"""Qualify no-change accounting for the single reviewed Dev OCR CAS rollout.

Never executes AWS operations, authorizes root apply, or filters managed drift.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from verify_governed_history_plan import require, changed_fields
from verify_preserved_deployment import unknowns

SOURCE = 'dc0fc7b22b8201299bf6a448dfbb9a539b9055dd'
ARTIFACT = {'bucket': 'trustcheckradar-dev-107827791950-artifacts',
            'key': f'releases/{SOURCE}/message_evaluator.zip',
            'object_version': 'Qz3S9pWTSg0yef9ZaLqS6DDAy26VT7RZ',
            'source_hash': '72rKZjvnUBZgE8w0Lw++4vMox/QrfuekUruifEQoUeM='}
CONSUMER_ARTIFACT = {'bucket': ARTIFACT['bucket'],
    'key': 'releases/ae17a53b783b74e0e70cc2b314cd86f0b29dcf7b/message_consumer.zip',
    'object_version': 'U9UzSSorYYU67oPYe.EC_ZpIC.1Q0rDE',
    'source_hash': 'kgUck3tzaq0RSVSuWbS1OW2Q8hNZx6shc2BzEaDa1vU='}
ENV_HASHES = {'consumer': '9655f704305f7f15387c29f36aab8e641ac4fe27705d1a5d3a72ab916c4f4875',
              'evaluator': '585748d38472e224ef2ec2380c757d864b9b23b000658d0f73164e5afbc8fb79'}
OLD_EVALUATOR = '6vzJ0oDuNdQq3gja0Qeod5TOcRxALiPDWYuKnaXlx0o='
HISTORICAL_ARTIFACTS = {
    'consumer': {'bucket': ARTIFACT['bucket'], 'key': 'releases/6d9ae503b7d4e36a16a4cfc6bee2c939b988c723/message_consumer.zip',
        'object_version': 'Exz6MG1Co_IrtzWPLvfF9hWXXD3EqCLO', 'source_hash': 'UbXMvj46spsxhd2P0rPATFWiqjGUbti4rv0fCALa2Xo='},
    'evaluator': {'bucket': ARTIFACT['bucket'], 'key': 'releases/6d9ae503b7d4e36a16a4cfc6bee2c939b988c723/message_evaluator.zip',
        'object_version': 'XOot9peLSF7kirfnRUAyO2hRN2RX.Zj.', 'source_hash': '4t6hHXE5RybaI7o4qTFqcWZgK0TaOdnN1uAZ+nctBj0='}}
COMPUTED = {'version', 'qualified_arn', 'qualified_invoke_arn', 'last_modified', 'code_sha256', 'source_code_size'}
F = 'aws_lambda_function.runtime["evaluator"]'
A = 'aws_lambda_alias.runtime["evaluator"]'
INVENTORY = {
    f'{kind}.runtime["{name}"]'
    for kind in ('aws_cloudwatch_log_group', 'aws_iam_role', 'aws_lambda_function', 'aws_lambda_alias')
    for name in ('consumer', 'evaluator')
} | {
    f'aws_lambda_function_event_invoke_config.no_async_retries["{name}"]'
    for name in ('consumer', 'evaluator')
} | {'aws_iam_role_policy.consumer[0]', 'aws_iam_role_policy.evaluator[0]',
     'aws_apigatewayv2_integration.message[0]'} | {
    f'{kind}.message["{route}"]'
    for kind in ('aws_apigatewayv2_route', 'aws_lambda_permission')
    for route in ('prepare', 'submit', 'reconcile')
}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def verified_caller_identity(plan):
    """Read Terraform's unchanged observation without inventing a change row."""
    address = 'data.aws_caller_identity.current'
    provider = 'registry.terraform.io/hashicorp/aws'

    def data_resources(module):
        result = [r for r in module.get('resources', []) if r.get('mode') == 'data']
        for child in module.get('child_modules', []):
            result.extend(data_resources(child))
        return result

    def is_caller(row):
        return (row.get('address') == address and row.get('mode') == 'data'
                and row.get('type') == 'aws_caller_identity' and row.get('name') == 'current'
                and row.get('provider_name') == provider)

    prior = data_resources(plan.get('prior_state', {}).get('values', {}).get('root_module', {}))
    require(len(prior) == 1 and is_caller(prior[0]), 'One verified prior Dev caller observation required.')
    value = prior[0].get('values') or {}
    require(set(value) == {'account_id', 'arn', 'id', 'user_id'}
            and all(type(v) is str and v for v in value.values())
            and value['account_id'] == value['id'] == '107827791950'
            and re.fullmatch(r'arn:aws:(iam|sts)::107827791950:.+', value['arn']), 'Exact Dev caller account binding required.')

    config = plan.get('configuration', {}).get('root_module', {})
    declared = [r for r in config.get('resources', []) if r.get('mode') == 'data']
    require(not config.get('module_calls') and len(declared) == 1
            and declared[0].get('address') == address and declared[0].get('type') == 'aws_caller_identity'
            and declared[0].get('name') == 'current' and declared[0].get('provider_config_key') == 'aws'
            and plan.get('configuration', {}).get('provider_config', {}).get('aws', {}).get('full_name') == provider,
            'Caller observation must belong to the configured AWS data source.')

    changes = [r for r in plan.get('resource_changes', []) if r.get('mode') == 'data']
    if changes:
        require(len(changes) == 1 and is_caller(changes[0]), 'Unexpected or duplicate caller change row.')
        c = changes[0]['change']
        require(c['actions'] == ['no-op'] and c.get('before') == c.get('after') == value
                and not unknowns(c.get('after_unknown', {})), 'Caller reads, changes and unknown values are forbidden.')
    planned = data_resources(plan.get('planned_values', {}).get('root_module', {}))
    require(not planned or (len(planned) == 1 and is_caller(planned[0]) and planned[0].get('values') == value),
            'Planned caller observation must match the unchanged prior observation.')
    return value


def profile(values):
    require(values.get('environment') == 'dev' and values.get('aws_region') == 'us-east-1'
            and values.get('project_name') == 'trustcheckradar' and values.get('enabled') is True,
            'Exact Dev root required.')
    p = values.get('dev_ocr_preservation')
    require(type(p) is dict and set(p) == {'phase', 'evaluator_live_version', 'artifact', 'recorded_consumer_artifact', 'environments'}, 'Exact OCR profile required.')
    require(p['artifact'] == ARTIFACT and p['recorded_consumer_artifact'] == CONSUMER_ARTIFACT, 'Only the two recorded artifacts are permitted.')
    require((values.get('deployment') or {}).get('artifacts') == HISTORICAL_ARTIFACTS, 'Historical provider inputs must remain inert and exact.')
    require(p['phase'] in ('baseline', 'staged', 'live'), 'Unknown rollout phase.')
    require((type(p['evaluator_live_version']) is str and re.fullmatch('[1-9][0-9]*', p['evaluator_live_version']) and int(p['evaluator_live_version']) > 7)
            if p['phase'] == 'live' else p['evaluator_live_version'] == '7', 'No guessed or unrelated live version.')
    require(values.get('activate_rules_engineering') is True and values.get('candidate3_rules_only_enabled') is True
            and values.get('governed_history_settlement_enabled') is True and values.get('message_ai_primary_enabled') is False
            and values.get('url_assessment_enabled') is False, 'Rules-only boundaries required.')
    require(type(p['environments']) is dict and set(p['environments']) == set(ENV_HASHES), 'Exact staged environment components required.')
    for name, expected in ENV_HASHES.items():
        env = p['environments'][name]
        require(type(env) is dict and all(type(k) is str and type(v) is str for k, v in env.items()) and digest(env) == expected, 'Staged environment fingerprint mismatch.')
        require(env.get('MESSAGE_AI_ENABLED') == env.get('MESSAGE_AI_PRIMARY_ENABLED') == 'false'
                and env.get('MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED') == 'true', 'AI must remain disabled.')
    e = p['environments']['evaluator']
    require(all(e.get(k) == 'false' for k in ('MESSAGE_AI_QUALIFIED', 'MESSAGE_AI_DEV_EXCEPTION_ENABLED', 'MESSAGE_PROPOSER_ENABLED'))
            and p['environments']['consumer'].get('MESSAGE_PROVIDER_CIRCUIT_OPEN') == 'true', 'No qualification, exception or provider activation.')
    return p


def review(plan, revision, baseline=None, publication=None):
    require(re.fullmatch('[0-9a-f]{40}', revision) and plan.get('terraform_version') == '1.12.1'
            and plan.get('complete') is True and not plan.get('errored'), 'Complete pinned plan required.')
    require(not plan.get('resource_drift'), 'Managed drift requires separate exact refresh review; never filtered here.')
    values = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    p = profile(values)
    rows = {r['address']: r for r in plan.get('resource_changes', []) if r.get('mode') == 'managed'}
    require(set(rows) == INVENTORY and len(rows) == len([r for r in plan['resource_changes'] if r.get('mode') == 'managed']), 'Exact unique 19-resource inventory required.')
    verified_caller_identity(plan)
    for row in rows.values():
        c = row['change']
        require(row.get('provider_name') == 'registry.terraform.io/hashicorp/aws' and c['actions'] == ['no-op']
                and c['before'] == c['after'] and not unknowns(c.get('after_unknown', {})), 'No resource mutation or unknown value is permitted.')
    require(all(v['actions'] == ['no-op'] and v.get('before') == v.get('after') and not unknowns(v.get('after_unknown', {}))
                for v in plan.get('output_changes', {}).values()), 'All outputs must be unchanged.')
    for name in ('consumer', 'evaluator'):
        fn = rows[f'aws_lambda_function.runtime["{name}"]']['change']['after']
        alias = rows[f'aws_lambda_alias.runtime["{name}"]']['change']['after']
        expected = CONSUMER_ARTIFACT['source_hash'] if name == 'consumer' else OLD_EVALUATOR if p['phase'] == 'baseline' else ARTIFACT['source_hash']
        require(fn['function_name'] == 'trustcheckradar-dev-message-' + name and fn['code_sha256'] == expected
                and fn['environment'][0]['variables'] == p['environments'][name], 'Actual staged code/config must match profile.')
        require(alias['name'] == 'live' and alias['function_name'] == fn['function_name'] and not alias.get('routing_config')
                and alias['function_version'] == ('8' if name == 'consumer' else p['evaluator_live_version']), 'Independent unweighted live aliases required.')
    if p['phase'] != 'baseline':
        require(type(baseline) is dict, 'Reviewed baseline required after code mutation.')
        review(baseline, revision)
        old = {r['address']: r['change']['after'] for r in baseline['resource_changes'] if r.get('mode') == 'managed'}
        require(set(old) == set(rows), 'Baseline inventory changed.')
        for address, row in rows.items():
            fields = changed_fields(old[address], row['change']['after'])
            require(fields <= (COMPUTED if address == F else {'function_version'} if address == A else set()), 'Unrelated runtime/IAM/auth/budget/resource change.')
        require(set(plan.get('output_changes', {})) == set(baseline.get('output_changes', {}))
                and all(plan['output_changes'][k]['after'] == v['after'] for k, v in baseline['output_changes'].items()), 'Baseline outputs changed.')
    if p['phase'] == 'live':
        require(type(publication) is dict and publication.get('FunctionName') == 'trustcheckradar-dev-message-evaluator'
                and publication.get('Version') == p['evaluator_live_version'] and publication.get('CodeSha256') == ARTIFACT['source_hash']
                and publication.get('environmentSha256') == ENV_HASHES['evaluator'], 'Actual verified publication receipt required; no future version guess.')
    return {'status': 'PRESERVATION_NOOP_VERIFIED', 'phase': p['phase'], 'managedNoOps': 19,
            'resourceMutations': 0, 'rootApplyAuthorized': False,
            'reviewedDigest': digest({'revision': revision, 'plan': plan, 'baseline': baseline, 'publication': publication})}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--publication', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(review(json.loads(args.plan.read_text()), args.revision,
            json.loads(args.baseline.read_text()) if args.baseline else None,
            json.loads(args.publication.read_text()) if args.publication else None)))
    except (ValueError, KeyError, TypeError, OSError):
        raise SystemExit('OCR preservation rejected; private plan values were not printed.') from None
