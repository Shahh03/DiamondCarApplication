import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../authentication/api/auth_api.dart';
import 'api_config.dart';

class AuthenticatedClient {
  static const _timeout = Duration(seconds: 30);

  static Future<http.Response> get(String path) => _request('GET', path);

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

  static Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request('DELETE', path, body: body);

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
          return http
              .delete(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
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

  static Future<http.Response> uploadFile({
    required String path,
    required String fieldName,
    required String filePath,
    required MediaType contentType,
  }) =>
      _upload(
        path: path,
        fieldName: fieldName,
        files: [(path: filePath, contentType: contentType)],
      );

  static Future<http.Response> uploadImageFiles({
    required String path,
    required String fieldName,
    required List<String> filePaths,
  }) =>
      _upload(
        path: path,
        fieldName: fieldName,
        files: filePaths
            .map((filePath) => (
                  path: filePath,
                  contentType: _imageMediaType(filePath),
                ))
            .toList(),
      );

  static Future<http.Response> _upload({
    required String path,
    required String fieldName,
    required List<({String path, MediaType contentType})> files,
  }) async {
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
      request.headers.addAll(await AuthApi.authorizedHeaders(json: false));
      for (final file in files) {
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            file.path,
            contentType: file.contentType,
          ),
        );
      }
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

  static MediaType _imageMediaType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }
}
