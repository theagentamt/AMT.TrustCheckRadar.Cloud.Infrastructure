# ATCR-94 connected Android export: Dev qualification

The corrected connected emulator run passed on September 27, 2026. It exercised
real Amplify SRP sign-in, the existing Settings device-registration confirmation,
the actual protected Dev exporter, CreateDocument Cancel/Save, saved-file validation
and local export denial after sign-out. This increment does not complete ATCR-94's
remaining deletion, History and badge-control acceptance.

Android [PR43](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/43)
is integrated into `release-V01`: reviewed source
`79b77b959384f5747595f01d5752b528765016b9`, release merge
`2bface784363927a861feaee3e786afc82644805`.

## Observed result and source boundary

The single passing native case took 76.079 seconds. It made one registration and
42 export requests, with zero explicit retries. The saved document contained 21
pages covering all 20 declared families; three pages were nonempty. Both downloads
completed: the first picker was cancelled, and the second saved artifact was read
and validated in test memory. A post-sign-out export was rejected locally without
another HTTP request. Success was emitted only after input, document and session
cleanup; the dedicated emulator was subsequently removed.

See [the counts-only native report](evidence/android-connected-export-dev-2026-09-27/connected-native-success.json).
The fresh account had no subscription, trial or engineering grant. No purchase,
analysis-provider, Google reputation or VirusTotal request was made. Empty families
are not live evidence of populated Play/History/campaign projections. Login-form
interaction, native signup confirmation, second-account replacement, process death,
Spanish connected execution and spoken TalkBack remain outside this case.

The immutable contract is candidate.3, producer
`39cce61623794a123e61d25f5248b0c081eccf4a`. Installed exporter source remains
`a25e81f3ef919e65d2ec2fb702637b287e9c79d8`; campaign cleanup source remains
`9effc4f0a38d7d3191b687cb07c9dbda561d69f4`. No new Lambda artifact or runtime-role permissions
were introduced. The Android change adds an explicitly opted-in Dev native runner,
a protected fixture-transfer helper, and recoverable handling of actual HTTP 429
responses. The normal controller still requires explicit Retry; its same-cursor
regression passed, but this live run did not encounter throttling.

## Infrastructure and fixture controls

Root prepared a fresh synthetic identity using the reviewed profile producer and
actual age-attestation API. The app generated its own SecureRandom installation
fingerprint in app-private no-backup storage and registered it itself. This path is
not the separate Keystore identity provider. Authentication used the actual native
SDK; no JWT was injected into the test.

Private Terraform overlays admitted exactly one disposable export subject and
preserved original cleanup subjects when adding that fixture. Export used the
existing package, tables and initialized keyrings, exact JWT issuer/audience/scope,
route-scoped invoke permission, two requests per second and burst four. No general
access, UAT or Production setting changed. All ordinary Android service gates stayed
closed; only the reviewed test composition injected the two real transports.

Credentials were transferred once through stdin from an exclusive owner-readable
host file into the selected emulator's private no-backup directory. The host file
was removed after byte verification; the app consumed the input before login.
Passwords, tokens, subjects, fingerprints, cursors, exported values and private UI
trees are absent from retained evidence. The saved test document was deleted; this
does not promise that the app can erase users' separately saved exports.

## Failed attempts and reconciliation

The first attempt failed after 3.279 seconds; a faulty shell-cleanup sentinel masked
its original stage. Android executes `executeShellCommand` as a process command,
not a shell expression. The runner now sends only its generated cleanup script to
an explicit shell through stdin and preserves the original fixed failure stage.
Credential-free reconciliation proved no session, identity, binding or test file.
That first account was deleted through its original supported operation; all twelve
valid receipts and profile/device/Cognito absence were verified, then original Dev
settings were restored. Its original failure remains undetermined.

The second fresh fixture authenticated successfully but timed out at registration
entry. Its test clicked Settings while the navigation drawer was closed. A separate
credential-free native regression reproduced the failure and verified the visible
drawer path and Cancel with zero registration calls. Native and strong server reads
confirmed no session, binding, registration or export side effect. A separately
reviewed, exclusively journaled password renewal produced a new one-use handoff for
that same clean fixture. No credential, age request or registration was blindly
replayed. The corrected navigation then passed the connected case described above.

The setup, cleanup and narrowly bounded renewal operator helpers passed 11, 18 and
16 offline tests respectively and independent review. Their exact hashes and plans
are retained in [operator review evidence](evidence/android-connected-export-dev-2026-09-27/operator-helper-review.json).
These were supervised operator helpers; this increment does not deliver an
unattended backend fixture-provisioning system.

## Execution and validation handoff

The durable Android entry point is `ConnectedAccountExportTest#realAuthenticatedSettingsExportCancelAndSave`
with the explicit `connectedExport=true` instrumentation argument. The Android
page `docs/v1/android-account-export-connected-dev.md` documents exact build,
selected-emulator, private-input, instrumentation and whitelisted-report commands.
It is accompanied by `android-account-export-connected-validation.json`. Obtain a
fresh, separately reviewed backend fixture/scope first; consumed inputs and these
completed identities must not be reused without reconciliation and review.

Local Android evidence includes the full required 455-task quality gate, 917 Dev
host tests executed, 844 UAT and 844 Production result records reused by Gradle,
six transfer-helper tests, the credential-free navigation regression, installed APK
hash verification and opt-out skips. Passing, failed, skipped, synthetic and
connected cases remain separately identified in the Android manifest. Temporary
infrastructure plans and exact readbacks were independently reviewed.

Both fixtures completed their original supported deletion operations with twelve
valid receipts and verified profile/device/Cognito absence. Final Terraform
restoration removed the export route and gateway permission, disabled export, and
restored the exact original cleanup scopes. Installed artifacts and keyring version
metadata stayed unchanged. Detailed-exit-code plans returned zero with no changes
for API, URL consumer and Play lifecycle. See the
[final restoration](evidence/android-connected-export-dev-2026-09-27/final-restoration.json)
and [no-drift evidence](evidence/android-connected-export-dev-2026-09-27/final-no-drift.json).

[SECUR4ALL-331](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-331) remains open
for assembled release/UAT qualification using [the release instructions](SECUR4ALL-236-RELEASE-TESTS.md).
Physical-only cases remain [ATCR-148](https://andmorethings.youtrack.cloud/issue/ATCR-148).
This connected Dev pass does not activate ordinary application access or declare
release readiness.
