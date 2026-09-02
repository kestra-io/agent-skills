# Troubleshooting reference

A starting map from common Kestra failure signatures to the doc page that explains
them and the schema check that confirms the cause. **Not exhaustive, and not a
substitute for checking the running version** — always:

1. `mcp__kestra__search_docs` with `q` = key terms from the error and `version` set
   to the user's Kestra version.
2. `mcp__kestra__get_doc` for the top hit(s), `version` pinned.
3. `mcp__kestra__task_schema` (`cls: <FQCN>`) for any type the error names — check
   the property exists, is spelled right, and is not `$deprecated`.

Kestra pins docs per version, so a page that describes the fix as a "migration"
tells you exactly which release introduced the change.

---

## Renamed / moved / removed properties (version traps)

These surface as `Invalid property '<x>'`, `Unknown property`, schema-validation
failure on deploy, or a silently ignored setting.

| Symptom | Cause / change | Doc page | Confirm |
|---------|----------------|----------|---------|
| `maxAttempt` rejected on `retry` | renamed to `maxAttempts` in 0.24 | `docs/migration-guide/v0.24.0/retries-maxattempts` | `task_schema` for the task → `retry.maxAttempts` |
| `name:` rejected on an input | inputs use `id:` since 0.15 | `docs/migration-guide/v0.15.0/inputs-name` | `get_doc docs/workflow-components/inputs` |
| `runner:` ignored / rejected on a script task | replaced by `taskRunner:` in 0.18 | `docs/migration-guide/v0.18.0/runners` | `task_schema` → `taskRunner` |
| `scheduleConditions` rejected on Schedule trigger | renamed to `conditions` in 0.15 | `docs/migration-guide/v0.15.0/schedule-conditions` | `task_schema` for `io.kestra.plugin.core.trigger.Schedule` |
| `*Condition` type not found | conditions renamed in 0.20 | `docs/migration-guide/v0.20.0/conditions-renamed` | `list_triggers` / `task_schema` |
| `outputDir` / `LocalFiles` not working | deprecated in 0.17 — use `outputFiles` / `inputFiles` | `docs/migration-guide/v0.17.0/local-files` | `docs/scripts/input-output-files` |
| `io.kestra.core.tasks.*` type not found | core plugins renamed to `io.kestra.plugin.core.*` in 0.17 | `docs/migration-guide/v0.17.0/renamed-plugins` | `search` (PLUGINS) for the new FQCN |
| `permissions:` rejected on `PurgeAuditLogs` | renamed to `resources:` in 1.0 | `docs/migration-guide/v1.0.0/purge-audit-logs` | `task_schema` for the task |
| `autocommit` rejected on a JDBC Query | removed from query tasks in 0.23 | `docs/migration-guide/v0.23.0/jdbc-autocommit` | `task_schema` for the JDBC task |
| Flow won't save — id like `executions`, `flows`, … | reserved keywords can't be flow ids since 1.0 | `docs/migration-guide/v1.0.0/reserved-flow-ids` | — |

## Feature not available in this version

Surfaces as an unknown top-level key or a task type that doesn't resolve.

| Property / type | Available from | Doc |
|-----------------|---------------|-----|
| `concurrency` | 0.13 | `docs/workflow-components/concurrency` |
| `sla` | 0.20 | `docs/workflow-components/sla` |
| `finally` | 0.21 | `docs/workflow-components/finally` |
| `afterExecution` | 0.22 | `docs/workflow-components/afterexecution` |
| `checks` | 1.2 | `docs/workflow-components/checks` |
| Realtime triggers | 0.17 | `docs/workflow-components/triggers/realtime-trigger` |

Check the version gate in `list_doc_children docs/workflow-components` metadata before
recommending any of these.

## Expressions / Pebble

| Symptom | Likely cause | Doc |
|---------|--------------|-----|
| Expression renders literally / not resolved | non-recursive rendering since 0.14 — nested `{{ }}` isn't re-evaluated; use the `render()` function | `docs/migration-guide/v0.14.0/recursive-rendering`, `docs/expressions/functions/rendering` |
| `{{ trigger.<x> }}` is empty at runtime | that output isn't declared by the trigger type, or the flow was run manually (no trigger context) | per-trigger page under `docs/workflow-components/triggers/`, plus `task_schema` for the trigger's `outputsSchema` |
| Numeric comparison always false | value is a string — apply `| number` first | `docs/expressions` |
| Date arithmetic wrong / errors | use `dateAdd` / `date` filters, not string math | `docs/expressions/filters/dates` |
| `kv('<key>')` fails instead of returning null | `kv()` errors on missing keys since 0.22 — pass a default or guard | `docs/migration-guide/v0.22.0/kv-error-on-missing` |

## Inputs

| Symptom | Cause | Doc |
|---------|-------|-----|
| Input default not applied as expected | defaults are dynamically rendered since 1.0 | `docs/migration-guide/v1.0.0/inputs-defaults-property` |
| `prefill` behaving unexpectedly | new `prefill` property, breaking change in 1.1 | `docs/migration-guide/v1.1.0/prefill-inputs` |
| Loose `STRING` where a set is expected | tighten to `SELECT` / `ENUM` (also a hardening finding) | `docs/workflow-components/inputs` |

## Scripts

| Symptom | Cause | Doc |
|---------|-------|-----|
| Script can't see an uploaded file | `namespaceFiles.enabled: true` + `include` needed to mount, or use `inputFiles` | `docs/scripts/input-output-files`, `docs/scripts/working-directory` |
| Output file not captured | must be listed in `outputFiles` and written to the working dir | `docs/scripts/input-output-files` |
| Task WARNING on stderr no longer happens | WARNING-on-ERROR-logs removed for script tasks in 0.23 | `docs/migration-guide/v0.23.0/script-warnings` |
| `Commands` vs `Script` confusion | `Commands` mounts files / runs a CLI; `Script` takes inline code | `docs/scripts/commands-vs-scripts` |

## Flow structure & execution

| Symptom | Cause | Doc |
|---------|-------|-----|
| Subflow outputs not visible to parent | outputs behavior changed in 0.15 — subflow must declare `outputs` | `docs/migration-guide/v0.15.0/subflow-outputs`, `docs/workflow-components/subflows` |
| `ForEachItem` iteration index off by one | iteration starts at 0 since 1.1 | `docs/migration-guide/v1.1.0/foreach-item` |
| `LoopUntil` polling too fast/slow | `checkFrequency` defaults changed in 0.23 | `docs/migration-guide/v0.23.0/loop-until-defaults` |
| Concurrency `behavior` seems ignored on a triggered flow | trigger holds a lock — new trigger executions are skipped, not queued; pair with trigger `allowConcurrent` | `docs/workflow-components/concurrency` |
| `errors` / `finally` / `afterExecution` doing the wrong thing | they fire at different points — pick by intent | `docs/workflow-components/errors`, `.../finally`, `.../afterexecution` |
| Retry loops but never delays | `retry.interval` ≥ `retry.maxDuration` | `docs/workflow-components/retries` |

## Operational (hand off to `kestra-ops`)

| Symptom | Cause | Doc |
|---------|-------|-----|
| API calls / CLI rejected on 0.23+ OSS | multitenancy is mandatory — a tenant is required | `docs/migration-guide/v0.23.0` |
| CLI auth fails on 0.24+ OSS | basic auth is now required | `docs/migration-guide/v0.24.0/basic-authentication` |
| `KESTRA_<x>` env vars not picked up | flow-scoped env prefix changed `KESTRA_` → `ENV_` in 0.23 | `docs/migration-guide/v0.23.0/default-env-prefix` |
| Secret not resolving | secret backend not configured, or wrong name — `{{ secret('NAME') }}` | `docs/concepts/secret`, `docs/how-to-guides/secrets` |
