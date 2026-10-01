# Infrastructure release branch reconciliation

The owner authorized integration of outstanding branch work into `release-V01`
where it was not already covered by `main`. This is source integration only;
it does not authorize a deployment, activation or promotion to `main`.

## Integrated source

- `codex/manual-dev-consumer-deployment` at `c5722d26fd24fcdff4fbdba1ae9eabad6af175b0`:
  six previously published commits containing Dev consumer IAM, provisioned
  artifact pins, inactive routes/lifecycle integration, operations and historical
  qualification evidence. The release previously lacked this source despite its
  publication on a feature branch.
- `codex/device-recovery-readiness` at `719261475e05d09135f32a864cd38ed4c005654f`:
  two inactive recovery acceptance/control commits. These were also the only
  non-equivalent outstanding commits in `codex/url-resolver-dev`; all eight
  resolver-specific commits have patch-equivalent integrated changes.
- Dependabot checkout 7.0.1 (`c816e17d3d769d8c2952b3dab26bb1fd98fd381c`, PR #2)
  and AWS credentials 6.3.0 (`c0f301ee15de3ecf97e381c99954293f8ce76bd9`, PR #1).
  Official release notes reviewed; existing workflow triggers, permissions,
  inputs and jobs are unchanged apart from these action versions. The older
  AWS branch name and dependency metadata say 6.2.4; its actual patch is 6.3.0.

The branch inventory is recorded in
[infrastructure-audit.json](evidence/branch-reconciliation-2026-09-21/infrastructure-audit.json).
Existing merged feature branches are recognized by ancestry or patch equivalence,
including the two recent squash merges. Untracked planning files in the original
checkout remain untouched and are not represented as committed source.

## Integration correction and retained boundaries

Independent review found that the newer message consumer still constrained
`ConditionCheckItem` by `EnclosingOperation=TransactWriteItems`, unlike the URL
consumer correction documented in prior Dev qualification. The message grant
now permits `GetItem` and `ConditionCheckItem` only on its existing `V1#*`
authority scope; `PutItem` and `UpdateItem` remain transaction-only. A regression
assertion checks that separation; no Query/Delete or additional resources added.

Dev URL infrastructure remains provisioned in the checked-in configuration, with
`activate_engineering=false` and an empty subject allowlist. Its schedules and
stream processing remain inactive under those inputs. Message configuration is
disabled in all environments, with its consumer, evaluator, authority and model
gates closed. Consumer device recovery remains disabled and requires reviewed
contract/security acceptance for an exact coordinated release.

The recovery development document is a historical 2026-09-17 checkpoint. Source
integration supersedes its statements about unpublished source, but does not
resolve its remaining public-contract, retry, live acceptance or activation
decisions. Lambda confirms the candidate contract-set digest remains
`e5d09ff748ce5f6e2f0ad6d97dd2ce38723709e3e620365218dc20ff9c509050`
and manifest digest remains
`504a3b4d2667c35357b33d495543efc8d5304bea4655564e8eada60707c48884`.

## Local validation

- Terraform 1.12.1 init with backend disabled and validate: API, URL consumer,
  URL resolver, URL assessment and message consumer.
- Mocked Terraform tests: API 60, URL consumer 8, resolver 10, assessment 5,
  message consumer 10; 93 passed, zero failures. The final message IAM assertion
  passed a targeted rerun; that rerun is not double-counted.
- Python helper suite: 43 passed.
- Recursive Terraform formatting, whitespace checks and actionlint passed.
- Parsed workflow comparison confirms only reviewed action versions changed;
  automatic CI remains main-only and deployment controls remain unchanged.
- Independent static review's one IAM finding corrected as described above.

No AWS calls, plans against live state, applies, service activation, hosted CI
dispatches or main updates are part of this reconciliation. Passing mocked tests
does not establish live recovery acceptance or qualify future hosted action runs.
