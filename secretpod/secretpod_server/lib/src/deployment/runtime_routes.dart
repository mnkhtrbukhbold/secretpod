import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../services.dart';
import 'runtime_config.dart';

final _noStore = Headers.build((headers) {
  headers['Cache-Control'] = ['no-store'];
  headers['X-Content-Type-Options'] = ['nosniff'];
});

class RuntimeConfigRoute extends Route {
  RuntimeConfigRoute(this.config) : super(methods: {Method.get});
  final RuntimeConfig config;

  @override
  Future<Result> handleCall(Session session, Request request) async =>
      Response.ok(
        headers: _noStore,
        body: Body.fromString(
          jsonEncode({'apiUrl': config.apiUrl}),
          mimeType: MimeType.json,
        ),
      );
}

class HealthRoute extends Route {
  HealthRoute(this.services) : super(methods: {Method.get});
  final VaultServices services;

  @override
  Future<Result> handleCall(Session session, Request request) async {
    try {
      await services.store.read((_) => null);
      return Response.ok(headers: _noStore, body: Body.fromString('ok'));
    } catch (_) {
      return Response(
        503,
        headers: _noStore,
        body: Body.fromString('unavailable'),
      );
    }
  }
}
