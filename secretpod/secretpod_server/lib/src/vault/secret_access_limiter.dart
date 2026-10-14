import '../generated/protocol.dart';

/// A process-local budget shared by all plaintext access routes and sessions.
/// Reservations are synchronous, before any database work is queued.
class SecretAccessLimiter {
  SecretAccessLimiter({DateTime Function()? now, this.maxActors = 4096})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final int maxActors;
  final _requests = <String, List<DateTime>>{};

  void consume(String actor) {
    final now = _now();
    final minuteStart = now.subtract(const Duration(minutes: 1));
    _requests.removeWhere((_, times) => !times.last.isAfter(minuteStart));
    final times = _requests[actor] ?? <DateTime>[];
    times.removeWhere((time) => !time.isAfter(minuteStart));
    final burst = times
        .where(
          (time) => time.isAfter(now.subtract(const Duration(seconds: 10))),
        )
        .toList();
    DateTime? retryAt;
    if (burst.length >= 10) {
      retryAt = burst.first.add(const Duration(seconds: 10));
    }
    if (times.length >= 60) {
      final minuteRetry = times.first.add(const Duration(minutes: 1));
      if (retryAt == null || minuteRetry.isAfter(retryAt)) {
        retryAt = minuteRetry;
      }
    }
    // Do not evict active budgets: rotating keys must not reset their limits.
    if (!_requests.containsKey(actor) && _requests.length >= maxActors) {
      retryAt = _requests.values
          .map((entries) => entries.last.add(const Duration(minutes: 1)))
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }
    if (retryAt != null) {
      final seconds = (retryAt.difference(now).inMicroseconds / 1000000).ceil();
      throw VaultException(
        message:
            'Too many secret access requests. Try again in $seconds seconds.',
      );
    }
    times.add(now);
    _requests[actor] = times;
  }
}
