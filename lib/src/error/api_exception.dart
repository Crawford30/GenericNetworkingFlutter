import 'package:dio/dio.dart';

import '../enums/http_status.dart';
import '../serialization/json_serializable.dart';
import '../serialization/response_deserializer.dart';

enum NetworkErrorType {
  noConnection,
  timeout,
  cancelled,
  badCertificate,
  invalidUrl,
  unauthorized,
  forbidden,
  notFound,
  validation,
  client,
  server,
  serialization,
  unknown,
}

/// Single error type thrown by the client.
///
/// [data] holds the raw error body so callers can decode their own error
/// model with [decodeData].
class ApiException implements Exception {
  ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.data,
    this.headers = const {},
    this.cause,
    this.stackTrace,
  });

  factory ApiException.fromResponse({
    required int? statusCode,
    required Object? data,
    Map<String, List<String>> headers = const {},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return ApiException(
      type: _typeForStatus(statusCode),
      message: extractMessage(data, statusCode),
      statusCode: statusCode,
      data: data,
      headers: headers,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (e.type == DioExceptionType.badResponse && response != null) {
      return ApiException.fromResponse(
        statusCode: response.statusCode,
        data: response.data,
        headers: response.headers.map,
        cause: e,
        stackTrace: e.stackTrace,
      );
    }
    final (type, message) = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        (NetworkErrorType.timeout, 'The request timed out. Please try again.'),
      DioExceptionType.cancel => (NetworkErrorType.cancelled, 'Request was cancelled.'),
      DioExceptionType.badCertificate =>
        (NetworkErrorType.badCertificate, 'Could not verify a secure connection.'),
      DioExceptionType.connectionError =>
        (NetworkErrorType.noConnection, 'No internet connection.'),
      _ when e.error is ApiException => ((e.error as ApiException).type, (e.error as ApiException).message),
      _ => (NetworkErrorType.unknown, e.message ?? defaultMessage),
    };
    return ApiException(
      type: type,
      message: message,
      statusCode: response?.statusCode,
      data: response?.data,
      cause: e.error ?? e,
      stackTrace: e.stackTrace,
    );
  }

  factory ApiException.fromError(Object error, [StackTrace? stackTrace]) {
    if (error is ApiException) return error;
    if (error is DioException) return ApiException.fromDio(error);
    if (error is FormatException || error is TypeError) {
      return ApiException(
        type: NetworkErrorType.serialization,
        message: 'Could not read the server response.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return ApiException(
      type: NetworkErrorType.unknown,
      message: defaultMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static const defaultMessage = 'An unknown error occurred';
  static const serverErrorMessage = 'Server error occurred. Try again later.';

  final NetworkErrorType type;
  final String message;
  final int? statusCode;

  /// Raw (already JSON-decoded) error body.
  final Object? data;
  final Map<String, List<String>> headers;

  final Object? cause;
  final StackTrace? stackTrace;

  StatusCategory get category => StatusCategory.of(statusCode);
  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;
  bool get isServerError => category == StatusCategory.serverError;

  /// Field errors for form validation, e.g. Django REST
  /// `{"email": ["Enter a valid email."]}` -> `{"email": "Enter a valid email."}`.
  Map<String, String> get fieldErrors {
    final body = data;
    if (body is! Map) return const {};
    final source = body['errors'] is Map ? body['errors'] as Map : body;
    final result = <String, String>{};
    for (final entry in source.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        result[entry.key.toString()] = value.first.toString();
      } else if (value is String && !_messageKeys.contains(entry.key)) {
        result[entry.key.toString()] = value;
      }
    }
    return result;
  }

  /// Decode the error body into your own error model.
  E? decodeData<E>(FromJson<E> fromJson) {
    try {
      return Deserializer.object(fromJson).deserialize(data);
    } catch (_) {
      return null;
    }
  }

  static const _messageKeys = {'message', 'error', 'detail', 'error_description'};

  /// Picks a human readable message from common error body shapes.
  static String extractMessage(Object? data, int? statusCode) {
    if (StatusCategory.of(statusCode) == StatusCategory.serverError) {
      return serverErrorMessage;
    }
    if (data is String && data.trim().isNotEmpty && !data.trimLeft().startsWith('<')) {
      return data;
    }
    if (data is Map) {
      for (final key in _messageKeys) {
        final value = data[key];
        if (value is String && value.isNotEmpty) return value;
        if (value is Map && value['message'] is String) return value['message'] as String;
      }
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) return nonField.first.toString();
      for (final value in data.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
      }
    }
    return switch (statusCode) {
      HttpStatus.unauthorized => 'Your session has expired. Please sign in again.',
      HttpStatus.forbidden => 'You do not have permission to do that.',
      HttpStatus.notFound => 'The requested resource was not found.',
      _ => defaultMessage,
    };
  }

  static NetworkErrorType _typeForStatus(int? code) => switch (code) {
        HttpStatus.unauthorized => NetworkErrorType.unauthorized,
        HttpStatus.forbidden => NetworkErrorType.forbidden,
        HttpStatus.notFound => NetworkErrorType.notFound,
        HttpStatus.badRequest || HttpStatus.unprocessableEntity => NetworkErrorType.validation,
        _ => switch (StatusCategory.of(code)) {
            StatusCategory.serverError => NetworkErrorType.server,
            StatusCategory.clientError => NetworkErrorType.client,
            _ => NetworkErrorType.unknown,
          },
      };

  @override
  String toString() => 'ApiException(${type.name}, status: $statusCode, message: $message)';
}
