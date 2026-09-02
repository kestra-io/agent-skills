# kestractl command reference

The `kestractl` command surface used by the `kestra-ops` skill. Load this when a request
needs a command beyond the cheat-sheet in `SKILL.md`.

> This file currently covers the command groups the skill has always supported
> (`config`, `flows`, `executions`, `namespaces`, `nsfiles`). Broader coverage
> (`triggers`, `kv`, `plugins`, `workers`, `blueprints`, and EE-only groups) and an
> in-depth reference sourced from the `kestractl` repo are tracked separately.

## Global flags

Available on every command (see `SKILL.md` → Configuration precedence for how they resolve):

- `--host` — Kestra API base URL
- `--tenant` — tenant ID
- `--token` — API token (prefer `KESTRACTL_TOKEN` — see `references/workflow.md` guardrails)
- `--output` — `table` (human) or `json` (automation / parsing)

## Config

```bash
kestractl config add dev http://localhost:8080 main --token DEV_TOKEN
kestractl config add prod https://prod.kestra.io production --token PROD_TOKEN
kestractl config use dev
kestractl config show
```

## Flows

```bash
kestractl flows list my.namespace
kestractl flows get my.namespace my-flow
kestractl flows validate ./flows/
kestractl flows deploy ./flows/ --namespace prod.namespace --override --fail-fast
```

## Executions

```bash
kestractl executions run my.namespace my-flow --wait
kestractl executions get 2TLGqHrXC9k8BczKJe5djX
```

## Namespaces

```bash
kestractl namespaces list
kestractl namespaces list --query my.namespace
```

## Namespace files

```bash
kestractl nsfiles list my.namespace --path workflows/ --recursive
kestractl nsfiles get my.namespace workflows/example.yaml --revision 3
kestractl nsfiles upload my.namespace ./assets resources --override --fail-fast
kestractl nsfiles delete my.namespace workflows --recursive
```
