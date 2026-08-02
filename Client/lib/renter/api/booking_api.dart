import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class BookingApi {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<List<dynamic>> getUpcomingBookings(String renterId) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/renter/getUpcomingBookings/$renterId',
          ),
        )
        .timeout(_timeout);

    if (_isSuccessful(response)) {
      final decoded = _decode(response.body);
      return decoded is List ? decoded : <dynamic>[];
    }

    throw Exception(_message(response, 'Failed to load upcoming bookings.'));
  }

  static Future<List<dynamic>> getRenterBookings(String renterId) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/renter/getBookings/$renterId'),
        )
        .timeout(_timeout);

    if (_isSuccessful(response)) {
      final decoded = _decode(response.body);
      return decoded is List ? decoded : <dynamic>[];
    }

    throw Exception(_message(response, 'Failed to load bookings.'));
  }

  static Future<Map<String, dynamic>> getBookingById(
    String bookingId,
  ) async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/booking/get/$bookingId'))
        .timeout(_timeout);
    final data = _map(response.body);

    if (_isSuccessful(response)) return data;

    throw Exception(_message(response, 'Failed to load booking details.'));
  }

  static Future<List<Map<String, dynamic>>> getUnavailableDateRanges(
    String carVariantId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/booking/unavailable-dates/$carVariantId',
          ),
        )
        .timeout(_timeout);
    final data = _map(response.body);

    if (!_isSuccessful(response)) {
      throw Exception(
        _message(response, 'Could not load unavailable dates.'),
      );
    }

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
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/booking/availability/$carVariantId',
    ).replace(
      queryParameters: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );

    final response = await http.get(url).timeout(_timeout);
    final data = _map(response.body);

    if (_isSuccessful(response)) return data;

    throw Exception(_message(response, 'Could not check availability.'));
  }

  static Future<Map<String, dynamic>> createStripePaymentIntent({
    required String renterId,
    required String carVariantId,
    required DateTime startDate,
    required DateTime endDate,
    required bool savePaymentMethod,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/stripe/payment-intent'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'renter': renterId,
            'carVariant': carVariantId,
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
            'savePaymentMethod': savePaymentMethod,
          }),
        )
        .timeout(_timeout);

    final data = _map(response.body);
    if (_isSuccessful(response)) return data;

    throw Exception(_message(response, 'Could not start the payment.'));
  }

  static Future<Map<String, dynamic>> getStripePaymentStatus(
    String paymentIntentId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/stripe/payment-status/'
            '${Uri.encodeComponent(paymentIntentId)}',
          ),
        )
        .timeout(_timeout);
    final data = _map(response.body);

    if (_isSuccessful(response)) return data;

    throw Exception(
      _message(response, 'Could not verify the payment status.'),
    );
  }

  static Future<String> cancelBooking(String bookingId) async {
    final response = await http
        .put(Uri.parse('${ApiConfig.baseUrl}/booking/cancel/$bookingId'))
        .timeout(_timeout);

    if (_isSuccessful(response)) {
      return _map(response.body)['message']?.toString() ??
          'Booking cancelled successfully.';
    }

    throw Exception(_message(response, 'Could not cancel the booking.'));
  }

  static bool _isSuccessful(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

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

  static String _message(http.Response response, String fallback) {
    final message = _map(response.body)['message']?.toString().trim();
    return message?.isNotEmpty == true
        ? message!
        : '$fallback (${response.statusCode})';
  }
}
