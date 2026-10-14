import 'generated/protocol.dart';

/// Reusable paging policy for list services. Apply authorization, filtering and
/// deterministic ordering before [apply]. Offsets are zero based.
class Pagination {
  static const defaultLimit = 10;
  static const maxLimit = 100;

  Pagination({this.offset = 0, this.limit = defaultLimit}) {
    if (offset < 0 || offset > 2147483647 || limit < 1 || limit > maxLimit) {
      throw VaultException(
        message: 'Use a non-negative offset and a page size from 1 to 100.',
      );
    }
  }
  final int offset;
  final int limit;

  Iterable<T> apply<T>(Iterable<T> items) => items.skip(offset).take(limit);
}
