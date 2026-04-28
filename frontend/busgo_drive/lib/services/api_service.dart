import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrl = kDebugMode
      ? 'http://192.168.1.3:5000/api'
      : 'https://your-api-domain.com/api';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
}



