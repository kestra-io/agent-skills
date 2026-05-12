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
    ├── kestra-ops/
    │   └── SKILL.md
    └── migrate-airflow-kestra/
        └── SKILL.md
```

## Contributing

- Add each skill as `skills/<skill-name>/SKILL.md`.
- Include purpose, trigger conditions, required inputs, workflow, guardrails, and example prompts.
- Keep commands copy-pasteable and production-safe.
