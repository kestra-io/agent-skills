# Backend configuration

One canonical `application.yaml` block, delivered three ways. Generate it once, then place it per target.

## Inputs

Repository and queue (`postgres`, `mysql`; `redis`, `elasticsearch`, `kafka` need EE or a version that supports them), storage (`local`, `s3`, `gcs`, `azure`), secret manager if any. Check the exact keys for the chosen version and edition in the Kestra docs before writing, never guess a key.

## Canonical blocks

Repository and queue on Postgres:

```yaml
datasources:
  postgres:
    url: jdbc:postgresql://${DB_HOST}:5432/kestra
    driverClassName: org.postgresql.Driver
    username: ${DB_USER}
    password: ${DB_PASSWORD}
kestra:
  repository:
    type: postgres
  queue:
    type: postgres
```

Storage, pick one:

```yaml
kestra:
  storage:
    type: s3
    s3:
      bucket: ${S3_BUCKET}
      region: ${S3_REGION}
      # Prefer an instance or workload identity. Otherwise read keys from the environment.
      accessKey: ${AWS_ACCESS_KEY_ID}
      secretKey: ${AWS_SECRET_ACCESS_KEY}
```

```yaml
kestra:
  storage:
    type: gcs
    gcs:
      bucket: ${GCS_BUCKET}
      projectId: ${GCP_PROJECT}
```

```yaml
kestra:
  storage:
    type: azure
    azure:
      container: ${AZURE_CONTAINER}
      endpoint: ${AZURE_ENDPOINT}
      connectionString: ${AZURE_CONNECTION_STRING}
```

Credentials are always `${VAR}` references or workload identity. Never write a literal secret.

## Deliver per target

| Target | Where the block goes |
|---|---|
| Standalone | `/etc/kestra/application.yaml`, secrets in `/etc/kestra/kestra.env` |
| Docker Compose | The `KESTRA_CONFIGURATION` env value of the `kestra` service, secrets in `.env` |
| Kubernetes | `configurations.application` in the Helm values, secrets in a Secret via `configurations.secrets` |

## Provision plugins from the config

Do not hand-pick plugin artifacts. `kestractl` derives the core plugins the config needs (internal storage, secret manager, queue and repository backend) and `download` takes that list:

```bash
VERSION=<kestra version>
kestractl plugins list "$VERSION" --from-config application.yaml
kestractl plugins download "$VERSION" \
  --plugins "$(kestractl plugins list "$VERSION" --from-config application.yaml)"
```

Bundled backends (local storage, JDBC, Kafka) emit no plugin, so an empty list is normal for Postgres with local storage. This covers backend plugins only. For task plugins, add `kestractl plugins list "$VERSION" --edition OSS` (or `EE`) as needed. EE backends (external secret managers, Elasticsearch) are not on Maven Central: pass `--maven-repository` and credentials from the environment, not literals.

Put the downloaded plugins where the target loads them (the `plugins` folder of the standalone install, a mounted volume for Compose, an init container or custom image for Kubernetes). Prefix `kestractl` calls as described in `kestra-ops`.

## EE-only choices

If the chosen backend or a resolved plugin needs EE, say so and confirm the license before going on. See `ee.md`.
