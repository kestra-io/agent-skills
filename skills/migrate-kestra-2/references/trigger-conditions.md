# Trigger conditions → when / dependsOn / window / mode

Official guide: `https://kestra.io/docs/migration-guide/v2.0.0/trigger-conditions-redesign`

Two separate rewrites, both parse failures on 2.0 if left unmigrated. `kestra-migrate` handles the well-defined subset automatically (skipped under `--stay-v1-compatible`); everything it warns about lands here.

## 1. `conditions:` on any trigger → one `when:` Pebble expression

Fires when truthy, skipped when falsy. On Schedule triggers `when` filters candidate dates (skipped dates advance to the next cron match — same semantics as old conditions). Context per trigger type: Schedule → `trigger.date`; Webhook → `trigger.body`, `trigger.headers`; Flow → `namespace`, `flowId`, `state`, `labels`, `outputs`, `hasRetryAttempt`.

| Removed condition type | `when` replacement |
|---|---|
| `DayWeek` (MONDAY) | `{{ dayOfWeek(trigger.date) == 'MONDAY' }}` |
| `Weekend` | `{{ isWeekend(trigger.date) }}` |
| `Not` > `Weekend` | `{{ not isWeekend(trigger.date) }}` |
| `PublicHoliday` (FR) | `{{ isPublicHoliday(trigger.date, 'FR') }}` (optional sub-division 3rd arg) |
| `DayWeekInMonth` (MONDAY, FIRST) | `{{ isDayWeekInMonth(trigger.date, 'MONDAY', 'FIRST') }}` |
| `DateTimeBetween` | `{{ trigger.date > '…' and trigger.date < '…' }}` |
| `TimeBetween` (08:00–17:00) | `{{ hourOfDay(trigger.date) >= 8 and hourOfDay(trigger.date) < 17 }}` |
| `Expression` | the expression itself |
| several conditions | combine with `and` / `or` in one `when` |

New Pebble helpers: `isPublicHoliday`, `isDayWeekInMonth`, `isWeekend`, `isLastWorkingDay`, `dayOfWeek`, `hourOfDay`, `dayOfMonth`, `monthOfYear`.

## 2. Flow trigger `preconditions`/`multipleConditions` → `dependsOn` + `window` + `mode`

`dependsOn` entry properties: `flowId` (exact; omit = any), `namespace` (exact; prefix match via `when` + `startsWith`), `states` (default `[SUCCESS, WARNING]` — **`PAUSED` is no longer included**), `labels` (all must match), `when` (extra Pebble filter).

| Old | New |
|---|---|
| `conditions` list on Flow trigger | `dependsOn` list |
| `preconditions` block | `dependsOn` + `window` |
| `multipleConditions` block | `dependsOn` + `window.every` |
| `ExecutionStatus` | `states:` on the entry |
| `ExecutionFlow` / `ExecutionNamespace` (exact) | `flowId` / `namespace` on the entry |
| `ExecutionNamespace` (PREFIX) | `when: "{{ namespace \| startsWith('…') }}"` |
| `ExecutionLabels` | `labels:` on the entry |
| `ExecutionOutputs` | `when` with `outputs.<key>` |
| `HasRetryAttempt` | `when: "{{ hasRetryAttempt == true }}"` |
| N separate triggers for OR logic | one trigger, `mode: ANY` |
| `preconditions.resetOnSuccess: true` | `window.fireOnce: true` |
| `timeWindow: DAILY_TIME_DEADLINE` | `window.deadline` |
| `timeWindow: DAILY_TIME_WINDOW` | `window.from` + `window.to` |
| `timeWindow: DURATION_WINDOW` | `window.every` (+ `offset`) |
| `timeWindow: SLIDING_WINDOW` | `window.lookback` |

`mode`: `ALL` (default) · `ANY` · `AT_LEAST` + `minSatisfied: N`. `window` takes exactly one property group — combining groups is a validation error. `onMiss.behavior: FAIL` (peer of `window`) creates a FAILED execution when a deadline passes unsatisfied, with attachable `labels` for alerting.

```yaml
# Before                                   # After
triggers:                                  triggers:
  - id: upstream                             - id: upstream
    type: io.kestra.plugin.core.trigger.Flow    type: io.kestra.plugin.core.trigger.Flow
    preconditions:                              dependsOn:
      id: upstreams                               - flowId: flow_a
      timeWindow:                                   namespace: company.team
        type: DURATION_WINDOW                       states: [SUCCESS]
        window: PT1H                              - flowId: flow_b
      flows:                                        namespace: company.team
        - namespace: company.team                   states: [SUCCESS]
          flowId: flow_a                        window:
          states: [SUCCESS]                       every: PT1H
        - namespace: company.team
          flowId: flow_b
          states: [SUCCESS]
```

## Warn — no equivalent or silent change

- `windowAdvance` — removed with **no direct equivalent**; discuss intent with the user and mark `deferred` if it can't be expressed.
- Flow-trigger default `states` lost `PAUSED` — flows relying on it must add `states: [SUCCESS, WARNING, PAUSED]` explicitly (smoke-test item).
- `trigger.outputs.<key>` → `trigger.outputs.<flowId>.<key>` for multi-entry `dependsOn` (single-entry keeps the unscoped shorthand).
- Input-rendering failures on Flow triggers now create a FAILED execution instead of silently dropping the event.
- Accumulated window state is lost on upgrade — at most one missed trigger cycle for in-flight multi-flow triggers.
