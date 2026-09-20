# V1 URL rules and separate resolver proposal

Status: design recorded 2026-09-19; separate Lambda and Terraform implementation added and deployed to Dev on 2026-09-20 after user authorization. Live resolver acceptance passed; notification recipient setup and analyzer integration remain pending. YouTrack remains the authoritative implementation tracker; this change has not updated tracker state. See the [completed deployment report](../../URL-RESOLVER-DEV-DEPLOYMENT-2026-09-20.md).

## Delivery order

The user requests a separate short-link resolver Lambda implemented and qualified before modifying the existing URL analyzer. Build the resolver and its infrastructure independently; integrate the analyzer only after the resolver contract and security tests pass. The resolver must not require the Google Web Risk key.

Source inspection: the Lambda repository's `src/web_risk_communication/validation.py` performs basic parsing, hostname and length checks, but does not provide complete SSRF protection or redirect expansion. Its scheme handling is not an HTTP/HTTPS allowlist and its path/query normalization can change URL meaning. `config.py` still selects Evaluate by default. The infrastructure repository already defines the existing analyzer, secret container, cache, and authenticated route. These observations concern repository source, not verified live AWS state.

## Rules to apply in implementation

| ID | Rule | Responsible component |
|---|---|---|
| URL-01 | Accept supported HTTP/HTTPS URLs only. Reject malformed or ambiguous input, control/header injection, and unsupported schemes. Do not silently repair a URL into a different destination. | API boundary and resolver; analyzer validates resolver output |
| URL-02 | HTTP triggers an unencrypted-connection warning, not an automatic scam/high-risk finding. HTTPS does not establish trustworthiness. Preserve HTTP exposure in the chain, including HTTP-to-HTTPS and HTTPS-to-HTTP transitions. | Resolver supplies facts; analyzer and mobile present policy |
| URL-03 | Before every outbound connection, validate the destination and resolved addresses. Block non-public destinations, including private, loopback, link-local, metadata and unsupported IPv4/IPv6 representations. Bind the connection to the validated address while preserving correct hostname/TLS verification. | Resolver and infrastructure |
| URL-04 | Disable automatic redirects. Explicitly parse and validate each Location, including relative references; never blindly visit URLs embedded in query parameters. | Resolver |
| URL-05 | Caller input cannot select arbitrary methods, headers, cookies, proxies, credentials or TLS settings. Do not forward credentials or provider secrets to inspected destinations. | Resolver |
| URL-06 | Bound network requests, redirects, DNS/connect/read time, overall elapsed time, header size and response bytes. Stop loops and oversized responses predictably. | Resolver and infrastructure |
| URL-07 | Do not execute JavaScript, render pages, submit forms, download files for analysis or treat fetched text as instructions. Unsupported navigation cannot imply a safe result. | Resolver |
| URL-08 | Keep risk and assessment completeness separate. A provider outage or incomplete expansion cannot become a low-risk verdict. Previously obtained threat evidence remains valid when later work fails. | Analyzer |
| URL-09 | Use Google Lookup through a dedicated adapter: match, no match and unavailable are distinct. A recognized threat match supports high risk; no match is not a safety guarantee. Replace the existing Evaluate-specific interpretation and cache semantics during the later analyzer change. | Analyzer, later delivery |
| URL-10 | One consumer check can make several internal calls without separate deductions. Authentication, entitlement, allowance and idempotency are enforced by the caller before paid service work; infrastructure security limits still apply to complimentary accounts. | Assessment coordinator; resolver is not directly consumer-accessible |
| URL-11 | Do not log raw URLs, Location values, page bodies, credentials or complete Lambda events. Record bounded outcome codes, counts and timings; handle errors without echoing sensitive input. | All components |

## Proposed resolver boundary

Name: `url_redirect_resolver`, rather than a TinyURL-specific function. Domain coverage remains a discussion choice: recommend public HTTP/HTTPS links using standard redirects, including custom shortener domains. Domain familiarity never bypasses destination validation.

Invoke synchronously through AWS IAM from explicitly authorized backend roles. No public API Gateway route or Lambda Function URL. No Google secret, consumer database, research store or risk-scoring responsibility. Limit the execution role to necessary runtime logging and any reviewed networking permissions. Infrastructure must document egress isolation; an IAM-only invocation boundary does not restrict outbound network access. Do not assume a security group alone can implement all destination exclusions.

Proposed input: schema version, opaque check ID and one URL. The deployment owns hard limits; callers cannot raise them. Do not accept user-supplied AWS identities or subscription claims as authorization.

Proposed output: schema version, check ID, resolution status, ordered observed hops, last observed URL, whether a supported HTTP terminal response was reached, transport warnings and reason codes. URLs in this private response are sensitive transient data, not approved logs or research contributions. Do not return arbitrary page content or response headers.

Suggested resolution statuses: `http_chain_complete`, `partial`, `blocked`, `invalid_input`. A nonredirect response only completes the supported HTTP protocol traversal; it does not establish that a preview page, JavaScript redirect or browser journey ends there. Never label that fact simply `safe` or promise an ultimate destination. A blocked internal destination is a resolver policy outcome, not proof the submitting person is malicious.

Proposed initial limits, to validate with controlled fixtures: five redirects, six outbound requests, ten seconds overall, and standard ports 80/443 only. DNS, connection and response-header deadlines must fit inside that total. Exact header/byte ceilings and infrastructure timeout margin must be set before implementation acceptance. No automatic application or SDK retry that silently multiplies visits. Use a fixed GET with streamed handling and stop after bounded headers for V1; this avoids HEAD/GET disagreement and fetching page bodies. Test that the selected client actually enforces these limits.

## Privacy and interaction limitations

Resolving a link contacts another service. Even a GET can register a click, notify a sender or consume an action token. No method or hostname heuristic can guarantee that a URL has no side effects. Never describe this as invisible scanning. Known sensitive/action-link forms should stop under an explicit policy; the permitted path/query representation and treatment of reset, login, signed and unsubscribe links remain contract decisions. Do not strip query parameters and then report the modified address as an assessment of the original.

Before consumer release, approve a brief EN/ES explanation of automated link inspection and the privacy policy for sensitive links. Standalone development should use controlled fixtures and deliberately selected public test links, not customer links.

## Acceptance and dependency sequence

1. Finalize resolver schema, domain scope, request limits, sensitive-link policy and egress design. Reconcile the existing resolver story SECUR4ALL-112 against shared contracts SECUR4ALL-103/104/105/110; avoid a duplicate implementation story.
2. Implement the separate Lambda and infrastructure. Supply an IAM-restricted development invocation path so the current analyzer need not change for testing.
3. Qualify with controlled tests: legitimate and relative redirects; nested shorteners; mixed IPv4/IPv6 DNS; public-to-private redirect; DNS rebinding; userinfo and encoded host ambiguity; CRLF; TLS failure; loops; slow/oversized headers; budget exhaustion; preview pages; and attempted credential forwarding. Verify no forbidden destination is contacted, no raw input leaks to logs, and every failure has the expected status. Confirm IAM rejects unauthorized invocation and role permissions exclude provider secrets and consumer data.
4. Only then modify the analyzer for Lookup and resolver orchestration. In that integration, check the original URL before expansion and retain/check the observed chain. A full-chain resolver does not pause for Google at each intermediate hop; if prechecking every hop is required, use a single-hop/continuation contract instead and agree it before implementation.
5. Reconcile infrastructure readiness with SECUR4ALL-242 and analyzer work SECUR4ALL-233; connect Android ATCR-124/125 and iOS consumers to the shared contract and release gates. These are proposed follow-ups, not tracker edits completed here.

## References

- [OWASP SSRF prevention guidance](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html): validate destinations and use application plus network defenses; disable automatic redirects.
- [Google connection-security guidance](https://support.google.com/chrome/answer/95617): insecure connection warnings differ from known dangerous-site warnings.
- [Google Web Risk Lookup contract](https://docs.cloud.google.com/web-risk/docs/reference/rest/v1/uris/search): later analyzer integration.
