import '../client/networking_client.dart';
import '../enums/content_type.dart';
import '../enums/http_method.dart';
import '../error/api_exception.dart';
import '../request/api_request.dart';
import '../response/api_result.dart';
import '../serialization/response_deserializer.dart';
import 'request_controller.dart';

/// Create/update state holder — the Flutter take on `useGenericSet`.
///
/// With an [id] the call defaults to PATCH `endpoint/id/`, otherwise POST.
class SubmitController<T> extends RequestController<T> {
  SubmitController(this.client, this.deserializer);

  final NetworkingClient client;
  final Deserializer<T> deserializer;

  bool get submitting => loading;

  Future<ApiResult<T>> submit({
    required String endpoint,
    Object? id,
    Object? body,
    HttpMethod? method,
    ContentType contentType = ContentType.json,
    Map<String, String>? headers,
    bool isExternal = false,
    void Function(T data)? onSuccess,
    void Function(ApiException error)? onError,
  }) {
    final request = ApiRequest<T>(
      endpoint: resolveEndpoint(endpoint, id),
      deserializer: deserializer,
      method: method ?? (id != null ? HttpMethod.patch : HttpMethod.post),
      body: body,
      headers: headers,
      contentType: contentType,
      isExternal: isExternal,
    );
    return run(
      () async => contentType == ContentType.formData
          ? (await client.upload(request)).data
          : (await client.send(request)).data,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
