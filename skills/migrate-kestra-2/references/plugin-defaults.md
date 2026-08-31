# pluginDefaults → Policies (EE) / inline values (OSS)

Official guide: `https://kestra.io/docs/migration-guide/v2.0.0/plugin-defaults-removed` · Policy DSL: `https://kestra.io/docs/enterprise/governance/policies`

`pluginDefaults` is removed at **all scopes** — flow level, namespace/tenant level (EE), and the `kestra.plugins.defaults` server config. Flows carrying the block **fail to parse on 2.0**, and `kestra-migrate --check` does **not** flag it — detect with `grep -rln 'pluginDefaults:' <dir>` (plus the server config file).

Branch on the audit's edition answer:

## EE

| 1.x scope | 2.0 replacement | Migration |
|---|---|---|
| Namespace / tenant Plugin Defaults | namespace-/tenant-scoped **Policy** | **auto-migrated during the upgrade** — review afterwards, don't recreate |
| `kestra.plugins.defaults` server config | **static policy** under `kestra.policies` in server config | manual; a malformed static policy prevents server startup — validate in staging first |
| Flow-level `pluginDefaults` | ask the user: **inline values** onto the tasks (one or two flows) or an `enforcement: reference` Policy + `policyRefs:` on each flow (many flows sharing the block) | manual |

`forced: false` → `Add` rule `override: false` (innermost scope wins); `forced: true` → `override: true` (outermost wins). Precedence: `STATIC → INSTANCE → TENANT → NAMESPACE`.

```yaml
# Before (application.yml)                  # After (application.yml)
kestra:                                     kestra:
  plugins:                                    policies:
    defaults:                                   - id: instance-plugin-defaults
      - type: io.kestra...shell.Commands          rules:
        values:                                     - type: io.kestra.plugin.ee.rules.Add
          containerImage: ubuntu:24.04                on: plugin
      - type: io.kestra.plugin.aws                    where:
        forced: true                                    - {field: type, operator: EQUAL_TO, value: io.kestra...shell.Commands}
        values:                                       values: {containerImage: ubuntu:24.04}
          region: eu-west-1                         - type: io.kestra.plugin.ee.rules.Add
                                                      on: plugin
                                                      override: true
                                                      where:
                                                        - {field: type, operator: STARTS_WITH, value: io.kestra.plugin.aws}
                                                      values: {region: eu-west-1}
```

Verification tooling: `POST /api/v1/{tenant}/flows/policies/preview` (mutated source with per-property attribution), `GET …/policies/{id}/evaluate` dry-run, `kestra flow validate <file>`.

Gotchas: policy `where` matches plugin `type` strings **literally** — deprecated aliases are not resolved, so cover both alias and canonical names or migrate types first; list values **replace** the author's list under `override: true` (1.x merged); `Add`+`Delete` conflicts are rejected at save; teams need the new `POLICY` permission.

## OSS

No centralized replacement. Options, in order: inline the values onto each affected task; hoist shared values into flow `variables:` and reference them; or EE for Policies. Present the tradeoff and apply the user's choice per flow.
