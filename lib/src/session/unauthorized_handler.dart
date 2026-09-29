import 'dart:async';

import '../error/api_exception.dart';

/// Called when a non-external request gets a 401, e.g. to log the user out.
abstract class UnauthorizedHandler {
  FutureOr<void> handle(ApiException error);
}

class CallbackUnauthorizedHandler implements UnauthorizedHandler {
  const CallbackUnauthorizedHandler(this.onUnauthorized);

  final FutureOr<void> Function(ApiException error) onUnauthorized;

  @override
  FutureOr<void> handle(ApiException error) => onUnauthorized(error);
}
