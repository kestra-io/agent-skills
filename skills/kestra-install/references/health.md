# Post-install health verification

Run at the end of every install and upgrade. Report pass or fail per component, not one "it started" verdict.

## 1. Process and probes

Kestra serves health on the management port (8081 by default). On Kubernetes, `kubectl port-forward svc/<release> 8080:8080 8081:8081` exposes both ports locally.

| Check | Endpoint |
|---|---|
| Alive | `/health/liveness` |
| Ready | `/health/readiness` |
| Overall | `/health` |

```bash
curl -fsS http://localhost:8081/health/liveness
curl -fsS http://localhost:8081/health/readiness
curl -fsS http://localhost:8081/health
```

- Docker Compose: also `docker compose ps` (all services `running`, backends `healthy`) and `docker compose logs kestra --tail 50`.
- Standalone: `systemctl is-active kestra` and `journalctl -u kestra -n 50`.
- Kubernetes: the chart already wires the same endpoints as `livenessProbe`, `readinessProbe` and `startupProbe` on the `management` port.
  ```bash
  kubectl -n kestra rollout status deployment/<name>   # one per enabled role
  kubectl -n kestra get pods
  ```
  Every pod must show all containers ready (`READY 2/2`, not `1/2`). A failing sidecar such as `dind` can leave a pod at `1/2` while the Kestra container serves traffic, so do not rely on `rollout status` alone. Check `kubectl -n kestra describe pod <pod>` and the sidecar logs.
  List deployments with `kubectl -n kestra get deploy`.

## 2. Smoke test with kestractl

A running process does not prove webserver, scheduler, worker, repository and queue work together. Run a minimal flow end to end, using the context from `bootstrap.md`:

```yaml
id: install-smoke-test
namespace: system.smoke
tasks:
  - id: hello
    type: io.kestra.plugin.core.log.Log
    message: install ok
```

```bash
kestractl flows deploy ./install-smoke-test.yaml --override
kestractl executions run system.smoke install-smoke-test --wait
```

Pass: the execution ends `SUCCESS`. Fail: report the state and read `executions get <id>` and the server logs.

## 3. Report

| Component | Check | Result |
|---|---|---|
| Server up | liveness | pass / fail |
| Ready for traffic | readiness | pass / fail |
| Repository and queue | smoke execution reached a final state | pass / fail |
| Worker | smoke task ran | pass / fail |

State what was not checked. Delete the smoke flow afterwards if the user does not want it kept.
