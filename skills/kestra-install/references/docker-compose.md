# Docker Compose install

Four recipes in `docker-compose/`. Each runs Kestra as one `server standalone` service (server, worker, scheduler together) next to its backend containers.

## Pick a recipe

Start from the smallest one that fits. Move up only on a measured need.

| Recipe | Repository / queue | Edition | Pick when |
|---|---|---|---|
| `jdbc-postgres` | Postgres / Postgres | OSS, EE | Default. Evaluation, small to mid-size, fewest moving parts |
| `jdbc-postgres-redis` | Postgres / Redis | EE only | Lower queue latency and higher throughput without Kafka. Fails on OSS (no Redis queue) |
| `elasticsearch-redis` | Elasticsearch / Redis | EE only | Not a pairing the Kestra docs describe (they pair Elasticsearch with Kafka). Confirm with Kestra before using |
| `elasticsearch-kafka` | Elasticsearch / Kafka | EE | High throughput, distributed, your team already runs Kafka |

Ask for expected concurrency and data volume if the user did not say. No answer: `jdbc-postgres`.

Redis, Elasticsearch and Kafka backends are Enterprise only, so the three EE recipes need a license (see `ee.md`) and the EE image. On OSS only `jdbc-postgres` works. The EE recipes were checked for syntax only, not run against a license: check their keys against the Kestra docs for the chosen version.

Tested on Kestra 2.0.x and 1.3.x (`jdbc-postgres`). Set `KESTRA_VERSION` to the chosen major.

## Steps

1. Copy the recipe and its env file next to each other:
   ```bash
   cp jdbc-postgres.yml docker-compose.yml
   cp jdbc-postgres.env.example .env
   chmod 600 .env
   ```
2. Fill `.env`. Pin `KESTRA_VERSION` to a real tag. Generate passwords with `openssl rand -base64 24`. Never paste a secret into the compose file.
3. Validate: `docker compose config -q`
4. Start: `docker compose up -d`
5. Verify with the health checks (`health.md`), then hand off to `kestra-ops`.

## Notes

- Compose reads `.env`, but a variable already exported in your shell wins over it. If a change in `.env` (for example `KESTRA_VERSION`) seems ignored, check `env | grep KESTRA`.
- Host ports 8080 and 8081 are set with `KESTRA_HTTP_PORT` and `KESTRA_MANAGEMENT_PORT` in `.env`. Check they are free first (`ss -ltn`).
- The Docker socket mount lets Docker-based tasks run. It gives the container control of the host Docker. Drop it if no flow uses Docker tasks.
- Dedicated workers: run extra containers with `command: server worker` on the same config. Remote workers over gRPC are EE.
- Storage defaults to a local volume. For S3, GCS or Azure use the backend config generator (`backend-config.md`).
- Upstream `kestra-io/deployment-recipes` still has these recipes as stubs. These templates can be proposed back there later.
