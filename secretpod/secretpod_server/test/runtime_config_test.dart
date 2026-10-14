import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/deployment/runtime_config.dart';
import 'package:test/test.dart';

void main() {
  test(
    'production resolves a relative API on the configured public origin',
    () {
      final config = RuntimeConfig.fromEnvironment({
        'SECRETPOD_PUBLIC_URL': 'https://vault.example/',
        'SECRETPOD_API_URL': '/api',
      });
      config.validateProduction();
      expect(config.apiUrl, 'https://vault.example/api/');
      expect(config.publicOrigin, 'https://vault.example');
    },
  );

  test(
    'development retains localhost ports; production requires HTTPS origin',
    () {
      final config = RuntimeConfig.fromEnvironment({});
      expect(config.apiUrl, 'http://localhost:8080/');
      expect(config.validateProduction, throwsStateError);
      final insecure = RuntimeConfig.fromEnvironment({
        'SECRETPOD_PUBLIC_URL': 'http://localhost:8082',
      });
      expect(insecure.validateProduction, throwsStateError);
    },
  );

  test('rejects credentials, paths, fragments and cross-origin APIs', () {
    for (final url in [
      'https://user:password@vault.example',
      'https://vault.example/path',
      'https://vault.example?secret=value',
      'https://vault.example/#fragment',
      'ftp://vault.example',
    ]) {
      expect(
        () => RuntimeConfig.fromEnvironment({'SECRETPOD_PUBLIC_URL': url}),
        throwsStateError,
      );
    }
    for (final api in [
      '//evil.example/api',
      'https://evil.example/api',
      '/api?token=secret',
      '/api#fragment',
    ]) {
      expect(
        () => RuntimeConfig.fromEnvironment({
          'SECRETPOD_PUBLIC_URL': 'https://vault.example',
          'SECRETPOD_API_URL': api,
        }),
        throwsStateError,
      );
    }
  });

  test(
    'key file accepts a final newline and rejects ambiguous sources',
    () async {
      final directory = await Directory.systemTemp.createTemp('secretpod-key-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/key');
      final key = base64Encode(List<int>.filled(32, 23));
      await file.writeAsString('$key\n');
      expect(
        await loadMasterKey({'SECRETPOD_MASTER_KEY_FILE': file.path}),
        key,
      );
      expect(
        () => loadMasterKey({
          'SECRETPOD_MASTER_KEY_FILE': file.path,
          'SECRETPOD_MASTER_KEY': key,
        }),
        throwsStateError,
      );
      expect(await loadMasterKey({'PODVAULT_MASTER_KEY': key}), key);
      expect(
        await loadMasterKey({
          'PODVAULT_MASTER_KEY': 'ignored',
          'SECRETPOD_MASTER_KEY': key,
        }),
        key,
      );
    },
  );

  test('key errors are generic and do not contain secret material', () async {
    for (final key in [
      '',
      'my-private-secret',
      base64Encode([1, 2, 3]),
    ]) {
      await expectLater(
        loadMasterKey({'SECRETPOD_MASTER_KEY': key}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            isNot(contains(key.isEmpty ? 'private-secret' : key)),
          ),
        ),
      );
    }
  });
}
