import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';


class ActivityApi {
  static const _timeout = Duration(seconds: 8);

  static Future<void> trackView({
    required String renterId,
    required String carVariantId,
  }) {
    return _send({
      'renterId': renterId,
      'eventType': 'view',
      'carVariantId': carVariantId,
    });
  }

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
  }) {
    return _send({
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
  }

  static Future<void> trackFilters({
    required String renterId,
    String? brand,
    String? category,
    String? transmission,
    String? fuelType,
    int? seats,
    double? minPrice,
    double? maxPrice,
  }) {
    return _send({
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
  }) {
    return {
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
  }

  static Future<void> _send(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/activity/track');
    final response = await http
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Activity tracking failed (${response.statusCode})');
    }
  }
}
