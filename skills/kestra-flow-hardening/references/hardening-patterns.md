# Hardening Patterns Reference

Canonical, copy-pasteable YAML for each hardening construct, with **when to apply** and
**when NOT to**. Validate every property via `mcp__kestra__task_schema` (`cls: <FQCN>`)
and, for flow-level shape, `mcp__kestra__get_doc` (`version` pinned) before recommending —
versions differ, and a property absent from the schema must not be used.

Version / edition gates (verify via `task_schema` / `get_doc` for the target version):
`concurrency` ≥ 0.13 · `sla` ≥ 0.20 · `finally` ≥ 0.21 · `afterExecution` ≥ 0.22 ·
`checks` ≥ 1.2 · `retry.maxAttempts` (was `maxAttempt` before 0.24) ·
`system.correlationId` idempotency via the executions search API is **Enterprise-only**.

---

## Retries (task-level)

Apply to **Safe / Conditionally-safe** tasks prone to transient failure (HTTP, JDBC, cloud APIs).
**Never** apply a blind retry to an Unsafe/unknown write — use an idempotency guard instead.

```yaml
- id: fetch_api
  type: io.kestra.plugin.core.http.Request
  uri: https://api.example.com/data
  timeout: PT30S            # bound a single attempt
  retry:
    type: exponential       # constant | exponential | random
    maxAttempts: 5
    interval: PT10S         # base interval
    maxInterval: PT5M       # exponential only
    maxDuration: PT30M      # total budget across all attempts + delays
    warningOnRetry: true    # mark execution WARNING if any retry happened
```

- `constant` — fixed `interval`. `exponential` — `interval` × `delayFactor` (default 2), capped at `maxInterval`. `random` — between `minInterval` and `maxInterval`.
- `timeout` bounds **one attempt**; `retry.maxDuration` bounds the **whole task** (all attempts + delays). Keep `interval` < `maxDuration` or retries never run.

## Retries (flow-level)

Apply when whole-execution replay is the right recovery unit.

```yaml
retry:
  maxAttempts: 3
  type: constant
  interval: PT1S
  behavior: CREATE_NEW_EXECUTION   # or RETRY_FAILED_TASK
```

- `CREATE_NEW_EXECUTION` — increments the execution attempt; also restarts subflows as new executions.
- `RETRY_FAILED_TASK` — re-runs only the failed task; same execution.

---

## Timeout

Apply to **every** runnable task that calls out or runs code — especially scripts, queries,
and cloud jobs (hang prevention + cost control). There is **no flow-level timeout** — use an
SLA `MAX_DURATION` for that.

```yaml
- id: costly_query
  type: io.kestra.plugin.scripts.shell.Commands
  commands: ["sleep 10"]
  timeout: PT5S            # ISO-8601; exceeded → attempt fails
```

---

## Errors — global handler (alerting)

Apply when failures would otherwise go unnoticed. Runs sequentially when any task errors.

```yaml
errors:
  - id: alert_on_failure
    type: io.kestra.plugin.slack.notifications.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "Failure: {{ flow.namespace }}.{{ flow.id }} exec {{ execution.id }}"
```

## Errors — local handler (targeted cleanup)

Apply inside a flowable task to scope handling / cleanup to its children only.

```yaml
tasks:
  - id: stage
    type: io.kestra.plugin.core.flow.Sequential
    tasks:
      - id: risky
        type: io.kestra.plugin.core.execution.Fail
    errors:
      - id: cleanup_stage
        type: io.kestra.plugin.core.log.Log
        message: "Cleaning up after {{ task.id }}"
```

## allowFailure / allowWarning

Apply only to **genuinely non-critical** tasks so downstream work continues.

```yaml
- id: flaky_optional
  type: io.kestra.plugin.core.execution.Fail
  allowFailure: true     # downstream continues; execution ends WARNING
# allowWarning: true     # warnings don't fail the run; execution ends SUCCESS
```

---

## finally — always-run cleanup

Apply for teardown that must happen regardless of outcome (stop containers, release infra).
Runs while the execution is still **RUNNING**. Not for business logic.

```yaml
finally:
  - id: stop_container
    type: io.kestra.plugin.docker.Stop
    containerId: "{{ outputs.start.taskRunner.containerId }}"
```

## afterExecution — final-state actions

Apply for notifications / reporting that branch on the **terminal** state. Errors here do
**not** change the final execution state (wrap in a `Sequential` with `errors` if you need a state change).

```yaml
afterExecution:
  - id: on_success
    runIf: "{{ execution.state == 'SUCCESS' }}"
    type: io.kestra.plugin.slack.notifications.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "{{ flow.id }} succeeded"
  - id: on_failure
    runIf: "{{ execution.state == 'FAILED' }}"
    type: io.kestra.plugin.slack.notifications.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "{{ flow.id }} FAILED"
```

**Choosing between the three end-of-flow constructs:**
- `errors` → failure-specific handling; available locally inside flowable tasks.
- `finally` → cleanup that must always run; fires while RUNNING.
- `afterExecution` → branch on final SUCCESS / FAILED / WARNING after the run finishes.

---

## Concurrency limit

Apply when a flow hits a shared / rate-limited downstream (DB, SaaS API, warehouse) or needs
"only one at a time" semantics. Do **not** use it to throttle worker CPU/RAM.

```yaml
concurrency:
  limit: 2
  behavior: QUEUE   # QUEUE | CANCEL | FAIL
```

- `QUEUE` holds excess executions (each holds a DB lock — beware large backlogs).
- Caveat: when executions start from a **trigger**, the trigger locks until it finishes, so `behavior` may not apply — new trigger executions are simply skipped. Pair with trigger `allowConcurrent`.

## Trigger overlap

Apply to schedules that can fire faster than the flow completes.

```yaml
triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "*/5 * * * *"
    allowConcurrent: false   # skip a new run while the previous is still running
```

---

## Idempotency guard — OSS (KV-based)

Apply when the same business event may arrive more than once and you must process it once.
OSS-portable: persist a marker in the KV store and short-circuit duplicates.

```yaml
tasks:
  - id: check_seen
    type: io.kestra.plugin.core.kv.Get
    key: "processed_{{ inputs.idempotencyKey }}"
    errorOnMissing: false

  - id: guard
    type: io.kestra.plugin.core.flow.If
    condition: "{{ outputs.check_seen.value ?? '' != '' }}"
    then:
      - id: skip
        type: io.kestra.plugin.core.log.Log
        message: "Duplicate {{ inputs.idempotencyKey }} — skipping"
    else:
      - id: do_work
        type: io.kestra.plugin.core.log.Log
        message: "Processing {{ inputs.idempotencyKey }}"
      - id: mark_seen
        type: io.kestra.plugin.core.kv.Set
        key: "processed_{{ inputs.idempotencyKey }}"
        value: "{{ now() }}"
```

## Idempotency guard — Enterprise (`system.correlationId`)

EE value-add: a built-in execution label that propagates to subflows. Set it at execution
creation (API-triggered) or store the provider key as a custom label (webhook), then guard
against an existing SUCCESS execution with the same key.

```yaml
# webhook variant: provider key arrives in headers after the execution is created
variables:
  idem_key: "{{ trigger.headers['Idempotency-Key'] | first }}"

tasks:
  - id: set_key
    type: io.kestra.plugin.core.execution.Labels
    labels:
      idempotency.key: "{{ vars.idem_key }}"

  - id: check_existing
    type: io.kestra.plugin.core.http.Request
    uri: "http://localhost:8080/api/v1/{{ kv('KESTRA_TENANT') }}/executions/search?filters[labels][EQUALS][idempotency.key]={{ vars.idem_key }}&filters[state][IN]=SUCCESS&size=1"
    headers:
      Authorization: "Bearer {{ secret('KESTRA_API_TOKEN') }}"

  - id: maybe_skip
    type: io.kestra.plugin.core.flow.If
    condition: "{{ not (outputs.check_existing.body contains '\"total\":0') }}"
    then:
      - id: skip
        type: io.kestra.plugin.core.log.Log
        message: "Duplicate {{ vars.idem_key }} — skipping"
    else:
      - id: process
        type: io.kestra.plugin.core.log.Log
        message: "Processing {{ vars.idem_key }}"
```

> The duplicate check is **not atomic**. For strict once-only under concurrent load, enforce
> uniqueness at the source (broker dedup, DB unique constraint, API-gateway idempotency).

---

## Checks — pre-execution input validation (≥ 1.2)

Apply to block / fail / warn on bad inputs before any task runs.

```yaml
checks:
  - message: "Prod runs only allowed 06:00–22:00 UTC"
    condition: "{{ inputs.env != 'prod' or (inputs.run_date | date('HH') | number >= 6 and inputs.run_date | date('HH') | number < 22) }}"
    style: ERROR
    behavior: BLOCK_EXECUTION   # BLOCK_EXECUTION | FAIL_EXECUTION | CREATE_EXECUTION
```

Most restrictive behavior wins: `BLOCK_EXECUTION` → `FAIL_EXECUTION` → `CREATE_EXECUTION`.

## SLA (≥ 0.20)

Apply duration targets / assertions on business-critical flows, with breach labels for alerting.

```yaml
sla:
  - id: maxDuration
    type: MAX_DURATION       # or EXECUTION_ASSERTION
    duration: PT8H
    behavior: CANCEL         # CANCEL | FAIL | NONE
    labels:
      sla: miss
      reason: durationExceeded
```

Pair breach labels with a Flow trigger that alerts on `FAILED` / `CANCELLED` executions
labeled `sla: miss`.

## Input typing

Tighten loose `STRING` inputs into constrained types — a cheap, high-value guardrail.

```yaml
inputs:
  - id: environment
    type: SELECT             # constrained set instead of free STRING
    values: [dev, staging, prod]
    defaults: dev
  - id: api_token
    type: SECRET             # never a plain STRING for credentials
```

---

## Hygiene

- **Subflow extraction** — flows over ~100 TaskRuns degrade; isolate heavy sections into a `Subflow` task (new execution = isolated context).
- **Large outputs** — set `store: true` / use `stores` so big data is written to internal storage and only a URI rides in the execution context (the context has a ~1 MB practical limit). With `store: true`, read `{{ outputs.task.uri }}`, not `.value`.
- **Descriptions / labels / naming** — add `description` to flow and non-obvious tasks; add `labels` for filtering / ownership; follow namespace naming conventions.
- **Secrets** — never hardcode; use `{{ secret('NAME') }}` or `SECRET`-typed inputs.

---

## Platform-fit & maintainability (advisory)

These are **recommendations, not hardening** — never a severity, never a blocker. Report them
in the separate **Advisory** section. They reduce the amount of custom code a user maintains.

### Long inline script → Namespace File + `Commands`

When a `Script` task carries a large inline block, move the code to a Namespace File and call
it from a `Commands` task. The code becomes versioned (revision history), testable, editable in
the Code Editor, and reusable across flows. Pass values via `env`.

```yaml
# BEFORE — long inline logic in the flow YAML
- id: transform
  type: io.kestra.plugin.scripts.python.Script
  beforeCommands: ["pip install pandas requests"]
  script: |
    import pandas as pd, requests, os
    # ...40+ lines of real logic...
```

```yaml
# AFTER — code lives in a Namespace File (e.g. scripts/transform.py)
- id: transform
  type: io.kestra.plugin.scripts.python.Commands
  namespaceFiles:
    enabled: true
    include:
      - scripts/transform.py     # only mount what this task needs
  beforeCommands: ["pip install pandas requests"]
  commands: ["python scripts/transform.py"]
  env:
    INPUT_URI: "{{ inputs.uri }}"   # Commands receive values via env, not templating
```

- `namespaceFiles.enabled: true` mounts files into the working directory (needed when a CLI
  command reads them from disk). Use `include` to mount only what's required.
- For a `Script` task that takes a string, you can instead inline the file content with
  `script: "{{ read('scripts/transform.py') }}"` — no mounting needed. `read()` resolves files
  from the **same namespace** as the flow.

### Script duplicating plugin functionality → native plugin

When a script reimplements something a plugin already does, recommend the native task — but
**verify the task exists via `mcp__kestra__task_schema` before naming it**.

```yaml
# BEFORE — shell task wrapping curl
- id: fetch
  type: io.kestra.plugin.scripts.shell.Commands
  commands:
    - curl -s "https://api.example.com/data" -o out.json
```

```yaml
# AFTER — native HTTP task (typed outputs, retries, no shell/JSON plumbing)
- id: fetch
  type: io.kestra.plugin.core.http.Download
  uri: https://api.example.com/data
```

Common mappings (confirm via `task_schema` / `list_plugins`):

| Scripted with | Prefer native plugin |
|---------------|----------------------|
| `curl` / `wget` / `requests` | `io.kestra.plugin.core.http.Request` / `Download` |
| `psql` / `mysql` / `sqlite3` | `io.kestra.plugin.jdbc.*` Query / Queries |
| `aws` / `gcloud` / `az` CLI | `io.kestra.plugin.aws|gcp|azure.*` |
| `dbt` commands | `io.kestra.plugin.dbt.*` |
| `git clone` | `io.kestra.plugin.git.Clone` |

> If Namespace Files are available in context, read them and assess how much of the scripted
> logic maps to native tasks — quantify it ("~X of N steps map to native plugin tasks") so the
> user can judge the migration effort.
