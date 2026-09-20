# Dev resolver GitHub release qualification

Verified 2026-09-20. Scope: existing private Dev URL resolver, not the consumer URL analyzer or wider V1 entitlement model. UAT/Prod remain disabled.

## Reviewed changes and actual runs

- Infrastructure [PR #6](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/6) merged at `b6691adac7f2e95db15cd7e0e2c82705e317b9ff`, excluding unrelated predecessor device-recovery changes. [PR CI passed](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35497992274).
- The first real resolver plan authenticated successfully but failed refreshing EIP attributes. [PR #7](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/7) adds `ec2:DescribeAddressesAttribute` to the existing read supplement. Six mocked bootstrap tests passed. A saved targeted plan contained only that one action addition to the Dev role, with the existing us-east-1 condition and no new write authority. Applied policy readback exactly matched the reviewed policy. The 13 unrelated full-bootstrap differences were not applied.
- [Plan run 35498128931, attempt 2](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35498128931) succeeded at the exact main revision above. Terraform reported no changes. The verifier downloaded the pinned S3 version and validated its bytes/hash through the GitHub OIDC role.
- [Apply run 35498454801](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35498454801) succeeded at the same revision with reviewed digest `beb5370e55cab01dcd684bf76de1f5065573f8dc6801f731c9b143ee9caff432`. It recomputed the matching digest, applied the saved plan with **0 added, 0 changed, 0 destroyed**, and completed the post-apply no-drift check.

The workflow's digest excludes volatile OIDC identity data-source values while retaining managed-resource changes/drift and material plan projections. Its regression test proves differing role-session IDs do not invalidate an otherwise identical review; actual managed changes still alter the digest. The digest binds the workflow revision as well as the plan, so this recorded digest cannot authorize a future revision.

## Artifact boundaries

The deployed function remains version 2, Python 3.14, alias `live`. Its pinned artifact is:

- Bucket `trustcheckradar-dev-107827791950-artifacts`
- Key `releases/url-resolver-py314-dev-20260920-d107988b4412/url_redirect_resolver.zip`
- S3 version `zKohCq1dfkcQb5f2IPscPfiYv9RoIFYB`
- SHA256 (base64) `0QeYi0QSW0hfQ5Z4stNK5968KHovT00yoXq1MrBmbmw=`

Lambda [PR #7](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/7) merged at `43625ebc43a9c511266436d72f828e5c46200ecc`. [Main CI](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35498192642) and the [actual scoped publisher](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35498212315) passed. The Lambda agent verified exactly one object under that release prefix:

- Key `releases/43625ebc43a9c511266436d72f828e5c46200ecc/url_redirect_resolver.zip`
- S3 version `1_6Fk_.KBmYzNTBmVkh_sQZiHWmWYVUW`
- Same SHA256 as the deployed artifact; 336116 bytes

Broad Lambda publication was skipped. This publication did not mutate the runtime/alias or change Terraform's pinned selection. A future deployment requires an explicitly reviewed artifact tuple and fresh plan/digest for that revision.

## What this proves

The actual GitHub-to-AWS authentication, refresh permissions, pinned artifact verification, cross-run plan matching, saved-plan apply and post-apply drift path work in Dev. Infrastructure resolver-only merges do not invoke the broad environment deployment workflow. Lambda resolver-only merges publish only the resolver ZIP.

No changed-code release or rollback was performed in this qualification. No public URL assessment API, new caller grant, Google credential, billing authority or Android feature was activated. Earlier live resolver tests and Python migration evidence remain in [the runtime record](URL-RESOLVER-PYTHON314-MIGRATION.md). The broader infrastructure story SECUR4ALL-242 stays In Progress; the remaining contract dependencies are in [the acceptance matrix](V1-INFRASTRUCTURE-REMAINING-ACCEPTANCE.md).
