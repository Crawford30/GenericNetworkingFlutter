/// Static, app-wide networking configuration.
class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    this.applicationVersion,
    this.applicationPlatform,
    this.originCountryCode,
    this.additionalHeaders = const {},
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 60),
    this.sendTimeout = const Duration(seconds: 60),
    this.enableLogging = true,
  });

  /// Root URL prepended to relative endpoints, e.g. `https://api.example.com/v1`.
  final String baseUrl;

  final String? applicationVersion;
  final String? applicationPlatform;
  final String? originCountryCode;

  /// Headers attached to every non-external request.
  final Map<String, String> additionalHeaders;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Logs requests/responses in debug builds only.
  final bool enableLogging;
}
