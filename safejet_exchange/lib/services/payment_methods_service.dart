import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'dart:convert';
import '../models/payment_method.dart';
import '../models/payment_method_type.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PaymentMethodsService {
  final Dio _dio;
  final storage = const FlutterSecureStorage();

  PaymentMethodsService(this._dio);

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await storage.read(key: 'accessToken');
    return {
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<PaymentMethod>> getPaymentMethods(BuildContext context) async {
    try {
      final response = await _dio.get(
        '/payment-methods',
        options: Options(
          headers: await _getAuthHeaders(),
          responseType: ResponseType.json,
        ),
      );

      if (response.data == null) {
        return [];
      }

      try {
        if (response.data is! List) {
          print('Unexpected response data type: ${response.data.runtimeType}');
          return [];
        }

        return (response.data as List).map((json) {
          if (json is! Map<String, dynamic>) {
            print('Invalid payment method data: $json');
            return null;
          }
          try {
            return PaymentMethod.fromJson(json);
          } catch (e) {
            print('Error parsing payment method: $e');
            return null;
          }
        }).whereType<PaymentMethod>().toList();
        
      } catch (e) {
        print('Error parsing payment methods: $e');
        print('Response data: ${response.data}');
        throw 'Failed to parse payment methods data';
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        final message = e.response?.data['message'];
        throw message ?? 'Failed to fetch payment methods';
      }
      print('Error getting payment methods: $e');
      throw 'Failed to fetch payment methods';
    }
  }

  Future<void> createPaymentMethod(Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '/payment-methods',
        data: data,
        options: Options(headers: await _getAuthHeaders()),
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          throw 'Session expired';
        }
        throw e.response?.data['message'] ?? 'Failed to create payment method';
      }
      throw 'Failed to create payment method';
    }
  }

  Future<dynamic> updatePaymentMethod(String id, Map<String, dynamic> data, BuildContext context) async {
    try {
      // Process image fields if present
      if (data['details'] != null) {
        final details = data['details'] as Map<String, dynamic>;
        for (final entry in details.entries) {
          if (entry.value is Map && entry.value['value'] is String) {
            final value = entry.value['value'] as String;
            if (value.startsWith('data:image/')) {
              // Compress image before sending
              details[entry.key]['value'] = await compressAndEncodeImage(value);
            }
          }
        }
      }

      final response = await _dio.patch(
        '/payment-methods/$id',
        data: data,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return PaymentMethod.fromJson(response.data);
      } else {
        throw 'Failed to update payment method';
      }
    } catch (e) {
      print('Error updating payment method: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        throw e.response?.data['message'] ?? 'Failed to update payment method';
      }
      rethrow;
    }
  }

  Future<dynamic> deletePaymentMethod(String id, BuildContext context) async {
    try {
      final response = await _dio.delete(
        '/payment-methods/$id',
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.data;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        throw e.response?.data['message'] ?? 'Failed to delete payment method';
      }
      rethrow;
    }
  }

  Future<List<PaymentMethodType>> getPaymentMethodTypes(BuildContext context) async {
    try {
      final response = await _dio.get(
        '/payment-methods/types',
        options: Options(headers: await _getAuthHeaders()),
      );

      return (response.data as List).map((json) {
        // Convert the icon string to IconData if needed
        final type = PaymentMethodType.fromJson(json);
        return type;
      }).toList();
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        final message = e.response?.data['message'];
        throw message ?? 'Failed to fetch payment method types';
      }
      throw 'Failed to fetch payment method types';
    }
  }

  Future<PaymentMethodType> getPaymentMethodType(String id, BuildContext context) async {
    try {
      final response = await _dio.get(
        '/payment-methods/types/$id',
        options: Options(headers: await _getAuthHeaders()),
      );

      return PaymentMethodType.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        final message = e.response?.data['message'];
        throw message ?? 'Failed to fetch payment method type';
      }
      throw 'Failed to fetch payment method type';
    }
  }

  Future<String> getImageUrl(String filename, BuildContext context) async {
    try {
      final response = await _dio.get(
        '/payment-methods/images/$filename',
        options: Options(
          headers: await _getAuthHeaders(),
          responseType: ResponseType.bytes,
        ),
      );
      
      if (response.data == null) {
        throw 'Failed to load image data';
      }

      // Convert response to base64
      final bytes = response.data as List<int>;
      final base64Image = base64.encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      print('Image loading error: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await Provider.of<AuthProvider>(context, listen: false)
              .handleUnauthorized(context);
          throw 'Session expired';
        }
        throw e.response?.data['message'] ?? 'Failed to load image';
      }
      rethrow;
    }
  }

  Future<String> compressAndEncodeImage(String base64Image) async {
    try {
      // Extract image data
      final String mimeType = base64Image.split(',')[0].split(':')[1].split(';')[0];
      final String base64Data = base64Image.split(',')[1];
      
      // Decode base64 to bytes
      final bytes = base64.decode(base64Data);
      
      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 800,
        minWidth: 800,
        quality: 70,
      );
      
      // Convert back to base64
      final compressedBase64 = base64.encode(compressedBytes);
      return 'data:$mimeType;base64,$compressedBase64';
    } catch (e) {
      print('Error compressing image: $e');
      return base64Image; // Return original if compression fails
    }
  }
} 