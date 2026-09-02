# GitHub Actions — Kestra CI/CD

Two templates: **raw `kestractl`** (provider-agnostic, offline-capable, full flag
control) and the **official Kestra actions** (no install step). Pick one.

Replace every `<PLACEHOLDER>`. Create the referenced secrets under
**Settings → Secrets and variables → Actions**, and one **Environment** per
deploy target (Settings → Environments) with required reviewers on `production`.

---

## Template A — raw `kestractl`

`.github/workflows/kestra-cicd.yml`

```yaml
name: Kestra CI/CD

on:
  pull_request:
    paths:
      - "<FLOWS_DIR>/**"          # e.g. flows/**
      - ".github/workflows/kestra-cicd.yml"
  push:
    branches:
      - <MAIN_BRANCH>             # e.g. main

env:
  KESTRACTL_VERSION: "<KESTRACTL_VERSION>"   # e.g. 1.18.1 — pin it, never "latest"
  FLOWS_DIR: "<FLOWS_DIR>"                    # e.g. flows

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install kestractl
        run: curl -fsSL https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh | VERSION="${KESTRACTL_VERSION}" INSTALL_DIR="$HOME/.local/bin" bash
      - name: Add kestractl to PATH
        run: echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - name: Validate flows
        env:
          KESTRACTL_HOST: ${{ secrets.KESTRA_HOST }}
          KESTRACTL_TENANT: ${{ secrets.KESTRA_TENANT }}
          KESTRACTL_TOKEN: ${{ secrets.KESTRA_TOKEN }}        # EE
          # KESTRACTL_USERNAME: ${{ secrets.KESTRA_USERNAME }}  # OSS basic auth
          # KESTRACTL_PASSWORD: ${{ secrets.KESTRA_PASSWORD }}
        run: kestractl flows validate "${FLOWS_DIR}" --output json

  deploy-staging:
    if: github.ref == 'refs/heads/<MAIN_BRANCH>'
    needs: validate
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - name: Install kestractl
        run: curl -fsSL https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh | VERSION="${KESTRACTL_VERSION}" INSTALL_DIR="$HOME/.local/bin" bash
      - run: echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - name: Deploy to staging
        env:
          KESTRACTL_HOST: ${{ secrets.KESTRA_HOST }}
          KESTRACTL_TENANT: ${{ secrets.KESTRA_TENANT }}
          KESTRACTL_TOKEN: ${{ secrets.KESTRA_TOKEN }}
        run: kestractl flows deploy "${FLOWS_DIR}" --namespace <STAGING_NAMESPACE> --override --fail-fast --output json

  deploy-production:
    if: github.ref == 'refs/heads/<MAIN_BRANCH>'
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production          # add required reviewers here = the manual gate
    steps:
      - uses: actions/checkout@v4
      - name: Install kestractl
        run: curl -fsSL https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh | VERSION="${KESTRACTL_VERSION}" INSTALL_DIR="$HOME/.local/bin" bash
      - run: echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - name: Deploy to production
        env:
          KESTRACTL_HOST: ${{ secrets.KESTRA_HOST_PROD }}
          KESTRACTL_TENANT: ${{ secrets.KESTRA_TENANT_PROD }}
          KESTRACTL_TOKEN: ${{ secrets.KESTRA_TOKEN_PROD }}
        run: kestractl flows deploy "${FLOWS_DIR}" --namespace <PROD_NAMESPACE> --override --fail-fast --output json
```

**Notes**
- Single environment? Keep `validate` + one `deploy` job, drop the rest.
- Deploy on tags instead of `main`: use `on: push: tags: ["v*"]` and
  `if: startsWith(github.ref, 'refs/tags/')`.
- To also remove flows deleted from the repo, replace `flows deploy` with
  `kestractl flows namespace-sync <NAMESPACE> "${FLOWS_DIR}" --delete --override`
  — only when the pipeline fully owns that namespace.
- Namespace files: add `kestractl nsfiles upload <NAMESPACE> ./<NSFILES_DIR> <REMOTE_PATH> --override` (see `kestra-ops` `references/commands.md`).

---

## Template B — official Kestra actions

`.github/workflows/kestra-cicd.yml`

```yaml
name: Kestra CI/CD

on:
  pull_request:
    paths: ["<FLOWS_DIR>/**"]
  push:
    branches: ["<MAIN_BRANCH>"]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kestra-io/github-actions/validate-flows@main
        with:
          directory: <FLOWS_DIR>
          server: ${{ secrets.KESTRA_HOST }}
          tenant: <TENANT>                       # "main" for OSS default
          apiToken: ${{ secrets.KESTRA_TOKEN }}  # EE; or user/password for OSS
          # user: ${{ secrets.KESTRA_USERNAME }}
          # password: ${{ secrets.KESTRA_PASSWORD }}

  deploy-production:
    if: github.ref == 'refs/heads/<MAIN_BRANCH>'
    needs: validate
    runs-on: ubuntu-latest
    environment: production          # required reviewers = the manual gate
    steps:
      - uses: actions/checkout@v4
      - uses: kestra-io/github-actions/deploy-flows@main
        with:
          directory: <FLOWS_DIR>
          namespace: <PROD_NAMESPACE>           # omit to keep each flow's own namespace
          override: "true"
          server: ${{ secrets.KESTRA_HOST_PROD }}
          tenant: <TENANT>
          apiToken: ${{ secrets.KESTRA_TOKEN_PROD }}
```

For offline validation with no reachable instance, use the legacy
`kestra-io/kestra-validate-action` instead of `validate-flows`.
