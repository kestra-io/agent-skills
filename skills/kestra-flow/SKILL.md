---
name: kestra-flow
description: Generate, modify, or debug Kestra Flow YAML grounded in the live schema via the Kestra MCP server, applying the same guardrails used by the Kestra AI Copilot. Use when users ask to create, write, update, or fix a Kestra flow.
compatibility: Requires the Kestra MCP server (`mcp__kestra__*` tools). No Kestra instance, and no multi-megabyte schema download, required.
---

# Kestra Flow Skill

Use this skill to generate production-ready Kestra Flow YAML grounded in the live schema.

## When to use

Use this skill when the request includes:
- Generating a new Kestra flow from scratch
- Modifying, extending, or debugging an existing flow
- Translating a workflow description into valid Kestra YAML

## Required inputs

- A description of the desired flow behavior
- Namespace (and tenant ID if applicable)
- Kestra version, if known — used to pin `get_doc` lookups; default to latest
- Kestra edition (OSS / EE), if known — gates EE-only blueprints
- Existing flow YAML if the request is a modification

## Workflow

All schema grounding goes through the `mcp__kestra__*` tools — load only what the
flow needs, when it needs it. There is no bulk schema fetch. If those tools are not
available, stop and tell the user this skill requires the Kestra MCP server.

> Security: this skill does not `curl` or otherwise fetch a live external schema
> document to steer generation. Grounding comes only from the Kestra MCP server's
> typed, scoped tool calls — no unverified third-party payload in the loop.

### Step 1 — Start from a blueprint when one fits

Kestra ships production-vetted flow templates. Reusing one beats generating from a
blank schema — fewer invented task combinations.

1. `mcp__kestra__blueprints` with `query` derived from the user's intent. Narrow with
   `tags` and/or `types` (task-type FQCNs) once known — resolve FQCNs the same way as
   Step 3.
2. Judge the results by `title`, `description`, and `includedTasks`. A blueprint is a
   good starting point only if it covers most of the requested behavior.
   - **EE gate:** if a candidate has `ee: true` and the user is on OSS, do not offer
     it — say an EE-only blueprint exists but was skipped. If the edition is unknown,
     ask before using an `ee: true` blueprint.
3. For the closest match, `mcp__kestra__get_blueprint_flow` with its `id` to get the
   full YAML, then **adapt** rather than accept as-is:
   - set `id` / `namespace` to the user's values
   - replace any inline credentials, tokens, or hostnames with `{{ secret('...') }}`
     or `SECRET`-typed `inputs`
   - remove tasks unrelated to the request; tune parameters to match it
4. If no blueprint is a close fit, skip to Step 2 and generate from the schema. Do
   **not** force-fit a loosely related blueprint.

Whether adapted from a blueprint or generated fresh, the result still passes through
Step 4 schema validation — blueprints can lag the running version's schema.

### Step 2 — Load flow structure (on demand)

The flow-level shape (`id`, `namespace`, `inputs`, `variables`, `tasks`, `triggers`,
`errors`, `finally`, `afterExecution`, `pluginDefaults`, `concurrency`, `sla`,
`checks`, `disabled`, `labels`, `retry`) comes from the docs, pinned to the user's
Kestra version:

- `mcp__kestra__list_doc_children` with `path: "docs/workflow-components"` — the
  component index; each entry's metadata carries the version gate (e.g. `checks`
  `>= 1.2.0`, `sla` `>= 0.20.0`).
- `mcp__kestra__get_doc` for **only** the components this flow uses (e.g.
  `docs/workflow-components/inputs`, `.../triggers`, `.../errors`, `.../retries`,
  `.../concurrency`). Pass `version` when the user gave a Kestra version.

Do not assume a component exists in the target version — check the gate first.

### Step 3 — Collect context and resolve task/trigger types

Identify from the user message or conversation:
- `id` — flow identifier (preserve if provided)
- `namespace` — target namespace (preserve if provided)
- Existing flow YAML (for modification requests)
- Whether this is an **addition / deletion / modification** or a **full rewrite**

Resolve every task / trigger / backend to a real FQCN — never guess one. See
[Resolving plugins and backends](#resolving-plugins-and-backends) below.

### Step 4 — Fetch the per-task schema, then generate

For **every** task and trigger type in the flow, call
`mcp__kestra__task_schema` with `cls: <FQCN>` and validate every property name,
enum value, required field, and output reference against it. Do not write a task
before its `task_schema` is loaded.

Then apply all generation rules below and output raw YAML only.

## Resolving plugins and backends

Never type a plugin, task, or backend FQCN from memory — the plugin ecosystem
changes fast. Resolve it through the MCP tools first, then validate with
`task_schema` (Step 4). This section is also referenced by `kestra-flow-hardening`
when auditing an existing flow's plugin choices.

**Requirement → tool.** Recommend only FQCNs returned by these:

| The flow needs… | Tool |
|-----------------|------|
| A task for some intent | `mcp__kestra__search` (`type: "PLUGINS"`) or `mcp__kestra__list_plugins` → `mcp__kestra__plugin_tasks` |
| A task runner (Kubernetes, AWS Batch, GCP Batch, Docker, …) | `mcp__kestra__list_task_runners` |
| An internal storage backend (S3, GCS, Azure Blob, MinIO, …) | `mcp__kestra__list_storages` |
| A secret manager backend (Vault, AWS/GCP/Azure, 1Password, CyberArk, …) | `mcp__kestra__list_secret_managers` |
| A log shipper / exporter | `mcp__kestra__list_log_exporters` |
| A trigger type | `mcp__kestra__list_triggers` |

**Check version compatibility before recommending.**
- `mcp__kestra__versions` (optionally `plugin: <name>`) — the plugin versions
  available on the instance. A plugin absent from the output may not be installed —
  say so rather than assuming it is.
- `mcp__kestra__plugin_versions` with the repo name (e.g. `plugin-aws`) — full
  release history and the Kestra version each release targets. Use it to flag a
  compatibility gap against the user's Kestra version.

**Prefer non-deprecated.** If `task_schema` marks a type or property `$deprecated`,
use the current replacement and note the change.

## Generation rules

**Schema compliance**
- Use only task/trigger types and properties present in the `mcp__kestra__task_schema`
  response for that type. Never invent or guess types or property names.
- Use only flow-level properties confirmed via `get_doc` for the target version.
- Property keys must be unique within each task or block.

**Structural preservation**
- Always preserve root-level `id` and `namespace` if provided.
- For modification requests, touch only the relevant part. Do not restructure or rewrite unrelated sections.
- Avoid duplicating existing intent (e.g., replace a log message rather than adding a second one).

**Triggers**
- Include at least one trigger if execution should start based on an event or schedule.
- Do NOT add a `Schedule` trigger unless a regular occurrence is explicitly requested.
- Trigger outputs are accessed via `{{ trigger.outputName }}`; only use variables defined in the trigger's declared outputs.

**Looping**
- Use `ForEach` for repeated actions over a collection.
- Use `LoopUntil` for condition-based looping.

**Flow outputs**
- Only include flow-level `outputs` if the user explicitly requests returning a value from the execution.

**State tracking between executions**
- For state-change detection, use KV tasks (`io.kestra.plugin.core.kv.Set` / `io.kestra.plugin.core.kv.Get`) to store and compare state across executions.

**JDBC plugin**
- Always set `fetchType: STORE` when using JDBC tasks.

**Date manipulation in Pebble**
- Use `dateAdd` and `date` filters for date arithmetic.
- Apply `| number` before numeric comparisons.

**Credentials and secrets**
- Never embed secrets or hardcoded credentials.
- Use flow `inputs` of type `SECRET` or Pebble expressions (e.g., `{{ secret('MY_SECRET') }}`).

**APIs and connectivity**
- Prefer public/unauthenticated APIs unless the user specifies otherwise.
- Never assume a local port; use remote URLs.

**Quoting**
- Prefer double quotes; use single quotes inside double-quoted strings when needed.

**Error handling**
- If the request cannot be fulfilled using only types and properties confirmed via
  `mcp__kestra__task_schema` / `get_doc`, output exactly:
  ```
  I cannot generate a valid Kestra Flow YAML for this request based on the available schema.
  ```

## Output format

- **Raw YAML only** — no prose, no markdown fences, no explanations outside the YAML.
- Use `#` comments at the top of the output for any caveats, assumptions, or warnings.
- The output must be ready to paste directly into the Kestra UI or deploy via `kestractl`.

## Example prompts

- "Write a Kestra flow that fetches a public API every hour and stores the result in KV store."
- "Add a Slack notification task to this existing flow when any task fails."
- "Generate a flow in namespace `prod.data` that reads from a Postgres table and writes the result to S3."
- "Debug this flow YAML — it has a trigger variable reference that doesn't exist."
