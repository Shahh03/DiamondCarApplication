import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';

import '../../authentication/api/auth_api.dart';
import '../../core/network/authenticated_client.dart';

class RenterApi {
  static Future<Map<String, dynamic>> getUserById(String _userId) async {
    final response = await AuthenticatedClient.get('/user/session');
    final data = _map(response.body);
    if (_successful(response.statusCode) && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    throw Exception(_message(response.body, response.statusCode, 'Failed to load user.'));
  }

  static Future<Set<String>> getWishlistVariantIds(String userId) async {
    final response = await AuthenticatedClient.get(
      '/renter/getWishlist/$userId',
    );
    if (_successful(response.statusCode)) {
      return _extractVariantIds(response.body);
    }
    throw Exception(_message(response.body, response.statusCode, 'Failed to load wishlist.'));
  }

  static Future<bool> addToWishlist(String userId, String variantId) async {
    final response = await AuthenticatedClient.post(
      '/renter/addToWishlist/$userId/$variantId',
    );
    if (_successful(response.statusCode) || response.statusCode == 409) {
      return true;
    }
    throw Exception(_message(response.body, response.statusCode, 'Could not add car to wishlist.'));
  }

  static Future<bool> removeFromWishlist(
    String userId,
    String variantId,
  ) async {
    final response = await AuthenticatedClient.post(
      '/renter/removeFromWishlist/$userId/$variantId',
    );
    if (_successful(response.statusCode)) return true;
    throw Exception(_message(response.body, response.statusCode, 'Could not remove car from wishlist.'));
  }

  static Set<String> _extractVariantIds(dynamic raw) {
    final data = raw is String ? _decode(raw) : raw;
    final list = data is List
        ? data
        : data is Map && data['wishlist'] is List
            ? data['wishlist'] as List
            : data is Map && data['data'] is List
                ? data['data'] as List
                : const <dynamic>[];

    return list
        .whereType<Map>()
        .map((item) => item['_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<void> uploadRenterImage({
    required String renterId,
    required File image,
  }) async {
    final response = await AuthenticatedClient.uploadFile(
      path: '/renter/changeProfilePicture/$renterId',
      fieldName: 'file',
      filePath: image.path,
      contentType: _imageMediaType(image.path),
    );
    if (!_successful(response.statusCode)) {
      throw Exception(_message(response.body, response.statusCode, 'Image upload failed.'));
    }
  }

  static Future<void> updateCurrency(
    String renterId,
    String currency,
  ) async {
    final response = await AuthenticatedClient.put(
      '/renter/updateCurrency/$renterId',
      body: {'currency': currency},
    );
    if (!_successful(response.statusCode)) {
      throw Exception(_message(response.body, response.statusCode, 'Failed to update currency.'));
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
    final response = await AuthenticatedClient.put(
      '/renter/update/$renterId',
      body: {
        'name': name,
        'nationality': nationality,
        'occupation': occupation,
        'location': location,
        'gender': gender,
        'birthDate': birthDate?.toIso8601String(),
      },
    );
    if (!_successful(response.statusCode)) {
      throw Exception(_message(response.body, response.statusCode, 'Failed to update profile.'));
    }
  }

  static Future<List<dynamic>> getWishlist(String renterId) async {
    final response = await AuthenticatedClient.get(
      '/renter/getWishlist/$renterId',
    );
    if (!_successful(response.statusCode)) {
      throw Exception(_message(response.body, response.statusCode, 'Failed to load wishlist.'));
    }

    final data = _decode(response.body);
    if (data is List) return List<dynamic>.from(data);
    if (data is Map && data['wishlist'] is List) {
      return List<dynamic>.from(data['wishlist'] as List);
    }
    if (data is Map && data['data'] is List) {
      return List<dynamic>.from(data['data'] as List);
    }
    return <dynamic>[];
  }

  static Future<String> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await AuthenticatedClient.put(
      '/renter/changePassword/$userId',
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
    final message = _message(
      response.body,
      response.statusCode,
      'Could not update password.',
    );
    if (!_successful(response.statusCode)) throw Exception(message);
    await AuthApi.clearLocalSession();
    return message;
  }

  static Future<String> changeUsername({
    required String userId,
    required String username,
    required String password,
  }) async {
    final response = await AuthenticatedClient.put(
      '/renter/changeUsername/$userId',
      body: {
        'username': username.trim().toLowerCase(),
        'password': password,
      },
    );
    final message = _message(
      response.body,
      response.statusCode,
      'Could not update username.',
    );
    if (_successful(response.statusCode)) return message;
    throw Exception(message);
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

  static Map<String, dynamic> _map(String body) {
    final decoded = _decode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static String _message(String body, int statusCode, String fallback) {
    final decoded = _decode(body);
    final message = decoded is Map ? decoded['message']?.toString().trim() : null;
    return message?.isNotEmpty == true ? message! : '$fallback ($statusCode)';
  }

  static MediaType _imageMediaType(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      case 'gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('image', 'jpeg');
    }
  }
}
