# Architecture Issue Candidates - 2026-05-12

Do not implement yet. These are Phase 1 architecture review candidates.

1. Extract a Turn Runtime module from `AIAgent`.
2. Deepen the Tool Invocation Pipeline across `model_tools.py` and `tools/registry.py`.
3. Define a Command Surface Adapter contract for CLI, gateway, and TUI command execution.
4. Split Gateway Session Runtime from platform adapters.
5. Introduce a TUI RPC Session Registry module.

Blockers: pre-existing `.gitignore` modification; `llm-tldr tree` ran too long and was killed, so `fd`, `rg`, and targeted repo-local docs were used as fallback.
