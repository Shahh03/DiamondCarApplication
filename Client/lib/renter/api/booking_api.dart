import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class BookingApi {
  static Future<List<dynamic>> getUpcomingBookings(String renterId) async {
    final response = await AuthenticatedClient.get(
      '/renter/getUpcomingBookings/$renterId',
    );
    return _list(response, 'Failed to load upcoming bookings.');
  }

  static Future<List<dynamic>> getRenterBookings(String renterId) async {
    final response = await AuthenticatedClient.get(
      '/renter/getBookings/$renterId',
    );
    return _list(response, 'Failed to load bookings.');
  }

  static Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    final response = await AuthenticatedClient.get('/booking/get/$bookingId');
    return _mapResult(response, 'Failed to load booking details.');
  }

  static Future<List<Map<String, dynamic>>> getUnavailableDateRanges(
    String carVariantId,
  ) async {
    final response = await AuthenticatedClient.get(
      '/booking/unavailable-dates/$carVariantId',
    );
    final data = _mapResult(response, 'Could not load unavailable dates.');
    final ranges = data['unavailableRanges'];
    if (ranges is! List) return <Map<String, dynamic>>[];
    return ranges
        .whereType<Map>()
        .map((range) => Map<String, dynamic>.from(range))
        .toList();
  }

  static Future<Map<String, dynamic>> checkAvailability({
    required String carVariantId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = Uri.encodeQueryComponent(startDate.toIso8601String());
    final end = Uri.encodeQueryComponent(endDate.toIso8601String());
    final response = await AuthenticatedClient.get(
      '/booking/availability/$carVariantId?startDate=$start&endDate=$end',
    );
    return _mapResult(response, 'Could not check availability.');
  }

  static Future<Map<String, dynamic>> createStripePaymentIntent({
    required String renterId,
    required String carVariantId,
    required DateTime startDate,
    required DateTime endDate,
    required bool savePaymentMethod,
  }) async {
    final response = await AuthenticatedClient.post(
      '/stripe/payment-intent',
      body: {
        'renter': renterId,
        'carVariant': carVariantId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'savePaymentMethod': savePaymentMethod,
      },
    );
    return _mapResult(response, 'Could not start the payment.');
  }

  static Future<Map<String, dynamic>> getStripePaymentStatus(
    String paymentIntentId,
  ) async {
    final response = await AuthenticatedClient.get(
      '/stripe/payment-status/${Uri.encodeComponent(paymentIntentId)}',
    );
    return _mapResult(response, 'Could not verify the payment status.');
  }

  static Future<String> cancelBooking(String bookingId) async {
    final response = await AuthenticatedClient.put(
      '/booking/cancel/$bookingId',
    );
    final data = _mapResult(response, 'Could not cancel the booking.');
    return data['message']?.toString() ?? 'Booking cancelled successfully.';
  }

  static List<dynamic> _list(dynamic response, String fallback) {
    if (!_successful(response.statusCode)) {
      throw Exception(_message(response.body, response.statusCode, fallback));
    }
    final decoded = _decode(response.body);
    return decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];
  }

  static Map<String, dynamic> _mapResult(dynamic response, String fallback) {
    final data = _map(response.body);
    if (_successful(response.statusCode)) return data;
    throw Exception(_message(response.body, response.statusCode, fallback));
  }

  static bool _successful(int code) => code >= 200 && code < 300;

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _map(String body) {
    final decoded = _decode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static String _message(String body, int code, String fallback) {
    final message = _map(body)['message']?.toString().trim();
    return message?.isNotEmpty == true ? message! : '$fallback ($code)';
  }
}
