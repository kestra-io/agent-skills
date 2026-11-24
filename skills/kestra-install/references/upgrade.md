# In-place upgrade (mechanics only)

Apply a version bump to an instance this skill (or the user) already provisioned. Deciding the target version and finding breaking changes is not this skill's job: ask the user for the target version and, if they need that analysis, point to the upgrade planning skill when it exists, or to the release notes. For 1.3 to 2.0 use `migrate-kestra-2`.

Before anything: confirm the target version and take a backup of the database and the storage. Do not continue without one. Upgrading from 1.3 to 2.0 drops the JDBC queue tables on startup and cannot be undone without a backup: use `migrate-kestra-2` for that jump.

## Steps per target

- **Docker Compose**: set `KESTRA_VERSION` in `.env` to the new tag, keep `application.yaml` and the config as is unless the target version requires a change.
  ```bash
  docker compose pull kestra
  docker compose up -d
  ```
- **Standalone**: download the new JAR next to the old one, keep the old for rollback, switch, restart.
  ```bash
  sudo systemctl stop kestra
  sudo mv /opt/kestra/kestra.jar /opt/kestra/kestra.jar.prev
  # place the new kestra.jar in /opt/kestra, verify its checksum
  sudo systemctl start kestra
  ```
- **Kubernetes**: upgrade with the target chart or app version, keeping the values file.
  ```bash
  helm repo update
  helm upgrade kestra kestra/kestra -n kestra -f values.yaml --version <chart-version>
  kubectl -n kestra rollout status deployment/<name>
  ```

## Plugins

Re-run the plugin provisioning against the new version and the existing config, then restart (service or Compose) or let the rollout finish (Kubernetes):

```bash
kestractl plugins download <new-version> \
  --plugins "$(kestractl plugins list <new-version> --from-config application.yaml)"
```

## Finish

Run `health.md`, including the smoke test. Pass: done. Fail: roll back (previous image tag, `kestra.jar.prev`, or `helm rollback kestra -n kestra`) and report. Database migrations may block a clean rollback, so say so when a restore from the backup is needed.

## Out of scope

Breaking-change detection, changelog review, migration doc lookups.
