---
name: kestra-flow
description: Generate, modify, or debug Kestra Flow YAML by fetching the live flow schema and applying the same guardrails used by the Kestra AI Copilot. Use when users ask to create, write, update, or fix a Kestra flow.
compatibility: Uses the Kestra MCP server (https://api.kestra.io/v1/mcp) when available, otherwise curl and jq with network access to https://api.kestra.io/v1/plugins/schemas/flow. No Kestra instance required.
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
- Existing flow YAML if the request is a modification

## Workflow

### Step 1 — Fetch the flow schema

If the Kestra MCP tools are available (`search`, `task_schema`, `search_docs`, `get_doc`, served by `https://api.kestra.io/v1/mcp`), use them. They return one class at a time and work where there is no shell (ChatGPT):

1. For each need that has no obvious task type (filter records, move a file, call an AI model...), call `search` first. A dedicated task usually exists (e.g. `io.kestra.plugin.transform.Filter` for filtering Ion records); do not improvise with SQL functions or scripts before checking.
2. Call `task_schema` on **every** task, trigger and task runner type you plan to use, and use only the properties listed in its `propertiesSchema`. The examples it returns can lag behind the current version: when an example uses a property that `propertiesSchema` does not list (or nests differently), follow `propertiesSchema`. `task_schema` does not resolve nested definitions: an object property such as `options` or `retry` comes back as a `$ref` to a `$defs` entry that is not included. Do not guess its sub-properties from examples. With a shell, read the definition from the full schema (`jq '.definitions["io.kestra.core.http.client.configurations.HttpConfiguration"]'`); without one, set only sub-properties confirmed by the docs page of that task (`search_docs` / `get_doc`), or leave the object out and say so.
3. Before using a Pebble filter or function you are not sure of, check its signature with `search_docs` / `get_doc` (e.g. `replace` takes a map: `replace({'a': 'b'})`).

Without the MCP tools, fall back to the schema endpoint. It is about 28 MB, so never read it whole: extract only the definitions you need.

```bash
curl -s https://api.kestra.io/v1/plugins/schemas/flow -o /tmp/kestra_schema.json
jq '.definitions["io.kestra.plugin.core.log.Log"]' /tmp/kestra_schema.json
```

Validate every type, property name, and structure used in the output against what you fetched. Do not generate anything before the schema is available.

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
- Use only task types and properties explicitly defined in the fetched schema. Never invent or guess types or property names.
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
- Use `io.kestra.plugin.core.flow.Loop` for repeated actions over a collection (`ForEach` and `ForEachItem` were removed in Kestra 2.0).
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
