import 'dart:async';

/// Supplies per-user values (token, ids) at request time.
///
/// Implement this in the app, backed by your auth state / secure storage.
abstract class NetworkSession {
  FutureOr<String?> get accessToken;

  /// Prefix for the Authorization header. Return `null` to send the raw token.
  String? get tokenPrefix => 'Bearer';

  /// Extra headers for the signed-in user (e.g. customer id).
  FutureOr<Map<String, String>> get sessionHeaders => const {};
}

/// Simple mutable session, handy for tests or apps without a token store.
class InMemoryNetworkSession extends NetworkSession {
  InMemoryNetworkSession({this.token, Map<String, String>? headers})
      : headers = headers ?? {};

  String? token;
  final Map<String, String> headers;

  @override
  String? get accessToken => token;

  @override
  Map<String, String> get sessionHeaders => headers;

  bool get isAuthenticated => token != null;

  void clear() {
    token = null;
    headers.clear();
  }
}
