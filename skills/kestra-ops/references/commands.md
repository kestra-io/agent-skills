<!--
Source: kestra-io/kestractl @ v1.18.1 (tag) — README.md "## Usage" + src/cli/*.go help text.
Curated, not exhaustive: command signatures, notable flags, and representative examples.
For the long tail of flags on any command, run `kestractl <group> <command> --help`.
Refresh this file when kestractl cuts a release that changes the CLI surface.
EE markers ("EE only") reflect what the CLI's own help text / README states — not inference.
-->

# kestractl command reference

The `kestractl` command surface used by the `kestra-ops` skill. Load this when a request
needs a command beyond the cheat-sheet in `SKILL.md`.

## Global flags

Available on every command (see `SKILL.md` → Configuration precedence for how they resolve):

| Flag | Purpose |
|------|---------|
| `--host` | Kestra API base URL |
| `--token` / `-t` | API token — prefer the `KESTRACTL_TOKEN` env var (see `references/workflow.md` guardrails) |
| `--username` / `--password` | Basic-auth credentials (alternative to `--token`) |
| `--tenant` | Tenant name |
| `--header` | Extra HTTP header, `Key:Value`, repeatable |
| `--output` / `-o` | `table` (human, default) or `json` (scripting / parsing) |
| `--config` | Config file path (default `~/.kestractl/config.yaml`) |
| `--verbose` / `-v` | Verbose output — **prints credentials in HTTP requests**; never in shared logs |

Command groups below are grouped OSS-first, then EE-only. EE groups return an
authorization/edition error against an OSS instance.

---

## Config

```bash
kestractl config add dev http://localhost:8080 main --token YOUR_TOKEN
kestractl config add prod https://prod.kestra.io production --token PROD_TOKEN --default
kestractl config add dev http://localhost:8080 main --token YOUR_TOKEN \
  --header "X-Custom-Header:value"
kestractl config show          # list all contexts
kestractl config use prod      # switch default context
kestractl config remove dev
```

## Flows

```bash
# Read
kestractl flows list [my.namespace]                 # alias: ls; omit ns for all namespaces
kestractl flows list-by-namespace my.namespace --page 1 --size 50
kestractl flows list-deprecated
kestractl flows get my.namespace my-flow            # aliases: show, describe
kestractl flows task my.namespace my-flow my-task-id
kestractl flows search-by-source --query "http.request"
kestractl flows dependencies my.namespace my-flow
kestractl flows namespace-dependencies my.namespace
kestractl flows expressions --namespace my.namespace --flow my-flow
kestractl flows graph my.namespace my-flow --revision 3 --output json
kestractl flows generate-graph-from-source --file flow.yaml

# Validate
kestractl flows validate path/to/flow.yaml
kestractl flows validate ./flows/
kestractl flows validate-task    --namespace my.namespace --flow my-flow --task-id my-task
kestractl flows validate-trigger --namespace my.namespace --flow my-flow --trigger-id my-trigger

# Deploy / write (aliases: create, apply)
kestractl flows deploy path/to/flow.yaml
kestractl flows deploy ./flows/ --namespace prod.namespace --override --fail-fast
kestractl flows bulk-update --file flows.yaml
kestractl flows namespace-sync my.namespace flows.yaml --delete --override

# Enable / disable / delete (+ -by-query bulk variants)
kestractl flows enable my.namespace my-flow
kestractl flows disable my.namespace my-flow
kestractl flows delete my.namespace my-flow
kestractl flows delete-by-query  --namespace my.namespace --query old-
kestractl flows disable-by-query --namespace my.namespace
kestractl flows enable-by-query  --namespace my.namespace

# Export / import
kestractl flows export --namespace my.namespace --output-file flows.zip
kestractl flows export-by-ids my.namespace/flow-a my.namespace/flow-b --output-file export.zip
kestractl flows export-by-query --namespace my.namespace --output-file export.zip
kestractl flows import flows.zip

# Revisions & concurrency
kestractl flows revisions my.namespace my-flow
kestractl flows delete-revisions my.namespace my-flow --before-revision 5
kestractl flows concurrency-limits my.namespace my-flow
kestractl flows update-concurrency my.namespace my-flow --limit 10
```

## Executions

```bash
# Run / inspect
kestractl executions run my.namespace my-flow [--wait]       # aliases: trigger, execute
kestractl executions get 2TLGqHrXC9k8BczKJe5djX              # aliases: show, describe
kestractl executions list --namespace my.namespace --flow my-flow
kestractl executions watch 2TLGqHrXC9k8BczKJe5djX            # alias: follow; non-zero exit on failure
kestractl executions latest --flow my.namespace:my-flow

# State control
kestractl executions kill|pause|resume|restart|force-run 2TLGqHrXC9k8BczKJe5djX
kestractl executions replay 2TLGqHrXC9k8BczKJe5djX
kestractl executions replay-with-inputs 2TLGqHrXC9k8BczKJe5djX --input key=value
kestractl executions unqueue 2TLGqHrXC9k8BczKJe5djX
kestractl executions change-status 2TLGqHrXC9k8BczKJe5djX SUCCESS
kestractl executions update-taskrun 2TLGqHrXC9k8BczKJe5djX taskRunId SUCCESS

# Labels
kestractl executions set-labels 2TLGqHrXC9k8BczKJe5djX env=prod team=platform

# Bulk by IDs
kestractl executions set-labels-bulk env=prod --ids id1 --ids id2
kestractl executions unqueue-bulk id1 id2 id3
kestractl executions change-status-by-ids --status SUCCESS id1 id2

# Bulk by query (--filter FIELD:OPERATION:VALUE, e.g. STATE:EQUALS:RUNNING)
kestractl executions kill-by-query    --namespace my.namespace --flow my-flow
kestractl executions pause-by-query   --namespace my.namespace
kestractl executions resume-by-query  --namespace my.namespace
kestractl executions restart-by-query --namespace my.namespace
kestractl executions replay-by-query  --namespace my.namespace --latest-revision
kestractl executions force-run-by-query --namespace my.namespace
kestractl executions delete-by-query  --namespace my.namespace --delete-logs --delete-storage
kestractl executions unqueue-by-query --namespace my.namespace
kestractl executions set-labels-by-query env=prod --namespace my.namespace
kestractl executions update-status-by-query --namespace my.namespace --new-status KILLED

# Webhook / files / expressions
kestractl executions trigger-webhook my.namespace my-flow my-webhook-key --method POST
kestractl executions download-file 2TLGqHrXC9k8BczKJe5djX --path outputs/result.csv
kestractl executions file-metadata  2TLGqHrXC9k8BczKJe5djX --path outputs/result.csv
kestractl executions eval-expression 2TLGqHrXC9k8BczKJe5djX "{{ outputs.myTask.value }}"
kestractl executions flow-graph 2TLGqHrXC9k8BczKJe5djX
kestractl executions delete 2TLGqHrXC9k8BczKJe5djX
```

## Triggers

```bash
kestractl triggers list
kestractl triggers search-for-flow my.namespace my-flow
kestractl triggers enable|disable|unlock|restart my.namespace my-flow my-trigger
kestractl triggers update my.namespace my-flow my-trigger --disabled
kestractl triggers delete my.namespace my-flow my-trigger

# Bulk by IDs (namespace/flowId/triggerId) and by query
kestractl triggers delete-by-ids  my.ns/my-flow/sched
kestractl triggers enable-by-ids|disable-by-ids|unlock-by-ids my.ns/my-flow/sched
kestractl triggers delete-by-query|unlock-by-query|disable-by-query|enable-by-query --namespace my.namespace

# Backfill (single / by-ids / by-query)
kestractl triggers create-backfill my.namespace my-flow my-trigger \
  --start 2024-01-01T00:00:00Z --end 2024-02-01T00:00:00Z
kestractl triggers backfill-pause|backfill-unpause|backfill-delete my.namespace my-flow my-trigger
kestractl triggers pause-backfill-by-query|unpause-backfill-by-query|delete-backfill-by-query --namespace my.namespace

kestractl triggers export-csv --output-file triggers.csv
```

## Namespaces

```bash
kestractl namespaces list [--query my.namespace]     # alias: ls
kestractl namespaces autocomplete --query my.
kestractl namespaces get my.namespace
kestractl namespaces create my.namespace
kestractl namespaces update my.namespace --description "Production namespace"
kestractl namespaces delete my.namespace

# Variables — replaces the full variable set on the namespace
kestractl namespaces create my.namespace --variable env=prod --variable region=eu
kestractl namespaces update my.namespace --variables-file variables.yml

kestractl namespaces inherited-secrets   my.namespace
kestractl namespaces inherited-variables my.namespace
kestractl namespaces plugin-defaults my.namespace
kestractl namespaces export-plugin-defaults my.namespace --output-file defaults.yaml
kestractl namespaces import-plugin-defaults my.namespace defaults.yaml
```

## Key-Value Store (kv)

Types: `STRING`, `NUMBER`, `BOOLEAN`, `DATETIME`, `DATE`, `DURATION`, `JSON`.

```bash
kestractl kv list [my.namespace]
kestractl kv set my.namespace STRING api_key "my-secret"
kestractl kv set my.namespace JSON settings '{"feature":true}'
kestractl kv set my.namespace STRING session_token "abc" --ttl PT1H     # ISO-8601 duration
kestractl kv update my.namespace NUMBER retries 5                        # fails if key absent
kestractl kv get my.namespace api_key
kestractl kv delete my.namespace api_key                                # alias: rm
```

## Namespace Files (nsfiles)

```bash
kestractl nsfiles list my.namespace [--path workflows/] [--recursive]   # alias: ls
kestractl nsfiles get my.namespace workflows/example.yaml [--revision 3]  # alias: cat
kestractl nsfiles upload my.namespace ./local.txt workflows/local.txt
kestractl nsfiles upload my.namespace ./assets resources --override --fail-fast
kestractl nsfiles upload my.namespace ./assets resources --allow-missing-namespace
kestractl nsfiles delete my.namespace workflows/example.yaml [--force]
kestractl nsfiles delete my.namespace workflows --recursive
```

`upload <ns> <localDir> <remotePath>` nests `localDir`'s basename under `remotePath`
(`./assets` → `resources` yields `resources/assets/...`). Use `--no-root` to place the
directory *contents* directly under the destination, or upload files one-by-one.

## Plugins

Offline plugin-JAR management for self-hosted deployments — not the running instance's plugins.

```bash
kestractl plugins download 1.3.9 [--plugins-dir ./plugins] [--concurrency 4]
kestractl plugins download develop                       # 'develop' / 'latest' = in-dev version
kestractl plugins download 1.3.9 --from-config /etc/kestra/application.yaml   # core plugins only
kestractl plugins list 1.3.9 --from-config /etc/kestra/application.yaml       # preview, no download
```

## Workers

```bash
kestractl workers registration-tokens generate          # offline, no instance required
```

## Logs

```bash
kestractl logs list <execution_id>                       # alias: ls
kestractl logs search                                    # across the tenant, free-text + filters
kestractl logs download <execution_id> --output-file exec.log
kestractl logs delete <execution_id>                     # alias: rm
kestractl logs delete-flow <namespace> <flow_id>         # all logs for a flow, all executions
```

## Secrets

```bash
kestractl secrets list <namespace>                       # alias: ls
kestractl secrets set <namespace> <key> <value>
kestractl secrets patch <namespace> <key>               # update metadata (description)
kestractl secrets delete <namespace> <key>               # alias: rm
```

## Server

```bash
kestractl server license                                 # license information
kestractl server actions                                 # available server actions
kestractl server generate                                # statistics report
```

## Blueprints

`community` is public/OSS. `flow` and `custom` subcommands are **EE only**.

```bash
kestractl blueprints community search --query "kafka" [--output json]
kestractl blueprints community get <id>
kestractl blueprints community source <id>              # flow YAML source
kestractl blueprints community graph <id> --output json

# EE only
kestractl blueprints flow list|get|create|update|delete ...
kestractl blueprints flow use-template <id> --input env=prod --input region=eu
kestractl blueprints custom get|source|create|update|delete ...
```

---

# Enterprise Edition command groups

All groups below require Kestra EE (as stated in the CLI's own help text). They fail
with an authorization/edition error on OSS. Gate on edition before offering them
(see `references/workflow.md`).

## Dashboards — EE only

```bash
kestractl dashboards list [--query my-dashboard] [--output json]     # alias: ls
kestractl dashboards get <id>                                        # aliases: show, describe
kestractl dashboards create --file my-dashboard.yaml
kestractl dashboards update <id> --file my-dashboard.yaml
kestractl dashboards delete <id>                                     # alias: rm
kestractl dashboards validate --file my-dashboard.yaml
kestractl dashboards validate-chart --file my-chart.yaml
kestractl dashboards preview-chart --file my-chart.yaml --output json
kestractl dashboards chart-data <dashboard-id> <chart-id> [--file filters.yaml]
kestractl dashboards export-chart-csv --file my-chart.yaml --output-file chart.csv
kestractl dashboards export-chart-data-csv <dashboard-id> <chart-id> --output-file chart.csv
```

## Apps — EE only

Low-code interfaces built on top of flows.

```bash
kestractl apps list [--namespace my.namespace] [--output json]       # alias: ls
kestractl apps get <uid>                                             # aliases: show, describe
kestractl apps deploy --file my-app.yaml
kestractl apps update <uid> --file my-app.yaml
kestractl apps enable|disable <uid>
kestractl apps delete <uid>                                          # alias: rm
kestractl apps export --output-file apps.zip
kestractl apps import apps.zip
kestractl apps bulk-enable|bulk-disable|bulk-delete uid-1 uid-2 [--yes]
kestractl apps tags
kestractl apps catalog [--query reporting] [--output json]
kestractl apps file-meta|file-preview <view-id> --path /path/to/file
kestractl apps logs <view-id> --min-level ERROR --output-file app.log
```

## Assets — EE only

```bash
kestractl assets list [--output json]                                # alias: ls
kestractl assets get <id>                                            # aliases: show, describe
kestractl assets create --name my-asset --file asset.csv
kestractl assets delete <id>                                         # alias: rm
kestractl assets dependencies <id> --expand-all --output json        # alias: deps
kestractl assets delete-by-ids id1 id2 id3
kestractl assets delete-by-query --namespace my.namespace [--purge]
kestractl assets lineage-events list|delete-by-query ...             # alias: lineage
kestractl assets usages list|delete-by-query ...                    # alias: usage
```

## Test Suites — EE only

```bash
kestractl test-suites list [--namespace my.namespace]                # alias: ls
kestractl test-suites get my.namespace my-test-suite
kestractl test-suites create --file suite.yaml
kestractl test-suites update my.namespace my-test-suite --file suite.yaml
kestractl test-suites validate --file suite.yaml
kestractl test-suites run my.namespace my-test-suite
kestractl test-suites run-by-query --namespace my.namespace
kestractl test-suites delete-bulk|disable-bulk|enable-bulk my.namespace/suite-a
kestractl test-suites search-results --namespace my.namespace
kestractl test-suites last-result --ids my.namespace/suite-a
kestractl test-suites get-result <result_id>
kestractl test-suites delete my.namespace my-test-suite
```

## Users — EE only

Instance-level resources. Use `--user-password` to set a user's password (not the
global `--password` basic-auth flag).

```bash
kestractl users list [--query alice] [--output json]                 # alias: ls
kestractl users get <user_id>                                        # aliases: show, describe
kestractl users autocomplete --query ali
kestractl users create --email alice@example.com --first-name Alice --user-password 'S3cret!'
kestractl users create --email bob@example.com --superadmin
kestractl users update <user_id> --first-name Alicia
kestractl users set-password <user_id> --user-password 'N3wPass!'
kestractl users change-my-password --old-password 'OldPass!' --new-password 'N3wPass!'
kestractl users set-super-admin <user_id> --superadmin[=false]
kestractl users set-restricted <user_id> --restricted=true
kestractl users delete-auth-method <user_id> BASIC_AUTH
kestractl users set-groups <user_id> --group <group_id>
kestractl users impersonate <user_id>
kestractl users revoke-refresh-token <user_id>
kestractl users delete <user_id> [--yes]                             # alias: rm
kestractl users tokens create|list|delete <user_id> [<token_id>] --name ci-token
```

## Groups — EE only

Tenant-scoped resources.

```bash
kestractl groups list [--query admins] [--output json]               # alias: ls
kestractl groups get <group_id>                                      # aliases: show, describe
kestractl groups autocomplete --query adm
kestractl groups list-by-ids <id1> <id2>
kestractl groups create --name admins --description 'Platform admins' [--member <user_id>]
kestractl groups update <group_id> --name platform-admins
kestractl groups set-membership <group_id> <user_id>
kestractl groups delete <group_id> [--yes]                           # alias: rm
kestractl groups members list|add|remove <group_id> [<user_id>]
```

## Roles — EE only

Tenant-scoped. Permissions: `--permission TYPE:LEVEL[,LEVEL]` (repeatable) or
`--permissions-file` (YAML/JSON) — not both. `update --permission` replaces the whole block.

```bash
kestractl roles list [--query editor] [--page 1 --size 50 --sort name:asc]   # alias: ls
kestractl roles get <role_id>                                        # aliases: show, describe
kestractl roles autocomplete --query edi
kestractl roles list-from-ids <id1> <id2>
kestractl roles create --name editor --permission FLOW:READ,CREATE,UPDATE --permission EXECUTION:READ
kestractl roles create --name viewer --permissions-file perms.yaml
kestractl roles update <role_id> --permission FLOW:READ,CREATE,UPDATE,DELETE
kestractl roles update <role_id> --default
kestractl roles delete <role_id> [--yes]                             # alias: rm
```

## Service Accounts — EE only

Instance-level resources (aliases: `service-account`, `sa`). `update` is a partial
update of name/description only.

```bash
kestractl service-accounts list [--output json] [--page 1 --size 50 --sort name:asc]   # alias: ls
kestractl service-accounts get <service_account_id>                  # aliases: show, describe
kestractl service-accounts create --name ci-bot --description "CI pipeline"
kestractl service-accounts create --name ops-bot --superadmin --tenant-grant main
kestractl service-accounts update <service_account_id> --name new-bot-name
kestractl service-accounts set-super-admin <service_account_id> --superadmin[=false]
kestractl service-accounts delete <service_account_id> [--yes]       # alias: rm
kestractl service-accounts tokens create|list|delete <service_account_id> [<token_id>] \
  --name deploy-token [--max-age P30D --extended]
```

## Bindings — EE only

Assign a role to a user, group, or service account within a tenant.

```bash
kestractl bindings list [--output json]                              # alias: ls
kestractl bindings get <binding_id>                                  # aliases: show, describe
kestractl bindings create --role <role_id> --user <user_id>
kestractl bindings create --role <role_id> --group <group_id>
kestractl bindings bulk-create --file bindings.json
kestractl bindings delete <binding_id>                               # alias: rm
```

## Invitations — EE only

```bash
kestractl invitations list [--output json]
kestractl invitations list-by-email user@example.com
kestractl invitations get <invitation_id>
kestractl invitations create --email user@example.com --role <role_id>
kestractl invitations delete <invitation_id>                         # alias: rm
```
