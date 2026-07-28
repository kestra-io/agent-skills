# Removed constructs & mechanical fixes

## Removed types — documented alternative, or defer

For each, present the alternative with its doc link; implement on confirmation or mark the flow `deferred(reason)` in the ledger.

| Removed | Alternative |
|---|---|
| `core.execution.Count` | KV Store counters or custom logic |
| `core.execution.Resume` | manipulate execution states via the SDK/API |
| `core.trigger.Toggle` | enable/disable triggers via the API or SDK |
| Listeners | separate flows with Flow triggers (`dependsOn` the listened flow) |
| `git.Push` | `git.SyncFlows` or Git API tasks |
| `scripts.nashorn.Eval` / `FileTransform` | GraalJS (`scripts.graaljs.*`) or another script task |
| `runner:` property | `taskRunner:` with `docker.image` → `containerImage` |
| `windowAdvance` (Flow trigger) | none — discuss intent, usually `deferred` |
| EE `TEMPLATE` permissions | dropped silently — nothing to grant |
| EE `IMPERSONATE` permissions | re-grant manually as `USER: IMPERSONATE` after upgrade |
| kestractl `--permission RESOURCE:CRUD` automation | rewrite to the action model (`https://kestra.io/docs/migration-guide/v2.0.0/rbac-action-model`); the `READ` alias maps to `VIEW` only and **under-grants** |

## Mechanical fixes — batch pass (apply across all affected flows at once)

| Class | Detection | Fix | Guide page |
|---|---|---|---|
| `json()` Pebble function | `grep -rln 'json('` — **kestra-migrate misses it** | `fromJson()` (same signature; leave the `is json` test alone) | `json-function-removed` |
| Pebble `read(..., version=)` | CLI warns per line | `revision=` (no fallback) | — |
| `checks[].condition` | CLI rewrites (skipped under `--stay-v1-compatible`) | `checks[].when` (alias still parses on 2.0.0, removal scheduled) | `checks-condition-renamed-when` |
| ION binary `read()` | grep `read(` on ION-producing task outputs followed by string ops | wrap: `fromIon(read(...))` / `fromIon(read(...), allRows=true)` — unwrapped expressions **silently corrupt or throw at runtime** | `ion-binary-format` |
| `fs.local.Delete` on directories | grep type + missing `recursive:` | CLI adds `recursive: true`; confirm intent — the 2.0 default flipped to `false` and stops deleting subdirectories **without any error** | `local-delete-recursive-default` |
| Executions API consumers | audit interview | move to `GET /api/v1/{tenant}/outputs/{executionId}[/{taskRunId}]` — `taskRunList` entries lost `outputs`/`executionId`/`namespace`/`flowId`; search lost `taskRunList` | `execution-api-response` |

Guide pages live under `https://kestra.io/docs/migration-guide/v2.0.0/`.

## Smoke-test checklist (append to the ledger for Phase 4)

Silent behavior changes that parse fine and only show up at runtime:

- [ ] `fs.local.Delete` directory deletions still remove what they should (`recursive` intent confirmed)
- [ ] Expressions reading ION outputs produce correct values (`fromIon` wrapping)
- [ ] Flow triggers that depended on `PAUSED` upstream states declare it explicitly
- [ ] Multi-flow trigger consumers read `trigger.outputs.<flowId>.<key>` (scoped shape)
- [ ] EE: auto-migrated Policies reviewed; `USER: IMPERSONATE` re-granted where needed
