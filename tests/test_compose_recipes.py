"""Exercise recipe parsing/interpolation with the actual Docker Compose CLI.

Run: python -m unittest discover -s tests -v
No images are pulled and no containers are started by these tests.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RECIPES = ROOT / "skills/kestra-install/references/docker-compose"
NAMES = (
    "jdbc-postgres",
    "jdbc-postgres-redis",
    "elasticsearch-redis",
    "elasticsearch-kafka",
)
COMPOSE = [shutil.which("docker-compose")] if shutil.which("docker-compose") else ["docker", "compose"]
DUMMY_ENV = {
    "POSTGRES_PASSWORD": "test-db-password",
    "REDIS_PASSWORD": "test-redis-password",
    "KESTRA_USERNAME": "test@example.com",
    "KESTRA_PASSWORD": "TestPassword123!",
    "KESTRA_ENCRYPTION_KEY": "MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=",
    "KESTRA_LICENSE_ID": "test-license-id",
    "KESTRA_LICENSE_FINGERPRINT": "test-fingerprint",
    "KESTRA_LICENSE_KEY": "test-license-key",
}


class ComposeRecipes(unittest.TestCase):
    def render(self, name, values):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            lines = []
            for key, value in values.items():
                quoted = value.replace("\\", "\\\\").replace("'", "\\'")
                lines.append(f"{key}='{quoted}'\n")
            env_file.write_text("".join(lines))
            # Ambient credentials must not hide a missing-input failure.
            environment = {key: value for key, value in os.environ.items() if key not in DUMMY_ENV}
            return subprocess.run(
                COMPOSE + ["--env-file", str(env_file), "-f", str(RECIPES / name / "docker-compose.yml"), "config", "--format", "json"],
                capture_output=True, text=True, env=environment,
            )

    def test_all_recipes_render_with_supplied_credentials(self):
        for name in NAMES:
            with self.subTest(recipe=name):
                result = self.render(name, DUMMY_ENV)
                self.assertEqual(result.returncode, 0, result.stderr)
                config = json.loads(result.stdout)
                self.assertIn("kestra", config["services"])

    def test_missing_access_password_fails_before_startup(self):
        for name in NAMES:
            with self.subTest(recipe=name):
                values = dict(DUMMY_ENV)
                del values["KESTRA_PASSWORD"]
                result = self.render(name, values)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("KESTRA_PASSWORD", result.stderr)

    def test_password_characters_survive_without_yaml_interpolation(self):
        for name in NAMES:
            with self.subTest(recipe=name):
                values = dict(DUMMY_ENV)
                values["KESTRA_PASSWORD"] = "Quote'colon:hash#dollar$123 space"
                result = self.render(name, values)
                self.assertEqual(result.returncode, 0, result.stderr)
                environment = json.loads(result.stdout)["services"]["kestra"]["environment"]
                # `config` emits a reusable Compose model and escapes literal
                # interpolation markers again for that serialized model.
                self.assertEqual(environment["KESTRA_PASSWORD"].replace("$$", "$"), values["KESTRA_PASSWORD"])
                self.assertIn("${KESTRA_PASSWORD}", environment["KESTRA_CONFIGURATION"])
                self.assertNotIn(values["KESTRA_PASSWORD"], environment["KESTRA_CONFIGURATION"])

    def test_enterprise_recipes_require_a_license(self):
        for name in NAMES[1:]:
            with self.subTest(recipe=name):
                values = dict(DUMMY_ENV)
                del values["KESTRA_LICENSE_KEY"]
                result = self.render(name, values)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("KESTRA_LICENSE_KEY", result.stderr)


if __name__ == "__main__":
    unittest.main()
