import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted, iterated SHA-256 password hashing.
///
/// Format stored in DB: `<iterations>$<salt-b64>$<hash-b64>`, so the scheme
/// can evolve without breaking existing accounts.
class PasswordHasher {
  const PasswordHasher._();

  static const int _iterations = 5000;
  static const int _saltBytes = 16;
  static final Random _rnd = Random.secure();

  static String _salt() {
    final b = List<int>.generate(_saltBytes, (_) => _rnd.nextInt(256));
    return base64Encode(b);
  }

  static String _digest(String password, String saltB64, int iterations) {
    var bytes = <int>[...base64Decode(saltB64), ...utf8.encode(password)];
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  static String hash(String password) {
    final salt = _salt();
    return '$_iterations\$$salt\$${_digest(password, salt, _iterations)}';
  }

  /// Constant-time comparison against a stored hash.
  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 3) return false;
    final iterations = int.tryParse(parts[0]);
    if (iterations == null) return false;
    final expected = parts[2];
    final actual = _digest(password, parts[1], iterations);
    if (expected.length != actual.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return diff == 0;
  }
}
