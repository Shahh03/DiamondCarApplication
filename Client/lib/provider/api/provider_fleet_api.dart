import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderFleetApi {
  static Future<List<Map<String, dynamic>>> getProviderCars({
    required String providerId,
    String? model,
  }) async {
    final query = model?.trim();
    var path = '/carVariant/getAllCarsForProvider/$providerId';

    if (query != null && query.isNotEmpty) {
      path = '$path?model=${Uri.encodeQueryComponent(query)}';
    }

    final response = await AuthenticatedClient.get(path);
    final decoded = _decode(response.body);

    if (!_successful(response.statusCode)) {
      throw Exception(
        _message(
          decoded,
          'Could not load your fleet (${response.statusCode}).',
        ),
      );
    }

    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> createCarVariant({
    required String providerId,
    required String carId,
    required String color,
    required String registrationNumber,
    required num rentalPricePerDay,
    required num depositAmount,
    Map<String, dynamic>? insuranceDetails,
  }) async {
    final response = await AuthenticatedClient.post(
      '/carVariant/create',
      body: {
        'provider': providerId,
        'car': carId,
        'color': color.trim(),
        'registrationNumber': registrationNumber.trim(),
        'rentalPricePerDay': rentalPricePerDay,
        'depositAmount': depositAmount,
        if (insuranceDetails != null)
          'insuranceDetails': insuranceDetails,
      },
    );

    final decoded = _decode(response.body);
    if (!_successful(response.statusCode)) {
      throw Exception(
        _message(
          decoded,
          'Could not create the car (${response.statusCode}).',
        ),
      );
    }

    if (decoded is! Map) {
      throw Exception('The server returned invalid car information.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static bool _successful(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  static String _message(dynamic decoded, String fallback) {
    if (decoded is Map) {
      final message = decoded['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }
}

