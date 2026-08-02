import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  const AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthApi {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/user/login');

    try {
      final response = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
              'password': password,
            }),
          )
          .timeout(_timeout);

      final Map<String, dynamic>? data = _decodeResponse(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawUser = data?['user'];

        if (rawUser is! Map) {
          throw const AuthApiException(
            'The server returned invalid account information.',
          );
        }

        final user = Map<String, dynamic>.from(rawUser);
        final id = user['_id']?.toString() ?? '';
        final type = user['type']?.toString() ?? '';

        if (id.isEmpty || type.isEmpty) {
          throw const AuthApiException(
            'The server returned incomplete account information.',
          );
        }

        return user;
      }

      final serverMessage = data?['message']?.toString().trim();
      throw AuthApiException(
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Login failed. Please check your details and try again.',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const AuthApiException(
        'The server took too long to respond. Please try again.',
      );
    } on AuthApiException {
      rethrow;
    } catch (_) {
      throw const AuthApiException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
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
  final url = Uri.parse('${ApiConfig.baseUrl}/user/create');

  try {
    final response = await http
        .post(
          url,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
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
          }),
        )
        .timeout(_timeout);

    final data = _decodeResponse(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data?['message']?.toString() ??
          'Account created successfully.';
    }

    final serverMessage = data?['message']?.toString().trim();

    throw AuthApiException(
      serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Could not create your account. Please try again.',
      statusCode: response.statusCode,
    );
  } on TimeoutException {
    throw const AuthApiException(
      'The server took too long to respond. Please try again.',
    );
  } on AuthApiException {
    rethrow;
  } catch (_) {
    throw const AuthApiException(
      'Could not connect to the server. Check your connection and try again.',
    );
  }
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
