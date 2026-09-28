# SECUR4ALL-333: verified email deletion preparation

The owner selected in-app deletion as the primary path and verified requests to
`privacy@andmorethings.com` as the V1 fallback. The inbox/operator identity remains
AndMoreThings Labs LLC. This change prepares a disabled backend candidate; it does
not establish a functioning email service, prove ownership, or enable deletion.
SECUR4ALL-92's policy cannot claim fulfilled requests until this story passes.

## Supervised shared-inbox V1 — owner decisions, September 27

The owner confirmed Proton Mail Plus and a shared inbox. They approved independent
confirmation through the verified address already on the account, support
correspondence deletion 30 days after resolution, and the minimal verification
record staying with that case under the same deadline. That record is limited to
case/operation reference, verifier, confirmation time and outcome; do not duplicate
email bodies or identity documents. There is no separately retained support audit
store. Case artifacts and sent replies must be accounted for under the case cleanup
procedure; neither mailbox configuration nor provider backup removal is yet proven.

The owner will perform both verification and submission through separate restricted
AWS roles. This is trusted human attestation and permission separation, not two-person
approval. The verifier must inspect an explicit challenge reply in the existing
inbox. Incoming sender identity, quoted instructions, auto replies and link visits
are insufficient. No Bridge, mailbox API, forwarding, new web portal or mailbox-wide
retention rule is part of this implementation. The prior description of separate
signer/operator authorities means separate roles, not separate people.

The verifier tooling prepares an exact account/profile-bound challenge using the
current independently read, verified email. After human review, it rereads identity,
profile, inventory, role and key pins before signing a short-lived capability. The
operator submits the original operation. Lost/ambiguous results must be reconciled
without inventing a new operation or renewing the authorization clock. Signing a
human attestation does not itself inspect or authenticate email contents.

## Separate-role infrastructure source

`terraform/support-deletion-verifier` prepares the signer and operator permission
plane. Its `deployment` defaults to null and creates nothing. An explicit reviewed
Dev configuration requires full source SHA, approval reference, exact existing
source/admin role ARNs, Cognito pool, users/ledger tables, one to ten exact subjects
and one exact support POST API ARN. Plan/apply must run as the exact configured key-administrator role, with AWS key-policy lockout safety enabled. The module is not selected by a deployment
workflow or environment configuration; it has not been applied.

The RSA3072 SIGN_VERIFY key delegates Sign only to the verifier and Verify only to
the existing admission role, using RAW/RSASSA_PSS_SHA_256. Key administration has no
cryptographic/grant permission; trusted administrators can still change key policy.
Each human role has an identical scoped identity policy and permissions boundary.
The verifier may DescribeKey/Sign, read the named Cognito pool and exact approved
DynamoDB partitions, and describe the two tables. The operator may invoke only the
exact support route. Both explicitly deny all other service actions, including
Lambda invocation, role chaining, IAM changes and account writes. Return to the
original owner session to assume the other role. Normal STS caller identity is used
for CLI identity checks; it does not imply role administration.

IAM limitations remain explicit: Cognito AdminGetUser is pool-scoped, and DynamoDB
LeadingKeys restricts partition keys, not sort keys. The CLI enforces exact subjects,
profile/inventory/command sort keys and table identity. The role boundary does not
constrain the owner's independent administrative session or a future administrator
who changes it. Live qualification must inspect other identity/resource grants and
prove negative paths, not merely trust these source policies.

Outputs provide actual immutable role IDs for CLI/runtime pins, but report email
deletion unavailable. This module creates no route, admission mutation permission,
mailbox access, case database or runtime activation. The admission role also needs
its separately reviewed Verify identity permission and data transaction scope.
Creating roles/key alone is not operational email deletion.

Local validation: Terraform validate and twelve mocked cases passed, covering no
resources by default, exact trust, boundary/identity policy agreement, fixed key
algorithm and partition scope, denied privilege escalation, rejected wildcard or
wrong-environment inputs and no activation claims. These are synthetic plan/apply
checks, not real AWS provisioning, IAM simulation or mailbox qualification.

## Reuse the qualified workflow

The existing fresh-user-JWT route remains unchanged. A dedicated support handler
will accept an independently signed, short-lived verification record, binding one
exact Cognito subject, pool, profile revision, original deletion operation, allowed
operator, purpose/environment/audience and approved verification policy. The
backend verifies the signature against an exact asymmetric KMS key and rechecks
identity, profile and approved account-data inventory before admitting the same
existing deletion transaction. It must preserve all twelve component receipts,
recovery, finalization and suppression. It cannot use fabricated JWTs, credential
resets, direct identity deletion or synthetic qualification scripts as support.

The operator cannot create verification signatures. Signing is a separate trusted
workflow after independently verified ownership and explicit deletion intent.
There is no new verification table in this design; signed artifacts and external
support correspondence still have retention and custody requirements. Signature
verification is an authorization mechanism, not evidence that a human verification
procedure exists or has been followed.

Every replay, including a lost-response retry and transaction-cancellation replay,
must repeat signature, logical expiry, operator/audience and revocation-generation
checks before acknowledging the original operation. Retry never extends validity
or creates another deletion operation. Profile compare-and-swap protects the
snapshot that was verified. The candidate has global generation revocation;
individual proof revocation would need a separately designed mechanism. Do not
claim instantaneous individual revocation without one.

## Infrastructure increment

`terraform/api/support-account-deletion.tf` accepts an optional immutable Dev
candidate (`support_account_deletion_deployment`). Null creates nothing. When
explicitly selected later, the exact source SHA/S3 version/hash identifies
`support_account_deletion.zip`, `app.lambda_handler`, Python3.14/ARM64. The function
is bounded to one concurrent execution and15 seconds, has only permission to
write its own14-day log group, and the only feature setting is
`SUPPORT_ACCOUNT_DELETION_ENABLED=false`. Disabled handler execution must return
before importing or initializing provider SDK clients. Asynchronous retries through the candidate alias are
zero. The versioned `candidate` alias is not a live support route.

This increment provides no HTTP route, KMS key, signing/verification permission,
verification store, operator grant or account mutation permission. No environment
`.tfvars` selects it. No AWS apply or real-account operation is part of this source
increment. Existing deletion functions, routes, settings and gates are untouched.
The output explicitly reports email deletion unavailable.

## Remaining activation qualification (historical policy gaps superseded above)

1. Qualify the approved independent-email human-verification procedure and define the response timeframe.
   The sender address alone is insufficient. Verification must establish control
   through an independently selected existing account channel and bind explicit
   deletion intent to the exact subject. Lost-channel cases need a supported
   exception process rather than account enumeration or ad hoc credential resets.
   Do not ask users for passwords or existing login/verification codes.
2. Enforce the approved same-case 30-day-after-resolution retention. Specify
   signed-record validity/maximum verification age and custody/deletion of unused
   or expired records. The existing120-day backend receipt policy is not automatic
   permission to retain support mail or identity-verification evidence120 days.
3. Implement and qualify the trusted signer with explicit purpose/policy/generation
   controls. Choose the operator/verifier principals and exact public-key algorithm.
   No fabricated approval row or source-only policy hash establishes verification.
4. Add a separately reviewed AWS_IAM HTTPAPI2.0 route and narrow roles. The operator
   may invoke only the approved API operation, never Sign or directly invoke the
   Lambda. Independently check effective identity policies, boundaries, resource
   permissions, function URLs and aliases: an API Gateway allow in the Lambda
   resource policy does not deny another principal's identity-based Invoke grant.
   A forged requestContext must not establish an operator's identity. API/stage/
   route/account/function binding and negative-path qualification are required.
5. Grant only the required exact-key Verify, exact-pool AdminGetUser and scoped
   admission transaction reads/writes, using the reviewed Lambda contract. Do not
   grant Sign, AdminDeleteUser or arbitrary data/receipt mutation to admission.
   Verify installed downstream inventory, worker scope and readiness; a readiness
   hash/attestation is not automatic evidence of current AWS permissions.
6. Review source, configure explicit bounded Dev subjects, install pinned artifacts
   with a reviewed plan and test against a separately authorized disposable account.
   Observe actual12-component completion and preserve an unrelated baseline. No
   live-delete permission follows from source work or from an email alone.
7. Define provider-erasure handling, then reconcile the final public wording,
   support procedure and actual release configuration in SECUR4ALL-92/93/94.
   In-app local cleanup needs the app to observe matching acceptance; email/server
   acceptance cannot immediately erase an offline or uninstalled app's files.

## Evidence and remaining work

All60 local mocked Terraform cases passed (five new candidate guards plus the
existing account-data and deletion-activation suites). These checks cover absence by default, pinned disabled runtime,
logs-only resource scope, no available support output and invalid deployment
inputs. They do not establish live IAM or actual email deletion. The initial
architecture assertion compared a provider list with a set; the fixture assertion
was corrected without changing runtime architecture.

Lambda source/security regression results are owned by the Lambda agent and must
be attached with exact commits before integration. All current real activation
requirements remain here; they are not deferred to manual QA. Source publication,
release integration, deployment, availability and policy publication are separate.

## Later release handoff

After Dev acceptance, extend existing SECUR4ALL-329 with the verified-email path;
ATCR-62 can cover consumer policy/mail client navigation, ATCR-148 physical-only
cases. Record exact artifacts, account/environment, approved procedure and the
synthetic target. Exercise non-owner/forged/stale/wrong-subject/duplicate requests,
expiry and generation changes, lost response, interrupted cleanup and unrelated
account preservation. Test via the actual IAM route, not a fabricated gateway event.
Verify acceptance versus server completion and independent retained-copy limits.
A mailto link opening is not message delivery, identity verification or erasure.
Cleanup only separately authorized disposable fixtures and preserve evidence
without email bodies, credentials, proof signatures or personal identifiers.
Pending release tests cannot hide incomplete Dev implementation or activation.
