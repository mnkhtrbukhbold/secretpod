"""Exercise the public launchers with Python absent from the launcher's PATH."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from docker_lifecycle import ROOT, host, certificate, assert_secret, rpc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', default='secretpod:test')
    parser.add_argument('--manager-image', default='secretpod-manager:test')
    args = parser.parse_args()
    (ROOT / '.cache').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='manager lifecycle ', dir=ROOT / '.cache') as temporary:
        workspace = Path(temporary)
        first, restored, saved = (workspace / name for name in ['first vault', 'restored vault', 'saved backup'])
        environment = dict(os.environ, SECRETPOD_MANAGER_IMAGE=args.manager_image)
        if os.name == 'nt':
            shell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
            launcher = [str(shell), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File']
            extension = 'ps1'
            environment['PATH'] = os.pathsep.join([str(Path(shutil.which('docker')).parent), str(shell.parent), str(Path(os.environ['SystemRoot']) / 'System32')])
        else:
            launcher = [shutil.which('sh')]
            extension = 'sh'
            binaries = workspace / 'bin'
            binaries.mkdir()
            for name in ['docker', 'sh', 'dirname', 'basename', 'mkdir', 'id', 'stat']:
                (binaries / name).symlink_to(shutil.which(name))
            environment['PATH'] = str(binaries)
        assert shutil.which('python', path=environment['PATH']) is None
        assert shutil.which('python3', path=environment['PATH']) is None
        # A common /opt install must not hide the pinned manager's entrypoint.
        subprocess.run(['docker', 'run', '--rm', '--pull', 'never', '--mount',
                        f'type=bind,src={workspace},dst=/opt,readonly',
                        args.manager_image, '--help'], check=True, stdout=subprocess.DEVNULL)

        def manage(command, root=first, *options, retained=False, fail=False):
            script = (first if retained else ROOT) / ('scripts/host.' + extension)
            result = subprocess.run([*launcher, str(script), command, '--dir', str(root), *map(str, options)], env=environment)
            if fail:
                assert result.returncode != 0, 'Unsafe operation unexpectedly succeeded'
            else:
                result.check_returncode()

        try:
            manage('setup', first, '--image', args.image, '--url', 'https://localhost:20443', '--http-port', '20088', '--no-pull')
            manifest = host.read_install(first)
            context = certificate(first, manifest)
            url = manifest['url']
            session = rpc(url, context, 'account/register', {'email': 'lifecycle@example.com', 'password': 'isolated-test-password-123!', 'name': 'Manager fixture'})
            token = session['token']
            organization = rpc(url, context, 'vault/createOrganization', {'name': 'Manager fixture'}, token)['id']
            secret = rpc(url, context, 'vault/saveSecret', {'organizationId': organization, 'id': None, 'name': 'TEST_VALUE', 'value': 'synthetic-value-never-a-real-credential', 'project': 'Verification', 'environment': 'Development', 'kind': 'API key', 'description': 'Synthetic fixture'}, token)['id']
            key_hash = host.sha256(first / 'secrets/master_key')
            manage('setup', first, '--no-pull')
            assert host.sha256(first / 'secrets/master_key') == key_hash
            manage('status', retained=True)
            manage('trust-cert', retained=True)
            manage('stop', retained=True)
            manage('up', first, '--no-pull', retained=True)
            certificate(first, manifest)
            assert_secret(url, context, organization, secret)
            print('PASS: Python-free launcher, spaces in paths, retained commands, verified HTTPS, restart and key persistence', flush=True)

            manage('backup', first, '--backup', saved, retained=True)
            host.validate_backup(saved)
            assert host.sha256(saved / 'master_key') == key_hash
            manage('backup', first, '--backup', saved, fail=True)
            if os.name == 'nt':
                # Host ACLs, not chmod inside Linux, must protect Windows keys.
                check = "$ErrorActionPreference='Stop'; $acl=[IO.Directory]::GetAccessControl($env:SECRETPOD_ACL_TARGET); if(-not $acl.AreAccessRulesProtected){exit 1}; $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value; foreach($r in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])){if($r.IdentityReference.Value -notin @($sid,'S-1-5-18')){exit 2}}"
                for directory in [first, saved]:
                    subprocess.run([str(shell), '-NoProfile', '-Command', check], env=dict(os.environ, SECRETPOD_ACL_TARGET=str(directory)), check=True)
            else:
                for directory in [first, saved]:
                    assert directory.stat().st_uid == os.getuid()
                    assert directory.stat().st_mode & 0o777 == 0o700
            candidate = 'secretpod:manager-upgrade'
            host.run(['docker', 'build', '-t', candidate, '-'], input=f'FROM {args.image}\nLABEL org.secretpod.manager="upgrade"\n'.encode())
            manage('upgrade', first, '--image', candidate, '--no-pull', retained=True)
            certificate(first, host.read_install(first))
            assert_secret(url, context, organization, secret)
            manage('restore', restored, '--backup', saved, '--url', 'https://localhost:21443', '--http-port', '21088', '--no-pull', retained=True)
            result = host.read_install(restored)
            restored_context = certificate(restored, result)
            assert_secret(result['url'], restored_context, organization, secret)
            manage('restore', first, '--backup', saved, '--no-pull', fail=True)
            assert host.sha256(restored / 'secrets/master_key') == key_hash
            print('PASS: Python-free backup, upgrade, restore, private permissions and overwrite refusal', flush=True)

            previous = host.read_install(first)
            manage('upgrade', first, '--image', 'invalid.invalid/secretpod:missing', fail=True)
            assert host.read_install(first) == previous
            assert_secret(url, context, organization, secret)
            print('PASS: failed host-side image pull preserves the working vault', flush=True)

            broken = 'secretpod:manager-broken'
            host.run(['docker', 'build', '-t', broken, '-'], input=f'FROM {args.image}\nENTRYPOINT ["/missing-test-executable"]\n'.encode())
            manage('upgrade', first, '--image', broken, '--no-pull', fail=True)
            assert (first / 'upgrade-pending.json').exists()
            pending = json.loads((first / 'upgrade-pending.json').read_text())
            assert Path(pending['backup']).is_dir(), 'Recovery instructions must name an accessible host path'
            manage('up', first, '--no-pull', fail=True)
            backups = list((first / 'backups').iterdir())
            assert len(backups) == 2
            for directory in backups:
                host.validate_backup(directory)
            print('PASS: failed candidate retains recoverable backups and blocks unsafe restart', flush=True)
        finally:
            for root in [restored, first]:
                if (root / 'manifest.json').exists():
                    assert root.is_relative_to(workspace)
                    host.compose(root, host.read_install(root), 'down', '-v', '--remove-orphans')
    print('All container-manager lifecycle checks passed.', flush=True)


if __name__ == '__main__':
    main()
