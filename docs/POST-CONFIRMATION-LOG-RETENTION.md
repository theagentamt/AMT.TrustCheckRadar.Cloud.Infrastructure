# Dev post-confirmation log retention

The current metadata audit found the existing
`/aws/lambda/trustcheckradar-dev-post-confirmation` log group had no expiration.
The owner-approved 14-day policy is recorded in
[account-data decisions](ACCOUNT-DATA-POLICY-DECISIONS.md). The Dev identity stack
now selects that policy and declaratively imports the existing group. It is not
recreated. This adoption is limited to Dev; UAT/Prod inputs are unchanged.

The saved full identity-stack plan SHA256
`e25b78eca57eb47709b7a8229c0d66c6f27193c6778fb0b810c1624e8777044f`
contains one import and one in-place update: retention from unlimited to 14 days,
plus normal repository tags. Lambda source/runtime/environment, IAM and Cognito
trigger configuration have no changes. Five local Terraform tests pass; the
existing mock suite overrides the imported group because mock providers cannot
import resources. Production resources were not contacted by those tests.

Retention makes older logs eligible for expiration under the approved policy.
No log content was read. Applied status and metadata readback are recorded only
after the saved plan is applied.

The audit's absent `device-recovery-control` table is deliberate: Dev foundation
provisioning is false, and the deployed recovery function has no control table,
its feature disabled, and policy pending. This observation is not full recovery
inventory or activation approval. The post-confirmation profile-fence candidate
also remains unselected; the live writer has no deletion-ledger fence and still
uses its previous Python runtime. That separate Lambda/infrastructure dependency
must be qualified before enabling whole-account deletion.

## Applied and verified, 2026-09-23

PR68 merged at `4ea949bc16d183e950fb466d0243d37cb0d57b21`. The independently
reviewed saved plan applied successfully: one existing group imported and updated,
none created or destroyed. AWS readback confirms 14-day retention. A fresh full
identity-stack plan returned exit 0 (no drift). No Lambda, IAM or Cognito behavior
changed. See [metadata evidence](evidence/play-lifecycle-dev-2026-09-23/post-confirmation-log-retention.json).

The refreshed configuration audit found explicit retention on all 33 observed
log groups. The deliberately disabled recovery table is still absent; metadata
coverage alone does not qualify complete account-data erasure.
