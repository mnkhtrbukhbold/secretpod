import 'runtime_config.dart';

Future<ConfigResponse> fetchRuntimeConfig(Uri uri) =>
    throw UnsupportedError('Browser configuration is only fetched on the web.');
