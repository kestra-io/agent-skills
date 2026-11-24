# Standalone host install

Kestra as a JVM process on a host or VM, no containers. Needs Java 21+ and a running Postgres.

## Steps

1. Check prerequisites: `java -version` (21 or newer), Postgres reachable, and a database and user for Kestra. Ask before creating them.
2. Create a service user and folders:
   ```bash
   sudo useradd --system --home /opt/kestra --shell /usr/sbin/nologin kestra
   sudo mkdir -p /opt/kestra /etc/kestra /var/lib/kestra/storage
   sudo chown -R kestra:kestra /opt/kestra /var/lib/kestra
   ```
3. Download the release file and verify it. The OSS release asset is an executable JAR named `kestra-<version>` (the EE one needs license credentials and a different endpoint, see the docs):
   ```bash
   VERSION=<version without v, from the docs or the latest release>
   cd /opt/kestra
   sudo curl -fLO https://github.com/kestra-io/kestra/releases/download/v${VERSION}/kestra-${VERSION}
   sudo curl -fLO https://github.com/kestra-io/kestra/releases/download/v${VERSION}/checksums_sha256.txt
   grep " kestra-${VERSION}$" checksums_sha256.txt | sha256sum -c -
   sudo mv kestra-${VERSION} kestra.jar && sudo chown kestra:kestra kestra.jar
   ```
   The JAR ships without plugins. Provision them with `kestractl plugins download` (see `backend-config.md`) and point Kestra at the folder with `KESTRA_PLUGINS_PATH` in `kestra.env`, or enable plugin auto-install as the docs describe for your version.
4. Copy `standalone/application.yaml` to `/etc/kestra/application.yaml`. For other backends use `backend-config.md`.
5. Create `/etc/kestra/kestra.env` with `KESTRA_DB_PASSWORD`, `KESTRA_ADMIN_EMAIL`, `KESTRA_ADMIN_PASSWORD` (and `KESTRA_EE_*` for EE, see `ee.md`). Generate the passwords, do not reuse one. `sudo chmod 600` it.
6. Foreground run first, to see errors before systemd hides them:
   ```bash
   sudo -u kestra env $(cat /etc/kestra/kestra.env | xargs) \
     java -jar /opt/kestra/kestra.jar server standalone --config /etc/kestra/application.yaml
   ```
   Wait for the server to listen on 8080, run the health checks (`health.md`), then stop it with Ctrl+C.
7. Install the service:
   ```bash
   sudo cp standalone/kestra.service /etc/systemd/system/kestra.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now kestra
   journalctl -u kestra -f
   ```
8. Run the health checks again, then hand off to `kestra-ops`.

## Notes

- Ports: set `micronaut.server.port` (UI and API, default 8080), `endpoints.all.port` (management and health, default 8081) and, on 2.0 only, `kestra.controller.port` (internal gRPC controller, default 50051) in `application.yaml` if they clash with something else. A clash on 50051 stops the server at startup with `Error while building gRPC server`.
- `SuccessExitStatus=143` stops systemd from marking a normal SIGTERM stop as a failure.
- Tune `-Xmx` to the host. Leave memory for the OS and for tasks that run as local processes.
- Docker-based tasks need Docker on the host and the `kestra` user in the `docker` group.
