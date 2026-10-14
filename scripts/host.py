#!/usr/bin/env python3
"""SecretPod lifecycle CLI. Python standard library only; never prints secrets."""
import argparse
import base64
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tarfile
import time
from urllib.parse import urlsplit

SOURCE = Path(__file__).resolve().parents[1]
DEFAULT_IMAGE = 'ghcr.io/mnkhtrbukhbold/secretpod:0.1.0'


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def public_url(value):
    if not isinstance(value, str) or not re.fullmatch(r'https://[a-zA-Z0-9.-]+(?::[0-9]+)?/?', value):
        raise ValueError('Use an HTTPS origin such as https://vault.example.com, with no path or credentials.')
    parsed = urlsplit(value)
    if not parsed.hostname or '..' in parsed.hostname or parsed.hostname.startswith(('.', '-')):
        raise ValueError('Invalid HTTPS hostname.')
    if not 1 <= (parsed.port or 443) <= 65535:
        raise ValueError('Invalid HTTPS port.')
    return value.rstrip('/').lower()


def image_name(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._/@:+-]+', value):
        raise ValueError('Invalid image reference.')
    if ':latest' in value or (':' not in value.rsplit('/', 1)[-1] and '@sha256:' not in value):
        raise ValueError('Use a versioned image tag or digest, not latest.')
    return value


def private_write(path, content, mode=0o600):
    path = Path(path)
    if path.is_symlink():
        raise ValueError('Refusing to write through a symbolic link.')
    temporary = path.with_name(path.name + '.tmp')
    with temporary.open('x', encoding='utf-8', newline='\n') as stream:
        os.chmod(temporary, mode)
        stream.write(content)
    os.replace(temporary, path)


def private_directory(path):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name == 'nt':
        environment = dict(os.environ, SECRETPOD_ACL_TARGET=str(path))
        command = """$ErrorActionPreference='Stop'
$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl=New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
$acl.SetOwner($sid)
foreach($identity in @($sid,(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')))) {
  $rule=New-Object System.Security.AccessControl.FileSystemAccessRule($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
  $acl.AddAccessRule($rule)
}
[System.IO.Directory]::SetAccessControl($env:SECRETPOD_ACL_TARGET,$acl)
"""
        subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command], env=environment, check=True, stdout=subprocess.DEVNULL)
    else:
        os.chmod(path, 0o700)


def validate_manifest(manifest):
    if manifest.get('version') != 1:
        raise ValueError('Unsupported installation manifest version.')
    public_url(manifest['url'])
    image_name(manifest['image'])
    if not re.fullmatch(r'secretpod-[a-f0-9]{12}', manifest['project']):
        raise ValueError('Invalid Compose project identity.')
    for field in ['http_port', 'https_port']:
        if type(manifest[field]) is not int or not 1 <= manifest[field] <= 65535:
            raise ValueError('Invalid listener port.')
    if manifest['https_port'] != (urlsplit(manifest['url']).port or 443):
        raise ValueError('HTTPS listener port must match the public URL.')
    return manifest


def validate_key(path):
    try:
        value = path.read_text(encoding='ascii').strip()
        if len(base64.b64decode(value, validate=True)) != 32:
            raise ValueError()
    except (OSError, ValueError, UnicodeError):
        raise ValueError('Missing or invalid master key; restore the matching key from backup.') from None


def read_install(root):
    manifest = validate_manifest(json.loads((root / 'manifest.json').read_text()))
    validate_key(root / 'secrets/master_key')
    return manifest


def write_config(root, manifest):
    validate_manifest(manifest)
    hostname = urlsplit(manifest['url']).hostname
    content = '\n'.join([
        'SECRETPOD_IMAGE=' + manifest['image'],
        'SECRETPOD_PUBLIC_URL=' + manifest['url'],
        'SECRETPOD_HOST=' + hostname,
        'SECRETPOD_BIND=' + ('127.0.0.1' if hostname == 'localhost' else '0.0.0.0'),
        'SECRETPOD_HTTP_PORT=' + str(manifest['http_port']),
        'SECRETPOD_HTTPS_PORT=' + str(manifest['https_port']), '',
    ])
    private_write(root / 'config.env', content)
    private_write(root / 'manifest.json', json.dumps(manifest, indent=2) + '\n')


def prepare_install(root, url, image, http_port=80):
    root = Path(root)
    if root.is_symlink():
        raise ValueError('Installation directory must not be a symbolic link.')
    if (root / 'manifest.json').exists():
        manifest = read_install(root)
        if (url and public_url(url) != manifest['url']) or (image and image_name(image) != manifest['image']):
            raise ValueError('Existing installation differs. Use upgrade for image changes; preserve its URL and key.')
        return manifest
    url = public_url(url or 'https://localhost')
    image = image_name(image or DEFAULT_IMAGE)
    manifest = validate_manifest(dict(version=1, url=url, image=image, project='secretpod-' + secrets.token_hex(6), http_port=http_port, https_port=urlsplit(url).port or 443))
    if root.exists() and any(root.iterdir()):
        raise ValueError('Installation directory is not empty; refusing to generate or replace a key.')
    private_directory(root)
    (root / 'secrets').mkdir(mode=0o700)
    # Read-only bind mount, inside host-private directories, readable by container UID 10001.
    private_write(root / 'secrets/master_key', base64.b64encode(secrets.token_bytes(32)).decode() + '\n', 0o444)
    shutil.copyfile(SOURCE / 'compose.yaml', root / 'compose.yaml')
    shutil.copyfile(SOURCE / 'deploy/Caddyfile', root / 'Caddyfile')
    (root / 'deploy').mkdir()
    (root / 'scripts').mkdir()
    shutil.copyfile(SOURCE / 'deploy/Caddyfile', root / 'deploy/Caddyfile')
    shutil.copyfile(Path(__file__), root / 'scripts/host.py')
    write_config(root, manifest)
    return manifest


@contextlib.contextmanager
def installation_lock(root):
    root.parent.mkdir(parents=True, exist_ok=True)
    lock = root.parent / ('.' + root.name + '-operation')
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError:
        raise ValueError('Another operation is active. After a crash, verify no operation is running before removing ' + str(lock)) from None
    try:
        yield
    finally:
        lock.rmdir()


@contextlib.contextmanager
def operation_lock(root):
    path = root / '.operation.lock'
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError('Another operation is active. If it crashed, verify no operation is running before removing .operation.lock.') from None
    try:
        os.write(descriptor, str(os.getpid()).encode())
        os.close(descriptor)
        yield
    finally:
        path.unlink()


def run(arguments, **kwargs):
    return subprocess.run(arguments, check=True, **kwargs)


def compose(root, manifest, *arguments, **kwargs):
    return run(['docker', 'compose', '--project-name', manifest['project'], '--env-file', str(root / 'config.env'), '--project-directory', str(root), '-f', str(root / 'compose.yaml'), *arguments], **kwargs)


def prerequisites():
    if not shutil.which('docker'):
        raise ValueError('Install Docker Engine/Desktop with Docker Compose v2 first.')
    run(['docker', 'info'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    run(['docker', 'compose', 'version'], stdout=subprocess.DEVNULL)


def ensure_operable(root):
    if (root / 'upgrade-pending.json').exists():
        raise ValueError('An upgrade did not complete. Inspect upgrade-pending.json and restore its backup to a new directory; do not restart or downgrade this vault blindly.')


def start(root, manifest, pull=True, upgrading=False):
    if not upgrading:
        ensure_operable(root)
    if pull:
        compose(root, manifest, 'pull')
    compose(root, manifest, 'up', '-d', '--wait', '--wait-timeout', '120', '--pull', 'never')


def backup(root, manifest, destination, resume=True):
    destination = Path(destination).resolve()
    if destination.exists():
        raise ValueError('Backup destination must not exist.')
    private_directory(destination)
    container = compose(root, manifest, 'ps', '--all', '-q', 'secretpod', stdout=subprocess.PIPE, text=True).stdout.strip()
    status = run(['docker', 'inspect', '--format', '{{.State.Status}}', container], stdout=subprocess.PIPE, text=True).stdout.strip() if container else ''
    running = status in ('running', 'restarting')
    if container:
        compose(root, manifest, 'stop', 'secretpod')
    completed = False
    try:
        with (destination / 'data.tar').open('xb') as output:
            os.chmod(destination / 'data.tar', 0o600)
            run(['docker', 'run', '--rm', '--user', '0', '--entrypoint', 'tar', '-v', manifest['project'] + '_vault-data:/data:ro', manifest['image'], '-cpf', '-', '-C', '/data', '.'], stdout=output)
        private_write(destination / 'master_key', (root / 'secrets/master_key').read_text())
        private_write(destination / 'manifest.json', json.dumps(manifest, indent=2))
        private_write(destination / 'sha256.json', json.dumps({name: sha256(destination / name) for name in ['data.tar', 'master_key', 'manifest.json']}))
        validate_backup(destination)
        completed = True
    finally:
        if running and (resume or not completed):
            compose(root, manifest, 'start', 'secretpod')
    return destination


def validate_backup(directory):
    directory = Path(directory)
    for name in ['sha256.json', 'data.tar', 'master_key', 'manifest.json']:
        if not (directory / name).is_file() or (directory / name).is_symlink():
            raise ValueError('Backup is incomplete or contains symbolic links.')
    hashes = json.loads((directory / 'sha256.json').read_text())
    for name in ['data.tar', 'master_key', 'manifest.json']:
        if hashes.get(name) != sha256(directory / name):
            raise ValueError('Backup checksum mismatch.')
    validate_key(directory / 'master_key')
    manifest = validate_manifest(json.loads((directory / 'manifest.json').read_text()))
    allowed = {'vault.sqlite', 'vault.sqlite-wal', 'vault.sqlite-shm', 'vault.lock', 'vault.json'}
    names = set()
    with tarfile.open(directory / 'data.tar', 'r:') as archive:
        for member in archive:
            name = member.name.removeprefix('./')
            if member.isdir() and name in ('', '.'):
                continue
            if not member.isfile() or name not in allowed or name in names:
                raise ValueError('Unsafe or unexpected data archive entry.')
            names.add(name)
    if 'vault.sqlite' not in names:
        raise ValueError('Data archive has no SQLite vault.')
    return manifest


def restore(root, directory, url=None, http_port=80, pull=True):
    original = validate_backup(directory)
    if root.exists():
        raise ValueError('Restore requires a new installation directory; existing data is never overwritten.')
    manifest = prepare_install(root, url or original['url'], original['image'], http_port)
    key = root / 'secrets/master_key'
    key.chmod(0o600)
    private_write(key, (directory / 'master_key').read_text(), 0o444)
    with operation_lock(root):
        if pull:
            compose(root, manifest, 'pull')
        compose(root, manifest, 'create', 'secretpod')
        with (directory / 'data.tar').open('rb') as source:
            run(['docker', 'run', '--rm', '-i', '--user', '0', '--entrypoint', 'tar', '-v', manifest['project'] + '_vault-data:/data', manifest['image'], '-xpf', '-', '-C', '/data'], stdin=source)
        start(root, manifest, pull=False)
    return manifest


def upgrade(root, manifest, image, pull=True):
    ensure_operable(root)
    image = image_name(image)
    if image == manifest['image']:
        raise ValueError('Upgrade requires a different version tag or digest.')
    if pull:
        run(['docker', 'pull', image])
    destination = root / 'backups' / (time.strftime('%Y%m%d-%H%M%S') + '-' + secrets.token_hex(3))
    backup(root, manifest, destination, resume=False)
    updated = dict(manifest, image=image)
    pending = root / 'upgrade-pending.json'
    private_write(pending, json.dumps({'backup': str(destination), 'previousImage': manifest['image'], 'candidateImage': image}))
    write_config(root, updated)
    try:
        start(root, updated, pull=False, upgrading=True)
    except subprocess.CalledProcessError:
        compose(root, updated, 'stop', 'secretpod')
        raise ValueError(f'Upgrade failed. Application stopped; restore backup {destination} to a new directory. Do not downgrade a migrated database in place.') from None
    pending.unlink()
    print('Pre-upgrade backup: ' + str(destination))
    return updated


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['setup', 'up', 'stop', 'status', 'backup', 'restore', 'upgrade', 'trust-cert'])
    parser.add_argument('--dir', type=Path, default=Path.home() / 'secretpod')
    parser.add_argument('--url', help='Public HTTPS origin; defaults to https://localhost for setup')
    parser.add_argument('--image', help='Version tag or digest; required for upgrade')
    parser.add_argument('--http-port', type=int, default=80)
    parser.add_argument('--backup', type=Path, help='New output directory for backup; existing backup directory for restore')
    parser.add_argument('--no-pull', action='store_true', help='Use already-loaded images (offline/testing)')
    args = parser.parse_args(argv)
    root = args.dir.expanduser().absolute()
    prerequisites()
    with installation_lock(root):
        dispatch(args, parser, root)


def dispatch(args, parser, root):
    if args.command == 'restore':
        if not args.backup:
            parser.error('restore requires --backup')
        manifest = restore(root, args.backup.resolve(), args.url, args.http_port, not args.no_pull)
    else:
        if args.command == 'setup':
            manifest = prepare_install(root, args.url, args.image, args.http_port)
        else:
            manifest = read_install(root)
        with operation_lock(root):
            if args.command in ('setup', 'up'):
                start(root, manifest, not args.no_pull)
            elif args.command == 'stop':
                compose(root, manifest, 'stop')
            elif args.command == 'status':
                compose(root, manifest, 'ps')
            elif args.command == 'backup':
                if not args.backup:
                    parser.error('backup requires --backup')
                print('Backup: ' + str(backup(root, manifest, args.backup)))
            elif args.command == 'upgrade':
                if not args.image:
                    parser.error('upgrade requires --image')
                manifest = upgrade(root, manifest, args.image, not args.no_pull)
            elif args.command == 'trust-cert':
                if urlsplit(manifest['url']).hostname != 'localhost':
                    raise ValueError('trust-cert is only for local HTTPS installations.')
                compose(root, manifest, 'cp', 'proxy:/data/caddy/pki/authorities/local/root.crt', str(root / 'local-root.crt'))
                print('Local CA certificate: ' + str(root / 'local-root.crt') + '. Import into your trust store to trust local HTTPS.')
    print('SecretPod: ' + manifest['url'])


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, tarfile.TarError, subprocess.CalledProcessError) as error:
        print('Error: ' + str(error), file=sys.stderr)
        sys.exit(1)
