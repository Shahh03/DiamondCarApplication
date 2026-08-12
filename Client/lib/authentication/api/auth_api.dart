import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_config.dart';

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  const AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthApi {
  static const Duration _timeout = Duration(seconds: 15);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userIdKey = 'auth_user_id';
  static const _userTypeKey = 'auth_user_type';

  static Future<Map<String, dynamic>?>? _refreshInFlight;

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _postPublic('/user/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
    final data = _successfulMap(response, 'Login failed.');
    final user = _readSessionResponse(data);
    await _storeSession(data, user);
    return user;
  }

  static Future<Map<String, dynamic>?> restoreSession() async {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _restoreSessionInternal();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<Map<String, dynamic>?> _restoreSessionInternal() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _postPublic('/user/refresh', {
        'refreshToken': refreshToken,
      });
      final data = _successfulMap(response, 'Could not restore session.');
      final user = _readSessionResponse(data);
      await _storeSession(data, user);
      return user;
    } catch (_) {
      await clearLocalSession();
      return null;
    }
  }

  static Future<bool> refreshAccessToken() async {
    return await restoreSession() != null;
  }

  static Future<void> logout() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _postPublic('/user/logout', {'refreshToken': refreshToken});
      }
    } finally {
      await clearLocalSession();
    }
  }

  static Future<void> clearLocalSession() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userTypeKey),
    ]);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  static Future<String?> getStoredUserId() =>
      _storage.read(key: _userIdKey);

  static Future<String?> getStoredUserType() =>
      _storage.read(key: _userTypeKey);

  static Future<Map<String, String>> authorizedHeaders({
    bool json = true,
  }) async {
    final token = await getAccessToken();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<String> signup({
    required String username,
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required DateTime birthDate,
    required String gender,
    required String nationality,
    required String idCardNumber,
    required String drivingLicenseNumber,
    required String occupation,
    required String location,
    required bool hasAcceptedTerms,
  }) async {
    final response = await _postPublic('/user/create', {
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'type': 'Renter',
      'hasAcceptedTerms': hasAcceptedTerms,
      'name': name.trim(),
      'phoneNumber': phoneNumber.trim(),
      'birthDate': birthDate.toIso8601String(),
      'gender': gender,
      'nationality': nationality,
      'idCardNumber': idCardNumber.trim(),
      'drivingLicenseNumber': drivingLicenseNumber.trim(),
      'occupation': occupation.trim(),
      'location': location.trim(),
    });
    final data = _successfulMap(response, 'Could not create your account.');
    return data['message']?.toString() ?? 'Account created successfully.';
  }

  static Future<http.Response> _postPublic(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthApiException(
        'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const AuthApiException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  static Map<String, dynamic> _successfulMap(
    http.Response response,
    String fallback,
  ) {
    final data = _decodeResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = data['message']?.toString().trim();
    throw AuthApiException(
      message?.isNotEmpty == true ? message! : fallback,
      statusCode: response.statusCode,
    );
  }

  static Map<String, dynamic> _readSessionResponse(
    Map<String, dynamic> data,
  ) {
    final rawUser = data['user'];
    final accessToken = data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';

    if (rawUser is! Map || accessToken.isEmpty || refreshToken.isEmpty) {
      throw const AuthApiException(
        'The server returned incomplete session information.',
      );
    }

    final user = Map<String, dynamic>.from(rawUser);
    if ((user['_id']?.toString() ?? '').isEmpty ||
        (user['type']?.toString() ?? '').isEmpty) {
      throw const AuthApiException(
        'The server returned incomplete account information.',
      );
    }
    return user;
  }

  static Future<void> _storeSession(
    Map<String, dynamic> data,
    Map<String, dynamic> user,
  ) async {
    await Future.wait([
      _storage.write(
        key: _accessTokenKey,
        value: data['accessToken'].toString(),
      ),
      _storage.write(
        key: _refreshTokenKey,
        value: data['refreshToken'].toString(),
      ),
      _storage.write(key: _userIdKey, value: user['_id'].toString()),
      _storage.write(key: _userTypeKey, value: user['type'].toString()),
    ]);
  }

  static Map<String, dynamic>? _decodeResponse(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}
