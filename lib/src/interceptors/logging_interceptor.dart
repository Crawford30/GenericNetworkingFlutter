import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../enums/header_key.dart';
import '../request/multipart.dart';

/// Debug-only request/response logger. Redacts the Authorization header.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.maxBodyLength = 4000, void Function(String message)? logger})
      : logger = logger ?? ((m) => debugPrint(m));

  final int maxBodyLength;
  final void Function(String message) logger;

  static const _redacted = {HeaderKey.authorization, 'cookie', 'x-api-key'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger('┌── REQUEST ${options.method} ${options.uri}');
    logger('│ Headers: ${_pretty(_redact(options.headers))}');
    if (options.data != null) logger('│ Body: ${_body(options.data)}');
    logger('└──');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    logger('┌── RESPONSE ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.uri}');
    logger('│ Body: ${_body(response.data)}');
    logger('└──');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger('┌── ERROR ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.method} ${err.requestOptions.uri}');
    if (err.response?.data != null) logger('│ Body: ${_body(err.response?.data)}');
    if (err.message != null) logger('│ Message: ${err.message}');
    logger('└──');
    handler.next(err);
  }

  Map<String, dynamic> _redact(Map<String, dynamic> headers) => headers.map(
        (k, v) => MapEntry(
          k,
          _redacted.any((r) => r.toLowerCase() == k.toLowerCase()) ? '***' : v,
        ),
      );

  String _body(Object? data) {
    if (data is FormData) {
      return 'FormData(fields: ${data.fields}, files: '
          '${data.files.map((f) => '${f.key}=${f.value.filename}').toList()})';
    }
    if (data is MultipartBody) return 'MultipartBody(${data.files.length} files)';
    if (data is List<int>) return '<${data.length} bytes>';
    final text = _pretty(data);
    return text.length > maxBodyLength ? '${text.substring(0, maxBodyLength)}…' : text;
  }

  String _pretty(Object? data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
