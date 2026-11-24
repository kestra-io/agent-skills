# EE license and EE-only components

Only when the edition is EE. Ask the user for the license values. Never print, log or commit them.

## Per target

| Target | Where the license goes |
|---|---|
| Docker Compose | `KESTRA_EE_LICENSE_ID`, `KESTRA_EE_LICENSE_FINGERPRINT`, `KESTRA_EE_LICENSE_KEY` in `.env` (`chmod 600`), passed to the `kestra` service. The `elasticsearch-*` env examples already list them |
| Standalone | The same variables in `/etc/kestra/kestra.env`, loaded by `EnvironmentFile` in the systemd unit |
| Kubernetes | Inline under `configurations.application`, or better a Kubernetes Secret mounted through `configurations.secrets` (a config file holding the license block). Never a plaintext license in a checked-in `values.yaml` |

Compose service wiring:

```yaml
    environment:
      KESTRA_EE_LICENSE_ID: ${KESTRA_EE_LICENSE_ID}
      KESTRA_EE_LICENSE_FINGERPRINT: ${KESTRA_EE_LICENSE_FINGERPRINT}
      KESTRA_EE_LICENSE_KEY: ${KESTRA_EE_LICENSE_KEY}
```

Kubernetes Secret, created from a local file that is not committed:

```bash
kubectl -n kestra create secret generic kestra-license --from-file=license.yml=./license.yml
```

```yaml
configurations:
  secrets:
    - name: kestra-license
      key: license.yml
```

Check the exact variable names and the license config keys in the Kestra docs for the version.

## EE-only checks

- Elasticsearch and Kafka backends, remote workers over gRPC, and EE plugins need EE. When the backend config (`backend-config.md`) selects one, say so and confirm the license before installing.
- No license and an EE-only choice: fall back to the OSS equivalent (Postgres repository and queue) and tell the user.

## Worker groups and worker authentication (2.0)

Kestra 2.0 changed worker groups: they are created on the server (UI, API or declarative setup), workers join one with a registration token, and tasks select them with `workerSelector.tags`. Worker authentication is off by default. On Helm, the setting `kestra.ee.worker.auth.enabled: true` goes in `configurations.application` and each worker deployment gets `KESTRA_WORKER_AUTH_REGISTRATION_TOKEN` from a Kubernetes Secret through `extraEnv`. This skill does not build that topology. Follow the Kestra docs for worker groups and the Helm gRPC worker-controller page for the installed version.

## Out of scope

Designing worker groups, queues and tokens, and any 1.x `workerGroups` migration.
