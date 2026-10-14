import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/config/runtime_config.dart';

void main() {
  final production = Uri.parse('https://vault.example/#/secrets');
  test('runtime config determines API path without a build-time URL', () async {
    expect(
      await resolveApiUrl(
        baseUri: production,
        isWeb: true,
        fetch: (_) async =>
            const ConfigResponse(200, '{"apiUrl":"https://vault.example/api"}'),
      ),
      'https://vault.example/api/',
    );
  });
  test(
    'release web fails on missing, malformed or cross-origin runtime config',
    () async {
      for (final response in [
        const ConfigResponse(404, ''),
        const ConfigResponse(503, ''),
        const ConfigResponse(200, '<html>'),
        const ConfigResponse(200, '{"apiUrl":"https://evil.example/api"}'),
        const ConfigResponse(200, '{"apiUrl":"http://vault.example/api"}'),
        const ConfigResponse(200, '{"apiUrl":"https://u:p@vault.example/api"}'),
        const ConfigResponse(
          200,
          '{"apiUrl":"https://vault.example/api?key=x"}',
        ),
      ]) {
        await expectLater(
          resolveApiUrl(
            baseUri: production,
            isWeb: true,
            fetch: (_) async => response,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'only debug localhost with missing route gets standalone development fallback',
    () async {
      expect(
        await resolveApiUrl(
          baseUri: Uri.parse('http://localhost:50999/'),
          isWeb: true,
          isDebug: true,
          fetch: (_) async => const ConfigResponse(404, ''),
        ),
        'http://localhost:8080/',
      );
      await expectLater(
        resolveApiUrl(
          baseUri: Uri.parse('http://localhost:50999/'),
          isWeb: true,
          isDebug: true,
          fetch: (_) async => const ConfigResponse(500, ''),
        ),
        throwsFormatException,
      );
      await expectLater(
        resolveApiUrl(
          baseUri: production,
          isWeb: true,
          isDebug: true,
          fetch: (_) async => const ConfigResponse(404, ''),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'explicit developer URL and native fallback do not fetch web configuration',
    () async {
      Future<ConfigResponse> noFetch(Uri _) =>
          throw StateError('Unexpected fetch');
      expect(
        await resolveApiUrl(
          baseUri: production,
          isWeb: true,
          configuredUrl: 'http://localhost:9090',
          fetch: noFetch,
        ),
        'http://localhost:9090/',
      );
      expect(
        await resolveApiUrl(
          baseUri: Uri.parse('file:///app/'),
          isWeb: false,
          fetch: noFetch,
        ),
        'http://localhost:8080/',
      );
    },
  );
}
