#!/usr/bin/env python3
"""Validate a Dev code-only resolver plan; never print state or artifact content."""
import argparse
import base64
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ACCOUNT = '107827791950'
REGION = 'us-east-1'
FUNCTION = 'trustcheckradar-dev-url-resolver'
FUNCTION_ADDRESS = 'aws_lambda_function.resolver[0]'
ALIAS_ADDRESS = 'aws_lambda_alias.resolver[0]'
CODE_FIELDS = {
    's3_key', 's3_object_version', 'source_code_hash', 'reserved_concurrent_executions',
    'last_modified', 'version', 'qualified_arn', 'qualified_invoke_arn',
    'code_sha256', 'source_code_size',
}


def review(plan, revision):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('A full reviewed Git commit SHA is required.')
    if plan.get('errored') or plan.get('complete') is not True:
        raise ValueError('Only a complete, successful plan can be released.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    if (variables.get('environment'), variables.get('aws_region'), variables.get('project_name'), variables.get('enabled')) != ('dev', REGION, 'trustcheckradar', True):
        raise ValueError('This workflow only releases the existing enabled Dev resolver.')
    artifact = variables.get('artifact') or {}
    if artifact.get('bucket') != f'trustcheckradar-dev-{ACCOUNT}-artifacts':
        raise ValueError('Artifact must belong to the Dev account bucket.')
    if not re.fullmatch(r'releases/[^/]+/url_redirect_resolver\.zip', artifact.get('key', '')):
        raise ValueError('Invalid resolver artifact key.')
    if not artifact.get('object_version') or artifact['object_version'] == 'null':
        raise ValueError('An exact S3 object version is required.')
    try:
        digest = base64.b64decode(artifact['source_hash'], validate=True)
    except (KeyError, ValueError) as exc:
        raise ValueError('Invalid artifact SHA256.') from exc
    if len(digest) != 32:
        raise ValueError('Invalid artifact SHA256.')
    function_seen = alias_seen = False
    for resource in plan.get('resource_changes', []):
        if resource.get('mode') != 'managed':
            continue
        address = resource['address']
        change = resource['change']
        actions = change['actions']
        before, after = change.get('before') or {}, change.get('after') or {}
        if address == FUNCTION_ADDRESS:
            function_seen = True
            if before.get('function_name') != FUNCTION or after.get('function_name') != FUNCTION:
                raise ValueError('The existing Dev function must be preserved.')
            expected = {'s3_bucket': artifact['bucket'], 's3_key': artifact['key'], 's3_object_version': artifact['object_version'], 'source_code_hash': artifact['source_hash']}
            if any(after.get(k) != v for k, v in expected.items()):
                raise ValueError('The planned function does not match the pinned artifact.')
        elif address == ALIAS_ADDRESS:
            alias_seen = True
            if before.get('name') != 'live' or after.get('name') != 'live' or after.get('function_name') != FUNCTION:
                raise ValueError('The existing live alias must be preserved.')
        if actions == ['no-op']:
            continue
        if actions != ['update'] or address not in {FUNCTION_ADDRESS, ALIAS_ADDRESS}:
            raise ValueError(f'Out-of-scope resource change: {address}. Use separate infrastructure review.')
        allowed = CODE_FIELDS if address == FUNCTION_ADDRESS else {'function_version'}
        changed = {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
        changed |= {k for k, v in change.get('after_unknown', {}).items() if v}
        if changed - allowed:
            raise ValueError(f'Out-of-scope configuration change: {address}.')
    if not function_seen or not alias_seen:
        raise ValueError('An existing Dev function and live alias are required.')
    # Include refreshed state and unknowns, but omit volatile plan timestamps.
    reviewed = {k: plan.get(k) for k in ('terraform_version', 'variables', 'resource_changes', 'resource_drift', 'output_changes', 'checks')}
    reviewed['revision'] = revision
    fingerprint = hashlib.sha256(json.dumps(reviewed, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return artifact, fingerprint


def aws(*args):
    result = subprocess.run(['aws', *args, '--region', REGION, '--output', 'json'], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def verify_artifact(artifact, read=aws):
    if read('sts', 'get-caller-identity').get('Account') != ACCOUNT:
        raise ValueError('Unexpected AWS account; no artifact read performed.')
    with tempfile.TemporaryDirectory(prefix='resolver-artifact-') as directory:
        path = Path(directory) / 'resolver.zip'
        metadata = read('s3api', 'get-object', '--bucket', artifact['bucket'], '--key', artifact['key'], '--version-id', artifact['object_version'], str(path))
        if metadata.get('VersionId') != artifact['object_version']:
            raise ValueError('Downloaded artifact version does not match.')
        actual = base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode()
        if actual != artifact['source_hash']:
            raise ValueError('Downloaded artifact SHA256 does not match.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--expected-digest')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    artifact, fingerprint = review(json.loads(args.plan.read_text()), args.revision)
    if args.apply and (not args.expected_digest or args.expected_digest != fingerprint):
        raise ValueError('Apply requires the exact digest from the reviewed plan at this revision. Run plan again if state changed.')
    verify_artifact(artifact)
    print(json.dumps({'reviewedPlanDigest': fingerprint, 'revision': args.revision, 'artifactVersion': artifact['object_version'], 'artifactSha256': artifact['source_hash'], 'scope': 'dev-resolver-code-and-concurrency-only'}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        # Never emit subprocess output, downloaded contents or a raw plan.
        raise SystemExit(f'Resolver release rejected: {exc if isinstance(exc, ValueError) else type(exc).__name__}')
