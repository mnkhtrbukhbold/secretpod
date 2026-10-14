import '../generated/protocol.dart';

/// Bounds are UTC instants: inclusive start, exclusive next local midnight.
class ActivityFilter {
  ActivityFilter({
    this.from,
    this.until,
    this.project,
    this.action,
    this.user,
  }) {
    if (from != null && until != null && !from!.isBefore(until!)) {
      throw VaultException(message: 'Choose a valid activity date range.');
    }
  }
  final DateTime? from, until;
  final String? project, action, user;

  static String userKey(Map<String, dynamic> event) => event['actorId'] != null
      ? 'id:${event['actorId']}'
      : 'legacy:${event['actor']}';

  bool matches(Map<String, dynamic> event) {
    final time = DateTime.parse(event['createdAt'] as String);
    return (from == null || !time.isBefore(from!)) &&
        (until == null || time.isBefore(until!)) &&
        (project == null ||
            (event['project'] as String?)?.toLowerCase() ==
                project!.toLowerCase()) &&
        (action == null || event['action'] == action) &&
        (user == null || userKey(event) == user);
  }
}
