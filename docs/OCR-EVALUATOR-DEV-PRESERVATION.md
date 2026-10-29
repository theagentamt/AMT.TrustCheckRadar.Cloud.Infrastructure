# Dev evaluator OCR rollout

This profile is limited to account `107827791950`, `us-east-1`, root
`terraform/message-consumer`, backend key
`trustcheckradar/dev/message-consumer.tfstate`. It is source preparation, not
permission to apply the root or run the following deployment operations.

The evaluator artifact is the immutable `dc0fc7b22b8201299bf6a448dfbb9a539b9055dd`
object pinned in `dev_ocr_preservation`. The staged consumer artifact remains
`ae17a53b783b74e0e70cc2b314cd86f0b29dcf7b`. Consumer live stays at version 8,
History at version 3. All AI gates stay false and rules-only stays true.

## Source and state accounting

The profile preserves the two existing staged environment maps by exact hashes,
not arbitrary overrides. Private inputs and plan JSON contain identity/configuration
values: use a private directory (0700), files (0600), and sanitized summaries only.
Do not retrieve secret contents or signed artifact download URLs.

Existing `deployment.artifacts` S3 fields remain the exact historical `6d9ae503`
inputs. AWS provider reads do not reconstruct these inputs from deployed code.
They are inert provenance, not a claim that the historical ZIP is currently on
`$LATEST`. The profile separately pins actual staged artifacts and checks observed
`code_sha256`. The normal single-release validation remains unchanged outside
this exact profile. Never apply an ordinary root plan using this profile: native
Lambda updates do not provide the revision guards required for this deployment.

## Review and execution sequence

1. Integrate reviewed source before deployment. Freshly verify identity, source,
   backend VersionId/ETag/serial, artifact versions/checksums, full environment
   hashes, live aliases and runtime configuration. Capture protected IAM,
   authentication, budgets and History code/config/alias metadata separately;
   History is outside this root. Stop on any changed preservation pin.
2. Build private `baseline` inputs with evaluator live version `7`. Produce a
   full normal saved plan with normal refresh and own temporary locking.
   Preserve any existing staged-code/environment or computed-IAM observation
   drift. The verifier rejects all drift; it must not be filtered. If necessary,
   prepare a separate exact refresh-only preview and obtain review/release before
   persisting those observations. Then require a clean full normal plan with all
   19 managed resources unchanged and unchanged caller data/outputs.
3. After exact execution review/release, use only the three guarded operations:
   `UpdateFunctionCode` on the evaluator with the pinned S3 version,
   `Publish=false` and fresh RevisionId; `PublishVersion` with the resulting
   RevisionId and expected code SHA; then `UpdateAlias` from live version 7 to the
   **actual returned** published version using its original alias RevisionId.
   Wait and verify after each call. No environment write, consumer update,
   permission change or provider invocation is part of these operations. Never
   replay an uncertain operation; read back its outcome first.
4. Capture the actual publication receipt, including code SHA and verified full
   environment hash. Use that version in `live` inputs. Prepare a separate
   refresh-only preview accounting for evaluator observed code/publication/alias
   only. Review its exact effects before state persistence. Retain every other
   resource, data value and output. Afterwards require a full normal saved plan
   accepted by `scripts/verify_ocr_preservation_plan.py`, comparing the reviewed
   baseline and actual publication receipt. Recheck external History and live
   consumer preservation metadata and lock release.

Publishing also promotes the already-staged, inactive evaluator configuration
into the new published version. Its environment hash must remain
`585748d38472e224ef2ec2380c757d864b9b23b000658d0f73164e5afbc8fb79`;
AI/primary/exception/proposer remain false. Previous AI activation packets become
stale after a code/revision change and must not be reused.

If code publication succeeds but alias promotion does not, stop and retain the
actual outcome. `staged` accounts for the new evaluator code with live alias 7.
Alias rollback to 7 does not restore `$LATEST` or its Terraform observations.
Any rollback/reconciliation needs exact review; do not delete versions or silently
rewrite state. No targeting, refresh-disabled plan, drift waiver, global
`ignore_changes`, guessed version or automatic next activation is supported.

## Evidence boundaries

The Python fixtures are isolated unit regressions. Offline Terraform validation
and the existing mocked-provider tests supplement them; none prove live
preservation or OCR acceptance. Actual deployment requires fresh hash-bound plans,
revision receipts and postdeployment readback. Android/backend real-service
acceptance remains a separate handoff.
