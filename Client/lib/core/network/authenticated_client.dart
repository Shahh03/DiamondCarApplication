import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../authentication/api/auth_api.dart';
import '../../renter/api/api_config.dart';

class AuthenticatedClient {
  static const _timeout = Duration(seconds: 20);

  static Future<http.Response> get(String path) =>
      _request('GET', path);

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request('POST', path, body: body);

  static Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request('PUT', path, body: body);

  static Future<http.Response> delete(String path) =>
      _request('DELETE', path);

  static Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = await AuthApi.authorizedHeaders();
      final encodedBody = body == null ? null : jsonEncode(body);

      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers).timeout(_timeout);
        case 'POST':
          return http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        case 'PUT':
          return http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        case 'DELETE':
          return http.delete(uri, headers: headers).timeout(_timeout);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    }

    try {
      var response = await send();
      if (response.statusCode != 401) return response;

      if (!await AuthApi.refreshAccessToken()) return response;
      response = await send();
      return response;
    } on TimeoutException {
      throw Exception('The server took too long to respond.');
    }
  }

  static Future<http.Response> uploadFile({
    required String path,
    required String fieldName,
    required String filePath,
    required MediaType contentType,
  }) async {
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
      request.headers.addAll(await AuthApi.authorizedHeaders(json: false));
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          contentType: contentType,
        ),
      );
      return http.Response.fromStream(
        await request.send().timeout(_timeout),
      );
    }

    try {
      var response = await send();
      if (response.statusCode != 401) return response;
      if (!await AuthApi.refreshAccessToken()) return response;
      return send();
    } on TimeoutException {
      throw Exception('The server took too long to respond.');
    }
  }
}
