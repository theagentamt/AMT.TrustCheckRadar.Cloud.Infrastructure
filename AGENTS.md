# Repository working rules

## Testing and independent component delivery

- Owner direction applies to all current and future stories across infrastructure,
  Lambda, Android and iOS: use automated tests, emulators and simulators now.
  Do not request, wait for, discover, install on or test physical devices until
  the owner explicitly resumes physical testing.
- Put physical-device-only acceptance in a linked, open follow-up. Reuse Android
  ATCR-148 for the V1 physical-device pass; use the corresponding project follow-up
  for other platforms. Record the deferred cases and the owner's scope decision.
  Emulated or mocked results must never be reported as physical-device or actual
  store-provider transaction evidence.
- A blocked mobile story does not automatically block infrastructure or Lambda.
  Continue each component's implementation, contract tests, backend integration,
  deployment qualification and other authorized work independently where possible.
  A genuine blocker must identify the missing contract, artifact, service or
  decision, its owner, and the specific work it prevents. Continue unaffected work.
- Evaluate completion per component's agreed scope. Once its acceptance checks
  pass and commits/handoff records are pushed and integrated into release-V01,
  the component story may close with explicitly deferred physical testing linked
  to its open follow-up. Do not hold it open solely for unavailable mobile hardware.
  Do not close it if its own implementation or non-deferred acceptance is missing.
- Component completion, end-to-end acceptance and release readiness are distinct.
  Keep real integration/release dependencies and unperformed evidence visible;
  this rule does not bypass deployment, activation, privacy or launch approvals.

## Release integration and story completion

- `release-V01` is the integration branch for ongoing V1 work in this repository.
- Start new feature/fix branches from the latest `origin/release-V01`, using the
  `codex/` prefix unless the owner supplies a branch name. Target `release-V01`
  for all development pull requests, including work on existing feature branches.
- Do not push or merge development changes into `main`. Promotion from
  `release-V01` to `main` requires an explicit owner instruction for a release.
  Do not force-push or silently rewrite existing feature history to adopt this rule.
- A development story is complete only when its agreed acceptance criteria are
  satisfied, appropriate validation passes, implementation and required handoff
  records are committed, and those commits are pushed to GitHub and verified on
  the intended remote branch. A local commit or local deployment alone is not Done.
- Update the YouTrack story with validation evidence, commit/branch links and any
  remaining limitations before marking it Done. If pushing is blocked, report the
  blocker and keep the story open until publication is verified.
- Unperformed acceptance tests are not passes. Only an explicit owner-approved
  scope change may defer required acceptance into a linked follow-up; record the
  decision and keep that follow-up open until testing is performed.
- Pushed, merged into `release-V01`, deployed, and released from `main` are distinct
  states. Report them accurately. Preserve existing deployment approvals and
  environment gates; this branch policy does not authorize a deployment.
- Before closing completed development, verify that its final source and handoff
  changes are integrated into `main` or the current release branch. A pushed
  feature branch alone does not satisfy integration. Check local-only commits as
  well as remote heads; recognize verified squash/cherry-pick equivalence without
  reintroducing behavior that newer release changes have superseded.

## CI execution policy

- Automatic GitHub CI runs only on pushes to `main`, including merges into it.
  Do not add pull-request, merge-queue, feature-branch or release-branch CI triggers.
- Development and `release-V01` integration use the appropriate required local
  validation. Record that evidence and verify the GitHub push before completion.
  Remote CI is not a prerequisite for a development or release-branch merge.
- Keep all main CI checks intact. Do not configure those post-merge checks as
  required pre-merge statuses, which would prevent the merge that triggers them.
- Start subsequent work from the latest `origin/release-V01` so it inherits this
  workflow policy. Do not dispatch GitHub checks for feature/release work.
- CI changes do not authorize production promotion or alter deployment approvals,
  workflow inputs, environment protections or manual deployment gates.

## Authorized Dev deployment exception

- On 2026-09-21 the owner authorized manually triggered GitHub Actions for
  infrastructure and Lambda deployment from `release-V01`. This narrow exception
  permits the reviewed Dev deployment/publication/plan workflows; automatic CI
  remains main-only and Android Actions remain excluded.
- Follow `docs/DEV-RELEASE-ACTIONS.md`; publishing packages, planning, applying and
  accepting a runtime migration are separate states. Preserve activation gates.
