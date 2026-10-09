---
name: kestra-install
description: Use when provisioning or configuring a new non-managed Kestra server, spinning up a Kestra instance on a standalone host, Docker Compose, or Kubernetes, or reconfiguring an existing server's storage, secret manager, repository, or queue.
---

# Kestra Install

Get a non-managed Kestra instance configured and reachable. Use the short intake
below, then load only the relevant section of [references/routing.md](references/routing.md).
This scaffold establishes routing; target-specific procedures are tracked in the
linked sibling issues and are not all bundled yet.

## Required inputs

Reuse facts already provided; ask for missing decisions together:

- Target: standalone host (non-container JVM), Docker Compose, or Kubernetes.
- Kestra version and edition: OSS or Enterprise Edition (EE).
- Intent: quick evaluation or production; new installation or reconfiguration.
- Known backend preferences or existing services: repository, queue, internal
  storage, and secret manager. "No preference" is a valid answer.

Then gather target prerequisites: host OS/architecture and Java availability,
Docker Engine/Compose availability, or Kubernetes context/namespace and Helm
availability. For reconfiguration, record the current version, topology and
configuration before proposing changes; account for persistent data and active
executions when changing backends.

## Workflow

1. **Select the route** using [references/routing.md](references/routing.md).
   Preserve existing backend choices when compatible. Check the selected
   version's official documentation and edition support before generating
   configuration; do not assume one version's backend keys apply to another.
2. **Use the matching installation guidance.** Read bundled references when
   available. Where a sibling implementation is still absent, state that gap
   and use the linked official documentation for the chosen version. Do not
   invent missing templates, commands, or local reference paths.
3. **Configure and start the selected target.** Keep credentials out of generated
   examples; use placeholders and the user's chosen secret delivery mechanism.
   For an existing deployment, show configuration changes and their operational
   implications before applying them.
4. **Verify reachability from the user's client.** Check the intended URL, startup
   status and authentication; record any unresolved failures. A generated file
   or a running container alone does not establish reachability.
5. **Hand off to `kestra-ops`** once reachable, carrying the URL, version/edition,
   tenant and authentication method (not credential values). Discover that skill
   by name; it owns CLI contexts, flow validation/deployment and executions.
   If unavailable, offer to load/install it rather than claim the handoff ran.

## Boundaries

Managed Kestra, provisioning managed databases/DBaaS, and cloud infrastructure
as code (Terraform/Pulumi) are outside this skill. Existing managed backends may
be consumed. Work beyond getting a reachable instance belongs to `kestra-ops`;
an existing 1.3-to-2.0 upgrade belongs to `migrate-kestra-2`.

## Example prompts

- "Install Kestra on this Linux VM without containers."
- "Spin up a local OSS evaluation with Docker Compose; I have no backend preference."
- "Install Kestra on Kubernetes for production using our Postgres and S3 storage."
- "Reconfigure our Kestra instance to use an existing secret manager."
