import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

class CryptoService {
  CryptoService(String encodedKey) : _key = SecretKey(_decodeKey(encodedKey));
  final SecretKey _key;
  final _cipher = AesGcm.with256bits();

  static List<int> _decodeKey(String key) {
    final bytes = base64Decode(key);
    if (bytes.length != 32) {
      throw ArgumentError('SECRETPOD_MASTER_KEY must encode 32 bytes.');
    }
    return bytes;
  }

  static String randomToken() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
  }

  static String tokenDigest(String token) =>
      hashes.sha256.convert(utf8.encode(token)).toString();

  Future<String> encrypt(String plaintext, String context) async {
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
      aad: utf8.encode(context),
    );
    return base64Encode(box.concatenation());
  }

  Future<String> decrypt(String ciphertext, String context) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(ciphertext),
      nonceLength: 12,
      macLength: 16,
    );
    return utf8.decode(
      await _cipher.decrypt(box, secretKey: _key, aad: utf8.encode(context)),
    );
  }

  static Future<String> hashPassword(String password, String salt) =>
      Isolate.run(() async {
        final derived =
            await Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 600000,
              bits: 256,
            ).deriveKey(
              secretKey: SecretKey(utf8.encode(password)),
              nonce: base64Url.decode(salt),
            );
        return base64Encode(await derived.extractBytes());
      });

  static bool constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var difference = left.length ^ right.length;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ (i < right.length ? right[i] : 0);
    }
    return difference == 0;
  }
}
