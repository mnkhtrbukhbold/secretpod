import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    "export_source", Path(__file__).resolve().parents[1] / "scripts/export-source.py"
)
export_source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export_source)


class ExportSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.source = self.base / "source"
        self.source.mkdir()
        self.output = self.base / "release"

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, name, contents="public source"):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def test_exports_build_inputs_and_excludes_sensitive_sentinels(self):
        public = [
            "README.md", "Dockerfile", ".dockerignore", ".gitignore", ".gitattributes", "compose.yaml",
            "docs/development.md", "docs/self-hosting.md", "docs/demo.md",
            "deploy/demo.Dockerfile", "deploy/demo.Caddyfile",
            "secretpod/secretpod_flutter/lib/demo/demo_seed.dart",
            ".github/workflows/test.yaml", "scripts/start.ps1", "scripts/host.py",
            "deploy/Caddyfile", "deploy/manager.Dockerfile", "scripts/host.sh", "scripts/host.ps1", "tests/test_host.py", "secretpod/pubspec.lock",
            "secretpod/pubspec.yaml", "secretpod/secretpod_server/config/development.yaml",
            "secretpod/secretpod_server/lib/src/generated/protocol.yaml",
            "secretpod/secretpod_server/lib/server.dart",
            "secretpod/secretpod_client/lib/secretpod_client.dart",
            "secretpod/secretpod_flutter/web/index.html",
            "secretpod/secretpod_flutter/windows/runner/main.cpp",
            "secretpod/secretpod_flutter/ios/Runner.xcodeproj/project.pbxproj",
            "secretpod/secretpod_flutter/android/app/src/main/AndroidManifest.xml",
            "secretpod/secretpod_flutter/assets/config.json",
        ]
        private = [
            ".env", ".env.example", ".cache/source.dart", "docs/verification.md",
            "docs/superpowers/plans/private.md", "screenshots/private.png", "secretpod/AGENTS.md",
            "secretpod/secretpod_server/config/passwords.yaml",
            "secretpod/secretpod_server/config/passwords.backup.yaml",
            "secretpod/secretpod_server/data/vault.sqlite",
            "secretpod/secretpod_server/web/app/main.dart.js",
            "secretpod/secretpod_server/lib/.env.local",
            "secretpod/secretpod_server/lib/vault.json",
            "secretpod/secretpod_server/lib/credentials.json",
            "secretpod/secretpod_server/lib/example.pem",
            "secretpod/secretpod_server/lib/backup/source.dart",
            "secretpod/secretpod_server/lib/source.dart.bak",
            "scripts/__pycache__/host.pyc", "scripts/.env.production",
            "secretpod/secretpod_flutter/android/local.properties",
            "secretpod/secretpod_flutter/android/key.properties",
            "secretpod/secretpod_flutter/android/private.keystore",
            "secretpod/secretpod_flutter/windows/flutter/ephemeral/config.cmake",
            "secretpod/secretpod_flutter/ios/Flutter/Generated.xcconfig",
            "secretpod/secretpod_flutter/ios/Flutter/flutter_export_environment.sh",
            "secretpod/secretpod_flutter/ios/Runner.xcodeproj/xcuserdata/me.xcuserdatad/private.xml",
        ]
        for name in public:
            self.put(name)
        for name in private:
            self.put(name, "PRIVATE_SENTINEL")
        manifest_path = export_source.export(self.source, self.output)
        actual = sorted(p.relative_to(self.output).as_posix() for p in self.output.rglob("*") if p.is_file())
        self.assertEqual(actual, sorted(public))
        manifest = json.loads(manifest_path.read_text())
        self.assertEqual([entry["path"] for entry in manifest["files"]], sorted(public))
        for path in self.output.rglob("*"):
            if path.is_file():
                self.assertNotIn(b"PRIVATE_SENTINEL", path.read_bytes())

    def test_existing_destination_is_not_overwritten(self):
        self.put("README.md")
        self.output.mkdir()
        sentinel = self.output / "keep.txt"
        sentinel.write_text("preserve")
        with self.assertRaises(ValueError):
            export_source.export(self.source, self.output)
        self.assertEqual(sentinel.read_text(), "preserve")

    def test_source_or_ancestor_cannot_be_export_destination(self):
        self.put("README.md")
        for destination in (self.source, self.base):
            with self.assertRaises(ValueError):
                export_source.export(self.source, destination)

    def test_symlink_does_not_leak_external_file(self):
        outside = self.base / "private.dart"
        outside.write_text("PRIVATE_SENTINEL")
        link = self.source / "secretpod/secretpod_server/lib/linked.dart"
        link.parent.mkdir(parents=True)
        try:
            link.symlink_to(outside)
        except OSError:
            self.skipTest("Host does not permit symlink creation")
        self.put("README.md")
        export_source.export(self.source, self.output)
        self.assertFalse((self.output / link.relative_to(self.source)).exists())

    @unittest.skipUnless(os.name == 'nt', 'Windows directory junction test')
    def test_junction_is_excluded_without_python312_junction_helper(self):
        outside = self.base / 'external'
        outside.mkdir()
        (outside / 'private.dart').write_text('PRIVATE_SENTINEL')
        link = self.source / 'secretpod/secretpod_server/lib/linked'
        link.parent.mkdir(parents=True)
        result = subprocess.run(['cmd', '/c', 'mklink', '/J', str(link), str(outside)], capture_output=True)
        self.assertEqual(result.returncode, 0, 'Could not create the junction fixture')
        self.put('README.md')
        # Older Python releases lack Path.is_junction; emulate its unavailable
        # detection while using a real Windows directory junction.
        with mock.patch.object(Path, 'is_junction', return_value=False, create=True):
            export_source.export(self.source, self.output)
        self.assertFalse((self.output / link.relative_to(self.source)).exists())


if __name__ == "__main__":
    unittest.main()
