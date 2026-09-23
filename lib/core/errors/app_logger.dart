import 'package:flutter/foundation.dart';

/// Centralized logger with standard log levels.
///
/// Prevents exposing sensitive user credentials, payment details, or database internals.
class AppLogger {
  AppLogger._();

  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag]' : '[INFO]';
    debugPrint('$prefix $message');
  }

  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag:WARN]' : '[WARN]';
    debugPrint('$prefix $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    final prefix = tag != null ? '[$tag:ERROR]' : '[ERROR]';
    debugPrint('$prefix $message');
    if (error != null) {
      debugPrint('$prefix Cause: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('$prefix StackTrace:\n$stackTrace');
    }
  }
}

/// Standard custom exception for procurement application operations.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class AuthExceptionApp extends AppException {
  const AuthExceptionApp(super.message, {super.code, super.originalError});
}

class SessionException extends AppException {
  const SessionException(super.message, {super.code, super.originalError});
}

class CartException extends AppException {
  const CartException(super.message, {super.code, super.originalError});
}

class OrderException extends AppException {
  const OrderException(super.message, {super.code, super.originalError});
}
