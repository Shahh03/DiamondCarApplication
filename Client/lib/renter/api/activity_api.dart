import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ActivityApi {
  static Future<void> trackView({
    required String renterId,
    required String carVariantId,
  }) =>
      _send({
        'renterId': renterId,
        'eventType': 'view',
        'carVariantId': carVariantId,
      });

  static Future<void> trackSearch({
    required String renterId,
    required String query,
    String? brand,
    String? category,
    String? transmission,
    String? fuelType,
    int? seats,
    double? minPrice,
    double? maxPrice,
  }) =>
      _send({
        'renterId': renterId,
        'eventType': 'search',
        'searchData': _searchData(
          query: query,
          brand: brand,
          category: category,
          transmission: transmission,
          fuelType: fuelType,
          seats: seats,
          minPrice: minPrice,
          maxPrice: maxPrice,
        ),
      });

  static Future<void> trackFilters({
    required String renterId,
    String? brand,
    String? category,
    String? transmission,
    String? fuelType,
    int? seats,
    double? minPrice,
    double? maxPrice,
  }) =>
      _send({
        'renterId': renterId,
        'eventType': 'filter',
        'searchData': _searchData(
          brand: brand,
          category: category,
          transmission: transmission,
          fuelType: fuelType,
          seats: seats,
          minPrice: minPrice,
          maxPrice: maxPrice,
        ),
      });

  static Future<List<dynamic>> getRecentlyViewed({
    required String renterId,
    int limit = 10,
  }) async {
    final safeLimit = limit.clamp(1, 20);
    final response = await AuthenticatedClient.get(
      '/activity/recently-viewed/$renterId?limit=$safeLimit',
    );
    final decoded = _decode(response.body);

    if (_successful(response.statusCode)) {
      if (decoded is List) return List<dynamic>.from(decoded);
      if (decoded is Map && decoded['data'] is List) {
        return List<dynamic>.from(decoded['data'] as List);
      }
      return <dynamic>[];
    }
    throw Exception(_message(decoded, response.statusCode));
  }

  static Map<String, dynamic> _searchData({
    String? query,
    String? brand,
    String? category,
    String? transmission,
    String? fuelType,
    int? seats,
    double? minPrice,
    double? maxPrice,
  }) =>
      {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (transmission != null && transmission.trim().isNotEmpty)
          'transmission': transmission.trim(),
        if (fuelType != null && fuelType.trim().isNotEmpty)
          'fuelType': fuelType.trim(),
        if (seats != null) 'seats': seats,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };

  static Future<void> _send(Map<String, dynamic> payload) async {
    final response = await AuthenticatedClient.post(
      '/activity/track',
      body: payload,
    );
    if (!_successful(response.statusCode)) {
      throw Exception(_message(_decode(response.body), response.statusCode));
    }
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

  static String _message(dynamic decoded, int code) {
    final message = decoded is Map ? decoded['message']?.toString() : null;
    return message?.isNotEmpty == true
        ? message!
        : 'Activity request failed ($code)';
  }
}
