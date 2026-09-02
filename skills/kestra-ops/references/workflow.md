# kestra-ops operational workflow

How to run a `kestra-ops` request safely. Load this when the task is about *how* to
sequence an operation, not just which command to type.

## Standard workflow

1. Resolve and confirm the target context.
2. Run read-only discovery first.
3. Validate artifacts before any deployment.
4. Execute the requested operation with explicit flags.
5. Verify outcomes (`--wait` for run operations where needed).
6. Return a concise ops report with results and follow-up actions.

## Guardrails

- Confirm production context before write operations (`deploy`, `upload`, `delete`).
- Prefer `flows validate` before `flows deploy`.
- Use `--output json` for scripting and automation reliability.
- Avoid `--verbose` in shared logs because it can expose credentials.
- For destructive `nsfiles` actions, confirm path scope and only use `--force` intentionally.

## Ops report format

- Context used (host, tenant, context name)
- Commands executed (grouped by read vs write)
- Results (success/failure and key IDs)
- Risks, rollback notes, and follow-up actions
