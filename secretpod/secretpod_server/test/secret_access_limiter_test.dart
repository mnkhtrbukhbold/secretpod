import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/vault/secret_access_limiter.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late SecretAccessLimiter limiter;
  setUp(() {
    now = DateTime.utc(2026, 10, 14);
    limiter = SecretAccessLimiter(now: () => now);
  });
  test(
    'burst expires exactly at its boundary and denials do not extend it',
    () {
      for (var i = 0; i < 10; i++) {
        limiter.consume('actor');
      }
      now = now.add(const Duration(milliseconds: 9500));
      for (var i = 0; i < 100; i++) {
        expect(
          () => limiter.consume('actor'),
          throwsA(
            isA<VaultException>().having(
              (e) => e.message,
              'message',
              contains('1 seconds'),
            ),
          ),
        );
      }
      now = now.add(const Duration(milliseconds: 500));
      expect(() => limiter.consume('actor'), returnsNormally);
    },
  );
  test('sustained requests remain limited across burst windows', () {
    for (var window = 0; window < 6; window++) {
      now = DateTime.utc(2026, 10, 14).add(Duration(seconds: window * 10));
      for (var i = 0; i < 10; i++) {
        limiter.consume('actor');
      }
    }
    now = now.add(const Duration(seconds: 9));
    expect(() => limiter.consume('actor'), throwsA(isA<VaultException>()));
    now = now.add(const Duration(seconds: 1));
    expect(() => limiter.consume('actor'), returnsNormally);
  });
  test('full key capacity fails closed without evicting active budgets', () {
    limiter = SecretAccessLimiter(now: () => now, maxActors: 2);
    for (var i = 0; i < 10; i++) {
      limiter.consume('first');
    }
    limiter.consume('second');
    expect(() => limiter.consume('third'), throwsA(isA<VaultException>()));
    expect(() => limiter.consume('first'), throwsA(isA<VaultException>()));
    now = now.add(const Duration(minutes: 1));
    expect(() => limiter.consume('third'), returnsNormally);
  });
}
