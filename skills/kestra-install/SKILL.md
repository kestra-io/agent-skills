---
name: kestra-install
description: Provision and configure a self-hosted Kestra server on a standalone host, Docker Compose or Kubernetes (Helm), then hand off to kestra-ops. Use when users ask to install, spin up, deploy or reconfigure a Kestra instance, pick a backend (Postgres, Redis, Elasticsearch, Kafka, S3/GCS storage), or upgrade and harden one. Not for managed cloud, Terraform/Pulumi, or flow authoring.
compatibility: Needs a shell on the target host. Docker Compose path needs Docker, Kubernetes path needs kubectl and helm, standalone path needs Java 21+. Network access to the Kestra docs for current versions.
---

# Kestra Install Skill

Get a reachable, healthy Kestra server up on infrastructure the user controls, then hand off to `kestra-ops`.

## When to use

- "Spin up a Kestra instance", "install Kestra on this VM", "run Kestra with Postgres and S3 storage"
- Reconfiguring an existing non-managed Kestra (backend, storage, secret manager)
- Upgrading or hardening a self-hosted install

## Not this skill

- Managed or DBaaS provisioning, cloud infrastructure as code (Terraform, Pulumi)
- Anything beyond getting a reachable Kestra instance running and healthy
- Writing flows (`kestra-flow`) or operating a running instance (`kestra-ops`)

## Required inputs

Ask once for what is missing, default to the simplest option:

- **Target**: standalone host, Docker Compose, or Kubernetes
- **Edition**: OSS or EE. Default OSS.
- **Major version**: ask which one. Kestra 2.0 (latest) or 1.3 (LTS). Default to 2.0 for a new install, and keep an existing install on its major. The references were tested on 2.0.x. The Compose path was also run on 1.3.x. Settings that exist only in 2.0 are marked, and for 1.3 check the docs for that version.
- **Exact version**: the latest stable release of that major. Check the Kestra docs or the release list, do not guess a tag.
- **Backends** if known: repository and queue (Postgres, Redis, Elasticsearch, Kafka), storage (local, S3, GCS, Azure), secret manager

## Decision flow

1. Standalone host: JVM install under systemd. Read `references/standalone.md`.
2. Docker Compose: pick the recipe from expected concurrency and scale, never default to the most complex one. Read `references/docker-compose.md`.
3. Kubernetes: `kestra-starter` chart for a quick evaluation, the `kestra` chart for production with your own backends. Read `references/kubernetes.md`.

## Standard workflow

1. Resolve target, edition, version and backends.
2. Generate the backend config (`references/backend-config.md`) and provision plugins from it.
3. EE only: set up the license (`references/ee.md`).
4. Follow the target reference to install.
5. Verify the install is healthy (`references/health.md`).
6. Bootstrap the first admin and a `kestractl` context (`references/bootstrap.md`).
7. Apply first-run maintenance and hardening (`references/maintenance.md`).
8. Hand off to `kestra-ops`.

To upgrade an existing install, follow `references/upgrade.md`. It only applies the version bump. Planning what breaks is a separate task.

## Guardrails

- Never write a real password, token or license as a literal in a generated file or command. Use `.env` files (`chmod 600`), Kubernetes Secrets, or environment variables.
- Confirm before any action that deletes data (volumes, databases, namespaces).
- Do not install on a production host without the user confirming the host.
- Report what was not verified.

## Hand off

When the instance is reachable, switch to the `kestra-ops` skill for contexts, flows and executions. If it is not installed:

```bash
npx skills add kestra-io/agent-skills@kestra-ops
```
