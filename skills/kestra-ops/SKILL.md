# Skill: kestra-ops

## Purpose

Help an agent operate Kestra instances using `kestractl` for day-to-day flow, execution, namespace, and namespace-file operations.

## When to use

Use this skill when the request includes:
- Listing, inspecting, validating, or deploying flows
- Triggering or checking executions
- Managing namespaces or namespace files (`nsfiles`)
- Setting up or switching Kestra CLI contexts

## Inputs expected

- Target environment/context (dev, staging, prod)
- Host URL, tenant, and authentication method (usually token)
- Namespace, flow ID, execution ID, and/or file paths
- Output preference (`table` for humans, `json` for parsing)

## Prerequisites

- `kestractl` is installed and executable
- Access token and tenant are available
- A valid context exists in `~/.kestractl/config.yaml` or values are provided via env/flags

## Configuration model

Use this precedence (highest to lowest):
1. Command flags (`--host`, `--tenant`, `--token`, `--output`)
2. Environment variables (`KESTRACTL_HOST`, `KESTRACTL_TENANT`, `KESTRACTL_TOKEN`, `KESTRACTL_OUTPUT`)
3. Config file (`~/.kestractl/config.yaml`)
4. Built-in defaults

Common setup commands:

```bash
kestractl config add dev http://localhost:8080 main --token DEV_TOKEN
kestractl config add prod https://prod.kestra.io production --token PROD_TOKEN
kestractl config use dev
kestractl config show
```

## Workflow

1. Resolve target context and verify credentials before any write operation.
2. Run read-only discovery first (`namespaces list`, `flows list`, `flows get`, `executions get`).
3. Validate artifacts before deploy (`flows validate <file-or-dir>`).
4. Execute the requested operation with explicit flags when needed.
5. Verify results using follow-up read commands or `--wait` for execution runs.
6. Return a concise ops report with command outcomes and next actions.

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

- Confirm production context explicitly before `deploy`, `upload`, or `delete` commands.
- Prefer `flows validate` before `flows deploy`.
- Use `--output json` for automation and parsing reliability.
- Avoid verbose mode in shared logs because `--verbose` may expose credentials.
- For destructive namespace-file actions, confirm path scope and use `--force` only when intended.

## Output format

- Context used (host, tenant, context name)
- Commands executed (grouped by read/write)
- Results (success/failure and key IDs such as flow/execution)
- Risks, rollback notes, or follow-up recommendations

## Example prompts

- "Use `kestra-ops` to validate and deploy all flows in `./flows` to `prod.namespace` with fail-fast enabled, then report what changed."
- "Use `kestra-ops` to run `my-flow` in `my.namespace`, wait for completion, and summarize the execution status."
- "Use `kestra-ops` to upload `./assets` to namespace files under `resources` with override enabled, then list uploaded files recursively."
