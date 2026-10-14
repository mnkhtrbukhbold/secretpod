import 'dart:convert';

class ConfigResponse {
  const ConfigResponse(this.status, this.body);
  final int status;
  final String body;
}

typedef ConfigFetch = Future<ConfigResponse> Function(Uri uri);

String developmentApiUrl(Uri baseUri) => Uri(
  scheme: baseUri.scheme == 'https' ? 'https' : 'http',
  host: baseUri.host.isEmpty ? 'localhost' : baseUri.host,
  port: 8080,
  path: '/',
).toString();

Future<String> resolveApiUrl({
  required Uri baseUri,
  required bool isWeb,
  required ConfigFetch fetch,
  bool isDebug = false,
  String configuredUrl = '',
}) async {
  if (configuredUrl.isNotEmpty) return _validateUrl(configuredUrl).toString();
  if (!isWeb) return developmentApiUrl(baseUri);
  final response = await fetch(baseUri.resolve('/app-config.json'));
  if (isDebug &&
      baseUri.scheme == 'http' &&
      _loopback(baseUri.host) &&
      (response.status == 404 ||
          (response.status == 200 &&
              RegExp(
                r'^\s*(<!doctype html|<html)',
                caseSensitive: false,
              ).hasMatch(response.body)))) {
    // Flutter's standalone debug server has no backend configuration route.
    return developmentApiUrl(baseUri);
  }
  if (response.status != 200) {
    throw const FormatException('Application configuration is unavailable.');
  }
  final data = jsonDecode(response.body);
  if (data is! Map<String, dynamic> || data['apiUrl'] is! String) {
    throw const FormatException('Invalid application configuration.');
  }
  final api = _validateUrl(data['apiUrl'] as String);
  final localDevelopment =
      baseUri.scheme == 'http' &&
      api.scheme == 'http' &&
      _loopback(baseUri.host) &&
      api.host == baseUri.host;
  if (api.origin != baseUri.origin && !localDevelopment) {
    throw const FormatException('Application API must use the site origin.');
  }
  return api.toString();
}

bool _loopback(String host) => ['localhost', '127.0.0.1', '::1'].contains(host);

Uri _validateUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.hasQuery ||
      RegExp(r'\s').hasMatch(value) ||
      value.contains('\\')) {
    throw const FormatException('Invalid application API URL.');
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}
