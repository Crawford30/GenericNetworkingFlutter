import '../client/networking_client.dart';
import '../client/networking_client_extensions.dart';
import '../error/api_exception.dart';
import '../response/api_result.dart';
import '../serialization/response_deserializer.dart';
import 'request_controller.dart';

/// DELETE state holder — the Flutter take on `useDelete`.
class DeleteController extends RequestController<Object?> {
  DeleteController(this.client);

  final NetworkingClient client;

  bool get deleting => loading;

  Future<ApiResult<Object?>> delete({
    required String endpoint,
    Object? id,
    bool isExternal = false,
    void Function(Object? data)? onSuccess,
    void Function(ApiException error)? onError,
  }) {
    return run(
      () => client.deleteWithResponse<Object?>(
        resolveEndpoint(endpoint, id),
        Deserializer<Object?>((data) => data),
        isExternal: isExternal,
      ),
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
