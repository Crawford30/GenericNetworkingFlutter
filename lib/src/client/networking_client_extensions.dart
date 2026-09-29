import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../enums/content_type.dart';
import '../enums/http_method.dart';
import '../request/api_request.dart';
import '../request/multipart.dart';
import '../response/downloaded_file.dart';
import '../serialization/response_deserializer.dart';
import 'networking_client.dart';

/// Shorthand verbs returning the deserialized body directly.
///
/// ```dart
/// final user  = await client.get('users/1', Deserializer.object(User.fromJson));
/// final users = await client.get('users', Deserializer.list(User.fromJson));
/// final saved = await client.post('users', Deserializer.object(User.fromJson), body: newUser);
/// await client.delete('users/1');
/// ```
extension NetworkingClientVerbs on NetworkingClient {
  Future<T> get<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _data(ApiRequest<T>(
        endpoint: endpoint,
        deserializer: deserializer,
        queryParameters: queryParameters,
        headers: headers,
        isExternal: isExternal,
        cancelToken: cancelToken,
      ));

  Future<T> post<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ContentType contentType = ContentType.json,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _write(HttpMethod.post, endpoint, deserializer, body, queryParameters, headers,
          contentType, isExternal, cancelToken);

  Future<T> put<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ContentType contentType = ContentType.json,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _write(HttpMethod.put, endpoint, deserializer, body, queryParameters, headers,
          contentType, isExternal, cancelToken);

  Future<T> patch<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ContentType contentType = ContentType.json,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _write(HttpMethod.patch, endpoint, deserializer, body, queryParameters, headers,
          contentType, isExternal, cancelToken);

  /// DELETE ignoring the response body.
  Future<void> delete(
    String endpoint, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _write(HttpMethod.delete, endpoint, Deserializer.noBody, body, queryParameters,
          headers, ContentType.json, isExternal, cancelToken);

  /// DELETE returning a deserialized body.
  Future<T> deleteWithResponse<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
  }) =>
      _write(HttpMethod.delete, endpoint, deserializer, body, queryParameters, headers,
          ContentType.json, isExternal, cancelToken);

  /// Multipart upload of one or more documents plus form fields.
  Future<T> uploadDocument<T>(
    String endpoint,
    Deserializer<T> deserializer, {
    required List<UploadableFile> files,
    Map<String, Object?> fields = const {},
    HttpMethod method = HttpMethod.post,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final response = await upload(
      ApiRequest<T>(
        endpoint: endpoint,
        deserializer: deserializer,
        method: method,
        body: MultipartBody(files: files, fields: fields),
        headers: headers,
        contentType: ContentType.formData,
        isExternal: isExternal,
        cancelToken: cancelToken,
      ),
      onSendProgress: onSendProgress,
    );
    return response.data;
  }

  /// Saves a document to [saveDirectory]; see [NetworkingClient.download].
  Future<DownloadedFile> downloadDocument(
    String endpoint, {
    required String saveDirectory,
    String? fileName,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      download(
        endpoint,
        saveDirectory: saveDirectory,
        fileName: fileName,
        queryParameters: queryParameters,
        headers: headers,
        isExternal: isExternal,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Uint8List> downloadDocumentBytes(
    String endpoint, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      downloadBytes(
        endpoint,
        queryParameters: queryParameters,
        headers: headers,
        isExternal: isExternal,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  Future<T> _write<T>(
    HttpMethod method,
    String endpoint,
    Deserializer<T> deserializer,
    Object? body,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ContentType contentType,
    bool isExternal,
    CancelToken? cancelToken,
  ) =>
      _data(ApiRequest<T>(
        endpoint: endpoint,
        deserializer: deserializer,
        method: method,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        contentType: contentType,
        isExternal: isExternal,
        cancelToken: cancelToken,
      ));

  Future<T> _data<T>(ApiRequest<T> request) async => (await send(request)).data;
}
