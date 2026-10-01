# SEC207 period-work identity-policy qualification

The final isolated AWS run passed all **109 recorded cases** across seven assumed
fixture roles and two synthetic DynamoDB tables. [Qualification evidence](qualification.json)
binds the exact rendered plans, audited installed policy sources, fixture union
hashes and reviewed helper versions. Every role's identity was verified through
regional STS; every initial read probe succeeded on its first attempt in this run.
No credential retry was needed in the final successful run.

The export policy remained exactly scoped to its original inventory read. No
permission was broadened to make the test pass. The final lifecycle union also
includes the reviewed aggregate policy's pipeline progress cursor; cases cover
transactional Put, refusal of standalone/extra/foreign operations and atomic CAS
rollback. Intelligence table and ExpirationIndex permissions are bound and
explicitly omitted from this **two-table** runtime exercise. Their authorization
and aggregate runtime behavior require their separate qualification.

## Containment and cleanup

The [ownership journal](ownership-journal.json) records the namespace, seven role
and two table creation attempts, exact policy/input hashes and successful cleanup.
A separate read-only AWS check independently confirmed all seven roles returned
`NoSuchEntity` and both tables returned `ResourceNotFoundException`; see
[independent cleanup](independent-cleanup.json). No KMS keys, SQS queues,
application records, approval markers or deployed role policies were created or
changed by this fixture.

The copied report and journal were inspected: they contain policy metadata,
synthetic resource identities, fixed case names and hashes; no credentials,
application records or raw request/response items required redaction.
[Source and input hashes](source-and-input-hashes.json) preserve the reviewed
validator/executor and their tests. The recorded local suite passed 65 tests;
SDK/Moto cases verify expressions and containment, not AWS IAM behavior.

## Earlier attempts remain failures

[Prior failed-run summaries](prior-failed-runs.json) preserve source report hashes,
recorded case counts and reported cleanup outcomes. They are not acceptance passes:

- A 35-case attempt stopped with a generic fixture error; its service cause was not captured.
- A 0-case attempt stopped at a propagation wrapper that obscured the original error.
- A 17-case diagnostic attempt recorded `UnrecognizedClientException`.
- A 96-case regional attempt recorded `AccessDeniedException` during the export inventory read.

Earlier local setup also exposed macOS `/tmp` directory-symlink handling before
resource creation; the journal parent was subsequently canonicalized while
preserving exclusive/no-follow leaf creation. Later diagnostics preserved only
safe exception metadata. Regional STS identity checks and bounded fixed read
probes improved qualification reliability without retrying failed test cases.
The exact cause of the earlier service refusals is **not established**. The final
unchanged export policy passed; that does not retroactively turn those attempts
into passes or prove a particular propagation explanation.

## Evidence boundary

This exercise tests complete relevant identity-policy intersections remapped to
two fresh tables. Existing broader grants remain included, and the retired
analysis writer's explicit write Deny remains effective. It does not prove live
role/SCP/table-resource-policy authorization, KMS access, scheduler delivery,
full application handlers, complete period erasure, historical copy coverage or
approval to activate production data. Simulated lost acknowledgment occurs after
a successful SDK response; it is not a claim of an uncontrolled network failure.
