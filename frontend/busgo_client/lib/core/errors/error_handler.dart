import 'package:dio/dio.dart';
import 'app_exception.dart';

/// Converts raw Dio errors and HTTP status codes into typed [AppException]s.
class ErrorHandler {
  ErrorHandler._();

  /// Call this inside every service's catch block to get a typed exception.
  static AppException handle(Object error) {
    if (error is AppException) return error;

    if (error is DioException) {
      return _fromDio(error);
    }

    return ServerException('Unexpected error: ${error.toString()}');
  }

  static AppException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException('Connection timed out. Please try again.');

      case DioExceptionType.connectionError:
        return const NetworkException();

      case DioExceptionType.badResponse:
        return _fromResponse(e.response);

      case DioExceptionType.cancel:
        return const ServerException('Request was cancelled.');

      default:
        return const NetworkException();
    }
  }

  static AppException _fromResponse(Response? response) {
    if (response == null) return const ServerException();

    final statusCode = response.statusCode ?? 500;
    final body = response.data;

    // Extract server message if available
    String serverMessage = '';
    if (body is Map<String, dynamic>) {
      serverMessage = body['message'] as String? ?? '';
    }

    switch (statusCode) {
      case 400:
        return ValidationException(
          serverMessage.isNotEmpty ? serverMessage : 'Invalid request.',
          fieldErrors: _extractFieldErrors(body),
        );
      case 401:
        return UnauthorizedException(
          serverMessage.isNotEmpty ? serverMessage : 'Authentication required.',
        );
      case 403:
        return UnauthorizedException(
          serverMessage.isNotEmpty ? serverMessage : 'Access denied.',
        );
      case 404:
        return NotFoundException(
          serverMessage.isNotEmpty ? serverMessage : 'Not found.',
        );
      case 409:
        return ConflictException(
          serverMessage.isNotEmpty ? serverMessage : 'Conflict.',
        );
      case 422:
        return ValidationException(
          serverMessage.isNotEmpty ? serverMessage : 'Validation failed.',
          fieldErrors: _extractFieldErrors(body),
        );
      case 429:
        return const ServerException('Too many requests. Please slow down.');
      default:
        return ServerException(
          serverMessage.isNotEmpty ? serverMessage : 'Something went wrong. Please try again.',
        );
    }
  }

  /// Extract field-level errors from the API response shape:
  /// { "errors": [{ "field": "email", "message": "Invalid email" }] }
  static Map<String, String> _extractFieldErrors(dynamic body) {
    final result = <String, String>{};
    if (body is! Map<String, dynamic>) return result;
    final errors = body['errors'];
    if (errors is! List) return result;
    for (final e in errors) {
      if (e is Map<String, dynamic>) {
        final field = e['field'] as String?;
        final msg   = e['message'] as String?;
        if (field != null && msg != null) result[field] = msg;
      }
    }
    return result;
  }

  /// User-facing message for any [AppException].
  static String userMessage(AppException e) {
    if (e is NetworkException)     return 'Please check your internet connection.';
    if (e is SessionExpiredException) return 'Your session expired. Please log in again.';
    if (e is UnauthorizedException) return 'Authentication failed. Please log in again.';
    if (e is NotFoundException)    return 'The requested item was not found.';
    if (e is ConflictException)    return e.message;
    if (e is ValidationException)  return e.message;
    if (e is ServerException)      return 'Something went wrong. Please try again.';
    return e.message;
  }
}
