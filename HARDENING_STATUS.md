# Security/Subprocess Hardening Status

Branch: `codex/validation-docs-artifact`
Audit date: 2026-05-19

## What is done

- Added a clearer security trust model in `SECURITY.md`.
  - Explicitly states that OS-level isolation is the only real boundary against an adversarial LLM.
  - Separates terminal-backend isolation from whole-process wrapping.
  - Defines external-surface authorization expectations for gateway, HTTP, ACP, and TUI surfaces.
  - Reframes approval gates, redaction, Skills Guard, and similar controls as useful heuristics, not boundaries.

- Added supply-chain and static hardening checks.
  - `.github/workflows/osv-scanner.yml` scans pinned lockfiles through OSV without auto-updating pins.
  - `.github/dependabot.yml` scopes scheduled Dependabot updates to GitHub Actions only.
  - `.github/workflows/lint.yml` adds blocking `ruff check .` for `PLW1514` and a Windows-footgun checker.
  - `pyproject.toml` enables `PLW1514` for source files, while ignoring tests/skills/plugins.
  - `scripts/check-windows-footguns.py` detects Windows portability hazards such as text `open()` without `encoding=`, `os.kill(pid, 0)`, `os.killpg`, bare POSIX-only signals, and shebang script subprocess calls.

- Added subprocess compatibility primitives.
  - `hermes_cli/_subprocess_compat.py` centralizes Windows-specific Node command resolution, hidden-process flags, and detached subprocess kwargs.
  - Gateway launcher paths in `gateway/run.py` and `hermes_cli/gateway.py` use the shared detached-process helper in key watcher/restart paths.
  - Existing changed code uses guarded `preexec_fn=None if _IS_WINDOWS else os.setsid` in several local process paths.

- Hardened code-execution subprocess behavior.
  - `tools/code_execution_tool.py` now supports Windows via loopback TCP RPC instead of assuming Unix-domain sockets only.
  - Child-process env scrubbing keeps secret filtering but passes a small exact-name Windows OS allowlist (`SYSTEMROOT`, `COMSPEC`, `APPDATA`, etc.) needed for Winsock/subprocess startup.
  - Generated `hermes_tools.py` and `script.py` are written as UTF-8.
  - Child Python env forces `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`.
  - Child process cleanup uses psutil-based process-tree termination.

- Hardened local terminal subprocess behavior.
  - `tools/environments/local.py` strips provider/tool/gateway secrets from subprocess env by default.
  - Explicit passthrough and `_HERMES_FORCE_` opt-in paths are preserved.
  - Per-profile HOME isolation is applied to subprocesses.
  - Missing/deleted cwd recovery prevents future terminal calls from wedging.
  - Windows shell discovery prefers a Hermes-managed portable Git Bash before system Git.
  - Windows temp dir uses a controlled Hermes cache path instead of hardcoded `/tmp`.

- Added tool-call loop guardrails.
  - `agent/tool_guardrails.py` tracks repeated exact failures, repeated same-tool failures, and idempotent no-progress loops.
  - Defaults are soft warnings only.
  - Optional hard stops are configurable under `tool_loop_guardrails` in `hermes_cli/config.py`.
  - `run_agent.py` integrates guardrails into sequential and concurrent tool execution paths.

- Hardened packaging/runtime basics.
  - `Dockerfile` pins base helper images by digest, installs `tini`, uses `tini -g` as PID 1, keeps runtime non-root, and avoids leaking runtime data into the build context through `.dockerignore`.
  - `scripts/install.sh` unsets inherited `PYTHONPATH` and `PYTHONHOME` early to avoid module shadowing during install and in the launcher wrapper.
  - `scripts/run_tests.sh` falls back to `uv pip install --python` when `.venv` has no pip, unsets `HERMES_CRON_SESSION`, and can load a developer live-system pytest guard.
  - `scripts/check.sh` establishes a small validation-contract smoke slice.

## What remains

- The branch is extremely large: `2100 files changed, 466271 insertions(+), 27581 deletions(-)`. This audit did not review every changed file.

- Static footgun enforcement is not yet clean for the full diff.
  - `python scripts/check-windows-footguns.py --diff main` finds 95 matches across 1105 scanned files.
  - Most matches are tests/skills, but the checker as written scans them in diff mode while CI `--all` scans source roots. This mismatch needs a policy decision: either narrow `--diff` to the same source roots or fix/suppress the test/skill findings.

- `git diff --check` is not clean.
  - It reports trailing whitespace/new-blank-line issues across many files.
  - It also reports a leftover conflict marker in `tests/tools/test_mcp_oauth_metadata.py:10`; that file should be reviewed before merge even though it is not part of the subprocess hardening core.

- Several subprocess launch sites still need focused review for Windows/process-tree semantics.
  - `gateway/run.py` still has raw `start_new_session=True` fallback paths around restart/background execution.
  - `gateway/shutdown_forensics.py` uses `start_new_session=True`.
  - `tui_gateway/server.py` has `shell=True` call sites.
  - `tools/environments/docker.py` has `subprocess.Popen(..., shell=True)` stop/cleanup paths.
  - `tools/transcription_tools.py` has `shell=True` for string commands.
  - `cli.py` intentionally supports user-defined quick commands with `shell=True`; confirm docs and user-consent boundaries.

- The new Windows-footgun checker has possible false positives.
  - It flags some string/prose lines and tests that intentionally exercise POSIX behavior.
  - It also only scans `.py` files despite comments saying `.md`, `.sh`, `.ps1`, `.yaml`, etc.

- Test isolation needs cleanup.
  - Some runtime tests still touch the real `~/.hermes` unless `HERMES_HOME` is redirected.
  - Zombie-process tests conflict with the live-system guard because they call guarded `os.kill(pid, 0)` and `os.kill(pid, SIGKILL)`.

## Validation run

Passed:

```bash
UV_CACHE_DIR=/private/tmp/hermes-uv-cache scripts/check.sh
```

Result: `26 passed, 4 warnings in 9.18s`.

Passed after redirecting Hermes home into a writable sandbox:

```bash
HERMES_HOME=/private/tmp/hermes-agent-test-home scripts/run_tests.sh \
  tests/run_agent/test_tool_call_guardrail_runtime.py \
  tests/agent/test_tool_guardrails.py \
  -q
```

Result: `20 passed, 2 warnings in 11.00s`.

Failed targeted hardening slice:

```bash
scripts/run_tests.sh \
  tests/tools/test_code_execution_windows_env.py \
  tests/tools/test_local_env_blocklist.py \
  tests/tools/test_local_env_cwd_recovery.py \
  tests/tools/test_local_shell_init.py \
  tests/tools/test_terminal_config_env_sync.py \
  tests/tools/test_zombie_process_cleanup.py \
  tests/agent/test_tool_guardrails.py \
  tests/run_agent/test_tool_call_guardrail_runtime.py \
  tests/test_install_sh_pythonpath_sanitization.py \
  tests/tools/test_tirith_security.py \
  -q
```

Result: `157 passed, 3 skipped, 9 failed, 11 warnings in 26.16s`.

Failure classes:

- `tests/run_agent/test_tool_call_guardrail_runtime.py`: 7 failures from `PermissionError: Operation not permitted: '/Users/jwalinshah/.hermes/logs/agent.log'`. These passed when rerun with `HERMES_HOME=/private/tmp/hermes-agent-test-home`.
- `tests/tools/test_zombie_process_cleanup.py`: 2 failures from `tests/conftest.py` live-system guard blocking `os.kill(pid, 0)` and `os.kill(pid, SIGKILL)` on spawned sleep processes.
- Warnings in `tests/tools/test_local_env_blocklist.py`: background drain threads hit `TypeError: fileno() returned a non-integer` inside `tools/environments/base.py`. Tests still passed, but the warning should be reviewed.

Failed static checks:

```bash
.venv/bin/python scripts/check-windows-footguns.py --diff main
```

Result: failed with 95 Windows-footgun matches across 1105 scanned files.

```bash
git diff --check
```

Result: failed with whitespace findings and a leftover conflict marker in `tests/tools/test_mcp_oauth_metadata.py:10`.

Initial blocked command:

```bash
scripts/check.sh
```

Result: failed because uv tried to use `/Users/jwalinshah/.cache/uv`, which is outside the writable sandbox. Rerun succeeded with `UV_CACHE_DIR=/private/tmp/hermes-uv-cache`.

## Files still needing review

High priority:

- `gateway/run.py`
- `gateway/shutdown_forensics.py`
- `gateway/status.py`
- `gateway/platforms/whatsapp.py`
- `hermes_cli/_subprocess_compat.py`
- `hermes_cli/gateway.py`
- `hermes_cli/gateway_windows.py`
- `hermes_cli/web_server.py`
- `tui_gateway/server.py`
- `tools/code_execution_tool.py`
- `tools/environments/base.py`
- `tools/environments/local.py`
- `tools/environments/docker.py`
- `tools/environments/ssh.py`
- `tools/process_registry.py`
- `tools/terminal_tool.py`
- `tools/transcription_tools.py`
- `tools/tts_tool.py`

Security and policy:

- `SECURITY.md`
- `agent/tool_guardrails.py`
- `run_agent.py`
- `hermes_cli/config.py`
- `tools/tirith_security.py`
- `tools/skills_guard.py`
- `tools/mcp_tool.py`
- `tools/env_passthrough.py`
- `tools/approval.py`

CI, packaging, install, validation:

- `.github/workflows/lint.yml`
- `.github/workflows/osv-scanner.yml`
- `.github/dependabot.yml`
- `Dockerfile`
- `.dockerignore`
- `pyproject.toml`
- `scripts/check-windows-footguns.py`
- `scripts/check.sh`
- `scripts/run_tests.sh`
- `scripts/install.sh`
- `scripts/install.ps1`

Tests to re-review or fix:

- `tests/run_agent/test_tool_call_guardrail_runtime.py`
- `tests/agent/test_tool_guardrails.py`
- `tests/tools/test_code_execution_windows_env.py`
- `tests/tools/test_local_env_blocklist.py`
- `tests/tools/test_local_env_cwd_recovery.py`
- `tests/tools/test_local_shell_init.py`
- `tests/tools/test_process_registry.py`
- `tests/tools/test_terminal_config_env_sync.py`
- `tests/tools/test_tirith_security.py`
- `tests/tools/test_windows_native_support.py`
- `tests/tools/test_zombie_process_cleanup.py`
- `tests/test_install_sh_pythonpath_sanitization.py`
- `tests/test_live_system_guard_self_test.py`
- `tests/tools/test_mcp_oauth_metadata.py`
