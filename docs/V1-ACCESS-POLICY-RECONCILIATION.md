# V1 access policy reconciliation

Tracking: [SEC76](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-76),
[SEC230](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-230),
[SEC242](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-242).

This record reconciles the owner's existing decisions for Android-first V1.
It proposes no new price, allowance, retention period, endpoint or activation.
The historical free/Pro/credit-sales specification in SEC76 is superseded by
the approved individual subscription and capped trial. This record alone does
not complete any story; the acceptance mapping below must be reviewed and its
source, tests and handoff integrated before tracker completion.

## Approved commercial and accounting rules

| Rule | Existing owner decision and boundary |
| --- | --- |
| Individual subscription | $4.99 per monthly subscription period; 200 completed logical checks. These are configurable approved V1 limits, not a demonstrated profitability claim. |
| Family | $9.99 approved for the later family offering; family access is outside individual V1. |
| Trial | Explicit activation starts seven days or ten completed checks, whichever ends first. Reading access or restoring app state does not start/reset a trial. Eligibility records remain until account deletion under the approved policy. |
| Account requirement | All application access requires an account, including built-in checks and post-scam guidance. Adult attestation remains separate from paid access. |
| Complete checks | Only a chargeable, server-completed logical check deducts allowance, at most once. Internal URL resolution, reputation, AI work, retries and reconciliation do not create additional user checks. |
| Partial/failed/inconclusive | No deduction. Processing completion and chargeable completion are different fields; an inconclusive result must not be relabeled complete to charge it. |
| Exhausted/expired/ended trial | Built-in checks and built-in recovery remain available to the authenticated account. AI and external reputation work are denied, including when allowance is exhausted. |
| Complimentary access | Server-controlled grants bypass subscription/allowance requirements only. Account/device eligibility, rate, concurrency and provider budgets still apply. Consent is unchanged. No mobile field or normal user identity can grant this access. |
| Research | Ordinary research and demographic participation are independent optional choices. They neither grant cloud access nor replenish allowance. Commercial-use consent is a further separate choice. |
| Technical retries | Reuse the original logical operation identity; no duplicate settlement or deduction. An ambiguous response is not permission for a new provider call or a fresh operation. |
| Lost completed recovery response | The separately approved recovery policy permits one charge for a server-completed, settled clarification even when its sensitive suggestion cannot be recovered. Partial, failed and inconclusive recovery requests remain uncharged. |
| Existing results | Account/active-device-authorized reads of still-retained governed History consume no new allowance and invoke no provider. Preserve original accounting and distinguish historical evidence from current safety. This is not a reputation refresh. |

Provenance: SEC76's September 20 approved limits; the September 21 restore
decision; [access integration](V1-ACCESS-INTEGRATION.md);
[complimentary operator policy](SECUR4ALL-232-COMPLIMENTARY-ACCESS-RUNBOOK.md);
[recovery completion approval](RECOVERY-COMPLETION-APPROVAL.md); and the
owner-approved [governed History contract and Dev scope](GOVERNED-HISTORY-DEV.md).

## Store periods, restoration and retention

Google Play identities already present in reviewed source are:

| Field | Value |
| --- | --- |
| Canonical package | `com.andmorethings.trustcheckradar` |
| Subscription | `trustcheck_radar_pro_monthly` |
| Monthly base plan | `pro-monthly` |
| Period | `P1M` |

The September 22 bounded catalog check recorded HTTP 200, active monthly base
plan, US availability and $4.99. It supersedes the older disabled-API audit;
see the appended verified-catalog section of
[Google Play setup](GOOGLE-PLAY-VERIFICATION-SETUP.md). This is historical catalog
evidence, not a fresh Console audit or a successful customer purchase.

Paid boundaries must come from freshly verified funded store periods, not a
locally calculated calendar month or lifetime subscription start date. During
Google-confirmed grace or deferral, use remaining checks; do not issue a new
200-check allowance until a newly funded period is verified.

The owner approved restoration to a new account after deletion only with fresh
store verification and prevention of two simultaneous active owners. Previously
used checks follow the same purchase's funded period. The minimal purchase-linked
usage record lasts through the verified access/period end plus seven days for
reconciliation, with no deleted account ID, message or URL; disclosed backups
may retain it for up to 35 additional days. Grace/deferral extends that deadline
only to the newly verified access end plus seven days.

Encrypted Play purchase tokens remain only while the account exists and no later
than the latest verified access end plus seven days. Account deletion removes
them. The no-copy token store and the purchase-usage store have different backup
policies; do not extend token retention using the usage record's backup disclosure.
See [Play lifecycle infrastructure](PLAY-LIFECYCLE-INFRASTRUCTURE.md).

Minimized check/usage receipts and governed History have their original seven-day
deadline. Reopening does not extend it. TTL is asynchronous and is not evidence
of immediate physical erasure. No original or sanitized messages, screenshots,
submitted URLs, operation proofs or free-form model output are added to History.

## Acceptance audit in progress

| Work | Current audit boundary |
| --- | --- |
| SEC76 | Approved Android-first policy above is reconciled. Global Apple product mapping and total AI/AWS margin/provider qualification must not be inferred complete from Google catalog or deterministic tests. |
| SEC230 | The shared-authority source audit is integrated through Lambda PR109/main `c9d95fd8cdc95b6843c5b8b0114fc7b53186d872`; main CI37176124102 passed. The earlier controlled Dev checks and current candidate.3 rules-only message/History checks remain scoped evidence. No new accounting defect was found. Live multi-service fanout and provider/store economics are not established by those no-link checks; SEC230 stays open for its retained criteria and SEC334 carries later release qualification. SEC242 separately protects the retired endpoint against unsafe deployment inputs. |
| SEC242 | Current-source mocked tests passed 78 URL/access, 16 message-consumer and 5 private-assessment cases. The initial assessment attempt lacked its locked provider cache; after backend-free provider initialization, the actual test suite passed. A fresh five-function Dev configuration readback invoked no runtime, read no secrets/account data and changed nothing. The source review found a genuine retired-analysis promotion/IAM gap. The reviewed correction, its automated acceptance and exact Dev deployment procedure are documented in [the SEC242 retirement runbook](SECUR4ALL-242-ANALYSIS-RETIREMENT.md). Source tests do not establish that correction is applied; SEC242 stays open until the exact Dev plan, deployment and post-apply acceptance pass. |
| SEC190 | Broader cross-client contract work remains separate. Required versioned access/message/URL slices must be identified explicitly; an Android slice does not establish complete iOS adoption. |

The owner chose **no rollback** after SEC340: keep its existing dedicated-account,
rules-only Dev message/History scope and private subject selection. This is not
general customer access, provider qualification or an authorization to enable
another capability. The URL consumer remains closed in the fresh readback;
message AI is false and its provider circuit is open. Complimentary operator
activation is an independent SEC232 boundary and is not described as a mobile
grant or new activation here.

## Release qualification and outstanding product/provider work

Reuse [SEC334](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-334) for the
assembled accounting release/UAT matrix, with Android ATCR-112/114 and ATCR-62/108
for their existing store/access/History cases. Physical-only work remains ATCR-148.
Those tests are open and must not be reported as passed from this reconciliation.
The exact tested source, artifacts, gates, environment, positive/negative cases,
expected charge counts and privacy-safe evidence must accompany execution.

Apple product mapping and backend Apple verification remain in the existing
Apple work; do not invent identifiers or activate that writer. Actual store
purchase/lifecycle tests remain provider qualification. Google catalog readback
does not prove purchase, acknowledgment, renewal or notification behavior.

The approved 200-check allowance does not establish overall AI/AWS/store margin.
Existing first-experiment and model-evaluation records have their own budget and
activation prerequisites. Do not treat an experiment token ceiling, Google-only
cost scenario or mock provider as a production cost/quality qualification.
VirusTotal remains disabled pending an appropriate commercial quote.

Any remaining product choice will be presented as a concrete reviewed proposal.
Until its required decisions/evidence pass, SEC76's broader scope remains open.
Implementation stories are assessed against their own retained Dev criteria and
the exact contract slice they require, with genuine unresolved dependencies named.
