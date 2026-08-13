import 'dart:convert';

import '../../core/network/authenticated_client.dart';

class ProviderFleetApi {
  static Future<List<Map<String, dynamic>>> getProviderCars({
    required String providerId,
  }) async {
    final response = await AuthenticatedClient.get(
      '/carVariant/getAllCarsForProvider/$providerId',
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not load your fleet.');

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
        if (insuranceDetails != null) 'insuranceDetails': insuranceDetails,
      },
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not create the car.');
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateCarVariant({
    required String carVariantId,
    required String color,
    required String registrationNumber,
    required num rentalPricePerDay,
    required num depositAmount,
    required bool isAvailable,
    required String insuranceCompany,
    required String policyNumber,
    DateTime? insuranceExpiryDate,
  }) async {
    final response = await AuthenticatedClient.put(
      '/carVariant/update/$carVariantId',
      body: {
        'color': color.trim(),
        'registrationNumber': registrationNumber.trim(),
        'rentalPricePerDay': rentalPricePerDay,
        'depositAmount': depositAmount,
        'isAvailable': isAvailable,
        'insuranceDetails': {
          'insuranceCompany': insuranceCompany.trim(),
          'policyNumber': policyNumber.trim(),
          if (insuranceExpiryDate != null)
            'expiryDate': insuranceExpiryDate.toIso8601String(),
        },
      },
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not update the vehicle.');
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> uploadImages({
    required String carVariantId,
    required List<String> filePaths,
  }) async {
    if (filePaths.isEmpty) return <String, dynamic>{};
    final response = await AuthenticatedClient.uploadImageFiles(
      path: '/carVariant/uploadCarVariantImages/$carVariantId',
      fieldName: 'files',
      filePaths: filePaths,
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not upload the images.');
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> removeImage({
    required String carVariantId,
    required String imageUrl,
    String? imagePublicId,
  }) async {
    final response = await AuthenticatedClient.delete(
      '/carVariant/$carVariantId/image',
      body: {
        'imageUrl': imageUrl,
        if (imagePublicId?.isNotEmpty == true) 'imagePublicId': imagePublicId,
      },
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not remove the image.');
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<String> removeCarVariant(String carVariantId) async {
    final response = await AuthenticatedClient.delete(
      '/carVariant/$carVariantId',
    );
    final decoded = _decode(response.body);
    _throwUnlessSuccessful(response.statusCode, decoded, 'Could not remove the vehicle.');
    return _message(decoded, 'Vehicle removed from your fleet.');
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static void _throwUnlessSuccessful(
    int statusCode,
    dynamic decoded,
    String fallback,
  ) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw Exception(_message(decoded, '$fallback ($statusCode)'));
  }

  static String _message(dynamic decoded, String fallback) {
    if (decoded is Map) {
      final message = decoded['message']?.toString().trim();
      if (message?.isNotEmpty == true) return message!;
    }
    return fallback;
  }
}
