import 'package:dio/dio.dart';

import '../enums/content_type.dart';
import '../enums/http_method.dart';
import '../serialization/response_deserializer.dart';

/// Describes one HTTP call and how to deserialize its response.
///
/// [T] is the success model; [deserializer] converts the body into it.
class ApiRequest<T> {
  ApiRequest({
    required this.endpoint,
    required this.deserializer,
    this.method = HttpMethod.get,
    this.body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    this.contentType = ContentType.json,
    this.isExternal = false,
    this.cancelToken,
  })  : queryParameters = queryParameters ?? {},
        headers = headers ?? {};

  /// Relative to [NetworkConfig.baseUrl], or an absolute `http(s)://` URL.
  final String endpoint;
  final HttpMethod method;

  /// Map, List, [JsonSerializable], model with `toJson()`, [MultipartBody]
  /// or a raw [FormData].
  final Object? body;
  final Map<String, Object?> queryParameters;
  final Map<String, String> headers;
  final ContentType contentType;

  /// Third-party call: no auth/session/config headers, no 401 handling.
  final bool isExternal;

  final Deserializer<T> deserializer;
  final CancelToken? cancelToken;

  ApiRequest<T> copyWith({
    String? endpoint,
    HttpMethod? method,
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ContentType? contentType,
    bool? isExternal,
    CancelToken? cancelToken,
  }) {
    return ApiRequest<T>(
      endpoint: endpoint ?? this.endpoint,
      deserializer: deserializer,
      method: method ?? this.method,
      body: body ?? this.body,
      queryParameters: queryParameters ?? this.queryParameters,
      headers: headers ?? this.headers,
      contentType: contentType ?? this.contentType,
      isExternal: isExternal ?? this.isExternal,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }

  @override
  String toString() => 'ApiRequest(${method.value} $endpoint)';
}
