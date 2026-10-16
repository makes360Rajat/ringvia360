import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/sales_track_models.dart';

class AppLockService {
  static bool verifyPin({
    required String pin,
    required SalesTrackConfig config,
  }) {
    if (!config.appLockEnabled || config.appLockHash.isEmpty) {
      return true; // Lock is disabled
    }

    try {
      final saltBytes = utf8.encode(config.appLockSalt);
      final passwordBytes = utf8.encode(pin);
      final derivedKey = pbkdf2HmacSha256(
        password: passwordBytes,
        salt: saltBytes,
        iterations: config.appLockIterations > 0 ? config.appLockIterations : 100000,
        derivedKeyLength: 32,
      );

      final hexDerived = derivedKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toLowerCase();
      return hexDerived == config.appLockHash.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  static Uint8List pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int derivedKeyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final numBlocks = (derivedKeyLength + 31) ~/ 32;
    final derivedKey = Uint8List(derivedKeyLength);
    var offset = 0;

    for (var blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      final blockData = List<int>.from(salt)
        ..addAll([
          (blockIndex >> 24) & 0xff,
          (blockIndex >> 16) & 0xff,
          (blockIndex >> 8) & 0xff,
          blockIndex & 0xff,
        ]);

      var u = hmac.convert(blockData).bytes;
      final t = Uint8List.fromList(u);

      for (var iter = 1; iter < iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < 32; k++) {
          t[k] ^= u[k];
        }
      }

      final copyLength = (offset + 32 > derivedKeyLength) ? (derivedKeyLength - offset) : 32;
      derivedKey.setRange(offset, offset + copyLength, t.sublist(0, copyLength));
      offset += copyLength;
    }

    return derivedKey;
  }
}
