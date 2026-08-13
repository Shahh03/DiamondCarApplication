import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderEarningsApi {
  static Future<Map<String, dynamic>> getEarnings({
    required String providerId,
    required DateTime from,
    required DateTime to,
    int transactionLimit = 30,
  }) async {
    final parameters = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'limit': transactionLimit.clamp(1, 100).toString(),
    };
    final query = Uri(queryParameters: parameters).query;
    final response = await AuthenticatedClient.get(
      '/provider/earnings/$providerId?$query',
    );
    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _message(
          decoded,
          'Could not load earnings (${response.statusCode}).',
        ),
      );
    }

    if (decoded is! Map) {
      throw Exception('The server returned invalid earnings information.');
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
