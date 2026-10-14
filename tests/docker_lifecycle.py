"""Real Docker/HTTPS lifecycle verification, using only synthetic data."""
import argparse
import importlib.util
import json
import http.client
from pathlib import Path
import ssl
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('host', ROOT / 'scripts/host.py')
host = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(host)


def call(url, context, path, data=None, token=None, origin=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if origin:
        headers['Origin'] = origin
    request = Request(url + path, data=None if data is None else json.dumps(data).encode(), headers=headers)
    with urlopen(request, context=context, timeout=20) as response:
        body = response.read()
        return response.status, response.headers, body


def rpc(url, context, method, data, token=None):
    return json.loads(call(url, context, '/api/' + method, data, token)[2])


def certificate(root, manifest):
    target = root / 'local-root.crt'
    for attempt in range(30):
        try:
            host.compose(root, manifest, 'cp', 'proxy:/data/caddy/pki/authorities/local/root.crt', str(target), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            context = ssl.create_default_context(cafile=str(target))
            call(manifest['url'], context, '/healthz')
            return context
        except (subprocess.CalledProcessError, OSError, URLError):
            time.sleep(1)
    raise AssertionError('Verified local TLS health never became ready.')


def assert_secret(url, context, organization, secret):
    session = rpc(url, context, 'account/login', {'email': 'lifecycle@example.com', 'password': 'isolated-test-password-123!'})
    value = rpc(url, context, 'vault/revealSecret', {'organizationId': organization, 'id': secret}, session['token'])
    assert value == 'synthetic-value-never-a-real-credential', 'Secret could not be decrypted after lifecycle operation'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', default='secretpod:test')
    args = parser.parse_args()
    host.prerequisites()
    host.run(['docker', 'pull', 'caddy:2.11.2-alpine'])
    cache = ROOT / '.cache'
    cache.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='docker-lifecycle-', dir=cache) as directory:
        workspace = Path(directory)
        first, restored = workspace / 'first', workspace / 'restored'
        installations = []
        try:
            manifest = host.prepare_install(first, 'https://localhost:18443', args.image, 18088)
            installations.append((first, manifest))
            host.start(first, manifest, pull=False)
            context = certificate(first, manifest)
            url = manifest['url']
            redirect = http.client.HTTPConnection('localhost', 18088, timeout=10)
            redirect.request('GET', '/test-redirect', headers={'Host': 'localhost:18088'})
            response = redirect.getresponse()
            assert response.status == 308 and response.getheader('Location') == url + '/test-redirect'
            response.read()
            redirect.close()
            status, headers, body = call(url, context, '/app-config.json')
            assert status == 200 and 'no-store' in headers.get('Cache-Control', '')
            assert json.loads(body)['apiUrl'] == url + '/api/'
            assert b'SecretPod' in call(url, context, '/')[2]
            assert 'main.dart.js' in call(url, context, '/flutter_bootstrap.js')[2].decode()
            try:
                call(url, context, '/api/account/login', {}, origin='https://untrusted.example')
                raise AssertionError('Untrusted browser origin accepted')
            except HTTPError as error:
                assert error.code == 403
            print('PASS: fresh installation, verified HTTPS, runtime config, restricted origin', flush=True)

            session = rpc(url, context, 'account/register', {'email': 'lifecycle@example.com', 'password': 'isolated-test-password-123!', 'name': 'Lifecycle fixture'})
            token = session['token']
            organization = rpc(url, context, 'vault/createOrganization', {'name': 'Synthetic organization'}, token)['id']
            secret = rpc(url, context, 'vault/saveSecret', {'organizationId': organization, 'id': None, 'name': 'TEST_VALUE', 'value': 'synthetic-value-never-a-real-credential', 'project': 'Verification', 'environment': 'Development', 'kind': 'API key', 'description': 'Synthetic fixture'}, token)['id']
            assert_secret(url, context, organization, secret)
            key_hash = host.sha256(first / 'secrets/master_key')
            assert host.prepare_install(first, None, None) == manifest
            assert host.sha256(first / 'secrets/master_key') == key_hash
            host.compose(first, manifest, 'restart', 'secretpod')
            certificate(first, manifest)
            assert_secret(url, context, organization, secret)
            print('PASS: real account/secret lifecycle, setup idempotence and restart persistence', flush=True)

            saved = host.backup(first, manifest, workspace / 'saved')
            assert host.sha256(saved / 'master_key') == key_hash
            certificate(first, manifest)
            assert_secret(url, context, organization, secret)
            # The first release has no older published version. A different image
            # ID verifies container replacement; schema migration tests are in Dart.
            candidate = 'secretpod:lifecycle-upgrade'
            host.run(['docker', 'build', '-t', candidate, '-'], input=f'FROM {args.image}\nLABEL org.secretpod.lifecycle="upgrade"\n'.encode(), stdout=subprocess.DEVNULL)
            upgraded = host.upgrade(first, manifest, candidate, pull=False)
            installations[0] = (first, upgraded)
            certificate(first, upgraded)
            assert_secret(url, context, organization, secret)
            assert host.sha256(first / 'secrets/master_key') == key_hash
            print('PASS: backup and upgrade to a distinct image preserve decryption', flush=True)

            result = host.restore(restored, saved, 'https://localhost:19443', 19088, pull=False)
            installations.append((restored, result))
            restored_context = certificate(restored, result)
            assert_secret(result['url'], restored_context, organization, secret)
            assert host.sha256(restored / 'secrets/master_key') == key_hash
            assert json.loads(call(result['url'], restored_context, '/app-config.json')[2])['apiUrl'] == result['url'] + '/api/'
            try:
                host.restore(first, saved, pull=False)
                raise AssertionError('Restore overwrote existing installation')
            except ValueError:
                pass
            try:
                host.upgrade(first, upgraded, 'invalid.invalid/secretpod:does-not-exist')
                raise AssertionError('Invalid image pull succeeded')
            except subprocess.CalledProcessError:
                pass
            assert host.read_install(first) == upgraded
            assert_secret(url, context, organization, secret)
            print('PASS: restore to fresh volume/new URL, overwrite refusal, failed pull preserves running installation', flush=True)
            broken = 'secretpod:lifecycle-broken'
            host.run(['docker', 'build', '-t', broken, '-'], input=f'FROM {args.image}\nENTRYPOINT ["/missing-test-executable"]\n'.encode(), stdout=subprocess.DEVNULL)
            try:
                host.upgrade(first, upgraded, broken, pull=False)
                raise AssertionError('Broken candidate started')
            except ValueError:
                pass
            assert (first / 'upgrade-pending.json').exists()
            try:
                host.start(first, host.read_install(first), pull=False)
                raise AssertionError('Interrupted upgrade allowed ordinary startup')
            except ValueError:
                pass
            pending = json.loads((first / 'upgrade-pending.json').read_text())
            host.validate_backup(Path(pending['backup']))
            print('PASS: failed candidate preserves recovery backup and blocks unsafe restart', flush=True)
        finally:
            for root, manifest in reversed(installations):
                # Only randomly named projects created by this test are removed.
                assert root.is_relative_to(workspace)
                host.compose(root, manifest, 'down', '-v', '--remove-orphans')
    print('All Docker lifecycle checks passed.', flush=True)


if __name__ == '__main__':
    main()
