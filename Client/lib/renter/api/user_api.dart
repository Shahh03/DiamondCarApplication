import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class UserApi {
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/user/$userId');

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Invalid user data format');
    }

    throw Exception('Failed to load user (${response.statusCode})');
  }
}