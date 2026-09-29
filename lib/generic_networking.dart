/// Generic networking layer: typed REST client over Dio with request
/// serialization, response deserialization, session headers, 401 handling,
/// upload/download and state controllers.
library;

export 'package:dio/dio.dart' show CancelToken, ProgressCallback, Interceptor, Dio;

export 'src/client/dio_networking_client.dart';
export 'src/client/networking_client.dart';
export 'src/client/networking_client_extensions.dart';
export 'src/config/network_config.dart';
export 'src/connectivity/connectivity_service.dart';
export 'src/connectivity/offline_banner.dart';
export 'src/enums/content_type.dart';
export 'src/enums/header_key.dart';
export 'src/enums/http_method.dart';
export 'src/enums/http_status.dart';
export 'src/error/api_exception.dart';
export 'src/interceptors/logging_interceptor.dart';
export 'src/request/api_request.dart';
export 'src/request/multipart.dart';
export 'src/response/api_response.dart';
export 'src/response/api_result.dart';
export 'src/response/downloaded_file.dart';
export 'src/serialization/json_serializable.dart';
export 'src/serialization/request_serializer.dart';
export 'src/serialization/response_deserializer.dart';
export 'src/session/network_session.dart';
export 'src/session/unauthorized_handler.dart';
export 'src/state/delete_controller.dart';
export 'src/state/fetch_controller.dart';
export 'src/state/request_controller.dart';
export 'src/state/submit_controller.dart';
