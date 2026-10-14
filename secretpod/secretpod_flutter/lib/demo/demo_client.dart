import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:secretpod_client/secretpod_client.dart';

import 'demo_store.dart';

part 'demo_operations.dart';
part 'demo_vault.dart';
part 'demo_people.dart';

/// Implements the generated API entirely inside the browser's demo store.
///
/// Membership checks reproduce the interface's behavior. The visitor controls
/// this synthetic data; these checks are not a security boundary.
class DemoClient extends http.BaseClient {
  DemoClient(this.store);

  final DemoStore store;
  String? _epoch;
  bool _closed = false;

  static const _readRoutes = {
    'vault/organizations',
    'vault/members',
    'vault/listSecrets',
    'vault/summary',
    'vault/activity',
    'vault/secretActivity',
    'vault/memberRemovalSecrets',
    'invitation/inbox',
    'invitation/outgoing',
    'invitation/profile',
    'account/previewInvitation',
    'account/login',
    'vault/logout',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      if (_closed) _fail('This demo session has closed. Reload the demo.');
      if (request.method != 'POST') {
        _fail('This demo supports POST API requests only.');
      }
      final segments = request.url.pathSegments
          .where((part) => part.isNotEmpty)
          .toList();
      if (segments.length != 2) {
        _fail('This API operation is unavailable in the demo.');
      }
      final route = segments.join('/');
      final body = await request.finalize().bytesToString();
      final decoded = jsonDecode(body.isEmpty ? '{}' : body);
      if (decoded is! Map<String, dynamic>) _fail('Invalid demo request.');
      final write = !_readRoutes.contains(route);
      if (_epoch == null) {
        // Commit first-time initialization before pinning its generation. A
        // failed storage commit must remain retryable with this same client.
        final epoch = await store.access((data) => data['epoch'] as String);
        _epoch ??= epoch;
      }
      final result = await store.access((data) {
        final epoch = data['epoch'] as String;
        if (write && _epoch != null && epoch != _epoch) {
          _fail(
            'The demo was reset. Close this dialog and reload before editing.',
          );
        }
        return _DemoState(data, decoded).dispatch(route);
      }, write: write);
      return _response(request, jsonEncode(result), 200);
    } on VaultException catch (error) {
      return _error(request, error);
    } on FormatException {
      return _error(
        request,
        VaultException(
          message:
              'Demo data could not be read. Reset the demo to start again.',
        ),
      );
    } on TypeError {
      return _error(
        request,
        VaultException(
          message: 'Invalid demo data. Reset the demo to start again.',
        ),
      );
    } on StateError {
      return _error(
        request,
        VaultException(
          message:
              'Demo changes could not be saved in this browser. Allow site storage, or use Reset demo to free space. No changes were saved.',
        ),
      );
    }
  }

  http.StreamedResponse _error(
    http.BaseRequest request,
    VaultException error,
  ) => _response(request, Protocol().encodeWithType(error), 500);

  http.StreamedResponse _response(
    http.BaseRequest request,
    String body,
    int status,
  ) => http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    status,
    request: request,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  );

  @override
  void close() => _closed = true;
}
