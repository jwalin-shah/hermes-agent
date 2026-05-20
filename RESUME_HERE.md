# Resume Here

## Project Summary

Hermes Agent is a Python agent runtime with a large synchronous `AIAgent`
conversation loop, CLI/TUI/gateway frontends, tool orchestration, plugin
surfaces, memory providers, scheduled jobs, and a broad pytest suite. This
checkout is being used for the MID-ARC validation/docs pass: establish a
reliable validation contract before turning architecture findings into
implementation work.

## Current Branch Context

- Branch: `codex/validation-docs-artifact`
- Tracks: `fork/codex/validation-docs-artifact`
- Latest commit before this handoff: `77573e91a chore: package hermes validation smoke work`
- Current artifact package includes:
  - `CODEX_WORKPAD.md` with validation evidence from May 12-13, 2026.
  - `scripts/check.sh`, a smoke validation wrapper that syncs `dev`, `acp`, and
    `mcp` extras, then runs the maintained smoke slice through
    `scripts/run_tests.sh`.
  - `docs/architecture/architecture-findings.json`
  - `docs/architecture/index.html`
  - `docs/architecture/report-2026-05-12.html`
  - `docs/architecture/linear-issue-candidates.md`

## Next 3 Steps

1. Run `scripts/check.sh` from the repo root and record the result in
   `CODEX_WORKPAD.md` if it differs from the existing passing smoke evidence.
2. Convert `docs/architecture/linear-issue-candidates.md` into reviewable issue
   work only after the validation contract is accepted.
3. For the first architecture slice, start with the smallest vertical refactor
   that has clear tests; likely candidates are the Turn Runtime extraction or
   Tool Invocation Pipeline cleanup.

## Blockers

- The full pytest suite is not currently green based on the recorded May 12,
  2026 run: `12607 passed`, `84 skipped`, `1396 failed`, `27 errors`, and
  `10360 warnings`.
- The current validation wrapper is a smoke contract, not full-suite evidence.
- Some failures are environment/dependency related, but there are also real
  behavioral failures that need separate triage.
- Earlier architecture exploration noted that `llm-tldr tree` timed out, so
  targeted `fd`/`rg`/repo-doc reads were used instead.
