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

One SemVer for the whole repo, tagged `vX.Y.Z`. The tag must match the `version` in `plugin.json`, `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`.

- patch: wording or doc fix, small skill correction.
- minor: new skill, or new behavior in an existing skill.
- major: skill renamed or removed, or install layout changed.

Releases are automatic. On every push to `main`, `.github/workflows/auto-tag.yml` computes the next version from the conventional commit subjects since the last tag (`scripts/next-version.sh`, highest bump wins), commits the new version into the three manifests, tags that commit and publishes a GitHub release. Slack is notified of the release or its failure.

| commit | bump |
| --- | --- |
| `<type>!:` or `BREAKING CHANGE:` footer | major |
| `feat:` | minor |
| `fix:` `perf:` `build:` `refactor:` `chore(deps):` | patch |
| `docs:` `test:` `ci:` `style:` bare `chore:` | none |

Put `[skip release]` in the head commit subject to skip a release. Do not edit the manifest versions by hand. Pushing a `v*` tag by hand still runs the release workflow.
