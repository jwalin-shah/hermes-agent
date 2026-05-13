# Hermes Agent Workpad

## Portfolio Readiness Validation - 2026-05-12

Scope: classify the repo's current validation state for the portfolio cleanup
matrix.

Validation attempted:

```bash
python3 -m pytest
```

Result: failed after a large run:

- `12607 passed`
- `84 skipped`
- `1396 failed`
- `27 errors`
- `10360 warnings`

Primary failure classes observed:

- Missing dependencies or incompatible installed package versions:
  - `acp`
  - `fire`
  - `mcp.types.CreateMessageResultWithTools`
  - async pytest plugin support for async tests
- Many async tests are collected without a suitable pytest async plugin.
- Several real assertion failures remain after collection succeeds, including
  gateway/session behavior, Discord allowed-mentions behavior, provider/runtime
  state, and tool safety tests.

Environment follow-up:

```bash
uv run python - <<'PY'
for mod in ['acp','fire','pytest_asyncio','anyio','mcp']:
    ...
PY
```

Result: base uv environment can import `fire` and `anyio`, but not `acp`,
`pytest_asyncio`, or `mcp`.

```bash
uv run python -m pytest tests/acp/test_entry.py tests/cli/test_cli_status_command.py tests/gateway/test_discord_allowed_mentions.py -q
```

Result: failed immediately because the base uv environment does not install
pytest. The repo's validation command must include the relevant extras/groups,
not just bare `python3 -m pytest`.

Disposition:

- Hermes is not ready for presentation based on the current base validation
  command.
- This needs a dedicated validation-contract slice before architecture cleanup:
  define the supported uv command with extras/groups, pin/install the correct
  test dependencies, then separate environment failures from real behavioral
  regressions.

## Validation Contract Repair - 2026-05-13

Findings:

- The repo already documents `scripts/run_tests.sh` as the canonical runner.
- Required extras for the failing sample are `dev`, `acp`, and `mcp`.
- `uv run --extra dev --extra acp --extra mcp python ...` resolves `pytest`,
  `pytest_asyncio`, `mcp`, `acp`, and `fire`.
- `scripts/run_tests.sh` assumed `pip` existed in the active venv. A uv-created
  `.venv` does not necessarily include pip, so the runner failed before pytest.

Changes:

- `scripts/run_tests.sh` now falls back to `uv pip install --python "$PYTHON"`
  when it needs `pytest-split` and the venv has no pip.
- Added `scripts/check.sh` as a small validation-contract wrapper. It syncs the
  `dev`, `acp`, and `mcp` extras and runs a maintained smoke slice through the
  canonical runner.

Validation:

```bash
scripts/run_tests.sh tests/acp/test_entry.py tests/cli/test_cli_status_command.py tests/gateway/test_discord_allowed_mentions.py -q
```

Result: passed, `26 tests`, `30 warnings`.

Remaining:

- Full suite health is still unknown and previously failed broadly. The new
  wrapper is a smoke contract, not a claim that all Hermes tests are green.
