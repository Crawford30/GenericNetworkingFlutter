/// The class (or group) a status code belongs to, grouped by first digit.
enum StatusCategory {
  informational,
  success,
  redirection,
  clientError,
  serverError,
  undefined;

  static StatusCategory of(int? code) {
    if (code == null) return undefined;
    if (code >= 100 && code < 200) return informational;
    if (code >= 200 && code < 300) return success;
    if (code >= 300 && code < 400) return redirection;
    if (code >= 400 && code < 500) return clientError;
    if (code >= 500 && code < 600) return serverError;
    return undefined;
  }
}

/// Commonly used status codes.
abstract final class HttpStatus {
  static const ok = 200;
  static const created = 201;
  static const accepted = 202;
  static const noContent = 204;
  static const resetContent = 205;
  static const badRequest = 400;
  static const unauthorized = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const conflict = 409;
  static const unprocessableEntity = 422;
  static const tooManyRequests = 429;
  static const internalServerError = 500;
  static const badGateway = 502;
  static const serviceUnavailable = 503;
  static const gatewayTimeout = 504;

  /// Codes that never carry a response body.
  static const emptyResponseCodes = {noContent, resetContent};
}
