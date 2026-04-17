import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../routes/app_router.dart';
import 'token_service.dart';

/// Central HTTP client. All API calls route through here.
///
/// Responsibilities:
/// - Attach `Authorization: Bearer <accessToken>` header to every request.
/// - On 401: attempt silent token refresh once, then retry the original request.
/// - On refresh failure: clear tokens and redirect to /login.
/// - Wrap all errors into typed [AppException] subclasses.
class ApiClient {
  late final Dio _dio;
  final TokenService _tokenService;

  // Prevents parallel refresh races.
  bool _isRefreshing = false;

  ApiClient(this._tokenService) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: _onRequest,
      onError:   _onError,
    ));

    if (AppConfig.enableApiLogs) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ));
    }
  }

  // ── Interceptor handlers ──────────────────────────────────────────────────

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // Only intercept 401s that have not already been retried.
    if (error.response?.statusCode == 401 &&
        error.requestOptions.extra['retried'] != true) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          await _tokenService.refreshTokens();
        } catch (_) {
          _isRefreshing = false;
          await _tokenService.clearTokens();
          appRouter.go('/login');
          return handler.reject(error);
        }
        _isRefreshing = false;
      }

      // Retry the original request with the new token.
      try {
        final newToken = await _tokenService.getAccessToken();
        final opts = error.requestOptions
          ..headers['Authorization'] = 'Bearer $newToken'
          ..extra['retried'] = true;
        final response = await _dio.fetch(opts);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(error);
      }
    }
    handler.next(error);
  }

  // ── Public HTTP methods ───────────────────────────────────────────────────

  /// GET request. Returns the unwrapped `data` map/list from the response.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      return _unwrap(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// POST request.
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return _unwrap(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// PATCH request.
  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return _unwrap(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// DELETE request.
  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return _unwrap(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Multipart file upload (PATCH). [fieldName] is the form field for the file.
  Future<dynamic> uploadFile(
    String path,
    Uint8List fileBytes,
    String fileName,
    String contentType, {
    String fieldName = 'avatar',
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final response = await _dio.patch(path, data: formData);
      return _unwrap(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Unwrap the `data` field from the standard API response envelope.
  dynamic _unwrap(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body;
    }
    return body;
  }
}
