# Dev export cursor initial key setup

The owner authorized the next export setup step after the empty secret container
was deployed. This procedure initializes only that existing Dev container; it
does not rotate a populated keyring or enable export. It runs outside Terraform
so key bytes never enter plan/state, source, reports or shell arguments.

Run `python scripts/initialize_export_cursor.py --profile trustcheckradar` only
after AWS sign-in and independent review. The helper fences account/region/exact
secret ARN, refuses any existing version (including deprecated/interrupted
initializations), generates one cryptographically random 32-byte AES key and
encodes the approved `{activeKeyId, keys}` schema. Only fixed status and version
metadata may be retained. Never run with SDK debug logging.

The first PutSecretValue uses a unique initialization stage. It does not request
moving AWSCURRENT from another version. AWS may attach AWSCURRENT automatically
to the first version; the helper verifies that outcome. Otherwise promotion omits
RemoveFromVersionId, so a competing current version causes failure rather than
replacement. See the AWS API rules for
[PutSecretValue](https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_PutSecretValue.html)
and [UpdateSecretVersionStage](https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_UpdateSecretVersionStage.html).

The helper reads back only its exact version as AWSCURRENT, compares the generated
payload in memory and removes its initialization label. It never removes another
version's current label. A failure or lost acknowledgment requires metadata
inspection; do not automatically retry with a newly generated key. An interrupted
or losing concurrent attempt may leave a staged version. No cleanup/rotation or
secret deletion is implied by this procedure.

The actual runtime parser and local round-trip tests must validate compatibility
before activation. Secret setup alone does not qualify identity mapping, complete
inventory, live export behavior, key rotation or account cleanup. All current
export/deletion gates remain disabled.
