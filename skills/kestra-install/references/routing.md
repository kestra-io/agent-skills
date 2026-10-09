# Installation routing

Choose from the user's target, intent, version, edition and known backends.
Read the selected version's [installation documentation](https://kestra.io/docs/installation)
before applying configuration. This file defines interfaces for sibling work;
an issue link describes planned work, not a procedure already available locally.

## Target decision

| Target and intent | Route | Detailed procedure |
| --- | --- | --- |
| Standalone host | Non-container JVM installation; confirm OS, architecture and the selected version's Java requirement | [Host installation](https://kestra.io/docs/installation/standalone-server), implementation tracked in [#28](https://github.com/kestra-io/agent-skills/issues/28) |
| Docker Compose | Choose a compatible recipe below; confirm Docker/Compose and available resources/ports | [Compose installation](https://kestra.io/docs/installation/docker-compose), recipes tracked in [#27](https://github.com/kestra-io/agent-skills/issues/27) |
| Kubernetes, quick evaluation without existing backends | `kestra-starter` chart with bundled backends | [Kubernetes installation](https://kestra.io/docs/installation/kubernetes), tracked in [#29](https://github.com/kestra-io/agent-skills/issues/29) |
| Kubernetes, production or existing backends | Production `kestra` chart with bring-your-own backends; retain the user's existing PostgreSQL/object storage choices when supported | Same Kubernetes documentation and [#29](https://github.com/kestra-io/agent-skills/issues/29) |

An evaluation with existing services can use the bring-your-own-backends chart.
Do not silently replace production backends with the starter chart's bundled
services. If the user has not selected a target, explain these tradeoffs and ask
which environment they can operate; do not choose Kubernetes solely for scale.

## Compose recipe decision

The four recipe identifiers are the interfaces requested by #27. Select the
fewest moving parts that meet the user's requirements, after checking version
and edition compatibility:

| Recipe | Why choose it |
| --- | --- |
| `jdbc-postgres` | Default when there is no backend preference: PostgreSQL repository and queue, simplest operational footprint |
| `jdbc-postgres-redis` | PostgreSQL repository with Redis queue when lower queue latency is required |
| `elasticsearch-redis` | Elasticsearch repository with Redis queue when search/retention requirements justify Elasticsearch |
| `elasticsearch-kafka` | Elasticsearch repository with Kafka queue for high-throughput/distributed requirements that justify the extra services |

These names are not literal configuration values. In Kestra 2.0, OSS uses one
JDBC database for queue, repository and logs; independent Redis/Kafka queues and
Elasticsearch repositories require EE. Earlier versions used different backend
pairings and keys. Consult the selected version's docs rather than offering an
unsupported combination. See the official [backend architecture and edition
explanation](https://kestra.io/blogs/kestra-2-0-backend-choice).
Each recipe here still uses a standalone Kestra service; selecting Kafka alone
does not provision distributed Kestra roles.

## Follow-on interfaces

Keep target-specific installation instructions separate from these shared stages.
The linked work is not yet a substitute for executable local guidance:

| Stage | Contract | Tracked work |
| --- | --- | --- |
| Configuration/plugins | Produce the same logical `application.yaml` configuration for host files, Compose mounts or Helm values; resolve required plugins for the selected version | [#30](https://github.com/kestra-io/agent-skills/issues/30) |
| Bootstrap/handoff | Establish access and pass instance facts to `kestra-ops` | [#31](https://github.com/kestra-io/agent-skills/issues/31) |
| Enterprise setup | Resolve EE distribution/licensing and edition-specific configuration | [#32](https://github.com/kestra-io/agent-skills/issues/32) |
| Verification | Check health and a first flow; report what was actually verified | [#33](https://github.com/kestra-io/agent-skills/issues/33) |
| Upgrade | Route existing-version changes to version-aware upgrade guidance; use `migrate-kestra-2` for 1.3 to 2.0 | [#34](https://github.com/kestra-io/agent-skills/issues/34) |

## Routing examples

- Fresh Linux VM, no containers: host/JVM route, not `kestra-ops` before startup.
- Local OSS evaluation, no preferences: Compose `jdbc-postgres`.
- Production Kubernetes with existing PostgreSQL and S3: `kestra` chart, not
  bundled-backend `kestra-starter`.
- Reachable instance, deploy a workflow: `kestra-ops` directly; no installation.
- Create a managed database or Terraform infrastructure: outside this skill;
  resume installation once the supplied backend connection details are available.
