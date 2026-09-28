# SECUR4ALL-333 Dev qualification

This records a scoped automated Dev test with **synthetic confirmation**, not a
real email reply or general support-service availability. The owner authorized one
disposable account and exact activation plan. No email was sent. No existing user
account or purchase was involved. Main and public website publication are unchanged.

## Integrated source

| Component | Reviewed source | Release integration |
| --- | --- | --- |
| Protected AWS IAM route | `314092e985ad677de6d8959bb9f08eedc4a08841` | Infrastructure PR114, merge `6edfa7cb7f24f391eba059c31029c61015f5d3c3` |
| Optional scoped activation | `abb7be8bba2470ecd95fcb0c92b9b177e612d296` | Infrastructure PR115, merge `17bbf61c3e6e048ede36c5b9bc75b945b099e202` |
| Runtime and human verifier | `476d9ecb54f8ddd9b7299d214df37c025f4c3e0b` | Existing Lambda release integration |
| Operational submit/status CLI | `c46a19176150addfcec80c4015d9cbc8243ec49d` | Lambda PR81, merge `66df8ed159d1130210a0a5760585ae408c18603c` |

Runtime archive SHA256:
`f02d121e0b14237213f8a399114119350bc8976d0740291cc393b5dced5f4e4a`.
Operator tooling changes do not change that deployed runtime artifact. Local
validation passed 62 API Terraform cases, 12 verifier cases, 73 runtime/security
cases and 25 operational CLI cases (the latter also under Python optimized mode).
Focused synthetic helper checks are supplementary, not mailbox evidence.

## Actual scoped Dev operation

Protected transport was qualified while disabled: unsigned and verifier requests
returned403; the operator reached503 `SUPPORT_ADMISSION_DISABLED`; operator signing
and direct Lambda invocation by both restricted roles were denied. The actual
gateway uses AWS IAM and an exact route/account/stage permission. Administrators
remain trusted and can change permissions.

The exact approved activation plan was
`55b2d5a5aef9012d3e9eaf67da7ff6d2ec9e20feffacdfe50beeece3a4295602`.
It admitted only the newly prepared disposable subject. Existing V1/Play cleanup
allowlists were extended only for that subject, with existing entries preserved.
The account used the actual profile writer and a pending-onboarding profile;
confirmation was explicitly injected for this automated test. It had no purchase
or populated consumer history. Broader populated-family pipeline qualification
is the existing SECUR4ALL-200 evidence, not a claim about this minimal fixture.

Exactly one signed operator HTTP POST returned202. The original operation then
progressed through the existing workers and scheduled reconciliation. No second
POST, credential reset, direct identity deletion or fabricated receipt was used.
The actual restricted verifier status function accepted all12 terminal component
receipts and the original completed command, and independently observed the profile
and Cognito identity absent. Status worked after the admission proof expired.

That status probe used the real operational `status()` implementation with an
in-memory adapter for the synthetic harness's genuine attempt records. It made
22 SDK reads, zero HTTP submissions and zero mutations. It did not persist a
fabricated operational CLI intent or claim that CLI `submit` originated the test.
The latter is covered by component tests, including committed response loss and
durable intent/output-write failure without a second submission.

The frozen unrelated-data observer returned `SUPPORT_FIXTURE_UNCONFIRMED` after
terminal completion. The original failure and baseline are preserved; its
assertions were not relaxed. A separately reviewed read-only audit identified the failed assertion as a
whole-row baseline mismatch, with the following limits and results.

## Operational and release limits

The [support runbook](SECUR4ALL-333-SUPPORT-DELETION.md) specifies the approved
five-business-day acknowledgment/start-verification target, separate roles held
by the owner, same-case30-calendar-day cleanup, lost-channel handling and truthful
provider exceptions. It does not promise completion within five business days.

Real mail delivery/reply, selective correspondence/trash cleanup and assembled
release execution remain **NOT RUN** in
[SECUR4ALL-329](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-329). Consumer
policy navigation belongs to ATCR-62; physical-only cases stay separate. Synthetic
confirmation cannot satisfy mailbox ownership verification. SECUR4ALL-92 policy
publication and general operational availability remain separate gates.

Private plans, state, account identifiers, challenge material and signatures are
not published. The local private evidence includes the preserved original attempt,
observer results and exact reviewed plans; sanitized source/tracker notes provide
the durable engineering record.


## Preservation audit and restored baseline

The original13-table baseline held140 retained rows:136 remained byte-for-byte
hash-equal, zero were removed, and four changed rows matched exact current
operational-control schemas: one period sweep, one aggregate sweep and two period
work controls. Their table/inventory/generation bindings were checked against the
original runtime. No changed row was unclassified. There were also three new rows;
they remain explicitly unclassified additions, not claimed anonymous or erased.
The original strict baseline check remains **failed**; the audit establishes
preservation of the other136 existing rows rather than claiming that all140 were
unchanged. Baseline hashes cannot reconstruct those four records' old field values
or prove their exact historical transitions.

The separate audit also validated all12 original-operation receipts, terminal
command and absent recovery control, empty user/device partitions, absent Cognito
identity and unchanged runtime. Reviewed audit SHA256
`432220e9439297a775d0e30eb125deae1c5c32dfef1d4dfa7931ef7dd4d2b4ed`
passed19 focused tests normally and optimized. Its result is a read-only
reconciliation, not a change to the frozen test or a second account deletion.

After completion the four reviewed restoration plans were applied successfully,
in admission-first order:

| Module | Restoration plan SHA256 |
| --- | --- |
| API | `a8139c8fb864b809fb91d37f6ccc9560bbc2495686eec01e4b6daa0c20b24ed1` |
| V1 consumer cleanup | `6c4f8d4c457882d584ce3f25b045eaeb76191e9825c928d93f2fa94caeeb02e1` |
| Play lifecycle cleanup | `d9e6b6cdb01154d5f262c180dc8feaf1b6728f24c6b9f75c1947c69029d158dd` |
| Verifier scope | `23be8b706e6e64872502861619967c02bf3a18f33ee03abff8d45e9fac5b541d` |

Admission again has the exact disabled environment and logs-only execution policy.
The protected route remains. Both cleanup allowlists and the verifier's identity
policy/boundary are restored to their prior scopes. The deployed support artifact
is unchanged. New Lambda versions are configuration changes, not new runtime code.

All four post-restoration Terraform plans returned exit0/no changes. A fresh
revision-pinned gateway qualification also passed: verifier403, operator503 with
`SUPPORT_ADMISSION_DISABLED`, operatorSign denied and direct Lambda invocation
denied for both restricted roles. The non-admission signature verified locally.
No account input or valid deletion capability was used in this final probe.
Its plan SHA256 is
`3d29f28708d6702271661504f0bc415b822c69f4fe7a5483ef7d34fa25c75e23`.
The first final-probe invocation omitted the intended AWS profile and returned
unconfirmed; that result is preserved separately. The explicit-profile run passed.

These results complete the scoped automated Dev qualification and restoration.
They do not activate the general email fallback, qualify actual inbox operations,
publish a policy or promote a release to main.
