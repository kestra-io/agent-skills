---
name: kestra-ops
description: Operate Kestra environments using kestractl for context setup, flow inspection, flow validation and deployment, execution monitoring, namespace operations, and namespace file management. Use when users request Kestra operational CLI tasks in dev, staging, or production.
compatibility: Requires kestractl, network access to the Kestra API, and valid tenant/token credentials.
---

# Kestra Operations Skill

Use this skill to perform day-to-day Kestra operations with `kestractl`.

This SKILL.md is the entry point. Detailed material lives in `references/` and is
loaded on demand — pull in only what the current request needs:

| Load when the request involves | Reference |
|--------------------------------|-----------|
| Any command beyond the cheat-sheet below — the full `kestractl` surface (`flows`, `executions`, `triggers`, `namespaces`, `kv`, `nsfiles`, `plugins`, `workers`, `logs`, `secrets`, `server`, `blueprints`, and EE-only groups), pinned to a kestractl release | [`references/commands.md`](references/commands.md) |
| Deciding *how* to run an operation — edition (OSS/EE) awareness, per-group decision notes, discovery vs. write ordering, `--wait` vs. poll, `*-by-query` vs. loop, revision-awareness, guardrails, and the ops report format | [`references/workflow.md`](references/workflow.md) |

## When to use

Use this skill when the request includes:
- Listing, inspecting, validating, or deploying flows
- Triggering executions and checking execution status
- Managing namespaces or namespace files (`nsfiles`)
- Configuring or switching Kestra CLI contexts

## Required inputs

- Target environment or context (`dev`, `staging`, `prod`)
- Host URL, tenant, and authentication method (usually token)
- Kestra edition (OSS / EE) — gates the EE-only command groups; ask once if unknown
- Namespace, flow ID, execution ID, and/or local file paths
- Output preference (`table` for human-readable, `json` for automation)

## Prerequisites

- `kestractl` is installed and executable
- Access token and tenant are available
- A valid context exists in `~/.kestractl/config.yaml`, or values are provided via env vars / flags

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

## Most common commands

The everyday subset — for anything else, load [`references/commands.md`](references/commands.md):

```bash
kestractl flows list my.namespace
kestractl flows validate ./flows/
kestractl flows deploy ./flows/ --namespace prod.namespace --override --fail-fast
kestractl executions run my.namespace my-flow --wait
```

## Example prompts

- "Use `kestra-ops` to validate and deploy all flows in `./flows` to `prod.namespace` with fail-fast enabled, then report what changed."
- "Use `kestra-ops` to run `my-flow` in `my.namespace`, wait for completion, and summarize execution status."
- "Use `kestra-ops` to upload `./assets` to namespace files under `resources` with override enabled, then list uploaded files recursively."
