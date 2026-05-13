#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to create the Hermes validation environment." >&2
  exit 1
fi

uv sync --extra dev --extra acp --extra mcp --quiet

scripts/run_tests.sh \
  tests/acp/test_entry.py \
  tests/cli/test_cli_status_command.py \
  tests/gateway/test_discord_allowed_mentions.py \
  -q
