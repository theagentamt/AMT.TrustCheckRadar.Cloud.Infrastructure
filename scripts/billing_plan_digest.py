"""Project billing plans without the ephemeral STS caller session suffixes."""
import copy
import re

FIELDS = ('terraform_version', 'variables', 'resource_changes', 'resource_drift',
          'output_changes', 'checks', 'configuration')
ADDRESS = 'data.aws_caller_identity.current'
PROVIDER = 'registry.terraform.io/hashicorp/aws'
ACCOUNT = '107827791950'
ERROR = 'Billing plan caller identity cannot be qualified.'


def require(condition):
    if not condition:
        raise ValueError(ERROR)


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def known_mask(value):
    if type(value) is dict:
        return all(known_mask(child) for child in value.values())
    if type(value) is list:
        return all(known_mask(child) for child in value)
    return value is False


def normalize_identity(identity):
    require(type(identity) is dict and set(identity) == {'account_id', 'arn', 'id', 'user_id'} and
            all(type(value) is str for value in identity.values()))
    require(identity['account_id'] == identity['id'] == ACCOUNT)
    arn = re.fullmatch(r'arn:aws:sts::' + ACCOUNT + r':assumed-role/([A-Za-z0-9_+=,.@-]{1,64})/([A-Za-z0-9_+=,.@-]{2,64})', identity['arn'])
    user = re.fullmatch(r'(AROA[A-Z0-9]{17}):([A-Za-z0-9_+=,.@-]{2,64})', identity['user_id'])
    require(arn is not None and user is not None and arn.group(2) == user.group(2))
    return dict(identity, arn=identity['arn'].rsplit('/', 1)[0] + '/<session>', user_id=user.group(1) + ':<session>')


def data_rows(value):
    rows = []
    for node in walk(value):
        resources = node.get('resources', [])
        require(type(resources) is list)
        for row in resources:
            require(type(row) is dict)
            if row.get('mode') == 'data' or str(row.get('address', '')).startswith('data.'):
                rows.append(row)
    return rows


def projection(plan):
    """Keep every projected value except two validated assumed-role session names.

    Minimal plans without a caller declaration or reference need no normalization.
    A declared caller requires one fully known AWS no-op row. The source may
    consume its account only; role identity remains bound into the digest.
    """
    projected = copy.deepcopy({key: plan.get(key) for key in FIELDS})
    config = plan.get('configuration', {})
    declarations = []
    references = []
    for node in walk(config):
        resources = node.get('resources', [])
        require(type(resources) is list)
        for row in resources:
            require(type(row) is dict)
            if row.get('mode') == 'data' or str(row.get('address', '')).startswith('data.'):
                declarations.append(row)
        if 'references' in node:
            require(type(node['references']) is list and all(type(ref) is str for ref in node['references']))
            # Terraform emits the bare resource alongside account_id. A bare
            # object reference alone could expose the session through locals.
            require(ADDRESS not in node['references'] or ADDRESS + '.account_id' in node['references'])
            references.extend(ref for ref in node['references'] if 'data.aws_caller_identity' in ref)
    require(all(ref in (ADDRESS, ADDRESS + '.account_id') for ref in references))
    rows = projected.get('resource_changes')
    require(type(rows) is list and all(type(row) is dict for row in rows))
    drift = projected.get('resource_drift')
    if drift is None:
        drift = []
    require(type(drift) is list and all(type(row) is dict and row.get('mode') != 'data' and
            not str(row.get('address', '')).startswith('data.') for row in drift))
    data = [row for row in rows if row.get('mode') == 'data' or str(row.get('address', '')).startswith('data.')]
    prior = data_rows(plan.get('prior_state', {}).get('values', {}))
    planned = data_rows(plan.get('planned_values', {}))
    for source_rows in (prior, planned):
        require(len(source_rows) <= 1 and all(row.get('address') == ADDRESS and row.get('mode') == 'data' and
                row.get('type') == 'aws_caller_identity' and row.get('name') == 'current' and
                row.get('provider_name') == PROVIDER for row in source_rows))
    if not declarations and not references and not data and not prior and not planned:
        return projected
    require(len(declarations) == 1)
    declaration = declarations[0]
    require(declaration.get('address') == ADDRESS and declaration.get('mode') == 'data' and
            declaration.get('type') == 'aws_caller_identity' and declaration.get('name') == 'current')
    if not data:
        # Terraform omits an unchanged data source from resource_changes and
        # planned_values, retaining its refreshed identity only in prior_state.
        require(not planned)
        require(len(prior) == 1)
        row = copy.deepcopy(prior[0])
        require(set(row) == {'address', 'mode', 'type', 'name', 'provider_name', 'schema_version', 'values', 'sensitive_values'} and
                row.get('address') == ADDRESS and row.get('mode') == 'data' and
                row.get('type') == 'aws_caller_identity' and row.get('name') == 'current' and
                row.get('provider_name') == PROVIDER and type(row.get('schema_version')) is int and
                row['schema_version'] == 0 and known_mask(row.get('sensitive_values')))
        row['values'] = normalize_identity(row['values'])
        projected['qualified_caller_identity'] = row
        return projected
    require(len(data) == 1)
    row = data[0]
    require(row.get('address') == ADDRESS and row.get('mode') == 'data' and
            row.get('type') == 'aws_caller_identity' and row.get('name') == 'current' and
            row.get('provider_name') == PROVIDER)
    change = row.get('change')
    require(type(change) is dict and change.get('actions') == ['no-op'])
    require('after_unknown' in change and known_mask(change['after_unknown']) and
            known_mask(change.get('before_unknown', {})))
    require('before_sensitive' in change and 'after_sensitive' in change and
            known_mask(change['before_sensitive']) and known_mask(change['after_sensitive']))
    before, after = change.get('before'), change.get('after')
    require(type(before) is dict and type(after) is dict and before == after and
            set(before) == {'account_id', 'arn', 'id', 'user_id'} and
            all(type(value) is str for value in before.values()))
    normalized = normalize_identity(before)
    for side in ('before', 'after'):
        change[side] = copy.deepcopy(normalized)
    return projected
