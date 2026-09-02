# kestra-ops operational workflow

How to run a `kestra-ops` request safely. Load this when the task is about *how* to
sequence and decide an operation, not just which command to type — command
signatures live in [`commands.md`](commands.md).

## Standard workflow

1. Confirm `kestractl` is present and meets the minimum version — run
   [`../scripts/ensure-kestractl.sh`](../scripts/ensure-kestractl.sh) (dry-run;
   installs only with `--install`). Note the resolved version for the report.
2. Resolve and confirm the target context (host, tenant, context name) and the
   **Kestra edition** (OSS / EE) — see Edition awareness below.
4. Run read-only discovery first (`list` / `get` / `search*`).
5. Validate artifacts before any write (`flows validate`, `dashboards validate`,
   `test-suites validate`).
6. Execute the requested operation with explicit flags — never rely on defaults for
   `--namespace`, `--override`, `--fail-fast`.
7. Verify outcomes: `--wait` / `executions watch` for runs, a follow-up `get` /
   `list` for writes.
8. Return a concise ops report (see Ops report format).

## Edition awareness

The user states the edition up front (it is a required input). Do not probe for it.

- **EE-only command groups:** `dashboards`, `apps`, `assets`, `test-suites`, `users`,
  `groups`, `roles`, `service-accounts`, `bindings`, `invitations`, and the
  `blueprints flow` / `blueprints custom` subcommands. Everything else is OSS.
- If the request needs an EE-only group and the edition is OSS (or unknown):
  **stop and say so** — name the group, state that it requires EE, and offer the
  closest OSS alternative if one exists. Do not run the command "to see if it works".
- If the edition is unknown and the request is OSS-only, proceed and note the
  assumption in the report.
- An EE command run against OSS returns an authorization/edition error — handle it
  per the failure-handling section, do not retry.

## Per-group decision notes

**flows** — Discovery: `list`, `get`, `dependencies`, `namespace-dependencies`.
Always `flows validate` before `flows deploy`. `deploy` of a directory is a bulk
write: set `--namespace` explicitly, use `--override` only when replacing is
intended, `--fail-fast` to stop on first error. Before any destructive change to a
live flow (`delete`, `namespace-sync --delete`, `bulk-update`), check `flows
revisions` so a rollback target is known; `delete-revisions` is irreversible.
`namespace-sync ... --delete` removes flows absent from the file — confirm the file
is complete first.

**executions** — `run` starts a write (the flow does whatever it does). Use `--wait`
(or `executions watch`, which exits non-zero on failure) when the caller needs the
result inline and the flow is short/bounded; use fire-and-poll (`run`, then
`executions get <id>`) for long-running flows or when you only need the execution
ID. State-control verbs (`kill`, `pause`, `resume`, `restart`, `replay`,
`force-run`, `change-status`) act on live executions — confirm the target ID and
current state first. `delete-by-query --delete-logs --delete-storage` is
destructive and wide — always dry-run the matching `executions list` with the same
filters first and report the count.

**triggers** — Discovery: `list`, `search-for-flow`. `enable` / `disable` /
`update --disabled` change scheduling behavior on a live flow — confirm before prod.
`unlock` clears a stuck lock (safe, but note why it was locked). Backfills
(`create-backfill`, `*-backfill-by-query`) can enqueue a large number of
executions — confirm the `--start` / `--end` window and expected volume before
running.

**kv** — `list` / `get` are safe. `set` overwrites silently; `update` fails if the
key is absent (use it when you mean "must already exist"). `delete` is immediate
with no revision history. Namespace KV values may be read by running flows — treat
prod writes as production changes.

**nsfiles** — `list` / `get` are safe. `upload` of a directory nests the source
dir name under the destination unless `--no-root` is passed (see `commands.md`).
`delete --recursive` removes a whole subtree; confirm the path scope and prefer a
prior `list --recursive` to show exactly what will go. `--force` only to ignore
missing targets, never as a reflex.

**blueprints** — `community search` / `community get` / `community source` are
read-only and OSS — safe for discovery and for pulling a starting flow YAML.
`blueprints flow` / `blueprints custom` are EE.

**plugins** — Offline plugin-JAR download for self-hosted deployments; does not
touch the running instance. Read-mostly and safe.

**workers** — `registration-tokens generate` runs offline, no instance required.
Safe.

## Cross-cutting decision rules

- **`--output json` for anything you parse or report on.** Reserve `table` for
  output shown directly to a human with no further processing. Never screen-scrape
  `table`.
- **Prefer `*-by-query` / `*-bulk` over a scripted loop** of single-item commands
  (`delete-by-query`, `disable-by-query`, `set-labels-by-query`, `*-bulk`, ...):
  one atomic server-side operation, one result to report. Before running a
  `*-by-query` **write**, run the matching read (`list` with the same `--namespace`
  / `--filter`) and report how many items match.
- **`--wait` vs. poll:** `--wait` / `watch` for short bounded runs where the result
  is needed now; `run` + later `executions get` for long or fire-and-forget runs.
- **Revision-awareness:** inspect `flows revisions` before deleting or force-syncing
  a live flow; `delete-revisions` is irreversible.
- **Explicit flags always:** `--namespace`, `--override`, `--fail-fast`, `--yes`
  are never assumed — pass them deliberately or not at all.

## Guardrails

- Confirm production context before any write (`deploy`, `run`, `upload`, `delete`,
  `set`, `enable` / `disable`, `*-by-query`, `*-bulk`, `namespace-sync`).
- Validate before deploy (`flows validate`, `dashboards validate`,
  `test-suites validate`).
- `--output json` for anything parsed or reported; `table` only for direct display.
- Never `--verbose` in shared logs — it prints credentials in HTTP requests.
- Destructive actions (`delete`, `delete-revisions`, `delete-by-query`,
  `nsfiles delete --recursive`, `namespace-sync --delete`): confirm scope, show the
  matching read first, use `--force` / `--yes` only intentionally.
- Never auto-run an EE command against an OSS instance to test edition.
- Prefer env vars or the config file over credential flags on the command line —
  `KESTRACTL_TOKEN` over `--token`, `KESTRACTL_USERNAME` / `KESTRACTL_PASSWORD` over
  `--password` (both land in shell history and the process list).

## Ops report format

- Context used (host, tenant, context name, edition, kestractl version)
- Commands executed (grouped by read vs write)
- Results (success / failure and key IDs; for bulk ops, counts per outcome)
- Risks, rollback notes, and follow-up actions
