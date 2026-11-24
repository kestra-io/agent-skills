# First-run maintenance and hardening

Third phase after install and configuration. Covers the hygiene a fresh install needs once. Steady-state operation (flows, executions, namespaces) stays in `kestra-ops`.

Ask before changing a running instance. Check the exact config keys and task types in the Kestra docs for the installed version.

## Hardening checklist

1. **Credentials**: no default or placeholder passwords left. Admin and database secrets live in a secret manager, a `chmod 600` env file or a Kubernetes Secret.
2. **Network**: do not expose the management port (8081) or the database publicly. Put the UI behind a reverse proxy or ingress with TLS.
3. **Auth**: basic auth or SSO on. EE: roles and a non-admin identity for day-to-day use.
4. **Docker socket and dind**: remove the socket mount (Compose) or disable `dind` (Helm) when no flow runs Docker tasks.
5. **Pinned versions**: no `latest` tag. Pin the image, JAR or chart version.
6. **Resources**: set memory and CPU limits (Compose `deploy.resources`, Helm `common.resources`, JVM `-Xmx`).
7. **Backups**: schedule database backups and storage versioning, and test one restore.

## Retention and purge

Executions, logs and internal storage grow without bound. Deploy a scheduled system flow with the purge tasks `PurgeExecutions`, `PurgeLogs`, `PurgeKV` and `PurgeStorage` (the last one deletes orphaned files and defaults to `dryRun: true`). Start conservative and confirm the retention with the user, since a purge deletes data.

```yaml
id: purge
namespace: system
description: Purge executions and logs older than 30 days, run daily.

tasks:
  - id: purge_executions
    type: io.kestra.plugin.core.execution.PurgeExecutions
    endDate: "{{ now() | dateAdd(-30, 'DAYS') }}"
    purgeLog: false

  - id: purge_logs
    type: io.kestra.plugin.core.log.PurgeLogs
    endDate: "{{ now() | dateAdd(-30, 'DAYS') }}"

triggers:
  - id: daily
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "@daily"
```

Check the task properties for the installed version in the docs, validate with `kestractl flows validate`, then deploy with `kestra-ops`. Purge tasks do not touch the internal queues, which have their own retention settings. Also check the storage backend side: a bucket lifecycle rule or a local disk usage alert.

## Resource cleanup

- Compose: `docker image prune` for old Kestra images after an upgrade. Never `docker volume prune` on an install that holds data.
- Standalone: rotate journald or log files, clear the task temp directory.
- Kubernetes: remove old ReplicaSets with `common.revisionHistoryLimit`.

## Report

List what was changed and what was left to the user (backups, proxy, TLS), with owner and next step.
