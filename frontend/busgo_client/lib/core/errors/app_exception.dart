/// Base class for all BusGo application exceptions.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// No internet connectivity detected.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Please check your internet connection.']);
}

/// JWT access token expired and refresh also failed.
class SessionExpiredException extends AppException {
  const SessionExpiredException(
      [super.message = 'Your session has expired. Please log in again.']);
}

/// Server returned 401 and refresh was not possible.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Authentication required.']);
}

/// Server returned 404.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'The requested resource was not found.']);
}

/// Server returned 5xx.
class ServerException extends AppException {
  const ServerException([super.message = 'Something went wrong. Please try again.']);
}

/// Server returned 422 / 400 with field-level validation errors.
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;
  const ValidationException(super.message, {this.fieldErrors = const {}});
}

/// Server returned 409 Conflict (e.g. email already taken).
class ConflictException extends AppException {
  const ConflictException([super.message = 'This action conflicts with existing data.']);
}
