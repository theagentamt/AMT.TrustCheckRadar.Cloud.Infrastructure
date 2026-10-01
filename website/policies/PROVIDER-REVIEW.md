# SEC92 provider evidence — September 28, 2026

Evidence supporting the EN/ES source and release package. No provider settings, service
activation, website publication or store submission changed. Private organization
and project identifiers, credentials and account screenshots are excluded.

The current Lambda-owner source/runtime statement is commit
`4ab6b667cb3b4001d6910a907cd24eef6a163434`, based on `release-V01`
`0d90214ae83c69970a88b001c67951cb0d289fae`. Its 1,088 tests, 80 subtests,
Python 3.14 compilation and documentation validation passed. Publication and
release integration of that commit are tracked separately from this review.

## OpenAI: observed controls and owner attestation

| Evidence | Result | Limit |
| --- | --- | --- |
| Signed-in organization sharing controls | Feedback, evaluation/fine-tuning, API inputs/outputs: all Disabled | Point-in-time inspection; not Google's store definition of sharing |
| Project controls | Standard Retention; Global residency | No Zero Data Retention or exclusive-US-processing representation |
| API call logging | Enabled per call | Separate from training sharing and abuse-monitoring retention |
| Credential/project connection | Owner confirmed AWS key belongs to inspected project | Owner attestation; no secret retrieval or independent key comparison |
| Modern candidate source | Responses endpoint; store:false, background:false, tools empty | Source evidence, not deployed model qualification |

The Lambda owner's September 30 read-only Dev inventory did not find the two modern
evaluator functions, consistent with their inactive candidate scope. Do not use the retired
analyzer's model default as the active modern model. Release qualification must
identify the selected endpoint/model, flags and credential/project connection.
No API calls or configuration mutations were performed for this review.

[Official data controls](https://developers.openai.com/api/docs/guides/your-data)
distinguish training opt-in, abuse monitoring, stored responses and model-specific
caching. Disabling response storage does not remove the other categories. The
existing publication checklist retains the documented abuse-monitoring default;
the inspected Standard Retention setting is not a zero-retention agreement.

## Google Web Risk: Lookup boundary

[Lookup documentation](https://docs.cloud.google.com/web-risk/docs/lookup-api)
describes `uris.search` with an actual URL per request. A no-match response only
means no match in the queried lists. Redirect expansion is our separate network
activity, with its own destination-site disclosure.

[Service-specific terms, Web Risk section 46](https://cloud.google.com/terms/service-terms)
require fresh threat evidence and attribution with a conspicuous accuracy caveat
for applicable warnings. Their additional URL-reuse provision expressly addresses
Evaluate, Submission and Brand Phishing Protection. Do not extend it to Lookup
by assumption, or treat its
scope as proof that Lookup retains nothing. These sources do not establish a
Lookup-specific request-erasure mechanism or retention interval.

The current source fixes `webrisk.googleapis.com` and `GET /v1/uris:search`, with
MALWARE, SOCIAL_ENGINEERING and UNWANTED_SOFTWARE lists. Remaining evidence is the applicable customer agreement/project context and
processor handling for Lookup. No arbitrary number is added to the public draft,
and no support request is sent without the owner's instruction. Store mapping
must assess recipient use separately from the OpenAI dashboard sharing toggles.
Android's warning attribution/advisory coverage is being checked in its own
worksheet; this document does not claim runtime compliance.

## Release and public-copy boundary

The bilingual release package reflects inspected OpenAI settings and owner-confirmed
binding. It does not present an active OpenAI model, Google agreement, Lookup
retention period, zero-retention promise or US-only processing. Exact release
credentials/models/settings must be rechecked before enabling the gated provider
paths. Public byte validation and store-console submission remain distinct work.
Refer to [the checklist](PUBLICATION-CHECKLIST.md) and SEC329/ATCR62/ATCR148 for
the existing manual/release handoffs.
