# AGENTS.md

Rules for AI agents working in this repository.

## Skills

- Never mention MCP tool names (for example `task_schema` or `validate_flow`) in a `SKILL.md` or any other skill file. Describe the action instead ("fetch the schema of each type", "validate the whole flow"). Tool names change, and agents discover the tools themselves.
- Mentioning the MCP server itself (its URL) is fine.

## Pull requests

- The agent that opens a PR for a new issue must run a QA before asking for review, and post the report as a PR comment.
- Test the PR on every compatible harness (Claude Code, Cursor, Codex, and any other tool the repo supports), each from a real install of the branch, not only from a local `--plugin-dir` or `--mcp-config` shortcut.
- The report lists, per harness: version, install result, skill loading, and a runtime check. State what was not tested. Report failures as they are.
