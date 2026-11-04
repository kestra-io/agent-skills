---
name: migrate-airflow-kestra
description: Migrate an Airflow DAG to a production-ready Kestra flow. Extracts Python task logic into namespace files, maps DAG dependencies to Kestra tasks, and preserves parallel execution structure.
argument-hint: "<path-to-airflow-dag.py> [output-dir]"
compatibility: Requires curl and network access to https://api.kestra.io/v1/plugins/schemas/flow. No Kestra instance required for generation.
---

# Migrate Airflow DAG to Kestra

Migrate an **Apache Airflow** DAG file to a production-ready **Kestra** flow with proper namespace files, correct task ordering, and schema-validated YAML.

Never emit the legacy constructs below — they fail to parse, even if older docs, blueprints or examples use them:

| Never emit | Use instead |
|---|---|
| `ForEach`, `ForEachItem`, `EachSequential`, `EachParallel` | `io.kestra.plugin.core.flow.Loop` |
| `pluginDefaults` (flow-level) | Set the values on each task, or hoist shared values into flow `variables:` |
| `conditions:` on a trigger | `when:` Pebble expression |
| Flow trigger `preconditions` / `multipleConditions` | `dependsOn` + `window` + `mode` |
| `json()` Pebble function | `fromJson()` |
| `taskrun.value` / `parent.taskrun.value` | `item.value` (inside a `Loop`) |
| `runner:` property | `taskRunner:` or `containerImage` |
| Listeners, Templates, `core.trigger.Toggle`, `scripts.nashorn.*` | Flow triggers, Subflows, the API, `graalvm.*` |

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
6. **Control flow and cross-DAG links**: dynamic task mapping (`.expand()`), branching (`BranchPythonOperator`, `@task.branch`), sensors, Datasets, `TriggerDagRunOperator`, `trigger_rule`, callbacks. Map them with the [Airflow construct mapping](#airflow-construct-mapping) table
7. **`default_args`**: `retries`, `retry_delay`, `execution_timeout` etc. apply to every task — Kestra has no `pluginDefaults`, so these are set on each task

### Step 2 — Fetch and validate the Kestra schema

```bash
curl -s https://api.kestra.io/v1/plugins/schemas/flow -o /tmp/kestra_schema.json
```

If the user has a Kestra instance, prefer its own schema (`GET <host>/api/v1/plugins/schemas/flow`, tenant-less path) — it matches the plugins actually installed.

Extract the definitions needed for this flow. Add `Loop`, `If`, `Switch`, `Subflow` or `trigger.Flow` to `needed` when Step 1 found the matching Airflow constructs:

```bash
python3 -c "
import json
defs = json.load(open('/tmp/kestra_schema.json'))['definitions']
needed = [
    'io.kestra.plugin.scripts.python.Commands',
    'io.kestra.plugin.core.flow.Parallel',
    'io.kestra.plugin.core.trigger.Schedule',
]
for t in needed:
    d = defs[t]
    print(f'=== {t} ===')
    print('required:', d.get('required', []))
    for name, prop in sorted(d.get('properties', {}).items()):
        flag = ' (deprecated)' if prop.get('\$deprecated') else ''
        print(f'  {name}{flag}')
"
```

Do not generate any YAML until schema definitions have been read and validated. Never use a property flagged `(deprecated)`. `taskRunner` shows as required on script tasks but defaults to Docker — omit it and set `containerImage` instead.

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

This rule applies everywhere a task appears: top-level `tasks:`, inside `Parallel.tasks:`, `Loop.tasks:`, `If.then:`/`else:`, `Switch.cases:`, and in `triggers:` blocks. No exceptions.

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

### Airflow construct mapping

| Airflow | Kestra |
|---|---|
| Dynamic task mapping (`task.expand(x=[...])`) | `io.kestra.plugin.core.flow.Loop` with `values:`; reference the element as `{{ item.value }}` (use `fromJson(item.value).field` for objects). `concurrencyLimit: 0` for unlimited parallel mapping, `1` for sequential |
| Results of mapped tasks consumed downstream | Declare `outputs:` on the `Loop`; read `outputs.<loop_id>.outputs` after it |
| `BranchPythonOperator` / `@task.branch` | `io.kestra.plugin.core.flow.If` (two branches) or `Switch` (several) |
| `ShortCircuitOperator` | `runIf:` on the downstream task, or an `If` |
| `ExternalTaskSensor` / Dataset-scheduled DAG | `io.kestra.plugin.core.trigger.Flow` with `dependsOn:` (`flowId`, `namespace`, `states`); add `window:` + `mode:` when several upstreams must complete |
| `TriggerDagRunOperator` | `io.kestra.plugin.core.flow.Subflow` |
| `default_args.retries` + `retry_delay` | `retry: {type: constant, maxAttempts: <retries + 1>, interval: <retry_delay as ISO-8601, e.g. PT5M>}` on each task |
| `execution_timeout` | `timeout:` (ISO-8601 duration) on the task |
| `on_failure_callback` | flow-level `errors:` tasks |
| `trigger_rule="all_done"` (cleanup) | flow-level `finally:` tasks |

Inside a `Loop`, each iteration is an isolated sub-execution: `outputs.<task_id>` refers to the task in the same iteration — never index outputs by value.

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
| `catchup=False` | `recoverMissedSchedules: NONE` on the Schedule trigger |
| `catchup=True` | `recoverMissedSchedules: ALL` |
| `max_active_runs` | flow-level `concurrency: {limit: N}` |
| `default_args.retries` | task-level `retry` on each task (see construct mapping) |

### Schema compliance

- Use only task types and properties explicitly defined in the fetched schema
- Never invent property names
- Property keys must be unique within each task block
- Read JSON outputs in Pebble with `fromJson()`, never `json()`

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
