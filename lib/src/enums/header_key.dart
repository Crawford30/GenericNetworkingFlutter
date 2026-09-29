/// Well-known header names. App specific headers go in
/// [NetworkConfig.additionalHeaders] or [NetworkSession.sessionHeaders].
abstract final class HeaderKey {
  static const contentType = 'Content-Type';
  static const authorization = 'Authorization';
  static const accept = 'Accept';
  static const setCookie = 'Set-Cookie';
  static const applicationVersion = 'X-Platform-Version';
  static const applicationPlatform = 'X-Platform';
  static const originCountryCode = 'X-Origin-Country';
}
