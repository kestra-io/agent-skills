# Pre-flight audit

Ask access, confirm the probe plan, then detect first and ask the rest. Produce a readiness report the team can share, with a complexity tier grounded in evidence — not guesses.

## 1. Access (ask first, always)

Ask these even when detection could answer them — the user sees where the agent is pointing before anything runs:

1. Where does the 1.3 instance run — URL/host, and which environment is it (prod / staging / dev)?
2. How should the agent authenticate — an existing kestractl context (its name), basic auth, or an API token? Take credentials **by reference** (context name, env var, config-file path); the report records the auth *method*, never a secret value.
3. Which tenant?

**Probe plan** — before the first probe, state the target and identity ("I'll probe `<host>` as `<identity>`; every probe is read-only") and proceed on the user's go.

## 2. Detection (run against the confirmed Access target)

| Probe | Command | Feeds |
|---|---|---|
| Migration CLI present | `kestra-migrate --version` (install: `curl -fsSL https://raw.githubusercontent.com/kestra-io/kestra2-flow-migration/main/install-scripts/install.sh \| bash`) | readiness checklist |
| kestractl present + contexts | `kestractl version`; `kestractl config show` | readiness checklist |
| Instance reachable, version, edition | `GET <host>/api/v1/configs` (tenant-less path) → `version` + `edition` | topology |
| Flow inventory | `kestractl flows list <namespace>` (positional) → counts; hard-fails on legacy aliases like `ENUM` — raw-API fallback in cli-reference.md §Field gotchas | complexity evidence |
| Flow triage | export flows locally, then `kestra-migrate --check <dir>` → N/M need migration + warning classes | complexity evidence |
| Blind-spot greps | see cli-reference.md §Blind spots | complexity evidence |

Skip any interview question below that detection already answered.

## 3. Interview (six areas)

1. **Topology** — Where does 1.3 run: docker-compose, Kubernetes + Helm, standalone, managed? (picks the upgrade recipe) · Edition OSS or EE? (policies, worker groups, RBAC, and `migrate run` behavior all branch on it) · How many environments/instances? · Database backend (Postgres/MySQL/SQL Server/Elasticsearch)?
2. **Flows** — Source of truth: Git repository or the instance only? (decides whether an export step is needed)
3. **Safety** ⚠ one-way-door — Database backup taken *and verified restorable*? (2.0 drops JDBC queue tables irreversibly; the bcrypt rehash breaks 1.x login after rollback) · EE metadata backup (`kestra backups create FULL`)? · Staging environment ready for a first migration run?
4. **Target** — In-place upgrade, or a new 2.0 instance side-by-side? Side-by-side with an existing 2.0 instance: collect its URL and auth the same way as Access — those answers become the explicit target flags on every later kestractl command (cli-reference.md §Targeting an instance).
5. **Integrations** — External consumers of the executions API? (`taskRunList` lost `outputs`/`executionId`/`namespace`/`flowId`; search responses lost `taskRunList` entirely) · Automation using kestractl role CRUD? (permission action model replaced CRUD) · EE worker groups? (Helm `workerGroups` key removed; registration tokens now required)
6. **Timeline** — Cutover constraints? The documented upgrade is stop-the-world.

**Multi-instance:** audit one instance per run — recommend staging/dev first. Record the fleet inventory in the report so later runs slot in.

## 4. Complexity tier (effort, kept separate from readiness)

| Tier | Signals |
|---|---|
| **Low** | `--check` shows only ✎ auto-rewrites, no ✗ warnings; flows in Git; no affected integrations |
| **Medium** | ✗ warnings limited to mechanical classes (Pebble `version=`, `checks.condition`, `json()`); or flows only on the instance; or moderate volume |
| **High** | Structural-rewrite warnings present (`ForEach*`, trigger conditions, `pluginDefaults`); or EE features in play (worker groups, RBAC automation); or executions-API consumers |
| **Critical** | High signals combined with fleet-wide production constraints (many instances, hard downtime limits) |

Missing backup/staging never raises the tier — it lands in the readiness checklist and risk register instead.

## 5. Report

Write `kestra-2-migration-readiness-<instance>.md` in the working directory, then give a short chat gist. Sections:

1. **Summary** — tier, headline numbers (N/M flows need migration, warning classes), recommended path.
2. **Environment inventory** — detected + declared facts; fleet table if multiple instances.
3. **Readiness checklist** — CLIs, contexts, backup ⚠, staging, 2.0 target. Phrase the backup line as an instruction: "Take and verify a database backup before any upgrade step — 2.0 drops the JDBC queue tables on startup and a pre-upgrade backup is the only way back."
4. **Flow scan results** — table by warning class → count → migration-guide link (`https://kestra.io/docs/migration-guide/v2.0.0/<page>`).
5. **Risk register** — finding · severity · impact · mitigation. Proceeding without a backup, if the user so chooses, is recorded here as an explicitly accepted risk.
6. **Recommended migration path** — the ordered next steps Phase 2 will follow, branched on the Target answer.
