import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';

enum UserRole { renter, provider, admin }

UserRole? roleFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'renter': return UserRole.renter;
    case 'provider': return UserRole.provider;
    case 'admin': return UserRole.admin;
    default: return null;
  }
}

class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keyRole  = 'user_role';
  static const _storage  = FlutterSecureStorage();

  static Future<void> saveSession({
    required String token,
    String? role, // if backend sends role separately
  }) async {
    await _storage.write(key: _keyToken, value: token);
    if (role != null) {
      await _storage.write(key: _keyRole, value: role);
    } else {
      // Try to infer from JWT claim (e.g., "role" or "roles")
      try {
        final claims = Jwt.parseJwt(token);
        final claimRole = (claims['role'] ?? claims['roles'])?.toString();
        if (claimRole != null) {
          await _storage.write(key: _keyRole, value: claimRole);
        }
      } catch (_) {}
    }
  }

  static Future<String?> readToken() => _storage.read(key: _keyToken);

  static Future<UserRole?> readRole() async {
    final r = await _storage.read(key: _keyRole);
    return roleFromString(r);
  }

  static Future<bool> isLoggedIn() async {
    final token = await readToken();
    if (token == null) return false;
    try {
      return !Jwt.isExpired(token);
    } catch (_) {
      return true; // non-JWT fallback
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRole);
  }
}
