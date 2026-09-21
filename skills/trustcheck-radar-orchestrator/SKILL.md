---
name: trustcheck-radar-orchestrator
description: "Coordinate AMT TrustCheck Radar work across Android, Lambda, iOS and infrastructure: assess YouTrack dependencies, delegate implementation to repository owners, and verify release integration and story completion. Use for TrustCheck Radar sprint, story, cross-repository or release orchestration; not unrelated projects."
---

# TrustCheck Radar Orchestrator

Coordinate the user's authorized work across repositories without treating planning,
implementation, deployment and product qualification as interchangeable outcomes.

## Sources of truth

- Read current user direction, the target story and linked acceptance criteria,
  applicable repository `AGENTS.md`, and current release code before choosing work.
  Preserve historical evidence; a stale planning paragraph does not establish
  current implementation or supersede a newer approved contract.
- User instructions take precedence over this skill. Repository `AGENTS.md` files
  govern work inside their repositories; this skill coordinates across them. Raise
  a real conflict instead of silently weakening an acceptance criterion.
- YouTrack is the source for current story state, dependencies and sprint ordering.
  GitHub and local Git evidence establish publication and integration. Deployed
  state needs separate environment evidence. Fetch the relevant live state rather
  than preserving commit IDs, sprint counts or readiness claims in this skill.
- Maintain this skill's source in the infrastructure repository at
  `skills/trustcheck-radar-orchestrator/`. Install the matching copy under the
  active Codex skills directory. It is shared across the project repositories,
  not an Android or Lambda implementation artifact.

## Ownership and scope

| Work | Owner |
| --- | --- |
| Story selection, dependency reconciliation, YouTrack evidence and infrastructure | Orchestrator |
| Lambda application code, API validation, canonical backend contracts and backend fixtures | Lambda agent |
| Native Android behavior, storage, accessibility and Android validation | Android agent |
| Native iOS behavior, storage, accessibility and iOS validation | iOS agent |

When implementation is authorized, delegate concrete repository work to its owner;
reuse existing agents where possible. Each assignment should name the story,
acceptance boundary, dependencies, branch target and evidence expected back. The
orchestrator performs useful infrastructure/review work alongside independent
agent work. Do not create user-visible tasks merely to delegate internal subtasks.
Keep the configured model settings unless the user requests a change.

Android is the current first delivery platform. Coordinate shared contract changes
with both mobile projects where relevant, but do not implement an iOS feature merely
because its Android counterpart started. Keep affected iOS dependencies visible.
For a status or next-story question, inspect and recommend; do not turn that question
alone into implementation authorization. Brainstorming stays planning until the user
asks to implement.

## Starting a story

Identify what already works, what is missing, and which dependency is genuinely
blocking the next acceptance criterion. Verify whether a prerequisite has usable
contract evidence even when its broader story remains open. Do not mark the whole
prerequisite Done to unblock a smaller dependent increment.

For shared API work, reconcile the current version, entity vocabulary, size units,
Unicode behavior, errors and fixtures before dependent mobile changes. Preserve
already-dispatched request identity; an input contract or migration must not silently
rewrite a retry. Distinguish legacy and current endpoints instead of applying one
limit or privacy rule to both by assumption. Put canonical contract artifacts with
the Lambda owner and integration/deployment evidence with the relevant owners.

Discover repository paths from current project or Git configuration, verify remotes
and inspect dirty state. Preserve unrelated work. Use an isolated checkout when
needed. Read Keychain credentials through the established narrow integration path;
never place credential values in this skill, source, tracker comments or tool output.
If a secret reference cannot be resolved, ask for its item name rather than its value.

Update the existing story with actual start/dependency findings. Create a linked
story only for a concrete missing scope; avoid duplicate planning or completion
stories. Keep explicit user approvals linked to the behavior they authorize.

## Release and completion

Read each repository's current `AGENTS.md` for the detailed rules. The established
V1 integration branch is `release-V01`: start `codex/` branches from its latest remote
head and target it for development PRs. Promotion to `main` requires the user's
release instruction. Automatic GitHub CI runs on `main` pushes; feature/release
work uses appropriate local validation and must not trigger or dispatch CI.

Review each agent's final changes and evidence against the story. Distinguish
synthetic fixtures, local unit/build/lint checks, emulators, live Dev, store sandbox,
human review and physical-device tests. Existing ATCR-148 tracks the user-approved
end-of-V1 physical testing; do not use it as blanket permission to defer other
acceptance or claim device tests passed.

A story is Done only when its agreed acceptance is satisfied, necessary local
validation passes, changes are committed and pushed, and integration into the
intended release branch is verified. Check both local-only commits and remote
heads. Attach created PRs, record source/merge commits and limitations in YouTrack,
and read back the resulting tracker state. A pushed feature branch alone is not
complete. Preserve any unmet broader acceptance in its existing story; do not
silently redefine Done to match the code delivered.

## Deployment and evaluation boundaries

Carry forward authorization already given for the specific action and environment;
do not repeatedly request it. A release merge does not itself authorize deployment,
an AWS permission expansion, production activation, a new provider credential or
a paid experiment. Prepare the concrete change and complete independent work before
requesting any genuinely missing approval.

For manual AWS work, identify the intended account/environment, inspect the scoped
plan and preserve rollback and post-deployment checks. Do not substitute GitHub
deployment for the user's manual-deployment request. Alert destinations use
`support@andmorethings.com` where alerts are within the authorized scope.

For model evaluation, consult the current infrastructure runbook and Lambda tool
contract. Tool implementation, provider access, paid run authorization and production
model qualification are separate evidence. Synthetic engineering examples are not
independently reviewed quality data; `store:false` is not a zero-retention claim.
Use current price/access evidence and the reviewed ledger; unknown usage is not zero
cost or a retry credit. Do not copy changing experiment limits into this skill.

## Handoff

Report the delivered behavior, validation, publication/integration status and any
remaining gate. Identify the next ready story and why it follows. Keep credentials,
live account identifiers, customer data and mutable status out of reusable guidance.
Update this skill only for a durable workflow change approved by the user; update
stories and repository evidence for ordinary progress.
