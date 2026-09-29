import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../request/api_request.dart';
import '../response/api_response.dart';
import '../response/downloaded_file.dart';

/// Core networking contract. Depend on this in repositories so it can be
/// swapped for a fake in tests.
///
/// All methods throw [ApiException] on failure.
abstract interface class NetworkingClient {
  Future<ApiResponse<T>> send<T>(ApiRequest<T> request);

  /// Sends a [MultipartBody]/map body as `multipart/form-data`.
  Future<ApiResponse<T>> upload<T>(
    ApiRequest<T> request, {
    ProgressCallback? onSendProgress,
  });

  /// Streams the response to disk inside [saveDirectory]. The file name comes
  /// from [fileName], else the `Content-Disposition` header, else the URL.
  /// Existing files are not overwritten: `report.pdf` becomes `report(1).pdf`.
  Future<DownloadedFile> download(
    String endpoint, {
    required String saveDirectory,
    String? fileName,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });

  /// Downloads into memory. Works on every platform, including web.
  Future<Uint8List> downloadBytes(
    String endpoint, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    bool isExternal = false,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  });
}
