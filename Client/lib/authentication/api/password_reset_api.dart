import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class PasswordResetApiException implements Exception {
  final String message;

  const PasswordResetApiException(this.message);

  @override
  String toString() => message;
}

class PasswordResetApi {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<String> requestOtp(String email) async {
    final data = await _post('/user/password-reset/request', {
      'email': email.trim().toLowerCase(),
    });
    return data['message']?.toString() ?? 'Check your email for the code.';
  }

  static Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _post('/user/password-reset/verify', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });

    final token = data['resetToken']?.toString() ?? '';
    if (token.isEmpty) {
      throw const PasswordResetApiException(
        'The server returned an invalid reset session.',
      );
    }
    return token;
  }

  static Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final data = await _post('/user/password-reset/complete', {
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
    return data['message']?.toString() ?? 'Password updated successfully.';
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final data = _map(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return data;

      throw PasswordResetApiException(
        data['message']?.toString() ?? 'Could not process the request.',
      );
    } on TimeoutException {
      throw const PasswordResetApiException(
        'The server took too long to respond.',
      );
    } on PasswordResetApiException {
      rethrow;
    } catch (_) {
      throw const PasswordResetApiException(
        'Could not connect to the server.',
      );
    }
  }

  static Map<String, dynamic> _map(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}
