import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class UserApi {
  static Future<Map<String, dynamic>> getUserById(String _userId) async {
    // Identity comes from the access token; callers can no longer request an
    // arbitrary user's account by changing a URL parameter.
    final response = await AuthenticatedClient.get('/user/session');
    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map && decoded['user'] is Map) {
        return Map<String, dynamic>.from(decoded['user'] as Map);
      }
      throw Exception('Invalid user data format');
    }

    final message = decoded is Map ? decoded['message']?.toString() : null;
    throw Exception(message ?? 'Failed to load account.');
  }
}
