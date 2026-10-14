export 'page_size_store_memory.dart'
    if (dart.library.js_interop) 'page_size_store_web.dart'
    show createPageSizeStore;

/// Stores display preferences only, separately from authentication and vault data.
abstract interface class PageSizeStore {
  int? read(String accountId, String list);
  void write(String accountId, String list, int size);
}
