import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'runtime_config.dart';

Future<ConfigResponse> fetchRuntimeConfig(Uri uri) async {
  final response = await web.window
      .fetch(
        uri.toString().toJS,
        web.RequestInit(cache: 'no-store', credentials: 'same-origin'),
      )
      .toDart;
  final body = await response.text().toDart;
  return ConfigResponse(response.status, body.toDart);
}
