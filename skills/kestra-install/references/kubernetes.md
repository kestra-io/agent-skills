# Kubernetes install (Helm)

Use the official chart. Source and `values.yaml` live in `kestra-io/kestra` under `charts/kestra`. Read the chart's own `values.yaml` for the chosen chart version before generating values.

## Pick a chart

| Chart | Use for | Backends |
|---|---|---|
| `kestra/kestra-starter` | Quick evaluation | Bundles a Postgres subchart and an S3 emulator |
| `kestra/kestra` | Production | None bundled. Bring your own Postgres, storage and queue, wired through `configurations.application` |

Since the 1.0.0 chart migration, `kestra/kestra` no longer ships Postgres, MinIO, Kafka or Elasticsearch. Never use the starter chart for production data.

## Pick a version

The chart version follows the Kestra major: `2.0.x` charts run Kestra 2.0 (gRPC worker controller, `deployments.controller`), `1.0.x` charts run Kestra 1.3. Pin `--version` to the chart for the chosen major (`helm search repo kestra --versions`). The templates here target 2.0. For 1.3, remove the `controller` deployment and the `kestra.worker.controllers` block, which do not exist there, and check the 1.3 `values.yaml`.

## Pick a mode (production chart)

Set through `deployments.<role>.enabled`:

- **Standalone**: `standalone` on, one pod runs all roles. Start here. Template: `kubernetes/values-standalone.yaml`
- **Distributed**: `standalone` off, toggle `webserver`, `executor`, `indexer`, `scheduler`, `controller` (Kestra 2.0, needed by detached workers) and `worker`, and scale each. Detached workers also need `kestra.worker.controllers` pointing at the `<fullname>-controller` Service (already in the template: fix the host to match your release). Without it workers crash-loop with `Failed connecting to Kestra controller`. Template: `kubernetes/values-distributed.yaml`

## Steps

1. Check `kubectl config current-context` with the user. Confirm the cluster and namespace before installing.
2. Add the repo:
   ```bash
   helm repo add kestra https://helm.kestra.io/
   helm repo update
   ```
3. Copy a values template, fill the backend block (see `backend-config.md`), and create the Secret for credentials.
4. Dry run: `helm template kestra kestra/kestra -n kestra -f values.yaml > /dev/null`
5. Install:
   ```bash
   helm install kestra kestra/kestra -n kestra --create-namespace -f values.yaml
   ```
6. Verify with `health.md` (`kubectl rollout status`, probes), then hand off to `kestra-ops`.

## Notes

- `configurations.application` is raw Kestra YAML. The same block the standalone and Compose paths use.
- Credentials and licenses go in a Kubernetes Secret mounted through `configurations.secrets`, not in a checked-in `values.yaml`.
- The `dind` sidecar runs Docker tasks. It is on by default and needs a privileged, rootless-capable node. On clusters that cannot run it (kind, locked-down pod security) it crash-loops and the pod stays `1/2`. Disable it with both `dind.enabled: false` and `deployments.standalone.dind.enabled: false` if no flow uses Docker tasks.
- OSS needs basic auth: put `kestra.server.basic-auth` in the credentials Secret (see the values template). EE: skip it and create the admin in the UI setup.
- Expose the UI with `ingress` values or a port-forward: `kubectl -n kestra port-forward svc/kestra 8080:8080` (the service is named after the release, check with `kubectl -n kestra get svc`).
