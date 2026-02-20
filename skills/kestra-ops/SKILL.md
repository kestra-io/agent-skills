---
name: kestra-ops
description: Operate Kestra environments using kestractl for context setup, flow inspection, flow validation and deployment, execution monitoring, namespace operations, and namespace file management. Use when users request Kestra operational CLI tasks in dev, staging, or production.
compatibility: Requires kestractl, network access to the Kestra API, and valid tenant/token credentials.
---

# Kestra Operations Skill

Use this skill to perform day-to-day Kestra operations with `kestractl`.

## When to use

Use this skill when the request includes:
- Listing, inspecting, validating, or deploying flows
- Triggering executions and checking execution status
- Managing namespaces or namespace files (`nsfiles`)
- Configuring or switching Kestra CLI contexts

## Required inputs

- Target environment or context (`dev`, `staging`, `prod`)
- Host URL, tenant, and authentication method (usually token)
- Namespace, flow ID, execution ID, and/or local file paths
- Output preference (`table` for human-readable, `json` for automation)

## Prerequisites

- `kestractl` is installed and executable
- Access token and tenant are available
- A valid context exists in `~/.kestractl/config.yaml` or values are provided via env vars/flags

## Configuration precedence

Resolve config from highest to lowest precedence:
1. Command flags (`--host`, `--tenant`, `--token`, `--output`)
2. Environment variables (`KESTRACTL_HOST`, `KESTRACTL_TENANT`, `KESTRACTL_TOKEN`, `KESTRACTL_OUTPUT`)
3. Config file (`~/.kestractl/config.yaml`)
4. Built-in defaults

Common setup:

```bash
kestractl config add dev http://localhost:8080 main --token DEV_TOKEN
kestractl config add prod https://prod.kestra.io production --token PROD_TOKEN
kestractl config use dev
kestractl config show
```

## Standard workflow

1. Resolve and confirm the target context.
2. Run read-only discovery first.
3. Validate artifacts before any deployment.
4. Execute the requested operation with explicit flags.
5. Verify outcomes (`--wait` for run operations where needed).
6. Return a concise ops report with results and follow-up actions.

## Command patterns

Flows:

```bash
kestractl flows list my.namespace
kestractl flows get my.namespace my-flow
kestractl flows validate ./flows/
kestractl flows deploy ./flows/ --namespace prod.namespace --override --fail-fast
```

Executions:

```bash
kestractl executions run my.namespace my-flow --wait
kestractl executions get 2TLGqHrXC9k8BczKJe5djX
```

Namespaces:

```bash
kestractl namespaces list
kestractl namespaces list --query my.namespace
```

Namespace files:

```bash
kestractl nsfiles list my.namespace --path workflows/ --recursive
kestractl nsfiles get my.namespace workflows/example.yaml --revision 3
kestractl nsfiles upload my.namespace ./assets resources --override --fail-fast
kestractl nsfiles delete my.namespace workflows --recursive
```

## Guardrails

- Confirm production context before write operations (`deploy`, `upload`, `delete`).
- Prefer `flows validate` before `flows deploy`.
- Use `--output json` for scripting and automation reliability.
- Avoid `--verbose` in shared logs because it can expose credentials.
- For destructive `nsfiles` actions, confirm path scope and only use `--force` intentionally.

## Response format

- Context used (host, tenant, context name)
- Commands executed (grouped by read vs write)
- Results (success/failure and key IDs)
- Risks, rollback notes, and follow-up actions

## Example prompts

- "Use `kestra-ops` to validate and deploy all flows in `./flows` to `prod.namespace` with fail-fast enabled, then report what changed."
- "Use `kestra-ops` to run `my-flow` in `my.namespace`, wait for completion, and summarize execution status."
- "Use `kestra-ops` to upload `./assets` to namespace files under `resources` with override enabled, then list uploaded files recursively."
