import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CarVariantApi {
  static Future<Map<String, dynamic>> getCarVariantById(String variantId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/carVariant/$variantId');

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Invalid car variant data format');
    }

    throw Exception('Failed to load car variant (${response.statusCode})');
  }


  static Future<List<dynamic>> getAllAvailableCarVariants() async {
  final url = Uri.parse('${ApiConfig.baseUrl}/carVariant/getAllAvailable');

  final response = await http.get(url);

  if (response.statusCode == 200 || response.statusCode == 201) {
    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  throw Exception('Failed to load variants (${response.statusCode})');
}
}