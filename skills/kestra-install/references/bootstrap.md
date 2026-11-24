# Bootstrap and hand off

Run once the server answers on its URL (see `health.md`), on any target. Goal: a first admin identity and a `kestractl` context that `kestra-ops` can use.

Auth behavior changes between versions and editions. Check the Kestra docs for the installed version before telling the user what to click.

## 1. First admin

- **OSS**: open the UI. On a fresh instance Kestra asks to create the first user, or uses the basic auth credentials set in the config (`kestra.server.basicAuth`). Use the credentials from the `.env` or env file, never invent them.
- **EE**: create the first admin user in the UI setup, or through the documented setup command for the version. Then create an API token for that identity in the UI.

## 2. Credential for the CLI

- EE: use the API token. Keep it in a secret manager or an environment variable, not in a command.
- OSS with basic auth: use the username and password.

## 3. Register the context

Pass secrets as variables, not literals. Details and precedence live in `kestra-ops`, do not restate them here.

```bash
# token
kestractl config add <context> <host> <tenant> --token "$KESTRA_TOKEN"
# or basic auth
kestractl config add <context> <host> <tenant> --username "$KESTRA_USER" --password "$KESTRA_PASSWORD"
chmod 600 ~/.kestractl/config.yaml
kestractl config use <context>
```

Default tenant for OSS is `main`. Ask the user for the EE tenant.

## 4. Hand off

Check the context works with a read-only call (`kestractl flows list <namespace>`), then say the install is done and continue with the `kestra-ops` skill for flows, executions and namespaces. Do not keep operating from this skill.
