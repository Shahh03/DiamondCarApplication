import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class PaymentMethodsApi {
  static Future<Map<String, dynamic>> getSavedCards(String renterId) =>
      _request(AuthenticatedClient.get('/stripe/payment-methods/$renterId'));

  static Future<Map<String, dynamic>> createSetupIntent(String renterId) =>
      _request(
        AuthenticatedClient.post(
          '/stripe/setup-intent',
          body: {'renterId': renterId},
        ),
      );

  static Future<void> setDefaultCard({
    required String renterId,
    required String paymentMethodId,
  }) async {
    await _request(
      AuthenticatedClient.put(
        '/stripe/payment-methods/default',
        body: {
          'renterId': renterId,
          'paymentMethodId': paymentMethodId,
        },
      ),
    );
  }

  static Future<void> removeCard({
    required String renterId,
    required String paymentMethodId,
  }) async {
    await _request(
      AuthenticatedClient.delete(
        '/stripe/payment-methods/$renterId/$paymentMethodId',
      ),
    );
  }

  static Future<Map<String, dynamic>> _request(
    Future<dynamic> request,
  ) async {
    final response = await request;
    final data = _decodeMap(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = data['message']?.toString().trim();
    throw Exception(
      message?.isNotEmpty == true
          ? message
          : 'Payment method request failed (${response.statusCode})',
    );
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
