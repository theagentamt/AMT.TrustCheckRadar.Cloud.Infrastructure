#!/usr/bin/env python3
"""Prepare private, immutable one-account Dev billing inputs; never activate AWS."""
import base64
import json
import os
import re
from pathlib import Path

from verify_message_consumer_transition import aws, verify_artifacts

ACCOUNT = '107827791950'
BUCKET = f'trustcheckradar-dev-{ACCOUNT}-artifacts'
MODES = {'handoff': {'inactive', 'preparation', 'verification'}, 'lifecycle': {'inactive', 'ingress', 'background'}}
PACKAGES = {'handoff': 'v1_play_handoff', 'ingress': 'play_lifecycle_ingress', 'worker': 'play_lifecycle_worker'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load_provenance():
    path = Path(__file__).resolve().parents[1] / 'docs/evidence/sec244-billing-package-provenance.json'
    return json.loads(path.read_text())


def verify_manifest(source, hashes):
    pinned = load_provenance()
    require(source == pinned.get('source_sha'), 'Lambda source must match the checked-in reviewed provenance.')
    require(type(hashes) is dict and all(hashes.get(k) == pinned.get(k) for k in ('source_sha', *PACKAGES.values())), 'Mutable package manifest must exactly match all checked-in source/package hashes.')


def build(scope, mode, source, subjects, hashes, evidence, read=aws):
    require(scope in MODES and mode in MODES[scope], 'Invalid billing scope/mode.')
    require(isinstance(source, str) and re.fullmatch(r'[a-f0-9]{40}', source), 'Exact reviewed Lambda source required.')
    active = mode != 'inactive'
    require(type(subjects) is list and len(subjects) == int(active) and all(isinstance(s, str) and re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', s) for s in subjects), 'Exactly one private subject for active billing; none for inactive.')
    require(type(evidence) is dict and set(evidence) == {'inventory_reference', 'runtime_reference', 'permissions_reference'} and all(isinstance(v, str) and v.strip() for v in evidence.values()), 'Reviewed inventory/runtime/IAM evidence required.')
    require(type(hashes) is dict and hashes.get('source_sha') == source, 'Package manifest must match reviewed Lambda source.')
    verify_manifest(source, hashes)
    require(read('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Dev account required before artifact discovery.')
    names = ['handoff'] if scope == 'handoff' else ['handoff', 'ingress', 'worker']
    pins = {}
    if scope == 'lifecycle':
        digest = hashes.get('v1_play_handoff')
        require(isinstance(digest, str) and re.fullmatch(r'[a-f0-9]{64}', digest), 'Reviewed foreground handoff package hash required for lifecycle.')
    for name in names:
        digest = hashes.get(PACKAGES[name])
        require(isinstance(digest, str) and re.fullmatch(r'[a-f0-9]{64}', digest), 'Reviewed package SHA256 required.')
        key = f'releases/{source}/{PACKAGES[name]}.zip'
        head = read('s3api', 'head-object', '--bucket', BUCKET, '--key', key)
        version = head.get('VersionId')
        require(isinstance(version, str) and version not in {'', 'null'}, 'Versioned immutable package required.')
        pins[name] = {'bucket': BUCKET, 'key': key, 'object_version': version, 'source_hash': base64.b64encode(bytes.fromhex(digest)).decode()}
    verify_artifacts(pins, read=read)
    activation = dict(source_sha=source, subjects=subjects, **evidence) if active else None
    if active:
        activation['mode'] = mode
    if scope == 'handoff':
        return {'billing_artifact_override': {'source_sha': source, 'provenance_reference': evidence['runtime_reference'], 'artifact': pins['handoff']}, 'billing_activation': activation}
    return {'billing_artifact_overrides': {name: {'source_sha': source, 'provenance_reference': evidence['runtime_reference'], 'artifact': pin} for name, pin in pins.items() if name != 'handoff'}, 'billing_activation': activation}


def main():
    try:
        result = build(os.environ['BILLING_SCOPE'], os.environ['BILLING_MODE'], os.environ['LAMBDA_SOURCE_SHA'],
                       json.loads(os.environ.get('ENGINEERING_SUBJECTS_JSON') or '[]'),
                       json.loads(os.environ.get('BILLING_PACKAGE_HASHES_JSON') or '{}'),
                       json.loads(os.environ.get('BILLING_EVIDENCE_JSON') or '{}'))
        path = Path(os.environ['RUNNER_TEMP']) / 'billing.tfvars.json'
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(result, stream)
        print('Private one-account billing inputs and immutable artifact hashes verified.')
    except Exception:
        raise SystemExit('Billing configuration rejected; private inputs were not printed.') from None


if __name__ == '__main__':
    main()
