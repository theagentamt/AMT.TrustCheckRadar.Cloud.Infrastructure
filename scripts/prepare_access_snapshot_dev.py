#!/usr/bin/env python3
"""Prepare private Dev GET-only inputs; never change AWS resources or accounts."""
import base64
import json
import os
import re
from pathlib import Path
from uuid import UUID

from verify_message_consumer_transition import aws, verify_artifacts
from verify_governed_history_plan import require

ACCOUNT = '107827791950'
BUCKET = f'trustcheckradar-dev-{ACCOUNT}-artifacts'
FUNCTION_NAME = 'trustcheckradar-dev-v1-entitlements'
EXTRA_GATE = 'DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'
PROVENANCE_REFERENCE = 'docs/evidence/sec244-access-snapshot-package.json'


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate private JSON member.')
        result[key] = value
    return result


def selection(value):
    require(type(value) is list and len(value) == 1, 'Exactly one private subject is required.')
    try:
        require(isinstance(value[0], str) and str(UUID(value[0])) == value[0], 'Canonical subject required.')
    except (ValueError, AttributeError):
        raise ValueError('Canonical subject required.') from None
    return value


def load_provenance():
    root = Path(__file__).resolve().parents[1]
    return json.loads((root / PROVENANCE_REFERENCE).read_text(), object_pairs_hook=unique_pairs)


def previous_artifact():
    path = Path(__file__).resolve().parents[1] / 'docs/evidence/sec232-complimentary-operator-publication.json'
    data = json.loads(path.read_text())['artifact']
    return {'bucket': data['bucket'], 'key': data['key'], 'object_version': data['versionId'], 'source_hash': data['sourceCodeHash']}


def provenance_artifact(provenance):
    source, digest = provenance.get('source_sha'), provenance.get('v1_entitlements')
    require(isinstance(source, str) and re.fullmatch('[a-f0-9]{40}', source), 'Reviewed Lambda source required.')
    require(isinstance(digest, str) and re.fullmatch('[a-f0-9]{64}', digest), 'Reviewed package digest required.')
    version = provenance.get('object_version')
    require(isinstance(version, str) and version.strip() == version and version not in {'', 'null'}, 'Reviewed immutable object version required.')
    return {'bucket': BUCKET, 'key': f'releases/{source}/v1_entitlements.zip', 'object_version': version,
            'source_hash': base64.b64encode(bytes.fromhex(digest)).decode()}


def build(source, preserved, extra, provenance, read=aws):
    selection(preserved); selection(extra)
    require(preserved != extra, 'Extra snapshot account must differ from the preserved account.')
    require(source == provenance.get('source_sha'), 'Source must match checked-in reviewed package provenance.')
    artifact = provenance_artifact(provenance)
    require(read('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Dev account required.')
    current = read('lambda', 'get-function-configuration', '--function-name', FUNCTION_NAME, '--qualifier', 'live')
    env = current.get('Environment', {}).get('Variables', {})
    require(current.get('FunctionName') == FUNCTION_NAME and current.get('State') == 'Active' and current.get('LastUpdateStatus') == 'Successful', 'Existing qualified entitlement runtime required.')
    require(env.get('STAGE') == 'dev' and env.get('DEV_SUBJECT_ALLOWLIST_JSON') == json.dumps(preserved, separators=(',', ':')) and
            all(env.get(k) == 'true' for k in ('AUTHORITY_ENABLED', 'V1_ENTITLEMENTS_ENABLED', 'TRIAL_AUTHORITY_RETENTION_APPROVED')), 'Preserved access/trial selection and policy must match live.')
    require(env.get(EXTRA_GATE) in (None, '[]'), 'A new extra selection requires separately reviewed existing scope.')
    require(current.get('CodeSha256') == previous_artifact()['source_hash'], 'Existing qualified entitlement package must be preserved as baseline.')
    history = read('lambda', 'get-function-configuration', '--function-name', 'trustcheckradar-dev-governed-history', '--qualifier', 'live')
    require(history.get('Environment', {}).get('Variables', {}).get('DEV_SUBJECT_ALLOWLIST_JSON') == env['DEV_SUBJECT_ALLOWLIST_JSON'], 'Preserved History and access selection must match.')
    alias = read('lambda', 'get-alias', '--function-name', FUNCTION_NAME, '--name', 'live')
    require(alias.get('FunctionVersion') == current.get('Version') and not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'), 'Existing unweighted live alias required.')
    verify_artifacts({'entitlements': artifact}, read=read)
    baseline = provenance['terraform_baseline']
    return {'governed_trial_subjects': preserved, 'dev_access_snapshot_extra_subjects': extra,
            'entitlements_artifact_override': {'source_sha': source, 'baseline_source_sha': baseline['source_sha'],
                'baseline_source_hash': baseline['source_hash'], 'baseline_object_version': baseline['object_version'],
                'provenance_reference': PROVENANCE_REFERENCE, 'artifact': artifact}}


def main():
    try:
        result = build(os.environ['LAMBDA_SOURCE_SHA'],
            json.loads(os.environ.get('PRESERVED_ACCESS_SUBJECTS_JSON') or '[]', object_pairs_hook=unique_pairs),
            json.loads(os.environ.get('ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON') or '[]', object_pairs_hook=unique_pairs), load_provenance())
        path = Path(os.environ['RUNNER_TEMP']) / 'access-snapshot.tfvars.json'
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(result, stream, sort_keys=True)
        print('Private GET-only selection, preserved access/History selection and exact package verified.')
    except Exception:
        raise SystemExit('Snapshot configuration rejected; private inputs were not printed.') from None


if __name__ == '__main__':
    main()
