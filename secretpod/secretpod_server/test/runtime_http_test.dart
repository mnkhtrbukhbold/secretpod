import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/server.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:test/test.dart';

void main() {
  test(
    'real HTTP serves safe runtime config, health and origin restrictions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'secretpod-runtime-',
      );
      final keyFile = File('${directory.path}/master-key');
      await keyFile.writeAsString(base64Encode(List<int>.filled(32, 43)));
      final pod = await createServer(
        ['--mode', 'test'],
        environment: {
          'SECRETPOD_MASTER_KEY_FILE': keyFile.path,
          'SECRETPOD_DATA_DIR': '${directory.path}/data',
          'SECRETPOD_PUBLIC_URL': 'https://vault.example',
          'SECRETPOD_API_URL': '/api/',
        },
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await pod.shutdown(exitProcess: false);
        await VaultServices.instance.close();
        await directory.delete(recursive: true);
      });
      await pod.start();
      final request = await client.getUrl(
        Uri.parse('http://localhost:${pod.webServer.port}/app-config.json'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.headers.value('cache-control'), 'no-store');
      expect(response.headers.contentType?.mimeType, 'application/json');
      expect(jsonDecode(await utf8.decoder.bind(response).join()), {
        'apiUrl': 'https://vault.example/api/',
      });
      final health = await (await client.getUrl(
        Uri.parse('http://localhost:${pod.webServer.port}/healthz'),
      )).close();
      expect(health.statusCode, 200);
      expect(await utf8.decoder.bind(health).join(), 'ok');
      for (final origin in [
        'https://vault.example',
        'https://untrusted.example',
      ]) {
        final preflight = await client.openUrl(
          'OPTIONS',
          Uri.parse('http://localhost:${pod.server.port}/account/login'),
        );
        preflight.headers.set('Origin', origin);
        preflight.headers.set('Access-Control-Request-Method', 'POST');
        preflight.headers.set(
          'Access-Control-Request-Headers',
          'authorization,content-type',
        );
        final result = await preflight.close();
        if (origin == 'https://vault.example') {
          expect(result.statusCode, lessThan(300));
          expect(result.headers.value('access-control-allow-origin'), origin);
          expect(
            result.headers.value('access-control-allow-headers')?.toLowerCase(),
            contains('authorization'),
          );
        } else {
          // Serverpod answers OPTIONS before application middleware. The fixed
          // allowed origin still denies this preflight in a browser.
          expect(
            result.headers.value('access-control-allow-origin'),
            isNot(origin),
          );
        }
        await result.drain<void>();
      }
      final forbidden = await client.postUrl(
        Uri.parse('http://localhost:${pod.server.port}/account/login'),
      );
      forbidden.headers.set('Origin', 'https://untrusted.example');
      forbidden.headers.contentType = ContentType.json;
      forbidden.write('{}');
      final rejected = await forbidden.close();
      expect(rejected.statusCode, 403);
      await rejected.drain<void>();
      await VaultServices.instance.close();
      final unavailable = await (await client.getUrl(
        Uri.parse('http://localhost:${pod.webServer.port}/healthz'),
      )).close();
      expect(unavailable.statusCode, 503);
      expect(await utf8.decoder.bind(unavailable).join(), 'unavailable');
    },
  );
}
