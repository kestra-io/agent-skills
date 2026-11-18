# AGENTS.md

Rules for AI agents working in this repository.

## Skills

- Never mention MCP tool names (for example `task_schema` or `validate_flow`) in a `SKILL.md` or any other skill file. Describe the action instead ("fetch the schema of each type", "validate the whole flow"). Tool names change, and agents discover the tools themselves.
- Mentioning the MCP server itself (its URL) is fine.
