import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/network_config.dart';
import '../enums/content_type.dart';
import '../enums/http_status.dart';
import '../error/api_exception.dart';
import '../interceptors/headers_interceptor.dart';
import '../interceptors/logging_interceptor.dart';
import '../interceptors/request_extras.dart';
import '../request/api_request.dart';
import '../request/multipart.dart';
import '../response/api_response.dart';
import '../response/downloaded_file.dart';
import '../serialization/request_serializer.dart';
import '../session/network_session.dart';
import '../session/unauthorized_handler.dart';
import '../utils/file_system.dart';
import 'networking_client.dart';

class DioNetworkingClient implements NetworkingClient {
  DioNetworkingClient({
    required this.config,
    this.session,
    this.unauthorizedHandler,
    this.requestSerializer = const RequestSerializer(),
    Dio? dio,
    List<Interceptor> interceptors = const [],
  }) : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = config.baseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.sendTimeout
      ..responseType = ResponseType.json;

    this.dio.interceptors.addAll([
      HeadersInterceptor(config: config, session: session),
      ...interceptors,
      if (kDebugMode && config.enableLogging) LoggingInterceptor(),
    ]);
  }

  final NetworkConfig config;
  final NetworkSession? session;
  final UnauthorizedHandler? unauthorizedHandler;
  final RequestSerializer requestSerializer;

  /// Exposed for advanced use (extra interceptors, custom adapters).
  final Dio dio;

  @override
  Future<ApiResponse<T>> send<T>(ApiRequest<T> request) => _execute(request);

  @override
  Future<ApiResponse<T>> upload<T>(
    ApiRequest<T> request, {
    ProgressCallback? onSendProgress,
  }) {
    return _execute(
      request.copyWith(contentType: ContentType.formData),
      onSendProgress: onSendProgress,
    );
  }

  @override
  Future<DownloadedFile> download(
    String endpoint, {
    required String saveDirectory,
    String? fileName,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    var savedPath = '';
    var savedName = '';
    try {
      final response = await dio.download(
        endpoint,
        (Headers responseHeaders) async {
          savedName = fileName ??
              _fileNameFromHeaders(responseHeaders) ??
              _fileNameFromUrl(endpoint) ??
              'download';
          savedPath = await _uniquePath(saveDirectory, savedName);
          savedName = savedPath.split(RegExp(r'[/\\]')).last;
          return savedPath;
        },
        queryParameters: _cleanQuery(queryParameters),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: _options(headers: headers, isExternal: isExternal),
      );
      return DownloadedFile(
        path: savedPath,
        fileName: savedName,
        statusCode: response.statusCode,
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
    } catch (e, st) {
      throw await _mapError(e, st, isExternal: isExternal);
    }
  }

  @override
  Future<Uint8List> downloadBytes(
    String endpoint, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        endpoint,
        queryParameters: _cleanQuery(queryParameters),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: _options(headers: headers, isExternal: isExternal)
            .copyWith(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } catch (e, st) {
      throw await _mapError(e, st, isExternal: isExternal);
    }
  }

  // MARK: internals

  Future<ApiResponse<T>> _execute<T>(
    ApiRequest<T> request, {
    ProgressCallback? onSendProgress,
  }) async {
    final Response<Object?> response;
    try {
      response = await dio.request<Object?>(
        request.endpoint,
        data: await _encodeBody(request),
        queryParameters: _cleanQuery(request.queryParameters),
        cancelToken: request.cancelToken,
        onSendProgress: onSendProgress,
        options: _options(
          method: request.method.value,
          headers: request.headers,
          isExternal: request.isExternal,
          contentType: request.contentType,
        ),
      );
    } catch (e, st) {
      throw await _mapError(e, st, isExternal: request.isExternal);
    }

    final statusCode = response.statusCode;
    final raw = HttpStatus.emptyResponseCodes.contains(statusCode) || response.data == ''
        ? null
        : response.data;
    try {
      return ApiResponse<T>(
        data: request.deserializer.deserialize(raw),
        statusCode: statusCode,
        headers: response.headers.map,
      );
    } catch (e, st) {
      throw ApiException(
        type: NetworkErrorType.serialization,
        message: 'Could not read the server response.',
        statusCode: statusCode,
        data: raw,
        headers: response.headers.map,
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Object?> _encodeBody(ApiRequest<Object?> request) async {
    final body = request.body;
    if (body == null || body is FormData) return body;
    if (body is MultipartBody) return body.toFormData();
    if (request.contentType == ContentType.formData) {
      final serialized = body is Map ? body : requestSerializer.serialize(body);
      if (serialized is! Map) {
        throw ArgumentError('multipart/form-data bodies must serialize to a Map');
      }
      return createFormData(serialized.cast<String, Object?>());
    }
    if (request.contentType == ContentType.json) return requestSerializer.serialize(body);
    return body;
  }

  Options _options({
    String? method,
    Map<String, String>? headers,
    bool isExternal = false,
    ContentType contentType = ContentType.json,
  }) {
    return Options(
      method: method,
      headers: {
        'Accept': ContentType.json.value,
        ...?headers,
      },
      // Dio adds the multipart boundary itself when the body is FormData.
      contentType: contentType == ContentType.formData ? null : contentType.value,
      extra: {RequestExtras.isExternal: isExternal},
    );
  }

  Future<ApiException> _mapError(Object error, StackTrace st, {required bool isExternal}) async {
    final exception = ApiException.fromError(error, st);
    if (!isExternal && exception.isUnauthorized) {
      try {
        await unauthorizedHandler?.handle(exception);
      } catch (e) {
        debugPrint('generic_networking: unauthorized handler threw $e');
      }
    }
    return exception;
  }

  Map<String, Object?>? _cleanQuery(Map<String, Object?>? query) {
    if (query == null || query.isEmpty) return null;
    return Map.fromEntries(query.entries.where((e) => e.value != null));
  }

  String? _fileNameFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition');
    if (disposition == null) return null;
    final utf8Match = RegExp(r"filename\*=(?:UTF-8'')?([^;]+)", caseSensitive: false)
        .firstMatch(disposition);
    if (utf8Match != null) return Uri.decodeComponent(utf8Match.group(1)!.replaceAll('"', '').trim());
    final match = RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(disposition);
    return match?.group(1)?.trim();
  }

  String? _fileNameFromUrl(String endpoint) {
    final segments = Uri.tryParse(endpoint)?.pathSegments.where((s) => s.isNotEmpty);
    if (segments == null || segments.isEmpty) return null;
    final last = segments.last;
    return last.contains('.') ? last : null;
  }

  Future<String> _uniquePath(String directory, String fileName) async {
    var candidate = joinPath(directory, fileName);
    if (!await fileExists(candidate)) return candidate;

    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var index = 1;
    do {
      candidate = joinPath(directory, '$base($index)$ext');
      index++;
    } while (await fileExists(candidate));
    return candidate;
  }
}
