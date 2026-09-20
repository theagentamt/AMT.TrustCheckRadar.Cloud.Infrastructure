# Private Dev URL assessment

This independent stack runs the IAM-only `url_assessment` Lambda on Python 3.14 (ARM64), using Google Web Risk Lookup and the existing private redirect resolver. It does not expose a consumer API, implement subscription/allowance authority or replace the old `/web-risk-communication` route. The owner explicitly requested leaving that legacy Dev Lambda running.

## Boundaries

- Separate state key `trustcheckradar/dev/url-assessment.tfstate`. Only Dev can be enabled; UAT/Prod defaults remain disabled.
- Exact existing Web Risk secret ARN; Terraform creates no secret version and never reads the key. The function reads `AWSCURRENT` at execution. Provider credentials never enter environment values, logs, output, plan or source control.
- Exact `trustcheckradar-dev-url-resolver:live` invocation grant. No unqualified resolver invocation, consumer data-table access, S3 access or role chaining.
- No Function URL, gateway route, public resource policy, event source, or mobile caller grant. The optional test role trusts one named existing administrator role and permits only the assessment `live` alias. Existing administrator permissions are not a statement of universal invocation denial.
- Version-pinned ZIP, 35-second timeout, 256 MiB, concurrency at most two, no asynchronous retries, fourteen-day logs. Calls are intended to be synchronous; AWS asynchronous delivery is not an exactly-once billing mechanism.
- No new VPC/NAT: this coordinator uses AWS APIs and one fixed Google HTTPS endpoint. Arbitrary submitted destination fetching stays in the existing isolated resolver. The coordinator's application validates inputs and bounds provider requests; this is not a network firewall restricting all outbound destinations.
- No cache, result History, research contribution or billing write. The private result is an operator integration result, not the accepted Android consumer wire contract.

## Notifications

Three alarms (errors, throttles, handled dependency failures) use the existing resolver SNS topic and confirmed `support@andmorethings.com` subscription. Each alarms on one event in five minutes and notifies recovery; missing data is non-breaching. The resolver root's `assessment_alarm_notifications_enabled` allows only the three named assessment alarm ARNs in addition to its existing alarms. Apply that narrowly reviewed topic-policy update before enabling the assessment alarms. It does not change resolver runtime/network/caller grants.

The dependency metric consumes only the fixed `private_url_assessment` event and either an `unavailable` status or allowlisted operational `reason` codes; unsafe input and threat verdicts are not infrastructure failures. Provider-attempt counters are operational counts, not charges or logical user checks. [AWS JSON metric-filter syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html) supports the compound condition used here.

## Manual Dev deployment

1. Test/package through the Lambda agent; publish only `url_assessment.zip` to a new immutable release key. Independently verify exact S3 VersionId and SHA256 before filling Dev tfvars.
2. Confirm AWS account `107827791950`, region `us-east-1`, current secret version metadata, resolver alias and existing confirmed SNS subscription. Never retrieve credentials through operator output.
3. Set only Dev `enabled`, artifact tuple, exact secret/resolver/topic references and named operator test principal. Keep other environments disabled.
4. Initialize this root with `scripts/terraform.sh init dev url-assessment`, create a saved plan and review every managed-resource action. Apply only that plan. Never use a broad API/foundation apply to deploy this service.
5. Assume the dedicated test role in memory; invoke only the `live` alias with synthetic/owned inputs. Verify no-match, known threat, partial/invalid/private/sensitive inputs, no provider activity for rejected inputs, denied unqualified invocation and URL/key-free diagnostics. Distinguish local fixtures from actual Google observations.
6. Verify no Terraform drift and record artifact/runtime/alias/test evidence. A failed provider authentication test does not mean a link is safe; fix Google configuration before claiming readiness.

Local testing uses a mocked AWS provider (`terraform test`), so its apply commands create no real resources. Local helpers and CI validate both roots. New assessment paths are excluded from broad automatic infrastructure deployment. Manual AWS deployment is the approved Dev path for this work.

Rollback pauses the new function by setting its reserved concurrency to zero or selects a previously reviewed private artifact/version; a live pause must be authorized. Do not restore an ungated consumer endpoint as a rollback shortcut. The legacy endpoint remains governed by the owner's separate keep-running decision.
