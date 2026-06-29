import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class BookingApi {
  static Future<List<dynamic>> getUpcomingBookings(String renterId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/renter/getUpcomingBookings/$renterId',
    );

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }

    throw Exception(
      'Failed to load upcoming bookings (${response.statusCode})',
    );
  }

  static Future<List<dynamic>> getRenterBookings(String renterId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/renter/getBookings/$renterId',
    );

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }

    throw Exception(
      'Failed to load bookings (${response.statusCode})',
    );
  }
}