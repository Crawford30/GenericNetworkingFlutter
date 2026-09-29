import 'package:dio/dio.dart';

import '../config/network_config.dart';
import '../enums/header_key.dart';
import '../session/network_session.dart';
import 'request_extras.dart';

/// Adds config, session and auth headers to every non-external request.
/// Per-request headers set on [ApiRequest.headers] always win.
class HeadersInterceptor extends Interceptor {
  HeadersInterceptor({required this.config, this.session});

  final NetworkConfig config;
  final NetworkSession? session;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[RequestExtras.isExternal] == true) {
      return handler.next(options);
    }

    final defaults = <String, String>{
      ...config.additionalHeaders,
      if (config.applicationPlatform != null)
        HeaderKey.applicationPlatform: config.applicationPlatform!,
      if (config.applicationVersion != null)
        HeaderKey.applicationVersion: config.applicationVersion!,
      if (config.originCountryCode != null)
        HeaderKey.originCountryCode: config.originCountryCode!,
    };

    final session = this.session;
    if (session != null) {
      defaults.addAll(await session.sessionHeaders);
      final token = await session.accessToken;
      if (token != null && token.isNotEmpty) {
        final prefix = session.tokenPrefix;
        defaults[HeaderKey.authorization] = prefix == null ? token : '$prefix $token';
      }
    }

    for (final entry in defaults.entries) {
      options.headers.putIfAbsent(entry.key, () => entry.value);
    }
    handler.next(options);
  }
}
