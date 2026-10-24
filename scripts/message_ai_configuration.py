"""Normal Message AI configuration; source validation never authorizes activation."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import re
import stat
import zipfile

from verify_governed_history_plan import require

AI_FIELDS = {'secret_arn', 'qualification_id', 'qualification_evidence_sha256',
             'timeout_ms', 'max_nano_usd_per_window', 'cost_policy'}
COST_FIELDS = {'model', 'contextTokens', 'maxOutputTokens', 'inputNanoUsdPerToken', 'outputNanoUsdPerToken'}
BUDGET_FIELDS = {'window_seconds', 'max_attempts_per_window', 'max_failures_per_window'}
ENV_FIELDS = {'MESSAGE_AI_PRIMARY_ENABLED', 'MESSAGE_AI_COST_POLICY', 'MESSAGE_AI_QUALIFICATION_ID',
              'MESSAGE_PROPOSER_MODEL', 'MESSAGE_PROPOSER_SECRET_ARN', 'MESSAGE_PROPOSER_TIMEOUT_MS',
              'MESSAGE_PROPOSER_MAX_OUTPUT_TOKENS', 'MESSAGE_PROVIDER_NANO_USD_PER_WINDOW'}
POLICY = 'message-ai-2026-09-21-v1'


def unique_pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, 'AI_QUALIFICATION_BINDING')
        result[key] = value
    return result


def assignment(source, name):
    values = [node.value for node in ast.parse(source).body if isinstance(node, ast.Assign)
              and any(isinstance(n, ast.Name) and n.id == name for n in node.targets)]
    require(len(values) == 1, 'AI_QUALIFICATION_BINDING')
    return values[0]


def schema_hash(read):
    """Resolve only the current literal schema's two known dependencies."""
    reasons = ast.literal_eval(assignment(read('shared_message_contract/validation_v2.py'), 'AI_REASONS'))
    require(type(reasons) is set and all(type(x) is str for x in reasons), 'AI_QUALIFICATION_BINDING')
    span = assignment(read('message_evaluator/proposer.py'), 'SCHEMA')
    for field in ('properties', 'spans', 'items'):
        require(isinstance(span, ast.Dict), 'AI_QUALIFICATION_BINDING')
        matches = [value for key, value in zip(span.keys, span.values) if ast.literal_eval(key) == field]
        require(len(matches) == 1, 'AI_QUALIFICATION_BINDING')
        span = matches[0]
    span = ast.literal_eval(span)
    class Literals(ast.NodeTransformer):
        def visit_Call(self, node):
            require(ast.unparse(node) == 'sorted(AI_REASONS)', 'AI_QUALIFICATION_BINDING')
            return ast.parse(repr(sorted(reasons)), mode='eval').body
        def visit_Subscript(self, node):
            require(ast.unparse(node) == "proposer.SCHEMA['properties']['spans']['items']", 'AI_QUALIFICATION_BINDING')
            return ast.parse(repr(span), mode='eval').body
    schema = ast.literal_eval(Literals().visit(assignment(read('message_evaluator/ai_provider.py'), 'SCHEMA')))
    return hashlib.sha256(json.dumps(schema, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def integral(value, low, high):
    return type(value) is int and low <= value <= high


def validate(value):
    require(type(value) is dict and set(value) == {'message_ai_primary_enabled', 'candidate3_rules_only_enabled', 'ai_configuration', 'provider_budget'}
            and type(value['message_ai_primary_enabled']) is bool, 'AI_CONFIGURATION_SHAPE')
    require(value['candidate3_rules_only_enabled'] is None or type(value['candidate3_rules_only_enabled']) is bool,
            'AI_CONFIGURATION_SHAPE')
    if not value['message_ai_primary_enabled']:
        require(value['ai_configuration'] is value['provider_budget'] is None, 'AI_INACTIVE_CONFIGURATION')
        return value
    require(value['candidate3_rules_only_enabled'] is False, 'AI_PROFILE_CONFLICT')
    config, budget = value['ai_configuration'], value['provider_budget']
    require(type(config) is dict and set(config) == AI_FIELDS and type(budget) is dict and set(budget) == BUDGET_FIELDS,
            'AI_CONFIGURATION_SHAPE')
    cost = config['cost_policy']
    require(type(cost) is dict and set(cost) == COST_FIELDS and type(cost['model']) is str and
            re.fullmatch(r'[A-Za-z0-9._-]+-20[0-9]{2}-[0-9]{2}-[0-9]{2}', cost['model']) and
            integral(cost['contextTokens'], 1, 2_000_000) and integral(cost['maxOutputTokens'], 128, 512) and
            cost['maxOutputTokens'] <= cost['contextTokens'] and
            all(integral(cost[k], 1, 1_000_000_000) for k in ('inputNanoUsdPerToken', 'outputNanoUsdPerToken')),
            'AI_COST_CONFIGURATION')
    require(type(config['secret_arn']) is str and re.fullmatch(
        r'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-[A-Za-z0-9]{6}', config['secret_arn'])
        and type(config['qualification_id']) is str and re.fullmatch(r'[A-Za-z0-9_-]{1,64}', config['qualification_id'])
        and type(config['qualification_evidence_sha256']) is str and re.fullmatch(r'[a-f0-9]{64}', config['qualification_evidence_sha256'])
        and integral(config['timeout_ms'], 250, 8000), 'AI_PROVIDER_CONFIGURATION')
    reservation = cost['contextTokens'] * cost['inputNanoUsdPerToken'] + cost['maxOutputTokens'] * cost['outputNanoUsdPerToken']
    require(integral(config['max_nano_usd_per_window'], reservation, 10**18)
            and integral(budget['window_seconds'], 60, 86400)
            and integral(budget['max_attempts_per_window'], 1, 100000)
            and integral(budget['max_failures_per_window'], 1, budget['max_attempts_per_window']), 'AI_BUDGET_CONFIGURATION')
    return value


def environment(before, name, desired):
    """Change only provider policy fields; identity/admission/History stay exact."""
    validate(desired)
    require(name in ('consumer','evaluator'), 'AI_COMPONENT')
    active = desired['message_ai_primary_enabled']
    after = {k: v for k, v in before.items() if k not in ENV_FIELDS}
    after['MESSAGE_AI_ENABLED'] = str(active).lower()
    rules = desired['candidate3_rules_only_enabled']
    if rules is not None:
        after['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = str(rules).lower()
    if name == 'consumer':
        if active or rules is not None:
            after['MESSAGE_PROVIDER_CIRCUIT_OPEN'] = 'false' if active else str(rules).lower()
    else:
        require(before.get('MESSAGE_PROPOSER_ENABLED') == 'false', 'AI_LEGACY_PROPOSER_NOT_DISABLED')
        after['MESSAGE_AI_QUALIFIED'] = str(active).lower()
    if active:
        config = desired['ai_configuration']
        after.update(MESSAGE_AI_PRIMARY_ENABLED='true', MESSAGE_AI_COST_POLICY=json.dumps(config['cost_policy'], sort_keys=True, separators=(',', ':')))
        if name == 'consumer':
            after['MESSAGE_PROVIDER_NANO_USD_PER_WINDOW'] = str(config['max_nano_usd_per_window'])
            for field, key in {'window_seconds': 'MESSAGE_PROVIDER_WINDOW_SECONDS',
                'max_attempts_per_window': 'MESSAGE_PROVIDER_ATTEMPTS_PER_WINDOW',
                'max_failures_per_window': 'MESSAGE_PROVIDER_FAILURES_PER_WINDOW'}.items():
                after[key] = str(desired['provider_budget'][field])
        else:
            after.update(MESSAGE_AI_QUALIFICATION_ID=config['qualification_id'],
                MESSAGE_PROPOSER_MODEL=config['cost_policy']['model'], MESSAGE_PROPOSER_SECRET_ARN=config['secret_arn'],
                MESSAGE_PROPOSER_TIMEOUT_MS=str(config['timeout_ms']),
                MESSAGE_PROPOSER_MAX_OUTPUT_TOKENS=str(config['cost_policy']['maxOutputTokens']))
    return after


def policies(consumer, evaluator, authority_arn, assessment_arn, active, secret_arn=None):
    """Derive the exact reviewed delta, never replace unrelated existing allows."""
    left = copy.deepcopy(consumer)
    rows = [s for s in left['Statement'] if s.get('Sid') == 'MessageProviderBudget']
    require(len(rows) == 1 and rows[0]['Effect'] == 'Allow' and rows[0]['Action'] == ['dynamodb:UpdateItem']
            and rows[0]['Resource'] == authority_arn, 'AI_BUDGET_POLICY_BASELINE')
    base = ['PK', 'SK', 'recordType', 'revision', 'windowStart', 'attempts', 'failures']
    money = ['windowSeconds', 'reservedNanoUsd', 'unpricedAttempts']
    conditions = rows[0]['Condition']
    require(set(conditions) == {'ForAllValues:StringEquals', 'ForAnyValue:StringEquals'} and
            set(conditions['ForAllValues:StringEquals']) == {'dynamodb:LeadingKeys', 'dynamodb:Attributes'} and
            conditions['ForAllValues:StringEquals']['dynamodb:LeadingKeys'] == ['V1#CONTROL'] and
            conditions['ForAnyValue:StringEquals'] == {'dynamodb:EnclosingOperation': ['TransactWriteItems']} and
            conditions['ForAllValues:StringEquals']['dynamodb:Attributes'] in (base, base + money), 'AI_BUDGET_POLICY_BASELINE')
    conditions['ForAllValues:StringEquals']['dynamodb:Attributes'] = base + money if active else base
    right = copy.deepcopy(evaluator)
    statements = right['Statement']
    require(right.get('Version') == '2012-10-17' and len(statements) in (3, 7) and
            [s.get('Sid') for s in statements[:3]] == ['OwnLogs', 'OneReviewedUrlAssessmentAlias', 'NoConsumerStorageSecretsOrRoleChaining'] and
            statements[1] == {'Sid': 'OneReviewedUrlAssessmentAlias', 'Effect': 'Deny', 'Action': 'lambda:InvokeFunction', 'Resource': assessment_arn}, 'AI_URL_POLICY_BASELINE')
    deny = statements[2]
    require(deny.get('Effect') == 'Deny' and deny.get('Resource') == '*' and
            set(deny) == {'Sid', 'Effect', 'Action', 'Resource'} and
            deny['Action'] in (['dynamodb:*', 'secretsmanager:*', 's3:*', 'ssm:*', 'sts:AssumeRole'],
                               ['dynamodb:*', 's3:*', 'ssm:*', 'sts:AssumeRole']), 'AI_EVALUATOR_POLICY_BASELINE')
    if len(statements) == 7:
        old_secret = statements[3].get('Resource')
        require(statements[3:] == secret_statements(old_secret), 'AI_EVALUATOR_POLICY_BASELINE')
    else:
        require('secretsmanager:*' in deny['Action'], 'AI_EVALUATOR_POLICY_BASELINE')
    deny['Action'] = ['dynamodb:*'] + ([] if active else ['secretsmanager:*']) + ['s3:*', 'ssm:*', 'sts:AssumeRole']
    right['Statement'] = statements[:3] + (secret_statements(secret_arn) if active else [])
    return left, right


def secret_statements(arn):
    require(type(arn) is str and re.fullmatch(r'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-[A-Za-z0-9]{6}', arn), 'AI_PROVIDER_CONFIGURATION')
    return [
        {'Sid': 'OneQualifiedProviderSecret', 'Effect': 'Allow', 'Action': 'secretsmanager:GetSecretValue', 'Resource': arn,
         'Condition': {'StringEquals': {'secretsmanager:VersionStage': 'AWSCURRENT'}}},
        {'Sid': 'NoOtherSecrets', 'Effect': 'Deny', 'Action': 'secretsmanager:*', 'NotResource': arn},
        {'Sid': 'NoProviderSecretMutation', 'Effect': 'Deny', 'NotAction': 'secretsmanager:GetSecretValue', 'Resource': arn},
        {'Sid': 'NoOtherProviderSecretStage', 'Effect': 'Deny', 'Action': 'secretsmanager:GetSecretValue', 'Resource': arn,
         'Condition': {'StringNotEquals': {'secretsmanager:VersionStage': 'AWSCURRENT'}}},
    ]


def archive(name, path, desired):
    """Inspect bounded immutable ZIP metadata; never import or execute its code."""
    validate(desired)
    with zipfile.ZipFile(path) as package:
        entries = package.infolist()
        names = [x.filename for x in entries]
        require(len(names) <= 10000 and len(names) == len(set(names)) and
                sum(x.file_size for x in entries) <= 100_000_000 and all(
                    not x.filename.startswith('/') and '..' not in Path(x.filename).parts and
                    not stat.S_ISLNK(x.external_attr >> 16) and 'dev_ai_primary_e2e' not in x.filename
                    for x in entries), 'AI_PACKAGE_STRUCTURE')
        if name != 'evaluator' or not desired['message_ai_primary_enabled']:
            return
        def read(entry):
            require(entry in names and package.getinfo(entry).file_size <= 262144, 'AI_QUALIFICATION_BINDING')
            return package.read(entry)
        config = desired['ai_configuration']
        record = json.loads(read('message_evaluator/ai_qualifications.json'), object_pairs_hook=unique_pairs).get(config['qualification_id'])
        keys = {'model', 'policyVersion', 'promptSha256', 'schemaSha256', 'contractSha256', 'evidenceSha256', 'status', 'costPolicy'}
        require(type(record) is dict and set(record) == keys and record['status'] == 'approved'
                and record['model'] == config['cost_policy']['model'] and record['costPolicy'] == config['cost_policy']
                and record['policyVersion'] == POLICY and record['evidenceSha256'] == config['qualification_evidence_sha256'],
                'AI_QUALIFICATION_BINDING')
        require(hashlib.sha256(read('message_evaluator/qualifications/' + config['qualification_id'] + '.json')).hexdigest() == record['evidenceSha256']
                and hashlib.sha256(read('message_evaluator/ai_contract/SHA256SUMS')).hexdigest() == record['contractSha256']
                and all(type(record[k]) is str and re.fullmatch(r'[a-f0-9]{64}', record[k]) for k in ('promptSha256', 'schemaSha256')),
                'AI_QUALIFICATION_BINDING')
        members = set()
        for line in read('message_evaluator/ai_contract/SHA256SUMS').decode().splitlines():
            matched = re.fullmatch(r'([a-f0-9]{64}) [ *](.+)', line)
            require(matched is not None, 'AI_QUALIFICATION_BINDING')
            expected, member = matched.groups()
            require(member not in members and not Path(member).is_absolute() and '..' not in Path(member).parts,
                    'AI_QUALIFICATION_BINDING')
            members.add(member)
            require(hashlib.sha256(read('message_evaluator/ai_contract/' + member)).hexdigest() == expected,
                    'AI_QUALIFICATION_BINDING')
        require(bool(members), 'AI_QUALIFICATION_BINDING')
        # Bind the exact prompt/schema without executing archive code. Runtime
        # repeats these checks independently before any external call.
        instructions = ast.literal_eval(assignment(read('message_evaluator/ai_provider.py'), 'INSTRUCTIONS'))
        require(type(instructions) is str and hashlib.sha256(instructions.encode()).hexdigest() == record['promptSha256']
                and schema_hash(read) == record['schemaSha256'], 'AI_QUALIFICATION_BINDING')
