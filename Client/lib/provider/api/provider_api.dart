import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderApi {
  static Future<Map<String, dynamic>> getProviderById(
    String providerId,
  ) async {
    final response = await AuthenticatedClient.get(
      '/provider/get/$providerId',
    );
    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _message(
          decoded,
          'Could not load provider (${response.statusCode}).',
        ),
      );
    }

    if (decoded is! Map) {
      throw Exception('The server returned invalid provider information.');
    }

    final envelope = Map<String, dynamic>.from(decoded);
    final rawProvider = envelope['provider'] ?? envelope['data'] ?? envelope;

    if (rawProvider is! Map) {
      throw Exception('The server returned invalid provider information.');
    }

    final provider = Map<String, dynamic>.from(rawProvider);
    if ((provider['_id']?.toString() ?? '').isEmpty) {
      throw Exception('The server returned incomplete provider information.');
    }

    return provider;
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
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }
}
