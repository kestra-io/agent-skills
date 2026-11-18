---
name: kestra-flow
description: Generate, modify, or debug Kestra Flow YAML by fetching the live flow schema and applying the same guardrails used by the Kestra AI Copilot. Use when users ask to create, write, update, or fix a Kestra flow.
compatibility: Requires the Kestra docs MCP server (https://api.kestra.io/v1/mcp, declared in mcp.json and .mcp.json), or a Kestra instance's own schema. No Kestra instance required.
---

# Kestra Flow Skill

Use this skill to generate production-ready Kestra Flow YAML grounded in the live plugin schemas.

## When to use

Use this skill when the request includes:
- Generating a new Kestra flow from scratch
- Modifying, extending, or debugging an existing flow
- Translating a workflow description into valid Kestra YAML

## Required inputs

- A description of the desired flow behavior
- Namespace (and tenant ID if applicable)
- Existing flow YAML if the request is a modification

## Workflow

### Step 1 — Load schemas on demand

If the user has a Kestra instance, prefer its own schema (`GET <host>/api/v1/plugins/schemas/flow`, tenant-less path). It matches the Kestra version and the plugins actually installed. The public MCP server may not have the same plugins as the user's instance.

Otherwise use the Kestra docs MCP server (`https://api.kestra.io/v1/mcp`). Never download the full flow schema, it is about 16 MB:

1. Look up the task and trigger types the request needs. Do not guess type names or scrape docs pages.
2. Fetch the schema of each type you will use. Do not generate any task before its schema was fetched.
3. Validate the whole flow before returning it. This also catches flow-level mistakes (`inputs`, `triggers`, `afterExecution`) that per-task schemas do not cover.

### Step 2 — Collect context

Identify from the user message or conversation:
- `id` — flow identifier (preserve if provided)
- `namespace` — target namespace (preserve if provided)
- Existing flow YAML (for modification requests)
- Whether this is an **addition / deletion / modification** or a **full rewrite**

### Step 3 — Generate the YAML

Apply all generation rules below, then output raw YAML only.

## Generation rules

**Schema compliance**
- Use only task types and properties explicitly defined in the fetched task schemas. Never invent or guess types or property names.
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
- Use `Loop` for repeated actions over a collection, with the element as `{{ item.value }}`. Never use `ForEach`, `ForEachItem`, `EachSequential` or `EachParallel`: they were removed in Kestra 2.0 and fail to parse.
- Use `Loop` for condition-based looping too. Check the schema for the exact properties.

**Removed in Kestra 2.0**
- Never generate `pluginDefaults` (flow, namespace, tenant or server level). It was removed in 2.0 and the flow fails to parse. Set values on each task, or hoist shared values into flow `variables:`. On Enterprise, a Policy can enforce shared values.

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
- If the request cannot be fulfilled using only schema-defined types and properties, output exactly:
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
