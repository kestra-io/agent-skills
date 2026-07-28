# Server upgrade — 1.3 → 2.0

Official guides: `https://kestra.io/docs/migration-guide/v2.0.0/database-migrations` · `…/helm-grpc-worker-controller` · backup: `https://kestra.io/docs/administrator-guide/backup-and-restore`

## Sequence

1. **Version gate** — the instance must run **≥ 1.3.0**. Older: complete the LTS path first (`https://kestra.io/docs/migration-guide/v1.3.0/lts-migration`).
2. **Flows first** — flows carrying removed constructs fail to parse on 2.0; Phase 2 prepares them before this sequence runs (in-place path deploys them right after step 6).
3. **Verified backup — the one-way door.** 2.0 drops the JDBC queue tables on first start, irreversibly; the bcrypt password rehash breaks 1.x BasicAuth after rollback; 1.x cannot restore 2.0 backups. Take a database backup with the backend's native tool (`pg_dump`, `mysqldump`, `BACKUP DATABASE`, ES snapshots), verify it restores, and — EE — `kestra backups create FULL [--include-data]`, ideally under Maintenance Mode. Keep the 1.3 image + this backup until cutover is declared done.
4. **Stop all Kestra instances** (documented upgrade is stop-the-world; there is no supported rolling/mixed-version path).
5. **Database migrations with the 2.0 binary**:
   - `kestra migrate plan [--sql]` — read-only preview, no lock.
   - `kestra migrate run` — takes a distributed lock, single non-blocking attempt, exit 1 if the lock is held. `kestra migrate unlock` only works on Elasticsearch; on Postgres/MySQL/H2 the lock is session-scoped — kill the hung process instead.
   - **EE refuses to start with pending migrations** (`kestra.migration.auto=false` by default) — running `migrate run` manually is mandatory. **OSS auto-migrates on startup** — a fresh start of the 2.0 image is enough.
6. **Image/chart bump and start.**
7. **Verify** — pods Running; worker logs show the controller handshake on gRPC 50051; `kestra migrate plan` reports nothing pending; EE: roles verified via impersonation, Policies previewed.

## Deployment recipes

**Docker Compose** — one-off migration service, then the real server:

```yaml
services:
  kestra-migrate:
    image: kestra/kestra:v2.0.0
    command: migrate run
    environment: { KESTRA_CONFIGURATION: … }   # same config as the server
  kestra:
    image: kestra/kestra:v2.0.0
    command: server standalone
    depends_on:
      kestra-migrate: { condition: service_completed_successfully }
```

**Kubernetes** — one-time `batch/v1` Job running `/app/kestra migrate run` with the server's ConfigMap/Secrets, then roll the Deployment; `helm upgrade my-kestra kestra/kestra --version 2.0.0 -f values.yaml`.

**Helm 2.0 chart changes:** gRPC **port 50051** is exposed on all pods and the standalone Service — default-deny clusters need NetworkPolicy updates or workers fail to connect. The `workerGroups` values key is **removed** (EE): recreate groups server-side (UI/API) and join workers via a registration token (`kestra.worker.auth.registration-token`, requires `kestra.ee.worker.auth.enabled: true` + `jwt-signing-key`); the `--worker-group`/`-g` CLI flag is gone. Optional `deployments.controller` runs a dedicated controller.

**Config breaks:** `kestra.plugins.defaults` server config is removed → static Policies under `kestra.policies` (see plugin-defaults.md); a malformed static policy prevents startup — staging first. CLI: `kestra template` and `sys-ee` command groups are removed.

## Rollback reality

There is no documented rollback runbook — only constraints: restore the **pre-upgrade** backup onto 1.3 (2.0 backups don't restore on 1.x; the bcrypt rehash makes a post-upgrade DB useless to 1.x). Every step before `migrate run` is reversible; everything after is the one-way door. Say this to the user before step 4, not after.

## Field gotcha

Pointing a different 2.0 build (rc → GA → develop) at an already-migrated database fails startup with `Checksum mismatch for migration [2.0.01-upgrade]`. Same build or fresh database — relevant when a staging instance tested an RC.
