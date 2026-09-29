import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Responder = ResponseBody Function(RequestOptions options);

/// In-memory adapter: records requests and answers from [responder].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responder);

  Responder responder;
  final List<RequestOptions> requests = [];
  final List<String> bodies = [];

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = await requestStream.expand((c) => c).toList();
      bodies.add(utf8.decode(bytes, allowMalformed: true));
    } else {
      bodies.add('');
    }
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, {int status = 200, Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?headers,
      },
    );
