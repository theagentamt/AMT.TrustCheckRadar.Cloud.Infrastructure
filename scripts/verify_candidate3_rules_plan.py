#!/usr/bin/env python3
"""Review source-pinned Dev candidate.3 deterministic transitions without provider access."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from verify_message_consumer_transition import review as review_legacy, _expected_environment, TRANSITION_ADDRESSES, ACCOUNT, REGION, PREFIX
from verify_governed_history_plan import require, flag


def evaluator_policy(deployment, active):
    return {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'OwnLogs', 'Effect': 'Allow', 'Action': ['logs:CreateLogStream', 'logs:PutLogEvents'], 'Resource': f'arn:aws:logs:{REGION}:{ACCOUNT}:log-group:/aws/lambda/{PREFIX}-message-evaluator:*'},
        {'Sid': 'OneReviewedUrlAssessmentAlias', 'Effect': 'Deny' if active else 'Allow', 'Action': 'lambda:InvokeFunction', 'Resource': deployment['assessment_alias_arn']},
        {'Sid': 'NoConsumerStorageSecretsOrRoleChaining', 'Effect': 'Deny', 'Action': ['dynamodb:*', 'secretsmanager:*', 's3:*', 'ssm:*', 'sts:AssumeRole'], 'Resource': '*'},
    ]}

def review(plan, revision, mode):
    require(mode in {'inactive', 'rules-only', 'rules-only-history'}, 'Unknown candidate.3 mode.')
    require(plan.get('terraform_version') == '1.12.1', 'Pinned Terraform version required.')
    active = mode != 'inactive'
    history = mode == 'rules-only-history'
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    require(flag(variables, 'candidate3_rules_only_enabled') is active and flag(variables, 'governed_history_settlement_enabled') is history and flag(variables, 'activate_rules_engineering') is active, 'Candidate.3 activation gates do not match the selected mode.')
    require(not any(v.get('mode') == 'managed' and v.get('change', {}).get('actions') != ['no-op'] for v in plan.get('resource_drift', [])), 'Resolve unreviewed managed drift before transition.')
    managed = {v['address']: v for v in plan.get('resource_changes', []) if v.get('mode') == 'managed'}
    allowed = TRANSITION_ADDRESSES | {'aws_iam_role_policy.evaluator[0]'}
    changed = [v for v in managed.values() if v['change']['actions'] != ['no-op']]
    require(all(v['address'] in allowed and v['change']['actions'] == ['update'] for v in changed), 'Candidate.3 may update only existing message functions, aliases and evaluator IAM.')
    require(allowed <= set(managed), 'Both functions, aliases and evaluator policy post-plan inventory are required.')
    planned = {v['address']: v.get('values') for v in plan.get('planned_values', {}).get('root_module', {}).get('resources', []) if v.get('mode') == 'managed'}
    require(set(planned) == set(managed) and all(planned[k] == v['change']['after'] for k, v in managed.items()), 'Complete consistent post-plan inventory required.')
    normalized = copy.deepcopy(plan)
    normalized['variables']['candidate3_rules_only_enabled'] = {'value': False}
    normalized['variables']['governed_history_settlement_enabled'] = {'value': False}
    normalized['resource_changes'] = [v for v in normalized['resource_changes'] if v.get('address') in TRANSITION_ADDRESSES]
    config = {v['address']: v for v in plan.get('configuration', {}).get('root_module', {}).get('resources', [])}
    for name in ('consumer', 'evaluator'):
        address = f'aws_lambda_function.runtime["{name}"]'
        fn = managed[address]['change']['after']
        env = fn.get('environment', [{}])[0].get('variables') or {}
        expected = _expected_environment(name, variables, active)
        expected['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = str(active).lower()
        if name == 'consumer':
            expected['GOVERNED_HISTORY_SETTLEMENT_ENABLED'] = str(history).lower()
            expected['MESSAGE_PROVIDER_CIRCUIT_OPEN'] = 'true'
        require(env == expected, 'Candidate.3 environment differs from the exact provider-free contract.')
        require(not any(fn.get(k) for k in ('layers', 'vpc_config', 'dead_letter_config', 'file_system_config', 'image_uri')), 'Unexpected candidate runtime attachment.')
        alias_address = f'aws_lambda_alias.runtime["{name}"]'
        alias = managed[alias_address]['change']['after']
        version = alias.get('function_version')
        if fn.get('version') is not None and version is not None:
            require(fn['version'] == version, 'Alias version must serve the reviewed function.')
        else:
            refs = config.get('aws_lambda_alias.runtime', {}).get('expressions', {}).get('function_version', {}).get('references') or []
            require(managed[alias_address]['change'].get('after_unknown', {}).get('function_version') is True and any(v.startswith('aws_lambda_function.runtime') for v in refs), 'Alias must bind the version published by the reviewed function.')
        for item in normalized['resource_changes']:
            # Existing candidate.1 verifier positively checks runtime/artifact/account/JWT/allowance pins for both functions even on a no-op plan.
            item['change']['actions'] = ['update']
            if item['address'] == address:
                item['change']['after']['environment'][0]['variables'] = _expected_environment(name, variables, active)
    deployment = variables['deployment']
    policy = evaluator_policy(deployment, active)
    value = managed['aws_iam_role_policy.evaluator[0]']['change']['after']
    require(json.loads(value.get('policy', '{}')) == policy and value.get('role') == f'{PREFIX}-message-evaluator-execution', 'Evaluator must deny URL invocation and all provider secrets in rules-only mode.')
    output = normalized.get('output_changes', {}).get('candidate_contract', {}).get('after') or {}
    require(output.get('candidate3_rules_only_enabled') is active and output.get('governed_history_settlement_enabled') is history and output.get('provider_circuit_open') is True, 'Output activation posture does not match candidate.3.')
    output['provider_circuit_open'] = not active
    review_legacy(normalized, revision, 'engineering' if active else 'inactive')
    material = {k: plan.get(k) for k in ('terraform_version', 'variables', 'resource_changes', 'resource_drift', 'output_changes', 'checks', 'configuration')}
    material.update(revision=revision, mode=mode)
    digest = hashlib.sha256(json.dumps(material, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'reviewedPlanDigest': digest, 'revision': revision, 'mode': mode, 'resourceChanges': len(changed), 'providerCallsEnabled': False, 'historySettlementEnabled': history, 'environment': 'dev'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path); parser.add_argument('--revision', required=True)
    parser.add_argument('--mode', required=True); parser.add_argument('--expected-digest')
    args = parser.parse_args()
    try:
        result = review(json.loads(args.plan.read_text()), args.revision, args.mode)
        if args.expected_digest is not None: require(args.expected_digest == result['reviewedPlanDigest'], 'Plan digest differs from the approved plan.')
        print(json.dumps(result))
    except (ValueError, KeyError, TypeError, OSError) as exc:
        raise SystemExit(f'Candidate.3 plan rejected: {exc}')
