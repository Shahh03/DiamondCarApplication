import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CarVariantApi {
  static const _timeout = Duration(seconds: 12);

  static Future<Map<String, dynamic>> getCarVariantById(
    String variantId,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/carVariant/$variantId');
    final response = await http.get(url).timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw Exception('Invalid car variant data format');
    }

    throw Exception('Failed to load car variant (${response.statusCode})');
  }

  static Future<List<dynamic>> getAllAvailableCarVariants() async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/carVariant/getAllAvailable',
    );
    final response = await http.get(url).timeout(_timeout);
    return _decodeList(response, 'Failed to load variants');
  }

  static Future<List<dynamic>> getRecommendedCarVariants(
    String renterId, {
    int limit = 8,
  }) async {
    final safeLimit = limit.clamp(1, 20);
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/carVariant/recommended/$renterId',
    ).replace(queryParameters: {'limit': safeLimit.toString()});
    final response = await http.get(url).timeout(_timeout);
    return _decodeList(response, 'Failed to load recommendations');
  }

  static List<dynamic> _decodeList(
    http.Response response,
    String errorMessage,
  ) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) return List<dynamic>.from(data);
      if (data is Map && data['data'] is List) {
        return List<dynamic>.from(data['data'] as List);
      }
      return <dynamic>[];
    }

    throw Exception('$errorMessage (${response.statusCode})');
  }
}
