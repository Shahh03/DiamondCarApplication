import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class CarVariantApi {
  static Future<Map<String, dynamic>> getCarVariantById(
    String variantId,
  ) async {
    final response = await AuthenticatedClient.get('/carVariant/$variantId');
    final data = _decode(response.body);

    if (_successful(response.statusCode)) {
      if (data is Map) return Map<String, dynamic>.from(data);
      throw Exception('Invalid car variant data format');
    }
    throw Exception(_message(data, response.statusCode, 'Failed to load car.'));
  }

  static Future<List<dynamic>> getAllAvailableCarVariants() async {
    final response = await AuthenticatedClient.get(
      '/carVariant/getAllAvailable',
    );
    return _decodeList(response, 'Failed to load variants.');
  }

  static Future<List<dynamic>> getRecommendedCarVariants(
    String renterId, {
    int limit = 8,
  }) async {
    final safeLimit = limit.clamp(1, 20);
    final response = await AuthenticatedClient.get(
      '/carVariant/recommended/$renterId?limit=$safeLimit',
    );
    return _decodeList(response, 'Failed to load recommendations.');
  }

  static List<dynamic> _decodeList(response, String fallback) {
    final data = _decode(response.body);
    if (_successful(response.statusCode)) {
      if (data is List) return List<dynamic>.from(data);
      if (data is Map && data['data'] is List) {
        return List<dynamic>.from(data['data'] as List);
      }
      return <dynamic>[];
    }
    throw Exception(_message(data, response.statusCode, fallback));
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

  static String _message(dynamic data, int code, String fallback) {
    final message = data is Map ? data['message']?.toString() : null;
    return message?.isNotEmpty == true ? message! : '$fallback ($code)';
  }
}
