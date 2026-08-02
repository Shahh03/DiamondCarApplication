import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class PaymentMethodsApi {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<Map<String, dynamic>> getSavedCards(String renterId) async {
    return _request(
      http.get(
        Uri.parse('${ApiConfig.baseUrl}/stripe/payment-methods/$renterId'),
        headers: const {'Accept': 'application/json'},
      ),
      'Could not load your saved cards.',
    );
  }

  static Future<Map<String, dynamic>> createSetupIntent(
    String renterId,
  ) async {
    return _request(
      http.post(
        Uri.parse('${ApiConfig.baseUrl}/stripe/setup-intent'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'renterId': renterId}),
      ),
      'Could not start card setup.',
    );
  }

  static Future<void> setDefaultCard({
    required String renterId,
    required String paymentMethodId,
  }) async {
    await _request(
      http.put(
        Uri.parse('${ApiConfig.baseUrl}/stripe/payment-methods/default'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'renterId': renterId,
          'paymentMethodId': paymentMethodId,
        }),
      ),
      'Could not update your default card.',
    );
  }

  static Future<void> removeCard({
    required String renterId,
    required String paymentMethodId,
  }) async {
    await _request(
      http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}/stripe/payment-methods/'
          '$renterId/$paymentMethodId',
        ),
        headers: const {'Accept': 'application/json'},
      ),
      'Could not remove this card.',
    );
  }

  static Future<Map<String, dynamic>> _request(
    Future<http.Response> request,
    String fallback,
  ) async {
    try {
      final response = await request.timeout(_timeout);
      final data = _decodeMap(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }

      final message = data['message']?.toString().trim();
      throw Exception(
        message?.isNotEmpty == true
            ? message
            : '$fallback (${response.statusCode})',
      );
    } on TimeoutException {
      throw Exception('The server took too long to respond.');
    }
  }

  static Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}
