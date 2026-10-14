import 'dart:convert';
import 'dart:io';

/// Public, non-secret browser configuration. Never derive it from request headers.
class RuntimeConfig {
  RuntimeConfig._(this.publicOrigin, this.apiUrl);

  final String? publicOrigin;
  final String apiUrl;

  factory RuntimeConfig.fromEnvironment(
    Map<String, String> environment, {
    String developmentApiUrl = 'http://localhost:8080/',
  }) {
    final publicValue = environment['SECRETPOD_PUBLIC_URL'];
    Uri? publicUri;
    if (publicValue != null) {
      publicUri = _httpUri(publicValue, 'SECRETPOD_PUBLIC_URL');
      if (publicUri.path.isNotEmpty && publicUri.path != '/') {
        throw StateError(
          'SECRETPOD_PUBLIC_URL must be an HTTP(S) origin without a path.',
        );
      }
    }
    final apiValue =
        environment['SECRETPOD_API_URL'] ??
        (publicUri == null ? developmentApiUrl : '/api/');
    Uri apiUri;
    if (apiValue.startsWith('/') &&
        !apiValue.startsWith('//') &&
        publicUri != null) {
      apiUri = _httpUri(
        publicUri.resolve(apiValue).toString(),
        'SECRETPOD_API_URL',
      );
    } else {
      apiUri = _httpUri(apiValue, 'SECRETPOD_API_URL');
    }
    if (publicUri != null && apiUri.origin != publicUri.origin) {
      throw StateError(
        'SECRETPOD_API_URL must use the SECRETPOD_PUBLIC_URL origin.',
      );
    }
    final path = apiUri.path.endsWith('/') ? apiUri.path : '${apiUri.path}/';
    return RuntimeConfig._(
      publicUri?.origin,
      apiUri.replace(path: path).toString(),
    );
  }

  void validateProduction() {
    if (publicOrigin == null || !publicOrigin!.startsWith('https://')) {
      throw StateError(
        'Production requires SECRETPOD_PUBLIC_URL with an HTTPS origin.',
      );
    }
  }

  static Uri _httpUri(String value, String name) {
    final uri = Uri.tryParse(value);
    if (value.trim() != value ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        value.contains('\\') ||
        RegExp(r'\s').hasMatch(value)) {
      throw StateError(
        '$name must be an HTTP(S) URL without credentials, query or fragment.',
      );
    }
    return uri;
  }
}

Future<String> loadMasterKey(Map<String, String> environment) async {
  final keyFile = environment['SECRETPOD_MASTER_KEY_FILE'];
  String? key;
  if (keyFile != null) {
    if (environment.containsKey('SECRETPOD_MASTER_KEY') ||
        environment.containsKey('PODVAULT_MASTER_KEY')) {
      throw StateError(
        'Configure either SECRETPOD_MASTER_KEY_FILE or an environment master key, not both.',
      );
    }
    try {
      if (keyFile.isEmpty) throw const FileSystemException('Empty path');
      key = (await File(keyFile).readAsString()).trim();
    } catch (_) {
      throw StateError('Unable to read SECRETPOD_MASTER_KEY_FILE.');
    }
  } else {
    key =
        environment['SECRETPOD_MASTER_KEY'] ??
        environment['PODVAULT_MASTER_KEY'];
  }
  try {
    if (key == null || base64Decode(key).length != 32) {
      throw const FormatException();
    }
  } catch (_) {
    throw StateError(
      'Configure a base64-encoded 32-byte master key. See the root README.',
    );
  }
  return key;
}
