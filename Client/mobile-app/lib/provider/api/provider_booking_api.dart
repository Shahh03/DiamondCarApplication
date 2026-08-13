import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderBookingApi {
  const ProviderBookingApi._();

  static Future<List<Map<String, dynamic>>> getProviderBookings({
    required String providerId,
  }) async {
    final response = await AuthenticatedClient.get(
      '/booking/getbookingForProvider/$providerId',
    );
    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _message(
          decoded,
          'Could not load bookings (${response.statusCode}).',
        ),
      );
    }

    final list = decoded is List
        ? decoded
        : decoded is Map && decoded['bookings'] is List
            ? decoded['bookings'] as List
            : const <dynamic>[];

    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
