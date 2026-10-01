# V1 optional demographic research contract

- Stories: `ATCR-123`, `SECUR4ALL-164`, `SECUR4ALL-165`, `SECUR4ALL-239`
- Decision owner: Product owner
- Decision date: 2026-09-30
- Status: Approved contract; collection and reporting remain disabled

## Purpose and independence

Demographic research is an optional account feature for internal
consumer-protection research. It may measure campaign prevalence and trends
across one coarse age or geographic dimension to improve warnings and detection.

It is independent of ordinary protection, campaign participation and commercial
intelligence permission. Refusing or withdrawing it cannot change analysis,
subscription status, allowances, price, verdict standards, built-in features or
account access. It never authorizes advertising, sale, an individual risk score,
a victim list, personalized targeting or external/commercial API use.

## Eligibility, fields and collection boundary

The account must be authenticated and have completed the approved 18-or-older
onboarding. The feature is offered after onboarding and is off by default. No
control is preselected.

The only V1 self-reported values are:

- age band: `18_24`, `25_34`, `35_44`, `45_54`, `55_64`, `65_74`, or `75_PLUS`;
- geography: the 50 uppercase two-letter US state codes, `DC`, or
  `OTHER_US_JURISDICTION`;
- `PREFER_NOT_TO_SAY` independently for either field.

`PREFER_NOT_TO_SAY` can be returned to the account owner so the app remembers
the choice, but it contributes no demographic value to research.

V1 must not collect or infer birth date/year, ZIP, county, exact address,
coordinates, gender, sexual orientation, race or ethnicity, income, disability,
technology comfort, or geography from a phone number, IP address or device.
Unknown fields and free text fail closed.

## Consent and authenticated operations

Demographic permission uses its own purpose, notice, policy, consent epoch and
state version. It cannot be embedded in the age-attestation, campaign-consent,
commercial-consent or analysis-feature contracts.

The owner resource supports exact authenticated read and mutation operations:

- enroll with the two closed choices;
- correct the current choices;
- withdraw and omit both choices.

Mutations carry a canonical UUIDv4 operation identifier and expected state
version. The service derives the account from the verified token, checks the
active profile, adult onboarding and deletion fence, and never accepts an owner
identifier in the body. It does not read or change entitlements, usage, Play
state, campaign consent, commercial consent or device authority.

## Correction, withdrawal and deletion

A correction replaces the current profile. It immediately invalidates the old
profile version, blocks future joins with it and removes still-linkable pending
or source contributions that contain the old value within 24 hours. Future joins
use only the new version.

Withdrawal immediately blocks future demographic joins, removes the current
values and removes still-linkable contributions within 24 hours. A value-free
consent audit can remain for the approved duration. Account deletion includes the
same data and suppression rules. A restored copy remains quarantined and cannot
re-enter active use.

Finalized aggregates may remain only when they contain no subject or join key,
still meet the disclosure controls and expire by their original deadline.

## Retention

| Data class | Maximum active retention |
| --- | --- |
| Current demographic profile and consent | 400 days after the latest consent or correction; fresh consent is required after expiry |
| Idempotency/operation receipt | 7 days |
| Value-free consent audit | 400 days |
| Linkable contribution/outbox content | Existing research limit, no more than 72 hours |
| Transient processing and cleanup references | Existing research limits, no more than 21 days and the applicable 24-hour cleanup deadline |
| Content-free Dev logs | 14 days |
| Finalized unlinkable aggregate | 400 days from its original lifecycle start |

The current users table has a 35-day point-in-time recovery window. Logically
deleted or withdrawn values can remain in recovery history for up to that window.
They must stay suppressed from active processing and be re-deleted after any
reviewed restore. TTL is cleanup support, not proof of deadline erasure.

## Demographic reporting controls

Phase A implements only the independent owner profile, consent, export, deletion,
inventory and tests. It does not enrich campaign records or create demographic
reports.

Any later V1 reporting is restricted to operator-only, precomputed, immutable
calendar-month snapshots. A report describes only opted-in adult accounts with
the relevant self-reported value and an eligible observation in that month; it
must not be extrapolated to all users, victims or a state population.

- A released denominator requires at least 100 eligible opted-in accounts.
- A campaign/category cell requires at least 20 distinct contributing accounts.
- One account counts at most once per campaign/category per calendar month.
- A view may use campaign/category by age **or** by geography, never both.
- No multi-demographic cross-tabs, interactive filters, arbitrary or overlapping
  date windows, differencing queries, drill-down, small-cell pagination or export.
- Counts round to the nearest five and percentages to whole percentage points.
- Zero, exact and failing cells return only `insufficient_data`.
- Complementary suppression prevents totals from revealing a hidden cell.
- Only predefined wider age bands or Census-region rollups may be attempted;
  otherwise the result stays suppressed.
- Identical requests return the same immutable snapshot. Access is audited and
  rate-limited. Threshold or dimension changes require a new versioned privacy
  review.

The general campaign threshold of ten distinct contributors does not lower these
stricter demographic thresholds.

## Component phases and activation

1. **Phase A:** independent demographic owner profile, export, deletion,
   restored-copy suppression and automated tests.
2. **Phase B:** campaign enrichment only after the server owns the join,
   withdrawal cleanup is qualified and the reporting controls above are enforced.
3. **Phase C:** commercial use only after separate commercial-use permission and
   the approved commercial intelligence rules.

Android, Lambda and infrastructure gates default closed. When closed, the app
must not show the feature, construct demographic fields, read a token, persist a
draft or send a request; the service must not expose an admission route or accept
new values. Read/withdraw and enroll/correct capabilities remain separately
controllable.

The public privacy policy currently says these fields are not collected. It must
be versioned and published before collection is enabled. Source integration,
disabled deployment, scoped Dev activation, public-policy publication and release
approval are separate states.
