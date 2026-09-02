---
name: kestra-cicd
description: Scaffold a GitOps CI/CD pipeline that validates Kestra flows on pull/merge requests and deploys them on merge, wrapping kestractl. Supports GitHub Actions and GitLab CI, per-environment namespaces, and manual approval gating for production. Use when users ask to set up CI/CD, GitOps, or an automated validate/deploy pipeline for their Kestra flows.
argument-hint: "[github|gitlab] [flows-dir]"
compatibility: Generates pipeline definition files only. No Kestra instance or MCP server required.
---

# Kestra CI/CD Skill

Scaffold a GitOps pipeline that runs `kestractl flows validate` on every
pull/merge request and `kestractl flows deploy` on merge to a protected branch,
with per-environment namespaces and a manual gate before production.

This is the "automate the operating" companion to `kestra-ops` (interactive
`kestractl`). It **generates pipeline files** — it does not run deployments.

## When to use

- "Set up CI/CD for my Kestra flows."
- "GitHub Actions / GitLab CI to validate on PR and deploy on merge."
- "GitOps pipeline for Kestra with dev/staging/prod."

## Required inputs

- **CI provider** — GitHub Actions (default) or GitLab CI.
- **Flows directory** in the repo (e.g. `flows/`). Namespace-files directory if any.
- **Kestra host(s) and tenant(s).**
- **Environment model** — single, or dev / staging / prod — and the namespace
  mapping per environment.
- **Branch strategy** — which branch deploys where; whether prod needs a manual gate
  (default: yes).
- **Auth** — API token (EE) or username/password (OSS), always via the CI secret store.

## Use `kestra-ops` for operational `kestractl`

If the `kestra-ops` skill is available, use it for **any `kestractl` install,
configuration, or command you run yourself** while building or testing the
pipeline — its `scripts/ensure-kestractl.sh`, `references/commands.md`, and
`references/workflow.md` are the source of truth for flags, failure handling, and
guardrails. Do not install or configure `kestractl` directly from this skill.
This skill only *generates* the pipeline definition; the generated pipeline
installs `kestractl` in its own runner.

## GitHub-native alternative

For GitHub, Kestra also ships official actions —
`kestra-io/github-actions/validate-flows`, `deploy-flows`,
`deploy-namespace-files` — which wrap the CLI with no install step. Prefer them
for a standard GitHub setup; use the raw-`kestractl` template when you need
offline validation, provider parity with a GitLab pipeline, or full flag control.
The GitHub reference covers both.

## Workflow

1. Gather the inputs above; fill sensible defaults for anything unspecified and
   state the assumptions.
2. Load the matching reference and copy its template:
   - [`references/github-actions.md`](references/github-actions.md)
   - [`references/gitlab-ci.md`](references/gitlab-ci.md)
3. Replace every `<PLACEHOLDER>` — flows dir, hosts, tenants, namespaces, branch
   names, secret names, pinned `kestractl` version.
4. Write the file to its conventional path (`.github/workflows/kestra-cicd.yml` or
   `.gitlab-ci.yml`).
5. Explain: which secrets/variables to create in the provider, what each job does,
   how the prod gate works, and what to tune.

## Pipeline design principles

- **Validate before deploy.** PR/MR runs `kestractl flows validate <dir>` and fails
  the check on non-zero. Deploy jobs `needs:`/`depends_on` a green validate.
- **Deploy on merge, not on PR.** Deploy triggers only on push to the protected
  branch (or a release tag).
- **One job per environment.** Map branch/tag → namespace. Prod behind a manual
  approval: GitHub `environment:` protection, GitLab `when: manual`.
- **Pin `kestractl`.** Install a fixed version in the runner via the official
  installer (`curl -fsSL …/install-scripts/install.sh | VERSION=<x> bash`), never
  `latest`.
- **Secrets only from the CI store**, surfaced as `KESTRACTL_HOST` /
  `KESTRACTL_TENANT` / `KESTRACTL_TOKEN` (or `KESTRACTL_USERNAME` /
  `KESTRACTL_PASSWORD`) env vars. Never inline a token or pass it as a literal
  `--token` argument.
- **`--override` deliberately.** Use it when the pipeline is the source of truth
  for those flows. Consider `kestractl flows namespace-sync` when the pipeline
  should also delete flows removed from the repo — gate that carefully.
- **`--fail-fast`** on deploy so a bad flow stops the rollout; report which flows
  deployed and which failed.

## Guardrails

- Credentials only via the CI provider's secret store; mark them masked/protected.
- Production deploy always gated (manual approval / protected environment /
  protected branch) unless the user explicitly opts out.
- Least-privilege token — scoped to the target namespace(s) where possible.
- Add `labels: {system.readOnly: "true"}` to CI-managed flows so the UI editor is
  disabled and the repo stays the source of truth.
- Pin the `kestractl` version; bump it deliberately.
- Never echo secrets; no `--verbose` in pipeline logs.

## Example prompts

- "Scaffold a GitHub Actions pipeline that validates `flows/` on PRs and deploys to
  the `prod` namespace on merge to `main`."
- "Set up GitLab CI for Kestra with dev auto-deploy and manual staging/prod gates."
- "Add a CI/CD workflow for my Kestra flows with per-environment namespaces
  (`dev.*`, `staging.*`, `prod.*`)."
