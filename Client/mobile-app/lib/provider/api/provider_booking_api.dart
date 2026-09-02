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

  static Future<Map<String, dynamic>> startBooking({
    required String bookingId,
  }) => _transition(
        path: '/booking/start/${Uri.encodeComponent(bookingId)}',
        fallback: 'Could not start the rental.',
      );

  static Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
  }) => _transition(
        path: '/booking/complete/${Uri.encodeComponent(bookingId)}',
        fallback: 'Could not complete the rental.',
      );

  static Future<Map<String, dynamic>> _transition({
    required String path,
    required String fallback,
  }) async {
    final response = await AuthenticatedClient.put(path);
    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(decoded, fallback));
    }

    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'message': fallback};
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
