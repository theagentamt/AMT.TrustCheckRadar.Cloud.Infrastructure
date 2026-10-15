#!/usr/bin/env python3
"""Offline guard for CLOSED installation or recovery-only rollback plans.

No AWS/provider calls. A pass is not deployment approval. Activation is deliberately
unsupported; its exact reviewed plan and current-state inventory are still needed.
Never prints manifest URLs, subject IDs, plans, policies or exception contents.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

ACCOUNT = '107827791950'
TABLE = f'arn:aws:dynamodb:us-east-1:{ACCOUNT}:table/trustcheckradar-dev-url-qualification'
ROOTS = {
    'consumer': ('aws_lambda_function.runtime["consumer"]', 'aws_lambda_alias.runtime["consumer"]', 'aws_iam_role_policy.consumer[0]', 'url-consumer', 'url_consumer.zip'),
    'assessment': ('aws_lambda_function.assessment[0]', 'aws_lambda_alias.assessment[0]', 'aws_iam_role_policy.runtime[0]', 'url-assessment', 'url_assessment.zip'),
    'resolver': ('aws_lambda_function.resolver[0]', 'aws_lambda_alias.resolver[0]', 'aws_iam_role_policy.execution[0]', 'url-resolver', 'url_redirect_resolver.zip'),
}
FLAGS = {'URL_QUALIFICATION_ENABLED', 'URL_PROVIDER_ENABLED', 'URL_RETENTION_APPROVED'}
PUBLIC_KEYS = FLAGS | {'URL_QUALIFICATION_TABLE_NAME', 'URL_QUALIFICATION_MANIFEST_JSON'}
CONSUMER_KEYS = PUBLIC_KEYS | {'URL_NEW_ADMISSION_ENABLED', 'URL_RECONCILIATION_ENABLED', 'URL_SUBJECT_ALLOWLIST_JSON'}
PACKAGE = {'s3_bucket': 'bucket', 's3_key': 'key', 's3_object_version': 'object_version', 'source_code_hash': 'source_hash'}
COMPUTED = {'version', 'last_modified', 'qualified_arn', 'qualified_invoke_arn'}


def require(ok):
    if not ok:
        raise ValueError('URL qualification review rejected')


def unique(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value)
        value[key] = item
    return value


def manifest(raw):
    require(type(raw) is str and len(raw.encode()) <= 12000)
    value = json.loads(raw, object_pairs_hook=unique)
    require(type(value) is dict and set(value) == {'version', 'runId', 'startEpoch', 'endEpoch', 'syntheticOnly', 'targets'})
    require(type(value['version']) is int and value['version'] == 1 and value['syntheticOnly'] is True)
    require(type(value['startEpoch']) is int and type(value['endEpoch']) is int)
    require(0 < value['endEpoch'] - value['startEpoch'] <= 3600)
    require(type(value['runId']) is str and re.fullmatch(r'[0-9]{10}_[A-Za-z0-9_-]{1,32}', value['runId']))
    require(value['runId'].startswith(str(value['startEpoch']) + '_'))
    require(type(value['targets']) is list and 1 <= len(value['targets']) <= 16)
    ids, urls = set(), set()
    for target in value['targets']:
        require(type(target) is dict and set(target) == {'id', 'url'})
        ident, url = target['id'], target['url']
        require(type(ident) is str and re.fullmatch('[A-Za-z0-9_-]{1,48}', ident) and ident not in ids)
        require(type(url) is str and 0 < len(url.encode()) <= 2048 and url not in urls)
        parsed = urlsplit(url)
        require(parsed.scheme in ('https', 'http') and parsed.hostname and not parsed.username and not parsed.password)
        require('#' not in url and '\\' not in url and all(32 < ord(c) < 127 for c in url))
        ids.add(ident); urls.add(url)
    return value


def env(function):
    rows = function.get('environment') or []
    require(type(rows) is list and len(rows) <= 1)
    result = rows[0].get('variables') if rows else {}
    require(type(result) is dict and all(type(k) is str and type(v) is str for k, v in result.items()))
    require(sum(len(k.encode()) + len(v.encode()) for k, v in result.items()) <= 4096)
    return result


def has_unknown(value):
    if isinstance(value, dict): return any(has_unknown(v) for v in value.values())
    if isinstance(value, list): return any(has_unknown(v) for v in value)
    return value is True


def review(plan, root, phase, expected, revision):
    require(root in ROOTS and phase in ('install-closed', 'rollback-recovery'))
    require(root == 'consumer' or phase == 'install-closed')
    require(re.fullmatch('[a-f0-9]{40}', revision or ''))
    require(plan.get('complete') is True and plan.get('errored') is False and plan.get('terraform_version') == '1.12.1')
    require(not [r for r in plan.get('resource_drift', []) if r.get('mode') == 'managed'])
    require(all(c.get('status') == 'pass' for c in plan.get('checks', [])))
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    require(all(variables.get(k) == v for k, v in {'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar', 'enabled': True}.items()))
    function, alias, policy, suffix, package = ROOTS[root]
    rows = [r for r in plan.get('resource_changes', []) if r.get('mode') == 'managed']
    inventory = {r['address']: r for r in rows}
    require(len(inventory) == len(rows) and all(r.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for r in rows))
    require({function, alias, policy} <= inventory.keys())
    if root == 'consumer':
        require(all(f'aws_lambda_function.runtime["{name}"]' in inventory for name in ('recovery', 'entitlements', 'deletion')))
    changes = []
    for row in rows:
        change = row['change']
        actions = change.get('actions')
        if actions == ['no-op']:
            require(change.get('before') == change.get('after') and not has_unknown(change.get('after_unknown')))
            continue
        require(row['address'] in {function, alias, policy} and actions == ['update'])
        require(type(change.get('before')) is dict and type(change.get('after')) is dict)
        unknown = change.get('after_unknown') or {}
        allowed_unknown = COMPUTED if row['address'] == function else ({'function_version'} if row['address'] == alias else set())
        require(not has_unknown({k: v for k, v in unknown.items() if k not in allowed_unknown}))
        changes.append(row['address'])
    before, after = [inventory[function]['change'][key] for key in ('before', 'after')]
    name = 'trustcheckradar-dev-' + suffix
    require(before.get('function_name') == after.get('function_name') == name)
    require(before.get('runtime') == after.get('runtime') == 'python3.14')
    require(before.get('architectures') == after.get('architectures') == ['arm64'])
    require(type(before.get('role')) is str and before['role'].startswith(f'arn:aws:iam::{ACCOUNT}:role/'))
    changed = {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
    require(changed <= set(PACKAGE) | COMPUTED | {'environment'})
    for side, values in (('before', before), ('after', after)):
        pin = expected[side]
        require(set(pin) == {'bucket', 'key', 'object_version', 'source_hash'})
        require(pin['bucket'] == f'trustcheckradar-dev-{ACCOUNT}-artifacts')
        require(re.fullmatch('releases/[0-9a-f]{40}/' + re.escape(package), pin['key']))
        require(type(pin['object_version']) is str and pin['object_version'] not in ('', 'null'))
        require(re.fullmatch('[A-Za-z0-9+/]{43}=', pin['source_hash']))
        require(all(values.get(k) == pin[v] for k, v in PACKAGE.items()))
    old, new = env(before), env(after)
    require(new.get('STAGE') == 'dev' and new.get('URL_QUALIFICATION_TABLE_NAME') == TABLE.split('/')[1])
    value = manifest(new.get('URL_QUALIFICATION_MANIFEST_JSON'))
    require(all(new.get(flag) == 'false' for flag in FLAGS))
    keys = CONSUMER_KEYS if root == 'consumer' else PUBLIC_KEYS
    permitted = keys | ({'AUTHORITY_ENABLED'} if root == 'consumer' else ({'STAGE'} if root == 'resolver' else set()))
    require({k: v for k, v in old.items() if k not in permitted} == {k: v for k, v in new.items() if k not in permitted})
    require(set(new) - set(old) <= permitted)
    if root == 'consumer':
        subjects = json.loads(new['URL_SUBJECT_ALLOWLIST_JSON'])
        require(type(subjects) is list and len(subjects) == 1 and type(subjects[0]) is str and re.fullmatch('[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}', subjects[0]))
        require(new.get('URL_NEW_ADMISSION_ENABLED') == 'false' and new.get('CONSUMER_ENABLED') == 'false')
        require(new.get('URL_RECONCILIATION_ENABLED') == ('true' if phase == 'rollback-recovery' else 'false'))
        require(new.get('AUTHORITY_ENABLED') == ('true' if phase == 'rollback-recovery' else old.get('AUTHORITY_ENABLED')))
        if phase == 'rollback-recovery':
            require(old.get('URL_SUBJECT_ALLOWLIST_JSON') == new['URL_SUBJECT_ALLOWLIST_JSON'])
            require(old.get('URL_QUALIFICATION_MANIFEST_JSON') == new['URL_QUALIFICATION_MANIFEST_JSON'])
    else:
        require(not CONSUMER_KEYS.intersection(new.keys()) - PUBLIC_KEYS)
        require('COGNITO_ISSUER' not in new and 'COGNITO_APP_CLIENT_ID' not in new)
    policy_change = inventory[policy]['change']
    require(json.loads(policy_change['after']['policy']) == expected['policy'])
    require({k: v for k, v in policy_change['before'].items() if k != 'policy'} == {k: v for k, v in policy_change['after'].items() if k != 'policy'})
    # Existing allows cannot be broadened. The only new allows are exact,
    # partition-fenced qualification-table actions. Resource arrays are rejected
    # too; the installed IaC uses one exact table ARN for each new grant.
    old_policy = json.loads(policy_change['before']['policy'])
    require(expected['policy'].get('Version') == old_policy.get('Version') == '2012-10-17')
    old_statements = old_policy['Statement']
    new_statements = expected['policy']['Statement']
    for statement in old_statements:
        if statement in new_statements:
            continue
        permitted_deny = 'NoConsumerStorageOrRoleChaining' if root == 'assessment' else 'NoSecretsOrConsumerData' if root == 'resolver' else None
        require(statement.get('Effect') == 'Deny' and statement.get('Sid') == permitted_deny)
        narrowed = dict(statement)
        narrowed['Action'] = [action for action in statement['Action'] if action != 'dynamodb:*']
        require(narrowed in new_statements)
    for statement in new_statements:
        if statement in old_statements or statement.get('Effect') == 'Deny':
            continue
        require(statement.get('Effect') == 'Allow' and statement.get('Resource') == TABLE and 'NotResource' not in statement)
        acts = statement['Action']; acts = acts if type(acts) is list else [acts]
        allowed = {'dynamodb:GetItem'} if root == 'resolver' else {'dynamodb:GetItem', 'dynamodb:UpdateItem'} if root == 'consumer' else {'dynamodb:GetItem', 'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:ConditionCheckItem'}
        require(acts and set(acts) <= allowed)
        condition = statement.get('Condition', {})
        leading = condition.get('ForAllValues:StringEquals', {}).get('dynamodb:LeadingKeys')
        require(leading in (['CONTROL'], ['RUN#' + value['runId']]))
        if leading == ['CONTROL']:
            require(acts == ['dynamodb:GetItem'])
        else:
            require(root != 'resolver')
            if root == 'consumer':
                require(acts == ['dynamodb:UpdateItem'] and condition.get('ForAnyValue:StringEquals', {}).get('dynamodb:EnclosingOperation') == ['TransactWriteItems'])
    a = inventory[alias]['change']
    require(all(a[side].get('name') == 'live' and a[side].get('function_name') == name and not a[side].get('routing_config') for side in ('before', 'after')))
    require({k for k in a['before'].keys() | a['after'].keys() if a['before'].get(k) != a['after'].get(k)} <= {'function_version'})
    require(a['before'].get('function_version') == before.get('version'))
    if after.get('version') is None:
        cfg = plan.get('configuration', {}).get('root_module', {}).get('resources', [])
        refs = next((r for r in cfg if r.get('address') == alias.split('[')[0]), {}).get('expressions', {}).get('function_version', {}).get('references', [])
        require(inventory[function]['change'].get('after_unknown', {}).get('version') is True and a.get('after_unknown', {}).get('function_version') is True and a['after'].get('function_version') is None and function.split('[')[0] in refs)
    else:
        require(a['after'].get('function_version') == after['version'])
    require(all(v.get('before') == v.get('after') and not has_unknown(v.get('after_unknown')) for v in plan.get('output_changes', {}).values()))
    digest = hashlib.sha256(json.dumps({'plan': plan, 'expected': expected, 'revision': revision, 'root': root, 'phase': phase}, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'scope': 'dev-url-qualification-' + phase, 'root': root, 'changedResources': len(changes), 'reviewedPlanDigest': digest, 'deploymentAuthorized': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--expected', type=Path, required=True)
    parser.add_argument('--root', choices=ROOTS, required=True)
    parser.add_argument('--phase', choices=['install-closed', 'rollback-recovery'], required=True)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    try:
        result = review(json.loads(args.plan.read_text()), args.root, args.phase, json.loads(args.expected.read_text()), args.revision)
    except Exception:
        raise SystemExit('URL qualification plan rejected; private values were not printed.') from None
    print(json.dumps(result))


if __name__ == '__main__':
    main()
