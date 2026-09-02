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
| Deciding *how* to run an operation — edition (OSS/EE) awareness, per-group decision notes, discovery vs. write ordering, `--wait` vs. poll, `*-by-query` vs. loop, revision-awareness, failure handling, guardrails, and the ops report format | [`references/workflow.md`](references/workflow.md) |
| `kestractl` is missing, or older than this skill expects | [`scripts/ensure-kestractl.sh`](scripts/ensure-kestractl.sh) — dry-run check + on-request install/upgrade |

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

- **`kestractl` present and current.** Run [`scripts/ensure-kestractl.sh`](scripts/ensure-kestractl.sh)
  first — it is a no-op if `kestractl` is on `PATH` and meets the minimum version
  (`1.16.0`). If it reports missing or stale:
  1. Show the user the printed **PLAN** and the two install-dir choices — `~/.local/bin`
     (user home scope) or `<skill>/scripts/bin` (self-contained). Get an explicit OK.
  2. Re-run with `--install --install-dir <their choice>`. The script uses the official
     published installer (`curl … install-scripts/install.sh | bash`, which does OS/arch
     detection + sha256 verification). Never a system path, never `sudo`.
  3. Surface the resolved `kestractl` version in the ops report.
- **A connection context.** After a fresh install, or when none exists, **ask** the user
  whether to add one (don't assume): `kestractl config add <name> <host> <tenant> …
  --default` — `--username`/`--password` for OSS, `--token` for Enterprise. See
  Configuration precedence below.
- Tenant plus one of: an API token, or username/password (basic auth).

## Configuration precedence

Resolve config from highest to lowest precedence:
1. Command flags (`--host`, `--tenant`, `--token` or `--username`/`--password`, `--output`)
2. Environment variables (`KESTRACTL_HOST`, `KESTRACTL_TENANT`, `KESTRACTL_TOKEN` or `KESTRACTL_USERNAME`/`KESTRACTL_PASSWORD`, `KESTRACTL_OUTPUT`)
3. Config file (`~/.kestractl/config.yaml`)
4. Built-in defaults

**Never paste a real token or password as a literal CLI argument** — it lands in
shell history and the process list (`ps`). Use one of the two patterns below.

Preferred — environment variables (nothing persisted, read on every command):

```bash
export KESTRACTL_HOST="https://prod.kestra.io"
export KESTRACTL_TENANT="production"
export KESTRACTL_TOKEN="$(cat ~/secrets/kestra_token)"   # or KESTRACTL_USERNAME + KESTRACTL_PASSWORD
kestractl flows list my.namespace
```

Alternative — persist a context. Pass the secret via a shell variable, not a
literal, and lock down the file:

```bash
kestractl config add dev http://localhost:8080 main --token "$KESTRACTL_TOKEN"                       # token auth
kestractl config add oss http://localhost:8080 main --username "$KESTRACTL_USERNAME" --password "$KESTRACTL_PASSWORD"  # basic auth -> auth_method: basic
chmod 600 ~/.kestractl/config.yaml
kestractl config use dev
kestractl config show
```

`config add --token` / `--password` are plain flags (not env-bound), so the value
must be on the line — keep it a `$VAR` reference, never the secret itself.

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
