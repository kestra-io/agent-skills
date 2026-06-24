---
name: kestra-flow-hardening
description: Audit one or more existing Kestra flows and add production-hardening controls — retries, timeouts, concurrency limits, error/finally/afterExecution handlers, SLAs, checks, and idempotency guards. Produces a severity-ranked findings report, then applies confirmed edits. Use when users ask to harden, audit, review, or make a flow more production-ready, resilient, or idempotent — not for authoring new flows (use kestra-flow).
compatibility: Requires curl and network access to https://api.kestra.io/v1/plugins/schemas/flow. No Kestra instance required.
---

# Kestra Flow Hardening Skill

Audit existing Kestra flows, surface resilience / idempotency / guardrail gaps as a
severity-ranked report, then apply the edits the user confirms.

This is the **auditing** counterpart to the sibling skills:

| Skill | Owns |
|-------|------|
| `kestra-flow` | **Authoring** — create / modify / debug flow YAML from intent |
| **`kestra-flow-hardening`** | **Auditing** — find gaps, recommend + apply guardrails |
| `kestra-ops` | **Operating** — validate / deploy / run via `kestractl` |

Hand off to `kestra-flow` for "build a new flow" and to `kestra-ops` for "validate / deploy this".

## When to use

Trigger on requests to **harden, audit, review, or make production-ready / resilient / idempotent**:
- "Harden this flow / these flows for production."
- "Audit my flow — what's missing for reliability?"
- "Add retries, timeouts, and error handling to this flow."
- "Review this namespace's flows for resilience gaps."

Do **not** use this skill to author a brand-new flow from a description — that is `kestra-flow`.

## Required inputs

- One or more flows, in priority order:
  1. Inline YAML pasted into the chat
  2. File path(s), glob, or directory (e.g. `./flows/`, `./flows/*.yml`)
  3. Live instance — flows fetched via `kestra-ops` / `kestractl` (the user pairs the skills; this skill does not require a running instance)
  4. A namespace / directory batch
- **Kestra version and edition (OSS / EE).** Ask once if unknown; default to **latest OSS**. Used to gate version-/edition-specific recommendations.

## Workflow

### Step 1 — Fetch the flow schema (authoritative)

```bash
curl -s https://api.kestra.io/v1/plugins/schemas/flow
```

Read the raw JSON. The schema is the **source of truth** for which properties and types
exist in the target version. Never recommend a property absent from the schema — this is
what catches version traps such as `retry.maxAttempt` (pre-0.24) vs `retry.maxAttempts`.

### Step 2 — Confirm scope and context

- Resolve the input form (paste / file / glob / dir / namespace).
- Confirm version + edition (default latest OSS if not given).
- For a directory or namespace, gather **all** target flows before reporting.

### Step 3 — Calibrate by flow signals (proportionality)

Hardening must be proportional to what the flow does and where it runs. Read these
signals and tailor the audit — do **not** apply a fixed checklist to every flow:

- **Triggers / scheduling** present → concurrency, SLA, and overlap behavior become relevant; a manually-run flow needs them far less.
- **Real side-effects** (writes, external calls, cloud jobs, scripts) → resilience and idempotency findings matter; a pure-compute or log-only flow does not need them.
- **Namespace as env hint** — `prod.*` / `staging.*` raises the bar; `dev.*` / `sandbox.*` / `tutorial.*` gets a lighter touch ("this looks like dev — hardening deferred unless you're promoting it").
- **Controls already present** → acknowledge them; never re-flag what's already there.

**Never invent risk.** If a flow is genuinely sound, returning *"No critical or high findings;
this flow is reasonably hardened"* is a correct, encouraged outcome. Do not manufacture
Low-severity nits to look busy.

### Step 4 — Run the audit taxonomy

Evaluate each relevant dimension. For exact, copy-pasteable YAML per construct and the
"when to apply / when NOT to" guidance, load
[`references/hardening-patterns.md`](references/hardening-patterns.md).

**Resilience**
- Retries on transient-failure-prone tasks (HTTP, JDBC, cloud APIs) — see idempotency tiers below.
- Timeouts on every runnable task (scripts, queries, cloud jobs — hang and cost control).
- Flow-level `retry` where whole-execution replay makes sense.

**Failure handling**
- `errors` (global) for alerting; local `errors` inside flowable tasks for targeted cleanup.
- `finally` for resource teardown (containers, temp infra) — runs while execution is still RUNNING.
- `afterExecution` for final-state-based notifications (SUCCESS / FAILED / WARNING) via `runIf`.
- `allowFailure` / `allowWarning` on genuinely non-critical tasks only.

**Concurrency & idempotency**
- `concurrency` limit + `behavior` (QUEUE / CANCEL / FAIL) for flows hitting shared / rate-limited systems.
- Idempotency guard — `system.correlationId` + duplicate check (EE) or KV-based state guard (OSS).
- Trigger `allowConcurrent` / Schedule overlap behavior.

**Guardrails & contracts**
- `checks` (≥ 1.2) for pre-execution input validation.
- `sla` — `MAX_DURATION` / `EXECUTION_ASSERTION` with breach labels + alerting.
- Input typing — `SELECT` / `ENUM` / `SECRET` instead of loose `STRING`.

**Hygiene**
- Subflow extraction when a flow exceeds ~100 tasks or bloats the execution context.
- `store: true` / `stores` for large outputs instead of carrying data in the execution context.
- Descriptions, labels, naming conventions.
- No hardcoded secrets / credentials (reuse `kestra-flow`'s rule — see Shared rules below).

**Platform-fit & maintainability (advisory — not hardening, never a blocker)**
These are recommendations, not risks. They never carry a severity and never block; they
surface in a separate **Advisory** section (see report format). Use them to nudge users
toward better-maintained flows, not to gate anything.
- **Long inline scripts → Namespace Files.** A `Script` task with a large inline `script:` /
  `commands:` block (roughly > 15–20 lines, or containing real program logic) is harder to
  read, test, and version. Recommend moving the code into a **Namespace File** and calling it
  from a `Commands` task (`namespaceFiles: {enabled: true, include: [...]}`), or reading it via
  `read('path')` in a `Script` task. Kestra's own guidance: `Commands` for production
  workloads, `Script` for quick iteration.
- **Scripts duplicating plugin functionality → native plugin.** When a script reimplements
  something a Kestra plugin already does, recommend the native task — less custom code to
  maintain. Pattern-match common usage to plugin families and **verify the task exists in the
  fetched schema before naming it**:
  - `curl` / `wget` / `requests` → `io.kestra.plugin.core.http.Request` / `Download`
  - `psql` / `mysql` / `sqlite3` → the matching JDBC plugin (`io.kestra.plugin.jdbc.*`)
  - `aws` / `gcloud` / `az` CLI → the cloud plugins (`io.kestra.plugin.aws|gcp|azure.*`)
  - `dbt` → `io.kestra.plugin.dbt.*`; `git` clone → `io.kestra.plugin.git.Clone`
- **If Namespace Files are available in context**, assess how much of the scripted logic could
  be replaced by native tasks and quantify it ("~X of N steps map to native plugin tasks").

### Step 5 — Classify each finding by severity

| Severity | Definition | Example |
|----------|------------|---------|
| **Critical** | Will cause data corruption, duplicate side-effects, or silent loss in production | Retry / `allowFailure` on a non-idempotent write; no concurrency limit on non-atomic state updates; hardcoded secret |
| **High** | Will cause outages / hangs / cost-blowouts or undetected failures | No timeout on a cloud / script task; no `errors` alerting; no SLA on a business-critical schedule |
| **Medium** | Degraded resilience / recoverability | Missing transient retries on HTTP / JDBC; no `finally` teardown leaking resources; loose input typing |
| **Low** | Hygiene / maintainability | Missing descriptions / labels; naming; large-output `store` unset |

Platform-fit recommendations (long scripts → Namespace Files; scripts → native plugins) are
**not** assigned a severity. They are reported separately as **Advisory** and never block.

### Step 6 — Apply the idempotency judgment (before recommending retries)

A retry is good advice for a flaky read and **catastrophic** for a non-idempotent write
(double-charge, duplicate insert). Classify every candidate task before recommending:

| Tier | How detected | Retry recommendation |
|------|--------------|----------------------|
| **Safe** | Read-only by type (HTTP GET, SELECT, fetch / list, Log) | Recommend retries freely |
| **Conditionally safe** | Write with a natural idempotency key, or transactional / upsert task | Recommend retries **with the precondition stated** |
| **Unsafe / unknown** | Opaque scripts, POST / PUT to unknown endpoints, non-transactional writes | **Do NOT recommend a blind retry.** Flag the idempotency question in the report with **both branches**: dedup guard (correlationId / KV) vs. retry-if-safe. Let the user decide at confirm-time. |

### Step 7 — Emit the report

Format (findings numbered **globally** so the user can select by number):

```
## Hardening audit: <flow id> (<namespace>, v<X.Y>, OSS/EE)

### Critical
1. **<title>** — `tasks.<id>`
   Risk: <what breaks in production if unfixed>
   Caveat: <e.g. only safe if this endpoint dedupes on a key>
   Proposed: <the edit, or both branches for unknown-safety tasks>

### High
2. ...

### Medium
### Low

### Advisory (platform-fit) — not hardening, optional
- **Long inline script** — `tasks.transform`
  Move the ~40-line script into a Namespace File and call it from a `Commands` task
  (versioned, testable, editable in the Code Editor).
- **Script duplicates a plugin** — `tasks.fetch`
  This `curl` shell task can be `io.kestra.plugin.core.http.Request` (verified in schema).

---
Summary: N Critical · N High · N Medium · N Low · N Advisory
Reply with the numbers to apply (e.g. `1,4,7`), `all`, or `none`.
```

- Group by severity; each finding states **risk + caveat + proposed fix + severity**.
- **Diffs are deferred to confirm-time** — keep the report scannable.
- Mark **structural edits** (idempotency-guard insertion, flow-level retry behavior) clearly, since they add tasks rather than tweak one line.
- **Batch**: emit one consolidated report ranked by severity **across all flows**, with a per-flow summary table; then edit flow-by-flow on confirm.
- **EE-only findings** (e.g. correlationId guard): always label as EE, give the OSS fallback (KV guard), and frame the EE path as a value-add.

### Step 8 — Apply confirmed edits

On `apply 1,4,7` / `all`:
- **Surgical, structure-preserving edits.** Touch only the relevant tasks / blocks. Preserve root `id` / `namespace`, task ordering, and comments. Never restructure unrelated parts.
- **File input** → edit the file in place. **Pasted YAML** → return the modified YAML. **Batch** → edit each file.
- **Re-validate** every edit against the fetched schema (properties and types must exist).
- The initial number-selection **is** informed consent (the report already stated each risk / caveat) — do not re-prompt per finding, but show the diff as you apply it.
- Suggest `kestractl flow validate` (via `kestra-ops`) as an optional final gate; do not require a live instance.

## Shared rules (inherited from `kestra-flow`)

Do not restate — reuse the `kestra-flow` skill's rules so they don't drift:
- Schema compliance — only schema-defined task types and properties.
- No hardcoded secrets / credentials — use `inputs` of type `SECRET` or `{{ secret('...') }}`.
- Quoting — prefer double quotes; single quotes inside when needed.
- Structural preservation — touch only the relevant part; preserve `id` / `namespace`.

## Example prompts

- "Harden this flow for production." *(inline paste)*
- "Audit `./flows/ingest.yml` and add retries and timeouts where safe."
- "Review all flows in `./flows/` for resilience gaps and rank them worst-first."
- "Make this scheduled flow idempotent — it sometimes runs twice." *(idempotency tier judgment)*
- "Add alerting and an SLA to this business-critical flow."
