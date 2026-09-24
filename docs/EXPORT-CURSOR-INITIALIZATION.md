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

## CLI correction and export artifact selection, 2026-09-23

The first live CLI attempt stopped before secret access: boto3 clients support
`close()` but not context-manager entry. The wrapper now uses `contextlib.closing`;
a CLI regression test covers clients without context-manager support. Seven
initializer tests pass. No secret was written by the failed attempt.

The Dev selection now pins only `account_export_api` from Lambda source
`e1651f86e30fc1478f69ba16a4049be8baf0e5f3`, S3 version
`YNLn3_R23z7m.OIi_0AfJCu5abU2btay`, SHA256
`ca76130d8e28f2786a64eabeb88bb215372411a99a79cd535adf532a645db129`.
The Lambda owner independently downloaded and verified the archive and validated
an initializer-generated keyring with its packaged parser and local encryption
round-trip. Publication evidence is integrated in Lambda PR48.

The independently reviewed saved plan SHA256
`112e031fc6f84dc995d1a6412d91ea25fbe381ee210a0046e62e8b29b23a1789`
updates only the export function's three artifact fields (plus computed modification
time). Environment, IAM, other functions and all activation gates are unchanged.
Application and key initialization require separate readback evidence.

## Applied and verified

Infrastructure PR67 merged at `d4d5e79f4b9a00984efeb64eeea79e4fa77987fe`.
The reviewed plan applied successfully; a fresh full API plan returned exit 0.
The new export hash and revision matched, and the Lambda owner checked the
disabled entrypoint once: 503 SERVICE_NOT_ENABLED, no FunctionError, unchanged
revision before/after. Both export gates remain false.

The corrected initializer created one keyring version and verified AWSCURRENT
in memory. No key material is in these records. This does not qualify enabled
export, inventory, identity mapping or live deletion.

- [Deployment readback](evidence/play-lifecycle-dev-2026-09-23/export-parser-deployment.json)
- [Initialization metadata](evidence/play-lifecycle-dev-2026-09-23/cursor-initialization.json)
- [Disabled smoke](evidence/play-lifecycle-dev-2026-09-23/export-parser-smoke.json)
