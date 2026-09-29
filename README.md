# generic_networking

A reusable networking layer for Flutter apps. It is modelled on OMNetworkingKit (iOS) and the React Native `useAxios` / `useGenericSet` / `useDelete` hooks, and it runs on Dio.

| Concern | Here | OMNetworkingKit / RN equivalent |
|---|---|---|
| Client contract | `NetworkingClient`, `DioNetworkingClient` | `OMNetworkingClient` |
| Verbs | `getAPI` `postAPI` `putAPI` `patchAPI` `deleteAPI` `deleteAPIWithResponse` `uploadDocument` `downloadDocument` `downloadDocumentBytes` | `getApi`, `postApi`, `uploadToApi`, `downloadFileFromApi` |
| Request | `ApiRequest<T>` | `OMRequest<T>` |
| Serializing requests | `RequestSerializer`, `JsonSerializable` (ISO-8601 dates) | `JSONEncoder` |
| Deserializing responses | `Deserializer.object / list / paginated / noBody / raw` | `OmResponseSerializer<T>` |
| Response | `ApiResponse<T>`, `ApiResult<T>` | `OMResponse`, `Result` |
| Errors | `ApiException` (type, message, statusCode, `fieldErrors`, `decodeData`) | `OMHttpError`, `NetworkingError` |
| Config | `NetworkConfig` (base URL, platform/version headers, timeouts) | `NetworkConfig` |
| Session | `NetworkSession` (token, prefix, per-user headers) | `NetworkSession` |
| 401 | `UnauthorizedHandler` | `OMUnAunthorizedHandler` / `logout()` |
| UI state | `FetchController`, `SubmitController`, `DeleteController` | `useAxios().get`, `useGenericSet`, `useDelete` |
| Offline | `ConnectivityService`, `OfflineBanner` | `useNetworkListener`, `BackgroundTasks` |

## Install

```yaml
dependencies:
  generic_networking:
    path: ../generic_networking   # or a git url
```

## Setup

```dart
final client = DioNetworkingClient(
  config: const NetworkConfig(
    baseUrl: 'https://api.example.com/v1/',
    applicationPlatform: 'android',
    applicationVersion: '1.0.0',
    additionalHeaders: {'X-Api-Key': '...'},
  ),
  session: mySession,                    // implements NetworkSession
  unauthorizedHandler: CallbackUnauthorizedHandler((_) => auth.logout()),
);
```

Relative endpoints are appended to `baseUrl`. Keep the trailing slash on `baseUrl` and leave the leading slash off endpoints. Absolute `https://` endpoints are sent as they are. Pass `isExternal: true` for third-party APIs. That skips the auth, session and config headers and the 401 handling.

## Serialization

Requests: pass a `Map`, a `List`, or any model that implements `JsonSerializable` or has a `toJson()` method. This covers `json_serializable` and `freezed` models. `DateTime` values are sent as ISO-8601 UTC and enums by name.

Responses: choose a `Deserializer`.

```dart
client.getAPI('users/1/', Deserializer.object(User.fromJson));            // User
client.getAPI('users/', Deserializer.list(User.fromJson));                // List<User>
client.getAPI('users/', Deserializer.paginated('results', User.fromJson)); // DRF pagination
client.postAPI('logout/', Deserializer.noBody);                           // void
client.getAPI('anything/', Deserializer.raw);                             // dynamic
Deserializer((json) => custom(json));                                  // anything else
```

If a body has the wrong shape, you get `ApiException(type: serialization)` and the app keeps running.

## Calls

```dart
final user  = await client.postAPI('users/', Deserializer.object(User.fromJson), body: newUser);
final user2 = await client.patchAPI('users/1/', Deserializer.object(User.fromJson), body: {'name': 'Ada'});
await client.deleteAPI('users/1/');

await client.uploadDocument('documents/', Deserializer.noBody,
    files: [UploadableFile.fromPath(path, fieldName: 'document')],
    fields: {'type': 'national_id'},
    onSendProgress: (sent, total) => ...);

final file  = await client.downloadDocument('statements/7/', saveDirectory: dir.path);
final bytes = await client.downloadDocumentBytes('statements/7/'); // works on web too
```

For full control, use `client.send(ApiRequest<T>(...))`, which returns an `ApiResponse<T>` with the status and headers.

## Errors

Every call throws `ApiException`:

```dart
try { ... } on ApiException catch (e) {
  e.type;          // NetworkErrorType.validation / unauthorized / noConnection / timeout / server ...
  e.message;       // taken from message/error/detail/non_field_errors, or a friendly default
  e.fieldErrors;   // {'email': 'Enter a valid email.'}
  e.decodeData(MyErrorBody.fromJson);
}
```

If you'd rather not use try/catch, use `ApiResult.guard(() => client.getAPI(...))`, then `.when(success:, failure:)`.

## Controllers (hooks equivalent)

`ChangeNotifier`s that work with `ListenableBuilder`, Provider, Riverpod or setState:

```dart
final users = FetchController(client, 'users/', Deserializer.list(User.fromJson))..fetch();
final form  = SubmitController(client, Deserializer.object(User.fromJson));
form.submit(endpoint: 'users/', id: user?.id, body: data); // PATCH users/id/ if id, else POST
form.submitting; form.error; form.fieldErrors; form.updateErrors({'email': null});
final del = DeleteController(client)..delete(endpoint: 'users/', id: 5);
```

See [example/example.dart](example/example.dart).

## Tests

```sh
flutter test
```
