# Kestra Agent Skills

[![skills.sh](https://skills.sh/b/kestra-io/agent-skills)](https://skills.sh/kestra-io/agent-skills)

Agent skills that teach your AI coding assistant to write, harden, operate, and migrate [Kestra](https://kestra.io) flows.

Every skill is a folder with a `SKILL.md` file in the open [Agent Skills](https://agentskills.io) format, so the same skills work in Claude, Codex, Gemini CLI, Cursor, GitHub Copilot, OpenCode, and any other tool that reads that format.

| Skill | What it does |
|---|---|
| [`kestra-flow`](skills/kestra-flow/SKILL.md) | Generate, modify, or debug flow YAML against the live flow schema |
| [`kestra-flow-hardening`](skills/kestra-flow-hardening/SKILL.md) | Audit flows and add retries, timeouts, concurrency, SLAs, idempotency guards |
| [`kestra-ops`](skills/kestra-ops/SKILL.md) | Deploy flows, run executions, manage namespaces and files with `kestractl` |
| [`migrate-kestra-2`](skills/migrate-kestra-2/SKILL.md) | Upgrade an instance and its flows from Kestra 1.3 to 2.0 |
| [`migrate-airflow-kestra`](skills/migrate-airflow-kestra/SKILL.md) | Convert an Airflow DAG into a Kestra flow |

## Install

### Any AI coding tool (recommended)

The [`skills`](https://skills.sh) CLI detects the AI tools on your machine (Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode, Windsurf, Cline, and 40+ others) and installs the skills in the folder each one reads:

```bash
npx skills add kestra-io/agent-skills
```

Useful options:

```bash
# Install every skill without the picker
npx skills add kestra-io/agent-skills --skill '*'

# Install only some skills
npx skills add kestra-io/agent-skills --skill kestra-flow --skill kestra-ops

# Install for your user account (all projects) instead of the current project
npx skills add kestra-io/agent-skills -g

# Install for specific tools only
npx skills add kestra-io/agent-skills -a claude-code -a codex -a cursor

# List the skills without installing
npx skills add kestra-io/agent-skills --list
```

### Claude Code

Install as a plugin so Claude Code keeps the skills up to date:

```text
/plugin marketplace add kestra-io/agent-skills
/plugin install kestra@kestra-agent-skills
```

Skills are namespaced as `kestra:<skill>` (for example `kestra:kestra-flow`). Run `/skills` to check they are listed.

The plugin has no `version` field, so every new commit on `main` is picked up as an update. See [Versions and releases](#versions-and-releases).

### OpenAI Codex

```bash
codex plugin marketplace add kestra-io/agent-skills
codex plugin add kestra@kestra-agent-skills
```

Start a new Codex session after installing.

### ChatGPT

The repo root is also an [Agent Plugins](https://agent-plugins.org) package: `plugin.json` is the manifest (with the ChatGPT listing metadata), and `skills/` is picked up as is. Kestra is not listed in the ChatGPT plugin directory yet. To try it in ChatGPT desktop, clone the repo, add it as a repo marketplace, restart the app and install **Kestra** from the Plugins directory. Workspace admins can then publish it to the workspace from **Plugins > Personal**.

| Skill | ChatGPT |
|---|---|
| `kestra-flow`, `kestra-flow-hardening`, `migrate-airflow-kestra` | Yes, needs web access |
| `migrate-kestra-2` | Guidance only (no shell) |
| `kestra-ops` | No, needs `kestractl` and a shell |

### Cursor

```text
/add-plugin kestra-io/agent-skills
```

Cursor loads every skill under `skills/` from `.cursor-plugin/plugin.json`. Check them in **Settings → Rules, Skills, Subagents**.

### Claude.ai and Claude Desktop

1. Zip each skill folder (the zip must contain the folder, with `SKILL.md` inside):
   ```bash
   git clone https://github.com/kestra-io/agent-skills.git && cd agent-skills/skills
   for s in */; do zip -r "${s%/}.zip" "$s"; done
   ```
2. In Claude, open **Settings → Capabilities → Skills**, click **Upload skill**, and upload each zip.
3. Turn the skills on.

### Manual install

Each skill is a self-contained folder. Copy the ones you want from `skills/` into the skills folder your tool reads, for example `.agents/skills/` (Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode) or `.claude/skills/` (Claude Code):

```bash
git clone https://github.com/kestra-io/agent-skills.git /tmp/kestra-skills
mkdir -p .agents/skills
cp -R /tmp/kestra-skills/skills/* .agents/skills/
```

Check your tool's documentation for its user-wide skills folder. For a tool without skills support, attach or paste `skills/<name>/SKILL.md` into the chat.

### Update

| Installed with | Update with |
|---|---|
| `npx skills` | `npx skills update` (add `-g` for user-wide installs) |
| Claude Code plugin | `/plugin marketplace update kestra-agent-skills` |
| Manual copy | `git pull` in your clone, then copy the folders again |

## Versions and releases

The repo is versioned as one unit with [SemVer](https://semver.org), tagged `vX.Y.Z` (see [Releases](https://github.com/kestra-io/agent-skills/releases)). A release is cut automatically on every merge to `main` that contains a releasable [conventional commit](https://www.conventionalcommits.org): `feat:` bumps the minor version, `fix:`, `refactor:`, `build:` and `chore(deps):` bump the patch, and a `BREAKING CHANGE:` footer bumps the major. `docs:`, `test:` and bare `chore:` do not release.

The install commands above always follow `main`, not the tags, and the plugin manifests carry no version. The tags and releases give you a changelog and a stable point to pin to:

```bash
git clone --branch v1.0.0 https://github.com/kestra-io/agent-skills.git
```

## Telemetry

Three anonymous signals measure skill adoption. All are metadata only: no prompt, flow, file or credential content is sent.

| Signal | When | What is sent |
|---|---|---|
| `kestractl` tag | A skill runs `kestractl` | The skill prefixes the call with `KESTRACTL_SKILL_SOURCE=<skill>`; kestractl adds it as `skill_source` to its `cli_command_executed` event |
| MCP header | The plugin calls the Kestra docs MCP server | Header `X-Kestra-Plugin: agent-skills/<harness>` on each request. Plugin installs only |
| Claude Code hook | A skill of this plugin loads | `agent_skill_invoked` PostHog event: skill name, plugin ref, os/arch, random anonymous id |

Opt out of the `kestractl` tag and the hook with `KESTRACTL_TELEMETRY_DISABLED=true`. Opt out of the hook only with `KESTRA_SKILLS_TELEMETRY_DISABLED=true`. The header cannot be disabled by a variable: remove the `headers` entry from `.mcp.json` (Claude Code), `mcp.json` (Codex, Agent Plugins) or `.cursor-plugin/mcp.json` (Cursor) in your install, or add the MCP server yourself.

## Requirements

| Skill | Needs |
|---|---|
| `kestra-flow` | The Kestra docs MCP server (`https://api.kestra.io/v1/mcp`, declared in `.mcp.json`, `mcp.json` and `.cursor-plugin/mcp.json`). Skills-only installs (`npx skills add`, Claude.ai zip, manual copy) do not get it: add that server to your tool yourself. No Kestra instance needed. |
| `kestra-flow-hardening`, `migrate-airflow-kestra` | `curl` and access to `https://api.kestra.io`. No Kestra instance needed. |
| `kestra-ops` | [`kestractl`](https://kestra.io/docs), network access to your Kestra API, a tenant and token |
| `migrate-kestra-2` | Access to your instance; uses `kestra-migrate` and `kestractl` when available |

## Usage

Skills load automatically when your request matches them. You can also name the skill:

```text
Use kestra-flow to write a flow that polls a REST API every 30 minutes and stores the result in KV store.
```

```text
Use kestra-flow-hardening to audit the flows in ./flows before we go to production.
```

```text
Use kestra-ops to validate and deploy all flows in ./flows to prod.namespace with fail-fast.
```

```text
Is my instance ready for Kestra 2.0?
```

```text
Use migrate-airflow-kestra to migrate dags/ingest_pipeline.py from Airflow to Kestra, output to kestra/.
```

## Skills in detail

### kestra-flow

Generate, modify, or debug Kestra Flow YAML grounded in the live flow schema — the same way the Kestra AI Copilot does.

- Fetches task schemas on demand from the Kestra docs MCP server (`https://api.kestra.io/v1/mcp`)
- Schema-validated task and trigger generation
- Partial modification (touches only the relevant part)
- Guardrails: no invented types, no hardcoded secrets, correct looping and trigger patterns

### kestra-flow-hardening

Audit existing flows and add production-hardening controls — the consulting counterpart to `kestra-flow`.

- Severity-ranked report (Critical / High / Medium / Low) with risk, caveat, and fix per finding
- Never recommends a blind retry on a non-idempotent write
- Proportional to the flow; "already sound" is a valid result
- Surgical, schema-validated edits applied on confirmation
- Edition-aware (OSS / EE), with OSS fallbacks for EE-only patterns

### kestra-ops

Operate Kestra with `kestractl`.

- Context and auth setup (`config add`, `config use`, `config show`)
- Inspection (`flows list/get`, `executions get`, `namespaces list`)
- Safe writes (`flows deploy`, `nsfiles upload/delete`)
- Guardrails for production and automation output

### migrate-kestra-2

Guide a full Kestra 1.3 → 2.0 migration.

- Pre-flight audit with a readiness report and complexity rating
- Verified-backup guardrail before the irreversible upgrade
- CLI-first flow migration tracked in a `migration-ledger.md`
- Guided rewrites: `ForEach`/`ForEachItem` → `Loop`, trigger `conditions` → `when`/`dependsOn`, `pluginDefaults` → Policies, removed types
- Server upgrade steps for Docker Compose and Kubernetes/Helm
- Uses `kestra-ops` and `kestra-flow` when they are installed too

### migrate-airflow-kestra

Migrate an Apache Airflow DAG to a production-ready Kestra flow.

- Maps DAG tasks and dependencies to Kestra tasks, keeping fan-out/fan-in parallelism
- Extracts Python business logic into namespace files
- Maps XCom to `outputFiles`/`inputFiles`
- Validates against the live schema

## Contributing

- Add each skill as `skills/<skill-name>/SKILL.md`, with `name` and `description` frontmatter. The folder name must match `name`.
- Put long reference material in `skills/<skill-name>/references/` and link it from `SKILL.md`.
- Include purpose, trigger conditions, required inputs, workflow, guardrails, and example prompts.
- Keep commands copy-pasteable and production-safe.
- Add the new skill to the table at the top of this README.

## License

[Apache 2.0](LICENSE)
