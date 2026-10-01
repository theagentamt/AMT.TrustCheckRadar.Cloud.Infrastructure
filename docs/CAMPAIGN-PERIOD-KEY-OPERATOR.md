# Current-period HMAC key operator

Sources: `scripts/provision_campaign_period_key.py` and `scripts/test_provision_campaign_period_key.py`.

The reviewed create-only plan was executed successfully on September 26 for Dev period1480. No registry or inventory write or runtime activation occurred. Twenty offline tests pass with normal Python and `-O` under `/tmp/amt-live-deletion-venv/bin/python`.

The helper derives the current period with `epoch // 1209600`; the caller cannot supply another period. It accepts only Dev account `107827791950` and `us-east-1`. It strongly reads the exact `PERIOD#<derived> / HMAC_KEY` registry key and refuses any existing row. It never writes the registry or inventory.

Discovery fully traverses bounded KMS key/tag listings. Unrelated keys are inspected only for tag classification and omitted from the plan. A candidate must have exactly the initializer's four tags (`Project`, `Environment`, `Purpose`, `PeriodId`), HMAC_256 / GENERATE_VERIFY_MAC, AWS_KMS origin, CUSTOMER manager, Enabled state and MultiRegion=false. Extra tags, duplicate candidates, incomplete listings or denied metadata reads stop provisioning. Existing eligible keys require a new plan with their explicit ARN selected; they are never silently replaced.

For a future still-unregistered current period, prepare a read-only plan for independent review with:

```sh
/tmp/amt-live-deletion-venv/bin/python scripts/provision_campaign_period_key.py --plan-out /tmp/campaign-current-key-plan.json
```

The output includes the exact plan-file SHA256. Existing eligible keys produce `selection_required`; generate a fresh plan with `--reuse-key-arn <exact-candidate-ARN>` to select one deliberately. Creating and reusing have distinct plan modes.

Only a separately reviewed plan may be applied:

```sh
/tmp/amt-live-deletion-venv/bin/python scripts/provision_campaign_period_key.py --apply-plan /tmp/campaign-current-key-plan.json --plan-sha256 <reviewed-plan-file-sha256> --journal /tmp/campaign-current-key-journal.json
```

Apply verifies the bytes, immutable target/tag tuple, caller, current period, absent registry and current complete discovery again. It fsyncs the create-attempt journal before the single SDK CreateKey call. Successful response metadata is saved before further checks. An uncertain call can only resolve through one fully discovered matching key whose creation time is consistent with the attempt; zero, multiple or incomplete results remain unresolved. Reusing that journal never issues CreateKey again. Period rollover fails closed and preserves any known key ARN. No automatic compensation occurs.

The helper has no key-material, GenerateMac, rotation, disable, deletion, tag-edit, inventory approval or runtime activation operation. The separate reviewed initializer still owns subsequent registry creation after genuine inventory readiness.

Root must serialize provisioning across hosts. KMS ListKeys/tag discovery is not an atomic lock against an external concurrent creator. The helper detects a later visible collision and refuses completion, but cannot guarantee another operator never races without a separate locking surface. No such lock or DynamoDB write has been introduced.

Discovery first verifies DescribeKey ARN, KeyId and KeyManager. It skips only keys conclusively managed by AWS; CUSTOMER tag access or metadata failures remain fatal. Independent review passed source SHA256 `cfbb68c416168eb7a93a125bc8f68943f1ad6846974a2590530969e6a11fcc4a`, with 20 tests normally and under -O.
