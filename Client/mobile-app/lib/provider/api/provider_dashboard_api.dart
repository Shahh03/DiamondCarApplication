import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderDashboardApi {
  static Future<Map<String, dynamic>> getDashboard(String providerId) async {
    final response = await AuthenticatedClient.get(
      '/provider/dashboard/$providerId',
    );
    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _message(
          decoded,
          'Could not load dashboard (${response.statusCode}).',
        ),
      );
    }
    if (decoded is! Map) {
      throw Exception('The server returned invalid dashboard information.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _message(dynamic decoded, String fallback) {
    if (decoded is Map) {
      final message = decoded['message']?.toString().trim();
      if (message?.isNotEmpty == true) return message!;
    }
    return fallback;
  }
}
