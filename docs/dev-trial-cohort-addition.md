# Dev trial cohort addition

The owner's 2026-10-29 selection adds the existing dedicated tester to the
governed trial cohort and removes that tester's redundant GET-only snapshot
selection. It preserves the original member. The exact two-member canonical
SHA256 is `ea905c7184be88586e8a0a5745319bf0fdeef29734b57af80c9c048cd8e353d1`.
Private subject identifiers belong only in the protected plan packet.

This selects who may use the existing trial endpoint. It creates no grant,
consumes no trial/check allowance, changes no trial duration, and leaves normal
eligibility and permanent trial-history checks intact. There is no production
or general-access activation. Existing empty and singleton module modes remain.

The access branch of `prepare_governed_history_configuration.py` accepts this
exact pair and clears `dev_access_snapshot_extra_subjects`. Other History and
Message preparation modes keep their existing limits; the authority key-ring
reader is unchanged and is not used for this operation.

Before preparing the candidate, retain a fresh full normal saved plan with
56 managed no-ops, no managed drift and unchanged outputs. Current state, the
published/live/latest v18 configuration, named tester mapping and immutable
source/input/backend pins must agree. Do not reuse an old transition plan.
Any drift blocks the candidate; do not filter it, disable refresh, target
resources, or persist state to obtain a passing result.

Review the complete candidate with:

```sh
python3 scripts/verify_governed_trial_plan.py PRIVATE_CANDIDATE_JSON \
  --revision FULL_REVIEWED_SHA --mode trial --baseline PRIVATE_BASELINE_JSON
```

The addition verifier binds every resource to that baseline. Only the existing
entitlements function environment, its same-code published-version metadata,
the unweighted live alias bound to that function, and the subject-count output
may change. The two environment differences are the exact cohort addition and
omission of the now-empty snapshot-only key. Artifact inputs, observed code,
auth, IAM, routes, cleanup, maintenance and all other resources stay exact.
Independent review of the immutable source and saved plan precedes apply.

The existing `entitlements18-preservation.json` remains historical evidence;
this change does not repin it or treat a projected version as already deployed.
The preservation input helper distinguishes the approved pair/no-extra profile,
but the runtime preservation guard still requires its exact recorded version.
After any separately reviewed apply, retain and review the new published
version/configuration receipt before selecting a new preservation generation.
Unrecorded version drift continues to fail closed.

Rollback uses the owning IaC path and fresh revision guards to restore the
original one-member/snapshot-only selection. Never erase grant or trial history.
After deployment, a separately scoped access snapshot can verify selection;
this source change and its unit tests do not prove live trial activation or
assembled Android/UAT acceptance. Those remain in the existing release work.
