// lib/core/utils/password_hasher.dart
//
// SECURITY (C-3): offline login used to compare plaintext passwords directly
// in a SQL WHERE clause against an unencrypted SQLite file. This helper
// replaces that with salted PBKDF2-HMAC-SHA256 verification.
//
// Scope note: this protects the *local offline unlock* credential only.
// Supabase Auth remains the source of truth for online authentication.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  /// Stored format: `pbkdf2_sha256$<iterations>$<saltB64>$<hashB64>`
  static const String _algo = 'pbkdf2_sha256';
  static const int _defaultIterations = 10000;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  static final Random _rng = Random.secure();

  static Uint8List _randomSalt() {
    final b = Uint8List(_saltBytes);
    for (var i = 0; i < _saltBytes; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  /// PBKDF2-HMAC-SHA256. Pure Dart so it works on every target including web.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;

    while (out.length < keyLength) {
      // U1 = HMAC(password, salt || INT_BE32(block))
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xff
        ..[1] = (block >> 16) & 0xff
        ..[2] = (block >> 8) & 0xff
        ..[3] = block & 0xff;

      var u = Uint8List.fromList(
        hmac.convert(<int>[...salt, ...blockIndex]).bytes,
      );
      final f = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < f.length; j++) {
          f[j] ^= u[j];
        }
      }

      out.add(f);
      block++;
    }

    return Uint8List.fromList(out.toBytes().sublist(0, keyLength));
  }

  /// Produces a self-describing hash string safe to persist.
  static String hash(String password, {int iterations = _defaultIterations}) {
    final salt = _randomSalt();
    final derived =
        _pbkdf2(utf8.encode(password), salt, iterations, _keyBytes);
    return '$_algo\$$iterations\$${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  /// Constant-time-ish comparison of a candidate password against [stored].
  ///
  /// Returns false for null/empty/malformed stored values rather than throwing,
  /// so a corrupt cache row denies access instead of crashing login.
  static bool verify(String password, String? stored) {
    if (stored == null || stored.isEmpty) return false;

    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _algo) return false;

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;

    Uint8List salt;
    Uint8List expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } catch (_) {
      return false;
    }

    final actual =
        _pbkdf2(utf8.encode(password), salt, iterations, expected.length);

    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// True when [stored] is in the current hash format (used by the v78
  /// migration to decide whether a row still holds a legacy plaintext value).
  static bool isHashed(String? stored) {
    if (stored == null || stored.isEmpty) return false;
    final parts = stored.split(r'$');
    return parts.length == 4 && parts[0] == _algo;
  }
}
