# Kestra Agent Skills

A curated collection of agent skills for operating Kestra environments.


## Available skills

### kestra-flow

Generate, modify, or debug Kestra Flow YAML grounded in the live flow schema — the same way the Kestra AI Copilot does.

**Use when:**
- Generating a new Kestra flow from a description
- Modifying or extending an existing flow
- Debugging invalid YAML or incorrect task/trigger references

**Covers:**
- Fetching the live flow schema from `https://api.kestra.io/v1/plugins/schemas/flow`
- Schema-validated task and trigger generation
- Partial modification (touch only the relevant part)
- Guardrails: no invented types, no hardcoded secrets, correct looping and trigger patterns

Skill path: `skills/kestra-flow/SKILL.md`

---

### kestra-flow-hardening

Audit existing Kestra flows and add production-hardening controls — the consulting counterpart to `kestra-flow`.

**Use when:**
- Hardening one or more flows for production
- Auditing flows for resilience, idempotency, and guardrail gaps
- Adding retries, timeouts, error handling, concurrency limits, SLAs, or idempotency guards

**Covers:**
- Severity-ranked audit report (Critical / High / Medium / Low) with risk, caveat, and proposed fix per finding
- Idempotency judgment — never recommends a blind retry on a non-idempotent write; flags the dedup-guard vs. retry-if-safe branches
- Proportional auditing calibrated by flow signals (triggers, side-effects, namespace env); "already sound" is a valid result
- Surgical, schema-validated edits applied on confirmation, inline and structure-preserving
- Version- and edition-aware (OSS / EE), with EE-only patterns labeled and given an OSS fallback

Skill path: `skills/kestra-flow-hardening/SKILL.md`

---

### kestra-ops

Operate Kestra using `kestractl` for flow, execution, namespace, and namespace-file operations.

**Use when:**
- Validating or deploying flows
- Triggering executions and checking status
- Managing namespaces and `nsfiles`
- Configuring or switching CLI contexts

**Covers:**
- Context and auth setup (`config add`, `config use`, `config show`)
- Read and inspection flows (`flows list/get`, `executions get`, `namespaces list`)
- Safe write operations (`flows deploy`, `nsfiles upload/delete`)
- Operational guardrails for production and automation output

Skill path: `skills/kestra-ops/SKILL.md`

---

### migrate-kestra-2

Guide a full **Kestra 1.3 → 2.0** migration: pre-flight audit, server upgrade, CLI-first flow migration, and guided rewrites of the patterns the CLI can't automate.

**Use when:**
- Upgrading or migrating an instance to Kestra 2.0
- Checking whether an instance is ready for 2.0 (readiness report + complexity rating)
- Triaging `kestra-migrate` warnings or flows failing to parse after a 2.0 upgrade

**Covers:**
- Detect-first audit (probes CLIs, contexts, instance, runs `kestra-migrate --check`) with a shareable readiness report and Low/Medium/High/Critical complexity tier
- Advisory one-way-door guardrails: verified backup before upgrade (2.0 drops JDBC queue tables irreversibly), accepted risks recorded, never blocked
- CLI-first flow migration with a persistent `migration-ledger.md` — every flow driven to a terminal state (validated/deployed or deferred-with-reason)
- Guided per-pattern rewrites with diff + confirmation: `ForEach`/`ForEachItem` → `Loop`, trigger `conditions` → `when`/`dependsOn`, `pluginDefaults` → Policies/inline, removed types
- Server upgrade sequences for Docker Compose and Kubernetes/Helm, EE/OSS branches, `kestra migrate plan/run` handling
- Composes with `kestra-ops` and `kestra-flow` when installed (discovered by skill name — install via `npx skills add kestra-io/agent-skills@<name>`); standalone kestractl fallback inlined

---

### migrate-airflow-kestra

Migrate an **Apache Airflow** DAG to a production-ready **Kestra** flow.

**Use when:**
- Converting an Airflow DAG (`.py`) to a Kestra flow YAML
- Translating `@task`-decorated functions or operators into Kestra tasks
- Preserving Airflow parallel execution (fan-out/fan-in) in Kestra

**Covers:**
- Reading and analysing the Airflow DAG structure, tasks, and dependencies
- Fetching the live Kestra schema from `https://api.kestra.io/v1/plugins/schemas/flow`
- Extracting Python business logic into namespace files
- Generating schema-validated Kestra flow YAML with correct task ordering and parallelism
- Mapping Airflow XCom data passing to Kestra `outputFiles`/`inputFiles`

Skill path: `skills/migrate-airflow-kestra/SKILL.md`

## Install

### Any agent supporting the Agent Skills spec (Claude Code, Cursor, ...)

```bash
npx skills add kestra-io/agent-skills
```

### ChatGPT and Codex (plugin)

The repo root is also an [Agent Plugins](https://agent-plugins.org) package for ChatGPT and Codex: `plugin.json` is the manifest, `skills/` is picked up as is, and `mcp.json` connects the public Kestra MCP server (`https://api.kestra.io/v1/mcp`, no auth) for plugin, task schema, docs and blueprint lookups.

Codex CLI:

```bash
codex plugin marketplace add kestra-io/agent-skills
codex plugin add kestra@kestra-agent-skills
```

ChatGPT desktop: clone the repo, add it as a repo marketplace (`.agents/plugins/marketplace.json` is included), restart the app and install **Kestra** from the Plugins directory. Workspace admins can then publish it to the workspace from **Plugins > Personal**.

| Skill | ChatGPT | Codex |
|---|---|---|
| `kestra-flow` | Yes | Yes |
| `kestra-flow-hardening` | Yes | Yes |
| `migrate-airflow-kestra` | Yes | Yes |
| `migrate-kestra-2` | Guidance only (no shell) | Yes |
| `kestra-ops` | No, needs `kestractl` and a shell | Yes |

`kestra-ops` on ChatGPT will need a remote MCP server over the Kestra API with OAuth.

## Usage

Load the skill and provide a concrete operational objective.

Examples:

```text
Use kestra-flow to write a flow that polls a REST API every 30 minutes and stores the result in KV store.
```

```text
Use kestra-ops to validate and deploy all flows in ./flows to prod.namespace with fail-fast.
```

```text
Use kestra-ops to run my-flow in my.namespace, wait for completion, and summarize the result.
```

```text
Use migrate-airflow-kestra to migrate dags/ingest_pipeline.py from Airflow to Kestra, output to kestra/.
```

## Structure

```
.
├── README.md
├── plugin.json              # ChatGPT / Codex plugin manifest
├── mcp.json                 # public Kestra MCP server
├── assets/                  # plugin icon and logo
├── .agents/plugins/
│   └── marketplace.json     # local marketplace entry for testing
└── skills/
    ├── kestra-flow/
    │   └── SKILL.md
    ├── kestra-flow-hardening/
    │   ├── SKILL.md
    │   └── references/
    │       └── hardening-patterns.md
    ├── kestra-ops/
    │   └── SKILL.md
    ├── migrate-airflow-kestra/
    │   └── SKILL.md
    └── migrate-kestra-2/
        ├── SKILL.md
        └── references/
            ├── audit.md
            ├── cli-reference.md
            ├── foreach-to-loop.md
            ├── plugin-defaults.md
            ├── removed-constructs.md
            ├── server-upgrade.md
            └── trigger-conditions.md
```

## Contributing

- Add each skill as `skills/<skill-name>/SKILL.md`.
- Include purpose, trigger conditions, required inputs, workflow, guardrails, and example prompts.
- Keep commands copy-pasteable and production-safe.
