import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class ExchangeService {
  late final Dio _dio;
  final storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  ExchangeService() {
    final baseUrl = _authService.baseUrl.replaceAll('/auth', '');
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'accessToken');
          print('Request URL: ${options.baseUrl}${options.path}');
          print('Request Headers: ${options.headers}');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          print('Error Response: ${error.response?.data}');
          print('Error Status Code: ${error.response?.statusCode}');
          print('Error Headers: ${error.response?.headers}');
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getRates(String currency) async {
    try {
      print('Fetching rates for $currency');
      final response = await _dio.get('/exchange-rates/${currency.toLowerCase()}');
      print('Rate response: ${response.data}');
      return response.data;
    } catch (e) {
      print('Error fetching rates: $e');
      rethrow;
    }
  }

  Future<double> getCryptoPrice(String symbol, String currency) async {
    try {
      final response = await _dio.get(
        '/exchange-rates/crypto-price',
        queryParameters: {
          'symbol': symbol,
          'currency': currency,
        },
      );
      return response.data['price'];
    } catch (e) {
      print('Error getting crypto price: $e');
      rethrow;
    }
  }

  Future<double> convertCryptoToFiat(double amount, String cryptoSymbol, String fiatCurrency) async {
    try {
      final price = await getCryptoPrice(cryptoSymbol, fiatCurrency);
      return amount * price;
    } catch (e) {
      print('Error converting crypto to fiat: $e');
      rethrow;
    }
  }
} 