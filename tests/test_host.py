import importlib.util
import contextlib
import io
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('host', Path(__file__).parents[1] / 'scripts' / 'host.py')
host = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(host)


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'installation'

    def test_repeated_setup_preserves_key_and_project(self):
        first = host.prepare_install(self.root, 'https://vault.example.com', 'example/secretpod:1.0.0')
        key = (self.root / 'secrets/master_key').read_bytes()
        second = host.prepare_install(self.root, None, None)
        self.assertEqual(key, (self.root / 'secrets/master_key').read_bytes())
        self.assertEqual(first, second)

    def test_missing_key_in_existing_installation_is_fatal(self):
        host.prepare_install(self.root, 'https://vault.example.com', 'example/secretpod:1.0.0')
        key = self.root / 'secrets/master_key'
        key.chmod(0o600)
        key.unlink()
        with self.assertRaisesRegex(ValueError, 'key'):
            host.prepare_install(self.root, None, None)
        self.assertFalse(key.exists())

    def test_rejects_unsafe_urls_before_creating_state(self):
        for url in ['http://vault.example.com', 'https://a.example/path', 'https://user:pw@a.example', 'https://a.example\n{', 'https://a.example/?x=1']:
            with self.subTest(url=url):
                with self.assertRaises(ValueError):
                    host.prepare_install(self.root, url, 'example/secretpod:1.0.0')
                self.assertFalse(self.root.exists())

    def test_existing_setup_does_not_silently_change_domain_or_image(self):
        host.prepare_install(self.root, 'https://vault.example.com', 'example/secretpod:1.0.0')
        with self.assertRaises(ValueError):
            host.prepare_install(self.root, 'https://other.example.com', 'example/secretpod:1.0.0')
        with self.assertRaises(ValueError):
            host.prepare_install(self.root, None, 'example/secretpod:2.0.0')

    def test_arbitrary_existing_directory_is_not_adopted(self):
        self.root.mkdir()
        (self.root / 'keep.txt').write_text('preserve')
        with self.assertRaises(ValueError):
            host.prepare_install(self.root, 'https://localhost', 'example/secretpod:1.0.0')
        self.assertEqual((self.root / 'keep.txt').read_text(), 'preserve')

    def test_restore_rejects_traversal_and_corrupt_backup(self):
        import io
        import tarfile
        backup = Path(self.temp.name) / 'backup'
        backup.mkdir()
        manifest = {'version': 1, 'url': 'https://localhost', 'image': 'example/secretpod:1.0.0', 'project': 'secretpod-012345abcdef', 'http_port': 80, 'https_port': 443}
        (backup / 'manifest.json').write_text(json.dumps(manifest))
        (backup / 'master_key').write_text('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=')
        with tarfile.open(backup / 'data.tar', 'w') as archive:
            entry = tarfile.TarInfo('../escape')
            entry.size = 3
            archive.addfile(entry, io.BytesIO(b'bad'))
        (backup / 'sha256.json').write_text(json.dumps({name: host.sha256(backup / name) for name in ['manifest.json', 'master_key', 'data.tar']}))
        with self.assertRaisesRegex(ValueError, 'archive'):
            host.validate_backup(backup)
        (backup / 'master_key').write_text('corrupted')
        with self.assertRaises(ValueError):
            host.validate_backup(backup)

    def test_installation_lock_rejects_concurrent_operation(self):
        self.root.mkdir()
        with host.operation_lock(self.root):
            with self.assertRaisesRegex(ValueError, 'operation'):
                with host.operation_lock(self.root):
                    pass

    def test_shared_lock_covers_creation_of_new_destination(self):
        with host.installation_lock(self.root):
            self.assertFalse(self.root.exists())
            with self.assertRaisesRegex(ValueError, 'operation'):
                with host.installation_lock(self.root):
                    pass

    def test_key_directory_is_private_on_the_host(self):
        host.prepare_install(self.root, 'https://localhost', 'example/secretpod:1.0.0')
        if os.name == 'nt':
            command = """$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$acl=[System.IO.Directory]::GetAccessControl($env:SECRETPOD_ACL_TARGET)
if(-not $acl.AreAccessRulesProtected) { exit 1 }
foreach($rule in $acl.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier])) {
 if($rule.IdentityReference.Value -notin @($sid,'S-1-5-18')) { exit 2 }
}
"""
            result = subprocess.run(['powershell.exe', '-NoProfile', '-Command', command], env=dict(os.environ, SECRETPOD_ACL_TARGET=str(self.root)))
            self.assertEqual(result.returncode, 0)
        else:
            self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)

    def test_interrupted_upgrade_blocks_start_before_docker_is_called(self):
        manifest = host.prepare_install(self.root, 'https://localhost', 'example/secretpod:1.0.0')
        (self.root / 'upgrade-pending.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'restore'):
            host.start(self.root, manifest, pull=False)

    def test_release_archive_checksum_rejects_corruption(self):
        archive = Path(self.temp.name) / 'image.tar.gz'
        archive.write_bytes(b'abc')
        host.verify_archive(archive, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  image.tar.gz')
        archive.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            host.verify_archive(archive, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')

    def test_container_setup_retains_python_free_management_launchers(self):
        host.prepare_install(self.root, 'https://localhost', 'example/secretpod:1.0.0')
        self.assertTrue((self.root / 'scripts/host.sh').is_file())
        self.assertTrue((self.root / 'scripts/host.ps1').is_file())

    def test_precreated_private_destination_must_be_empty(self):
        self.root.mkdir()
        host.require_empty_destination(self.root, allow_empty=True)
        (self.root / 'keep.txt').write_text('preserve')
        with self.assertRaises(ValueError):
            host.require_empty_destination(self.root, allow_empty=True)
        self.assertEqual((self.root / 'keep.txt').read_text(), 'preserve')

    def test_default_destination_refuses_existing_empty_directory(self):
        self.root.mkdir()
        with self.assertRaises(ValueError):
            host.require_empty_destination(self.root)

    def test_pull_preflight_returns_image_without_creating_keys_or_installation(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            host.main(['setup', '--dir', str(self.root), '--image', 'private.example/team/vault:2.0', '--print-image'])
        self.assertEqual(output.getvalue().strip(), 'private.example/team/vault:2.0')
        self.assertFalse(self.root.exists())

    def test_pull_preflight_reads_the_installed_version(self):
        host.prepare_install(self.root, 'https://localhost', 'private.example/team/vault:1.0')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            host.main(['up', '--dir', str(self.root), '--print-image'])
        self.assertEqual(output.getvalue().strip(), 'private.example/team/vault:1.0')


if __name__ == '__main__':
    unittest.main()
