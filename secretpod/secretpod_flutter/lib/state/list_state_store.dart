import 'dart:convert';

export 'list_state_store_memory.dart'
    if (dart.library.js_interop) 'list_state_store_web.dart'
    show createListStateStore;

/// Display state only. Never store list rows, credentials or decrypted values.
class ListViewState {
  const ListViewState({this.page = 0, this.filters = const {}});
  final int page;
  final Map<String, String> filters;

  factory ListViewState.decode(String? encoded) {
    if (encoded == null) return const ListViewState();
    try {
      final data = jsonDecode(encoded);
      if (data is! Map || data['version'] != 1) {
        return const ListViewState();
      }
      final page = data['page'];
      final filters = data['filters'];
      return ListViewState(
        page: page is int && page >= 0 ? page : 0,
        filters: filters is Map
            ? Map.unmodifiable({
                for (final entry in filters.entries)
                  if (entry.key is String && entry.value is String)
                    entry.key as String: entry.value as String,
              })
            : const {},
      );
    } on FormatException {
      return const ListViewState();
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'page': page,
    'filters': filters,
  });
}

abstract interface class ListStateStore {
  String? read(String accountId, String key);
  void write(String accountId, String key, String value);

  static String listKey(String list, String? organizationId) =>
      'list:$list:${organizationId == null ? 'account' : 'org:${Uri.encodeComponent(organizationId)}'}';
  static const organizationKey = 'selected-organization';
}
