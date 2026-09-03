# GitLab CI — Kestra CI/CD

Raw `kestractl` (no official GitLab component). Replace every `<PLACEHOLDER>`.
Create the variables under **Settings → CI/CD → Variables**, all **Masked**, and
the environment-scoped ones **Protected** (available only on the protected branch).

`.gitlab-ci.yml`

```yaml
stages: [validate, deploy-staging, deploy-production]

variables:
  KESTRACTL_VERSION: "<KESTRACTL_VERSION>"   # e.g. 1.18.1 — pin it
  FLOWS_DIR: "<FLOWS_DIR>"                    # e.g. flows

.install_kestractl: &install_kestractl
  - curl -fsSL https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh
      | VERSION="${KESTRACTL_VERSION}" INSTALL_DIR="${CI_PROJECT_DIR}/.bin" bash
  - export PATH="${CI_PROJECT_DIR}/.bin:${PATH}"

validate:
  stage: validate
  image: alpine:3.20
  before_script:
    - apk add --no-cache curl bash
    - *install_kestractl
  script:
    - kestractl flows validate "${FLOWS_DIR}" --output json
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "<MAIN_BRANCH>"
  variables:
    KESTRACTL_HOST: $KESTRA_HOST
    KESTRACTL_TENANT: $KESTRA_TENANT
    KESTRACTL_TOKEN: $KESTRA_TOKEN            # EE
    # KESTRACTL_USERNAME: $KESTRA_USERNAME    # OSS basic auth
    # KESTRACTL_PASSWORD: $KESTRA_PASSWORD

deploy-staging:
  stage: deploy-staging
  image: alpine:3.20
  environment: { name: staging }
  before_script:
    - apk add --no-cache curl bash
    - *install_kestractl
  script:
    - kestractl flows deploy "${FLOWS_DIR}" --namespace <STAGING_NAMESPACE> --override --fail-fast --output json
  rules:
    - if: $CI_COMMIT_BRANCH == "<MAIN_BRANCH>"
  variables:
    KESTRACTL_HOST: $KESTRA_HOST
    KESTRACTL_TENANT: $KESTRA_TENANT
    KESTRACTL_TOKEN: $KESTRA_TOKEN

deploy-production:
  stage: deploy-production
  image: alpine:3.20
  environment: { name: production }
  before_script:
    - apk add --no-cache curl bash
    - *install_kestractl
  script:
    - kestractl flows deploy "${FLOWS_DIR}" --namespace <PROD_NAMESPACE> --override --fail-fast --output json
  rules:
    - if: $CI_COMMIT_BRANCH == "<MAIN_BRANCH>"
      when: manual                            # the production gate
  allow_failure: false
  variables:
    KESTRACTL_HOST: $KESTRA_HOST_PROD
    KESTRACTL_TENANT: $KESTRA_TENANT_PROD
    KESTRACTL_TOKEN: $KESTRA_TOKEN_PROD
```

**Notes**
- Single environment? Keep `validate` + one `deploy` job.
- Deploy on tags: `if: $CI_COMMIT_TAG` instead of the branch rule.
- Delete-on-remove GitOps: swap `flows deploy` for
  `kestractl flows namespace-sync <NAMESPACE> "${FLOWS_DIR}" --delete --override`
  — only when the pipeline fully owns that namespace.
- If you use a container image that already has `curl`/`bash`, drop the `apk add`.
- Namespace files: add a `kestractl nsfiles upload …` step (see `kestra-ops`
  `references/commands.md`).
