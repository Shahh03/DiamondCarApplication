import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class RenterApi {
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

  static Future<Set<String>> getWishlistVariantIds(String userId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/renter/getWishlist/$userId');

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractVariantIdsFromWishlistResponse(response.body);
    }

    throw Exception('Failed to load wishlist (${response.statusCode})');
  }

  static Future<bool> addToWishlist(String userId, String variantId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/renter/addToWishlist/$userId/$variantId',
    );

    final response = await http.post(url);

    return (response.statusCode >= 200 && response.statusCode < 300) ||
        response.statusCode == 409;
  }

  static Future<bool> removeFromWishlist(String userId, String variantId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/renter/removeFromWishlist/$userId/$variantId',
    );

    final response = await http.post(url);

    return (response.statusCode >= 200 && response.statusCode < 300) ||
        response.statusCode == 404;
  }

  static Set<String> _extractVariantIdsFromWishlistResponse(dynamic raw) {
      final data = raw is String ? jsonDecode(raw) : raw;

      final list = data is List
          ? data
          : data is Map && data['wishlist'] is List
              ? data['wishlist']
              : data is Map && data['data'] is List
                  ? data['data']
                  : const [];

      return list
          .whereType<Map>()
          .map((m) => m['_id']?.toString())
          .whereType<String>()
          .toSet();
    }

    static Future<void> uploadRenterImage({
      required String renterId,
      required File image,
    }) async {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/renter/changeProfilePicture/$renterId',
      );

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file', // must match renterUpload.single('file')
            image.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Upload failed: ${response.statusCode} $body');
      }
    }


  static Future<void> updateCurrency(String renterId, String currency) async {
  final url = Uri.parse(
    '${ApiConfig.baseUrl}/renter/updateCurrency/$renterId',
  );

  final response = await http.put(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'currency': currency}),
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to update currency (${response.statusCode})');
  }
}

static Future<void> updateRenterProfile({
    required String renterId,
    required String name,
    required String nationality,
    required String occupation,
    required String location,
    required String? gender,
    required DateTime? birthDate,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/renter/update/$renterId');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'nationality': nationality,
        'occupation': occupation,
        'location': location,
        'gender': gender,
        'birthDate': birthDate?.toIso8601String(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update profile');
    }
  }



  static Future<List<dynamic>> getWishlist(String renterId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/renter/getWishlist/$renterId');

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data;
      }

      if (data is Map && data['wishlist'] is List) {
        return data['wishlist'];
      }

      if (data is Map && data['data'] is List) {
        return data['data'];
      }

      return [];
    }

    throw Exception('Failed to load wishlist (${response.statusCode})');
  }

  static Future<String> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/renter/changePassword/$userId');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(response.body);
    final message = data['message'] ?? 'Unknown response';

    if (response.statusCode == 200 || response.statusCode == 201) {
      return message;
    }

    throw Exception(message);
  }


static Future<String> changeUsername({
    required String userId,
    required String username,
    required String password,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/renter/changeUsername/$userId',
    );

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    final message = data['message'] ?? 'Unknown response';

    if (response.statusCode == 200 || response.statusCode == 201) {
      return message;
    }

    throw Exception(message);
  }
  
}