# Repository working rules

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
