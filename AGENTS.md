# AGENTS.md

Rules for AI agents working in this repository.

## Skills

- Never mention MCP tool names (for example `task_schema` or `validate_flow`) in a `SKILL.md` or any other skill file. Describe the action instead ("fetch the schema of each type", "validate the whole flow"). Tool names change, and agents discover the tools themselves.
- Mentioning the MCP server itself (its URL) is fine.

## Pull requests

- The agent that opens a PR for a new issue must run a QA before asking for review, and post the report as a PR comment.
- Test the PR on every compatible harness (Claude Code, Cursor, Codex, and any other tool the repo supports), each from a real install of the branch, not only from a local `--plugin-dir` or `--mcp-config` shortcut.
- The report lists, per harness: version, install result, skill loading, and a runtime check. State what was not tested. Report failures as they are.

## Releasing

One SemVer for the whole repo, tagged `vX.Y.Z`. Releases are automatic: on every push to `main`, `.github/workflows/auto-tag.yml` computes the next version from the conventional commit subjects since the last tag (`scripts/next-version.sh`, highest bump wins), tags that commit and publishes a GitHub release. Slack is notified of the release or its failure. Nothing is committed to `main` and the manifests carry no version: the tag is the version.

| commit | bump |
| --- | --- |
| `BREAKING CHANGE:` footer | major |
| `feat:` | minor |
| `fix:` `refactor:` `build:` `chore(deps):` | patch |
| `docs:` `test:` bare `chore:` | none |

These are the types the `main` commit-message ruleset accepts. A bump means: patch for a wording or small skill fix, minor for a new skill or new behavior, major for a skill renamed or removed or a changed install layout.

Put `[skip release]` in the head commit subject to skip a release. Pushing a `v*` tag by hand also runs the release workflow.
