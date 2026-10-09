# Docker Compose recipes

These recipes target **Kestra 2.0.5** and Docker Compose v2 or newer. Each folder
contains a complete `docker-compose.yml` and `.env.example`. Copy both files into
a private deployment directory. They run **one Kestra `server standalone` service**
with persistent backend/storage volumes, backend health checks and service DNS.
The Kestra service binds only `127.0.0.1`; backends and the management port are
not published to the host.

## Choose a recipe

| Recipe | Edition | Use case | Resource budget for these defaults |
| --- | --- | --- | --- |
| [jdbc-postgres](jdbc-postgres/docker-compose.yml) | OSS; EE requires the adaptation below | Fewest moving parts; default when requirements do not justify a separate queue | Kestra 4 GiB/2 CPUs + PostgreSQL 512 MiB |
| [jdbc-postgres-redis](jdbc-postgres-redis/docker-compose.yml) | EE | Higher-concurrency workloads where lower queue latency justifies Redis | Above + Redis 256 MiB |
| [elasticsearch-redis](elasticsearch-redis/docker-compose.yml) | EE | Elasticsearch search/retention requirements with a lower-latency Redis queue | Kestra 4 GiB/2 CPUs + Elasticsearch 1.5 GiB + Redis 256 MiB |
| [elasticsearch-kafka](elasticsearch-kafka/docker-compose.yml) | EE | High-throughput/distributed architecture requirements that justify Kafka and Elasticsearch | Kestra 4 GiB/2 CPUs + Elasticsearch 1.5 GiB + Kafka 1 GiB |

Allow additional host memory/CPU for Docker and other services. These are example
limits, not capacity guarantees. Redis primarily improves queue latency; it does
not inherently raise total execution capacity. Kafka supports a distributed
architecture, but this recipe remains a **single Kestra process and one broker**.
It does not supply high availability. Keep PostgreSQL unless search/retention
requirements justify Elasticsearch's extra services and indexing latency.

The recipe identifiers come from
[deployment-recipes](https://github.com/kestra-io/deployment-recipes/tree/main/docker-compose).
They are not literal configuration values. Kestra 2.0 uses `postgres` for the
PostgreSQL queue/repository, rather than copying 1.x `jdbc` queue settings. OSS
requires a single JDBC backend for queue, repository and logs. Redis/Kafka queues
and Elasticsearch repositories require a licensed EE distribution. See the
official [2.0 backend/edition explanation](https://kestra.io/blogs/kestra-2-0-backend-choice).

Pinned backend images: PostgreSQL `16.13`, Redis `7.4.6`, Elasticsearch `8.17.4`,
Apache Kafka `3.9.1` (KRaft, no ZooKeeper). PostgreSQL 16 persists at
`/var/lib/postgresql/data`; do not change the major image version against an
existing volume without a database migration. These templates are not 1.x
upgrade procedures; use version-specific migration guidance for existing data.

## Configure

In the chosen recipe directory:

```bash
cp .env.example .env
```

PowerShell: `Copy-Item .env.example .env`.

Edit `.env`: supply `KESTRA_USERNAME` (email), a strong `KESTRA_PASSWORD`, and
`KESTRA_ENCRYPTION_KEY` (generate with `openssl rand -base64 32`). Supply the
backend passwords requested by that recipe. Leave no required value empty;
Compose rejects missing passwords/encryption/license values before starting.
Use single-quoted `.env` values for passwords containing `$`, `#`, or spaces.
Keep this file private and out of version control.
Avoid literal `${...}` sequences in configuration values: Micronaut interprets
them as property references, including inside environment-supplied passwords.

`KESTRA_PORT` controls the host port; if changed, update `KESTRA_URL` to match the
URL clients use. The internal UI port remains 8080. The `slim` OSS image includes
core tasks for the first-flow check below; install other task plugins appropriate
to your selected version when needed.

The application configuration is embedded in `KESTRA_CONFIGURATION`.
`$${VARIABLE}` deliberately survives Compose interpolation as `${VARIABLE}` for
Micronaut to resolve from the container environment, so credential values are
not interpolated into the YAML text. Do not remove that escaping.

### Enterprise recipes

Supply `KESTRA_LICENSE_ID`, `KESTRA_LICENSE_FINGERPRINT`, and `KESTRA_LICENSE_KEY`.
For a multiline license key, `.env` supports a single-quoted multiline value.
Authenticate to the private registry with your own licensed credentials before
pulling; use `docker login registry.kestra.io` interactively, or `--password-stdin`
with your existing secret delivery mechanism. Do not put registry credentials in
the recipe. Verify that your account provides the configured
`registry.kestra.io/docker/kestra-ee:v2.0.5` tag; `KESTRA_IMAGE` can point to the
equivalent approved 2.0.5 EE image in your registry. An OSS image is not a fallback
for an EE backend recipe.

License keys use the documented `kestra.ee.license` configuration. See
[EE setup](https://kestra.io/docs/enterprise/overview/setup) and the
[backend configuration](https://kestra.io/docs/configuration/enterprise-and-advanced).
Complete tenant/owner setup in the EE UI before handing off authenticated API
operations. EE plugin provisioning and broader setup are tracked separately.

For **PostgreSQL-only EE**, keep `jdbc-postgres`'s repository/queue and add the
license environment variables and `kestra.ee.license` configuration from
[jdbc-postgres-redis](jdbc-postgres-redis/docker-compose.yml), along with its EE
image setting and license entries from [.env.example](jdbc-postgres-redis/.env.example).
Merge those fields into the existing environment/configuration mappings (do not
add duplicate `kestra` keys). Redis is not needed. Changing `KESTRA_IMAGE` alone
does not configure an EE license.

## Start and verify

```bash
docker compose -p kestra-eval config --quiet
docker compose -p kestra-eval up -d --wait --wait-timeout 600
docker compose -p kestra-eval ps
```

Use the same project name for every command; choose a distinct name for each
deployment so recipes do not share volumes. `docker-compose` is equivalent when
the standalone Compose executable is installed.

Open `http://localhost:8080` (or the configured URL). Verify authenticated access,
not just container state. The in-container Kestra health check uses the private
management endpoint `http://localhost:8081/health`; only the UI/API port is mapped.
To inspect startup failures:

```bash
docker compose -p kestra-eval logs --tail 100 kestra
docker compose -p kestra-eval logs --tail 100
```

After the UI is reachable and authentication is configured, hand off to
`kestra-ops` to validate, deploy and execute a small flow, then confirm `SUCCESS`:

```yaml
id: compose_install_check
namespace: install.check
tasks:
  - id: hello
    type: io.kestra.plugin.core.log.Log
    message: Compose installation verified
```

Record URL, version, edition, tenant/auth method and verification results for the
handoff; do not include credential values. A health check alone does not verify
workflow execution.

## Persistence, teardown and production adaptation

```bash
docker compose -p kestra-eval down
```

This stops/removes the project's containers and network while retaining its
named volumes. Start with the same project name to reuse them. Volume deletion
is a separate, deliberate data-destroying operation; do not add `--volumes` to
routine teardown.

These are single-host examples: the Kestra service uses root to write the local
named volumes, Elasticsearch security is disabled on its unexposed internal
network, and Kafka has plaintext internal listeners and replication factor 1.
For production, configure network isolation, TLS/backend authentication, an
appropriate secret delivery mechanism, non-root volume permissions, backups,
retention and resource sizing. Do not present these local defaults as a hardened
or distributed production installation. Docker socket access is not mounted;
Docker task runners require a separately configured runner.

Validated templates may later be upstreamed to `deployment-recipes`; this skill
does not depend on that follow-up. To check interpolation and required inputs
without pulling images or starting containers, run from the repository root:

```bash
python -m unittest discover -s tests -v
```
