import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Generates a stable anonymous identifier for collaborative features.
class IdentityService {
  /// Creates an identity service.
  const IdentityService();

  static const _salt = 'coppelia-community-v1';

  /// Returns a SHA-256 hash of [jellyfinUserId] combined with the app salt.
  String getHashedUserId(String jellyfinUserId) {
    final input = utf8.encode('$jellyfinUserId$_salt');
    return sha256.convert(input).toString();
  }
}
