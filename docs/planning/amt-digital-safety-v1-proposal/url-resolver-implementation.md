# Resolver implementation evidence — 2026-09-20

This records the initial implementation. The subsequent Lambda-agent hardening, changed artifact checksum, operational controls and deployment attempt are recorded in [Dev readiness and deployment attempt](url-resolver-dev-readiness.md); use that newer handoff for deployment.

Implemented a separate `url_redirect_resolver` in the Lambda repository and an independent `terraform/url-resolver` stack here. Existing `src/web_risk_communication` and `terraform/api` are unchanged. No AWS apply, remote-state read, artifact upload, Google call, mobile integration or YouTrack mutation was performed.

## Delivered

- Private synchronous input/output contract, bounded DNS and pinned IPv4 connections, TLS hostname verification, controlled standard HTTP redirects, sensitive-link heuristic blocking and explicit partial/blocked outcomes.
- HTTP connection warnings retained independently of reputation; no risk score is produced.
- Limits: five redirects/six requests, ten-second application deadline, 16 KiB header reads, no page execution or content analysis, no credential/cookie forwarding or retries.
- Dedicated filtered VPC, private Lambda subnet, one NAT gateway, minimal role with explicit secret/data denies, selected caller grants to the published alias, immutable artifact inputs, logs and alarms.
- Disabled dev/uat/prod configuration, separate-state helper routing, CI validation, packaging and publication registry entries, and deployment/consumer contract documentation.

## Local verification

- Lambda full suite: **405 passed; 208 subtests passed**. Includes **63 resolver tests** covering parsing, redirects, sensitive links, private and mixed DNS, rebinding between hops, pinned connection/TLS identity, DNS timeouts, loops, size/time limits, header ambiguity, transport warnings and log privacy.
- Terraform `validate`: passed.
- Terraform mocked-provider tests: **5 passed**, including disabled/no-cost state, immutable-artifact requirement, wildcard caller rejection, network/IAM boundaries and bounded runtime.
- Infrastructure helper/script suite: **28 passed**, including isolated state routing for the new stack.
- Changed shell scripts: ShellCheck passed. Terraform formatting and tracked diff whitespace checks passed.
- ARM64/Python 3.13 ZIP built with dnspython 2.8.0. Packaged handler/dependency smoke test rejected a metadata URL before any network request.
- ZIP SHA256: `370d009343e776ebdbbc35daa0e14baff31f0be4bd8f7a15c9e226288a36f50e`. Artifact currently exists locally under `/tmp/amt-url-resolver-artifacts/url_redirect_resolver.zip`; it has not been published. Rebuild before publishing if source changes.

## Remaining release work

Publish the artifact, select an actual authorized Dev caller, review an enabled Terraform plan and network cost, then deploy and verify IAM/network enforcement against owned fixtures. Local and mocked tests do not prove deployed AWS enforcement. The isolated NAT/public IPv4 topology incurs cost once enabled and is single-AZ.

IPv6-only destinations, nonstandard ports, Unicode hostnames without ASCII/Punycode representation, JavaScript and interactive redirects are unsupported. An HTTP 2xx can be an interstitial page: `http_chain_complete` is explicitly limited to HTTP traversal, never an ultimate-destination or safety guarantee. Sensitive-link heuristics cannot guarantee side-effect-free inspection. Consumer privacy wording and the remaining permitted URL representation policy must be approved before consumer release.

Notifications require real alarm destinations; none are configured by default. Per-user access/allowance/idempotency and Google Lookup remain in the later analyzer integration. Reconcile existing tracker items and dependencies before marking any story done.

See [infrastructure contract](../../../terraform/url-resolver/README.md) and the Lambda repository's `docs/url-redirect-resolver.md` for usage and deployment inputs.
