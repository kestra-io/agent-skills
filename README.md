# Kestra Agent Skills

A curated collection of agent skills for operating Kestra environments.


## Available skills

### kestra-flow

Generate, modify, or debug Kestra Flow YAML grounded in the live schema via the Kestra MCP server — the same way the Kestra AI Copilot does.

**Use when:**
- Generating a new Kestra flow from a description
- Modifying or extending an existing flow
- Debugging invalid YAML or incorrect task/trigger references

**Covers:**
- Blueprint-first scaffolding — search vetted templates via `blueprints` / `get_blueprint_flow`, adapt rather than generate from scratch, EE-only blueprints gated for OSS users
- Incremental, on-demand schema grounding via `mcp__kestra__*` — flow structure from `list_doc_children` / `get_doc`, types from `search` / `plugin_tasks`, per-task schema from `task_schema` (no multi-MB download)
- Resolve, don't guess — task runners, storage, secret managers, and log shippers via `list_*`; plugin/version compatibility via `versions` / `plugin_versions`
- Schema-validated task and trigger generation
- Partial modification (touch only the relevant part)
- Guardrails: no invented types, no hardcoded secrets, correct looping and trigger patterns

Skill path: `skills/kestra-flow/SKILL.md`

---

### kestra-flow-hardening

Audit existing Kestra flows, add production-hardening controls, and diagnose failures — the consulting counterpart to `kestra-flow`.

**Use when:**
- Hardening one or more flows for production
- Auditing flows for resilience, idempotency, and guardrail gaps
- Adding retries, timeouts, error handling, concurrency limits, SLAs, or idempotency guards
- Diagnosing why a flow or execution failed ("troubleshoot mode")

**Covers:**
- Severity-ranked audit report (Critical / High / Medium / Low) with risk, caveat, and proposed fix per finding
- Troubleshoot mode — root-cause a failure grounded in version-pinned docs (`search_docs` / `get_doc`) and `task_schema`, citing the page used; `references/troubleshooting.md` maps common failure signatures
- Idempotency judgment — never recommends a blind retry on a non-idempotent write; flags the dedup-guard vs. retry-if-safe branches
- Proportional auditing calibrated by flow signals (triggers, side-effects, namespace env); "already sound" is a valid result
- Surgical, schema-validated edits applied on confirmation, inline and structure-preserving
- Version- and edition-aware (OSS / EE), with EE-only patterns labeled and given an OSS fallback
- MCP-grounded — no schema download; flow structure from `list_doc_children` / `get_doc`, types from `task_schema`

Skill path: `skills/kestra-flow-hardening/SKILL.md`

---

### kestra-ops

Operate Kestra using `kestractl` across flows, executions, triggers, KV, namespaces, and namespace files.

**Use when:**
- Validating or deploying flows
- Triggering executions and checking status
- Managing triggers, KV entries, namespaces, and `nsfiles`
- Configuring or switching CLI contexts

**Covers:**
- Short `SKILL.md` entry point + on-demand `references/` (progressive disclosure)
- `references/commands.md` — the full `kestractl` command surface, pinned to a release, with EE-only groups marked
- `references/workflow.md` — edition (OSS/EE) awareness, per-group decision notes, `--wait` vs. poll, `*-by-query` vs. loop, revision-awareness, and guardrails
- `scripts/ensure-kestractl.sh` — dry-run check for `kestractl`, with on-request install/upgrade via the official installer
- Operational guardrails for production and automation output

Skill path: `skills/kestra-ops/SKILL.md`

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
└── skills/
    ├── kestra-flow/
    │   └── SKILL.md
    ├── kestra-flow-hardening/
    │   ├── SKILL.md
    │   └── references/
    │       ├── hardening-patterns.md
    │       └── troubleshooting.md
    ├── kestra-ops/
    │   ├── SKILL.md
    │   ├── references/
    │   │   ├── commands.md
    │   │   └── workflow.md
    │   └── scripts/
    │       └── ensure-kestractl.sh
    └── migrate-airflow-kestra/
        └── SKILL.md
```

## Contributing

- Add each skill as `skills/<skill-name>/SKILL.md`.
- Include purpose, trigger conditions, required inputs, workflow, guardrails, and example prompts.
- Keep commands copy-pasteable and production-safe.
