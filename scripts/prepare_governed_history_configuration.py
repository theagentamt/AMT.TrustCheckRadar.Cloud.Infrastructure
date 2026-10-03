#!/usr/bin/env python3
"""Write bounded Dev plan variables without logging private subject identifiers."""
import base64
import hashlib
import hmac
import re
import json
import os
from pathlib import Path
from verify_governed_history_plan import require


def validate_mode(scope, mode):
    modes = {'index': {'active', 'inactive'}, 'reader': {'inactive', 'list', 'detail', 'both'}, 'message': {'inactive', 'rules-only', 'rules-only-history'}}
    require(scope in modes and mode in modes[scope], 'Scope and mode combination is invalid.')


def build(scope, mode, deployment, subjects, index_ready, partitions=None):
    validate_mode(scope, mode)
    if scope == 'index':
        require(mode in {'active', 'inactive'}, 'Unknown index mode.')
        return {'governed_history_index_enabled': mode == 'active'}
    require(type(deployment) is dict and deployment, 'Reviewed immutable deployment coordinates are required.')
    partitions = partitions or []
    require(type(subjects) is list, 'Subjects must be a JSON list.')
    active = mode != 'inactive'
    require(len(subjects) == (1 if active else 0), 'Only one synthetic subject is permitted for scoped activation; inactive requires an empty list.')
    if scope == 'reader':
        require(bool(partitions) if active else not partitions, 'Reader IAM requires the exact private subject partitions when active.')
        require(mode in {'inactive', 'list', 'detail', 'both'}, 'Unknown reader mode.')
        require(not active or index_ready, 'Active reader requires a verified active index.')
        return {'enabled': True, 'deployment': deployment, 'engineering_subjects': subjects, 'authority_partitions': sorted(partitions), 'list_enabled': mode in {'list', 'both'}, 'detail_enabled': mode in {'detail', 'both'}, 'index_ready': index_ready, 'api_gateway': {'api_id': 'icuak34th9', 'execution_arn': 'arn:aws:execute-api:us-east-1:107827791950:icuak34th9', 'authorizer_id': 'itms4b'}}
    require(scope == 'message' and mode in {'inactive', 'rules-only', 'rules-only-history'}, 'Unknown message mode.')
    require(mode != 'rules-only-history' or index_ready, 'Settlement requires a verified active index.')
    return {'enabled': True, 'deployment': deployment, 'engineering_subjects': subjects, 'activate_rules_engineering': active, 'candidate3_rules_only_enabled': active, 'governed_history_settlement_enabled': mode == 'rules-only-history'}


def derive_partitions(deployment, subjects, read):
    require(len(subjects) == 1 and isinstance(subjects[0], str) and re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', subjects[0]), 'Exactly one canonical subject is required before reading the key ring.')
    arn = deployment.get('authority_hmac_secret_arn', '')
    require(re.fullmatch(r'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]{6}', arn), 'Only the existing Dev authority key ring may be read.')
    try:
        raw = read('secretsmanager', 'get-secret-value', '--secret-id', arn, '--version-stage', 'AWSCURRENT')['SecretString']
        require(isinstance(raw, str) and len(raw) <= 4096, 'Invalid authority key ring.')
        def unique_pairs(pairs):
            obj = {}
            for name, value in pairs:
                if name in obj: raise ValueError()
                obj[name] = value
            return obj
        data = json.loads(raw, object_pairs_hook=unique_pairs)
        require(type(data) is dict and set(data) == {'activeKeyId', 'keys'} and type(data['keys']) is dict and 1 <= len(data['keys']) <= 4 and data['activeKeyId'] in data['keys'], 'Invalid authority key ring.')
        result = []
        for key_id, encoded in data['keys'].items():
            require(isinstance(key_id, str) and re.fullmatch(r'[A-Za-z0-9]{1,8}', key_id), 'Invalid authority key ring.')
            key = base64.b64decode(encoded, validate=True)
            require(len(key) >= 32, 'Invalid authority key ring.')
            digest = hmac.new(key, ('account\0' + subjects[0]).encode(), hashlib.sha256).hexdigest()
            result.append(f'V1#{key_id}#{digest}')
        return sorted(result)
    except Exception:
        raise ValueError('Authority partition derivation failed; no key material is logged.') from None


if __name__ == '__main__':
    scope, mode = os.environ['HISTORY_SCOPE'], os.environ['HISTORY_MODE']
    validate_mode(scope, mode)
    deployment = json.loads(os.environ.get('PINNED_DEPLOYMENT_JSON') or '{}')
    subjects = json.loads(os.environ.get('ENGINEERING_SUBJECTS_JSON') or '[]') if mode != 'inactive' and scope != 'index' else []
    if scope == 'reader':
        from verify_governed_history_readback import verify_reader_preflight
        verify_reader_preflight(allow_missing=mode == 'inactive')
    ready = False
    if scope == 'reader' and mode != 'inactive' or scope == 'message' and mode == 'rules-only-history':
        from verify_governed_history_readback import verify_index
        verify_index()
        ready = True
    partitions = []
    if scope == 'reader' and mode != 'inactive':
        from verify_message_consumer_transition import aws
        partitions = derive_partitions(deployment, subjects, aws)
    result = build(scope, mode, deployment, subjects, ready, partitions)
    destination = Path(os.environ['RUNNER_TEMP']) / 'governed-history.tfvars.json'
    destination.write_text(json.dumps(result, sort_keys=True))
    destination.chmod(0o600)
