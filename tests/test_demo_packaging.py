"""Opt-in HTTP checks of the demo Caddy config against synthetic static files.

Run with SECRETPOD_DEMO_CONTAINER_TEST=1 and Docker available. This checks the
actual Caddy routing/cache behavior without rebuilding Flutter or reading a vault.
"""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
CADDY_IMAGE = "caddy:2.11.2-alpine"


@unittest.skipUnless(
    os.environ.get("SECRETPOD_DEMO_CONTAINER_TEST") == "1",
    "Set SECRETPOD_DEMO_CONTAINER_TEST=1 to run Docker HTTP checks",
)
class DemoPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="secretpod-demo-http-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.web = Path(cls.temporary.name)
        fixtures = {
            "index.html": "<!doctype html><title>Synthetic demo fixture</title>",
            "flutter.js": "// synthetic loader",
            "flutter_bootstrap.js": "// synthetic bootstrap",
            "main.dart.js": "// synthetic demo code",
            "flutter_service_worker.js": "// synthetic worker",
            "version.json": '{"version":"fixture"}',
            "manifest.json": '{"name":"fixture"}',
            "assets/font.txt": "synthetic asset",
            "canvaskit/canvaskit.wasm": "synthetic wasm fixture",
            "icons/Icon-192.png": "synthetic icon fixture",
        }
        for name, contents in fixtures.items():
            path = cls.web / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents, encoding="utf-8")
        cls.urls = []
        config = ROOT / "deploy/demo.Caddyfile"
        if not config.is_file():
            raise AssertionError("The demo Caddy configuration is missing")
        # Exercise both the local default and Railway's runtime PORT override.
        for port, extra in ((8080, []), (8091, ["--env", "PORT=8091"])):
            container = cls.docker(
                "run", "--detach", "--rm", "--publish", f"127.0.0.1::{port}",
                "--mount", f"type=bind,source={config},target=/etc/caddy/Caddyfile,readonly",
                "--mount", f"type=bind,source={cls.web},target=/srv,readonly",
                *extra, CADDY_IMAGE,
            )
            cls.addClassCleanup(cls.remove_container, container)
            published = cls.docker("port", container, f"{port}/tcp")
            url = f"http://{published}"
            cls.urls.append(url)
            deadline = time.monotonic() + 20
            while True:
                try:
                    with urlopen(url + "/", timeout=2):
                        break
                except (URLError, TimeoutError, ConnectionError):
                    # Docker can accept a connection before Caddy is ready.
                    if time.monotonic() >= deadline:
                        logs = cls.docker("logs", container)
                        raise AssertionError(f"Caddy did not start: {logs}")
                    time.sleep(0.2)

    @staticmethod
    def docker(*args):
        result = subprocess.run(
            ["docker", *args], check=True, capture_output=True, text=True, timeout=120,
        )
        return result.stdout.strip()

    @staticmethod
    def remove_container(container):
        subprocess.run(
            ["docker", "rm", "--force", container], capture_output=True, timeout=30,
        )

    def test_healthcheck_accepts_railway_host_and_is_not_cached(self):
        for url in self.urls:
            with self.subTest(url=url):
                request = Request(url + "/healthz", headers={"Host": "healthcheck.railway.app"})
                with urlopen(request, timeout=3) as response:
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.read(), b"ok")
                    self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_app_shell_is_cached_briefly_at_edge_and_revalidated_by_browsers(self):
        for url in self.urls:
            for path in ("/", "/index.html", "/workspace/projects?sort=name"):
                with self.subTest(url=url, path=path):
                    with urlopen(url + path, timeout=3) as response:
                        self.assertEqual(response.status, 200)
                        self.assertIn(b"Synthetic demo fixture", response.read())
                        self.assertEqual(
                            response.headers["Cache-Control"],
                            "public, max-age=0, s-maxage=60, must-revalidate",
                        )
                        self.assertEqual(response.headers["X-Content-Type-Options"], "nosniff")

    def test_runtime_files_are_edge_cacheable_but_require_browser_revalidation(self):
        for url in self.urls:
            for path in (
                "/flutter.js", "/flutter_bootstrap.js", "/main.dart.js",
                "/manifest.json",
            ):
                with self.subTest(url=url, path=path):
                    with urlopen(url + path, timeout=3) as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(
                            response.headers["Cache-Control"],
                            "public, max-age=0, s-maxage=3600, must-revalidate",
                        )

    def test_service_worker_and_version_metadata_are_never_cached(self):
        for url in self.urls:
            for path in ("/flutter_service_worker.js", "/version.json"):
                with self.subTest(url=url, path=path):
                    with urlopen(url + path, timeout=3) as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_static_assets_have_bounded_cache(self):
        for url in self.urls:
            for path in ("/assets/font.txt", "/canvaskit/canvaskit.wasm", "/icons/Icon-192.png"):
                with self.subTest(url=url, path=path):
                    with urlopen(url + path, timeout=3) as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(
                            response.headers["Cache-Control"],
                            "public, max-age=0, s-maxage=3600, must-revalidate",
                        )

    def test_missing_asset_is_404_instead_of_html(self):
        for url in self.urls:
            with self.subTest(url=url):
                with self.assertRaises(HTTPError) as raised:
                    urlopen(url + "/assets/missing-font.txt", timeout=3)
                with raised.exception as response:
                    self.assertEqual(response.code, 404)


if __name__ == "__main__":
    unittest.main()
