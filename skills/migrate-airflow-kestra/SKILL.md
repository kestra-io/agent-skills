---
name: migrate-airflow-kestra
description: Migrate an Airflow DAG to a production-ready Kestra flow. Extracts Python task logic into namespace files, maps DAG dependencies to Kestra tasks, and preserves parallel execution structure.
argument-hint: "<path-to-airflow-dag.py> [output-dir]"
compatibility: Requires curl and network access to https://api.kestra.io/v1/plugins/schemas/flow. No Kestra instance required for generation.
---

# Migrate Airflow DAG to Kestra

Migrate an **Apache Airflow** DAG file to a production-ready **Kestra** flow with proper namespace files, correct task ordering, and schema-validated YAML.

## When to use

Use this skill when the request involves **migrating from Apache Airflow to Kestra**, including:
- Migrating an Airflow DAG (`.py`) to a Kestra flow YAML
- Translating `@task`-decorated functions or operators into Kestra tasks
- Converting Airflow DAG dependencies into Kestra's sequential/parallel task structure

## Required inputs

- Path to the Airflow DAG `.py` file (`$ARGUMENTS`)
- Output directory for generated files (defaults to `kestra-migrate/` next to the DAG)
- Target Kestra namespace (ask if not provided; default to `company.team`)

## Workflow

### Step 1 — Read and analyse the Airflow DAG

Read the DAG file in full. Extract:

1. **DAG metadata**: `dag_id`, `schedule`, `default_args`, `tags`
2. **Tasks**: for each `@task`-decorated function or operator, note:
   - Task ID (function name or `task_id`)
   - Python imports and dependencies (`pip` packages used)
   - Whether it contains **important business logic** (pandas transforms, ML, data processing, API calls, multi-step computation) — these become namespace files
   - Whether it is a trivial one-liner — these can be inlined
3. **Dependencies**: map `>>` operators, `set_upstream`/`set_downstream` calls, and direct task invocations into an ordered dependency graph
4. **Parallelism**: identify tasks that share the same upstream and have no dependency on each other — these must be wrapped in `io.kestra.plugin.core.flow.Parallel`
5. **Data passing**: identify XCom pushes/pulls or return values passed between tasks — these become `outputFiles` → `inputFiles` in Kestra

### Step 2 — Fetch and validate the Kestra schema

```bash
curl -s https://api.kestra.io/v1/plugins/schemas/flow -o /tmp/kestra_schema.json
```

Extract the definitions needed for this flow:

```bash
python3 -c "
needed = [
    'io.kestra.plugin.scripts.python.Commands',
    'io.kestra.plugin.core.flow.Parallel',
    'io.kestra.plugin.core.flow.WorkingDirectory',
    'io.kestra.plugin.core.trigger.Schedule',
]
content = open('/tmp/kestra_schema.json').read()
for t in needed:
    idx = content.find(f'\"{ t }\"')
    if idx >= 0:
        print(f'=== {t} ===')
        print(content[idx:idx+3000])
"
```

Do not generate any YAML until schema definitions have been read and validated.

### Step 3 — Create namespace files

For every task that contains **important business logic** (see rule below), extract the Python function body into a standalone script under `<output-dir>/scripts/`.

**Namespace file rules:**
- One file per Airflow task, named after the task: `<task_id>.py`
- The script must be self-contained: read inputs from local files (e.g. `products.json`), write outputs to local files (e.g. `category_stats.json`)
- Remove all Airflow imports (`from airflow …`, `from pendulum …`) — they have no equivalent
- Replace XCom `ti.xcom_push` / return values with `json.dump(result, open("output.json", "w"))`
- Replace XCom `ti.xcom_pull` with `json.load(open("input.json"))`
- Keep all business logic, pandas transforms, API calls, and helper functions intact

**When to use a namespace file vs inline:**

| Situation | Decision |
|---|---|
| Task has pandas/numpy/ML logic | Namespace file |
| Task makes HTTP requests with processing | Namespace file |
| Task has > 10 lines of logic | Namespace file |
| Task is a single API call or shell command | Inline in flow |
| Task is a `BashOperator` one-liner | Inline in flow |

### Step 4 — Generate the Kestra flow YAML

Apply all rules below. Write the flow to `<output-dir>/flow.yaml`.

---

## Generation rules

### Task structure — the YAML list marker (`-`) MUST be on the `id` line, `type` MUST be the very next line

This is the single most important formatting rule. Every task block in `tasks:` (including nested tasks inside `Parallel`) **must** follow this exact pattern:

1. The YAML sequence dash (`-`) goes on the **`id:`** line — never on `type:` or any other property.
2. **`type:`** is always the second line, indented to align with `id:` (no dash).
3. All remaining properties (`containerImage`, `namespaceFiles`, `commands`, etc.) follow after `type:`, at the same indentation level as `type:`.

```yaml
# ✅ CORRECT — dash on id, type immediately after, then everything else
- id: fetch_products
  type: io.kestra.plugin.scripts.python.Commands
  containerImage: python:3.11
  namespaceFiles:
    enabled: true
    include:
      - scripts/fetch_products.py
  commands:
    - python scripts/fetch_products.py

# ❌ WRONG — dash on type instead of id
- type: io.kestra.plugin.scripts.python.Commands
  id: fetch_products

# ❌ WRONG — dash on containerImage
- containerImage: python:3.11
  id: fetch_products
  type: io.kestra.plugin.scripts.python.Commands

# ❌ WRONG — dash on namespaceFiles
- namespaceFiles:
    enabled: true
  id: fetch_products
  type: io.kestra.plugin.scripts.python.Commands

# ❌ WRONG — dash on commands
- commands:
    - python scripts/fetch_products.py
  id: fetch_products
  type: io.kestra.plugin.scripts.python.Commands

# ❌ WRONG — dash on dependencies
- dependencies:
    - pandas
  id: fetch_products
  type: io.kestra.plugin.scripts.python.Commands

# ❌ WRONG — type is not the second property
- id: fetch_products
  containerImage: python:3.11
  type: io.kestra.plugin.scripts.python.Commands

# ❌ WRONG — extra blank line between id and type
- id: fetch_products

  type: io.kestra.plugin.scripts.python.Commands
```

This rule applies everywhere a task appears: top-level `tasks:`, inside `Parallel.tasks:`, inside `WorkingDirectory.tasks:`, and in `triggers:` blocks. No exceptions.

### Container image — always `python:3.11`

Every Python task (`io.kestra.plugin.scripts.python.Commands`) must specify:

```yaml
containerImage: python:3.11
```

Never omit this property. Never use `python:3.13-slim` or any other image.

### Namespace files — always use for important Python logic

For tasks backed by a namespace file, always declare:

```yaml
namespaceFiles:
  enabled: true
  include:
    - scripts/<task_id>.py
```

Reference the script in `commands`:

```yaml
commands:
  - python scripts/<task_id>.py
```

### Data passing between tasks

Use `outputFiles` to capture JSON written by a script and store it in Kestra internal storage:

```yaml
outputFiles:
  - result.json
```

Inject that output into a downstream task via `inputFiles`:

```yaml
inputFiles:
  result.json: "{{ outputs.<upstream_task_id>.outputFiles['result.json'] }}"
```

### Parallelism — mirror the Airflow fan-out/fan-in

Tasks with a shared upstream and no mutual dependency must be wrapped in `io.kestra.plugin.core.flow.Parallel`:

```yaml
- id: compute_analytics
  type: io.kestra.plugin.core.flow.Parallel
  tasks:
    - id: compute_category_stats
      type: io.kestra.plugin.scripts.python.Commands
      containerImage: python:3.11
      ...
    - id: compute_brand_stats
      type: io.kestra.plugin.scripts.python.Commands
      containerImage: python:3.11
      ...
```

Tasks that are independent at the fetch/ingest stage should also run in parallel.

### Schedule trigger

Map Airflow `schedule` to a Kestra `Schedule` trigger:

| Airflow | Kestra cron |
|---|---|
| `@daily` | `@daily` |
| `@hourly` | `@hourly` |
| `0 6 * * *` | `0 6 * * *` |
| `None` | Omit trigger entirely |

```yaml
triggers:
  - id: daily
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "@daily"
```

### DAG metadata mapping

| Airflow | Kestra |
|---|---|
| `dag_id` | `id` |
| `default_args.owner` | `# comment` or label |
| `tags` | `labels` |
| `description` | `description` |
| `catchup=False` | No equivalent needed |
| `retries` | Not set at flow level; handle per-task if needed |

### Schema compliance

- Use only task types and properties explicitly defined in the fetched schema
- Never invent property names
- Property keys must be unique within each task block

### Secrets and credentials

- Never hardcode tokens, passwords, or API keys
- Use `{{ secret('SECRET_NAME') }}` Pebble expressions

---

## Output structure

```
<output-dir>/
├── flow.yaml                        # Kestra flow
└── scripts/
    ├── <task_id>.py                 # One file per task with business logic
    └── ...
```

### flow.yaml skeleton

```yaml
id: <dag_id>
namespace: <namespace>
description: <dag description>

tasks:
  # Stage 1 — parallel fetch
  - id: fetch_data
    type: io.kestra.plugin.core.flow.Parallel
    tasks:
      - id: <task_id>
        type: io.kestra.plugin.scripts.python.Commands
        containerImage: python:3.11
        namespaceFiles:
          enabled: true
          include:
            - scripts/<task_id>.py
        dependencies:
          - <pip-package>
        commands:
          - python scripts/<task_id>.py
        outputFiles:
          - <output>.json

  # Stage 2 — parallel transforms
  - id: compute_analytics
    type: io.kestra.plugin.core.flow.Parallel
    tasks:
      - id: <task_id>
        type: io.kestra.plugin.scripts.python.Commands
        containerImage: python:3.11
        namespaceFiles:
          enabled: true
          include:
            - scripts/<task_id>.py
        inputFiles:
          <input>.json: "{{ outputs.<upstream_id>.outputFiles['<input>.json'] }}"
        dependencies:
          - <pip-package>
        commands:
          - python scripts/<task_id>.py
        outputFiles:
          - <output>.json

  # Stage 3 — sequential summary
  - id: <final_task_id>
    type: io.kestra.plugin.scripts.python.Commands
    containerImage: python:3.11
    namespaceFiles:
      enabled: true
      include:
        - scripts/<final_task_id>.py
    inputFiles:
      <a>.json: "{{ outputs.<task_a>.outputFiles['<a>.json'] }}"
      <b>.json: "{{ outputs.<task_b>.outputFiles['<b>.json'] }}"
    dependencies:
      - <pip-package>
    commands:
      - python scripts/<final_task_id>.py
    outputFiles:
      - <output>.json

triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "<mapped-cron>"
```

---

## Deploying with kestra-ops

After generating the files, if the user wants to deploy, use the `kestra-ops` skill. Key note on namespace file uploads: **always upload files individually** to avoid path nesting issues:

```bash
for f in <output-dir>/scripts/*.py; do
  name=$(basename "$f")
  kestractl nsfiles upload <namespace> "$f" "scripts/$name" --override
done
```

Do not use directory upload (`kestractl nsfiles upload <ns> ./scripts scripts`) — it nests the directory name, producing `scripts/scripts/<file>` instead of `scripts/<file>`.

---

## Example prompts

- "Migrate `dags/ingest_pipeline.py` from Airflow to Kestra, output to `kestra/`"
- "Convert this Airflow DAG to a Kestra flow in the `analytics.products` namespace"
- "Migrate the Airflow DAG at `dags/etl.py` and deploy it using kestra-ops"
