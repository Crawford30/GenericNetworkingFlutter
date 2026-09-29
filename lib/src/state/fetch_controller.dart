import 'package:dio/dio.dart';

import '../client/networking_client.dart';
import '../client/networking_client_extensions.dart';
import '../error/api_exception.dart';
import '../response/api_result.dart';
import '../serialization/response_deserializer.dart';
import 'request_controller.dart';

/// GET state holder — the Flutter take on `useAxios().get`.
///
/// ```dart
/// final users = FetchController(client, 'users/', Deserializer.list(User.fromJson))..fetch();
/// ListenableBuilder(listenable: users, builder: (_, _) => ...);
/// ```
class FetchController<T> extends RequestController<T> {
  FetchController(
    this.client,
    this.endpoint,
    this.deserializer, {
    Map<String, Object?>? queryParameters,
    this.isExternal = false,
    super.initialData,
  }) : queryParameters = queryParameters ?? {};

  final NetworkingClient client;
  final String endpoint;
  final Deserializer<T> deserializer;
  final bool isExternal;
  Map<String, Object?> queryParameters;

  CancelToken? _cancelToken;

  /// [id] fetches a single instance (`endpoint/id/`). New [queryParameters]
  /// are merged and remembered for [refresh].
  Future<ApiResult<T>> fetch({
    Object? id,
    Map<String, Object?>? queryParameters,
    bool background = false,
    void Function(T data)? onSuccess,
    void Function(ApiException error)? onError,
  }) {
    if (queryParameters != null) {
      this.queryParameters = {...this.queryParameters, ...queryParameters};
    }
    _cancelToken?.cancel();
    final token = _cancelToken = CancelToken();
    return run(
      () => client.getAPI(
        resolveEndpoint(endpoint, id),
        deserializer,
        queryParameters: this.queryParameters,
        isExternal: isExternal,
        cancelToken: token,
      ),
      background: background,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  /// Re-fetch silently, keeping current data on screen.
  Future<ApiResult<T>> refresh() => fetch(background: true);

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}
