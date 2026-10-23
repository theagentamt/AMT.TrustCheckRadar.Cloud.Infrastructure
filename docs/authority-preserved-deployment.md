# Preserved Dev deployment modes

This focused main-based source change adds two choices to the existing manual
Deploy infrastructure workflow. Both require an exact main revision, Dev account
107827791950, the existing protected Dev environment/role and Terraform 1.12.1.
The broad and legacy jobs exclude these choices. No automatic trigger, IAM/trust,
secret, API, admission default or provider setting is changed.

`authority-maintenance` can update only the existing recovery function's
LEASE_SWEEP_ENABLED environment flag, its unweighted live alias, existing
one-minute rule, heartbeat alarm controls and overdue-alarm actions. Worker code
is pinned to the retained v11 hash; all artifacts and unrelated resources remain
unchanged. Shared recovery and expiry are inseparable: enabling this mode can
permanently delete eligible expired records across Dev accounts. The owner must
approve this scope separately before an apply. No apply is authorized by source
publication or by a successful plan.

`message-consumer-preserve-history` preserves candidate.3/schema3, History, AI-off
and the provider-open circuit. It permits coordinated Message package/alias
updates only; IAM and all runtime environments remain exact. The existing
two-subject Message/History cohort is pinned by its sorted JSON SHA-256. The old
one-subject qualification remains supported separately; no arbitrary second
subject is admitted. A future AI exception remains a different, one-tester gate.

The workflow first makes a private, non-applicable baseline plan using existing
source inputs. A read-only helper binds every selected existing function/alias to
its current version, package hash, full environment, limits and successful update
state, then prepares a private overlay. Maintenance preparation preserves existing
governed trial, separate GET-only access and deletion selections. It does not read
user items, derive keys, fetch secret values, register devices or grant access.
An optional full artifact_release SHA selects the two already-published versioned
Message objects; their hashes are checked before plan review. Artifact coordinates
that cannot be joined to current state/live code fail closed rather than being
guessed or replaced with stale defaults.

Message planning requires actual enabled same-table maintenance first. Readback
checks the exact worker hash/runtime/role/table, rule and target, input, retries,
invocation resource policy, existing role/trust/inline-policy baseline, and both
alarm identities/destinations. Missing read permissions stop the workflow; no
permission expansion or skipped check is allowed.

The final saved-plan verifier rejects failed/unknown checks, managed drift,
missing or inconsistent inventory, replacements, unrelated changes, private scope
changes, networking/limit changes, IAM updates and alias replay. It requires the
same refreshed baseline and captured live data. Apply needs the exact reviewed
digest at the same source revision and fresh identical live capture. Existing
caller-session normalization is reused for digest stability; no plan timestamps
or session suffixes serve as identity. Actual post-apply function/alias/control
readback and a zero-drift plan are required. Every shell creating private files
uses umask 077; exclusive private JSON writers use 0600; temporary files are removed
on success or failure. Only minimized fixed results/digests enter job summaries.

This is source completion, not deployment or live connectivity acceptance. The
two modes cannot enable AI, read a provider key or consume the one-generation
allowance. The exact retained worker 11 ZIP imports successfully in the cached
official Python 3.14 ARM64 Lambda image with networking disabled and no credentials;
its handler was not invoked. Full non-secret inventory shape, behavioral cleanup
qualification, fresh due-index inventory and irreversible-expiry approval remain
pre-activation gates. The earlier due-index observation was zero pending/zero
expiring at 15:17 UTC on 2026-10-23; it is eventual, dated and not future permission.
Keep complimentary access through 2026-10-27T22:09:34Z and active paid/trial state
unchanged. Expired period deletion is an explicit separate destructive scope.

Validation includes 42 passing focused Python cases, actionlint, Terraform
format/Message configuration validation, and whitespace checks. These are pure
saved-plan/compiler and workflow/static checks, not live connectivity evidence.
The read-only current maintenance metadata check passed with all controls disabled;
there was no mock-provider connectivity demonstration or live business submission.
Independent review found and corrected incomplete maintenance binding and missing
private umasks before publication. Main-push CI remains unchanged and must be
observed after integration; absent PR checks are not passing checks.
