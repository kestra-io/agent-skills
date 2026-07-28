# CLI reference — kestra-migrate + kestractl

## kestra-migrate

Zero-config Go binary over **local YAML files** — no API access, no kestractl context, no network. Install:

```bash
curl -fsSL https://raw.githubusercontent.com/kestra-io/kestra2-flow-migration/main/install-scripts/install.sh | bash
```

One root command:

```bash
kestra-migrate --check ./flows/                        # triage: never writes, exit 1 if anything needs migration
kestra-migrate -o v2-flows/ ./flows/                   # migrate into v2-flows/ preserving directory structure
kestra-migrate --stay-v1-compatible -o out/ ./flows/   # only rules whose output still parses on 1.3
```

- Default output (no `-o`) is stdout; there is no in-place flag.
- Unchanged flows come back byte-identical, so re-running on migrated flows doubles as a CI gate (`--check` exit 0 = clean).
- `--stay-v1-compatible` skips the trigger-conditions rewrite, `checks.when`, `PurgeKV.behavior`, and `workerSelector` — the constructs 1.3 can't parse — and is the transition tool for in-place migrations that must keep deploying to 1.3 before cutover.

### Parsing its output (no JSON — strip ANSI first: `sed 's/\x1b\[[0-9;]*m//g'`)

**Migration mode**: migrated YAML to stdout/files; warnings to **stderr**, one per line, exit 0 even with warnings — read stderr, not the exit code:

```
⚠  <file>: <taskId> uses <type> (<reason>)
```

**`--check` mode** (all stdout): `✔ <name>` compatible · `✎ <name>` + unified diff (auto-rewrites) · indented `✗ <warning>` per manual item · `✗ <name>: <error>` parse failure · summary `⚠  N/M flows need migration` (exit 1) or `✔  All M flows are v2-compatible` (exit 0).

### Blind spots — grep these yourself

`kestra-migrate --check` does **not** detect two hard breaks (verified empirically):

```bash
grep -rln 'json('            <dir>   # json() Pebble function — removed; fromJson() in 2.0
grep -rln 'pluginDefaults:'  <dir>   # pluginDefaults block — fails to parse on 2.0
```

Also worth sweeping (silent behavior changes no tool flags): `fs.local.Delete` on directories without `recursive:`, `read(` on ION outputs followed by string operations, Flow triggers relying on `PAUSED` in default states.

## kestractl (export / validate / deploy)

Prefer the **kestra-ops** skill when installed. Standalone fallback:

```bash
kestractl config add <name> <host> <tenant> --username <u> --password <p>   # or --token
kestractl flows list --namespace <ns>                                       # inventory / export source
kestractl flows validate v2-flows/ --output json                            # server-side, needs a 2.0 endpoint
kestractl flows deploy v2-flows/ --override                                 # --fail-fast to stop on first error
```

`validate --output json` returns per-flow `{file_path, flow_id, success, constraints[]}`; exit 1 when any flow fails but stdout stays parseable (empty stdout = auth/host error).

**Validate-failure triage:**

| Constraint message | Meaning | Action |
|---|---|---|
| "Invalid type" | removed type or missing plugin | back to the matching pattern reference |
| "must not be null" | `secret()`/variable unresolvable at validation time | usually ignorable — confirm with the user and record in the ledger |
| "reserved keyword" | flow ID clash (`pause`, `resume`, …) | kestra-migrate already appends `-flow`; check for collisions |

**Field gotchas** (observed against real instances):

- kestractl performs client-side validation with its own model: a deploy can report `API error: ENUM is not a valid Type` while the 1.3 server **accepted and stored the flow** (ENUM is a server-side deprecated alias). After a reported failure, check server state (`flows/search`) before retrying.
- 1.3.x deploy-time validation already rejects some pre-1.3 syntax the migrate CLI has rules for (input `BOOLEAN`, `required: false` with `defaults`). Those CLI rules exist for older exports — expect them to be no-ops on flows exported from a live 1.3.
- Switching between different 2.0 builds (rc → GA → develop) over the same database trips the migration checksum guard (`Checksum mismatch for migration [2.0.01-upgrade]`) and the server refuses to start; use a fresh database or the same build.
