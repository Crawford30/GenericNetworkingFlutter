import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' show Dio, ResponseBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_networking/generic_networking.dart';

import 'fake_adapter.dart';

class User implements JsonSerializable {
  User({required this.id, required this.name, this.joined});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        joined: json['joined'] == null ? null : DateTime.parse(json['joined'] as String),
      );

  final int id;
  final String name;
  final DateTime? joined;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'joined': joined};
}

class ErrorBody {
  ErrorBody(this.code);
  factory ErrorBody.fromJson(Map<String, dynamic> json) => ErrorBody(json['code'] as String);
  final String code;
}

void main() {
  late FakeAdapter adapter;
  late InMemoryNetworkSession session;
  late DioNetworkingClient client;
  late int unauthorizedCalls;

  setUp(() {
    adapter = FakeAdapter((_) => jsonBody({'id': 1, 'name': 'Ada'}));
    session = InMemoryNetworkSession(token: 'abc', headers: {'X-Customer-Id': '42'});
    unauthorizedCalls = 0;
    client = DioNetworkingClient(
      config: const NetworkConfig(
        baseUrl: 'https://api.test/v1/',
        applicationPlatform: 'android',
        applicationVersion: '1.2.3',
        additionalHeaders: {'X-Api-Key': 'key'},
        enableLogging: false,
      ),
      session: session,
      unauthorizedHandler: CallbackUnauthorizedHandler((_) => unauthorizedCalls++),
      dio: Dio()..httpClientAdapter = adapter,
    );
  });

  group('serialization', () {
    test('deserializes object and list responses', () async {
      final user = await client.get('users/1', Deserializer.object(User.fromJson));
      expect(user.name, 'Ada');

      adapter.responder = (_) => jsonBody([
            {'id': 1, 'name': 'Ada'},
            {'id': 2, 'name': 'Linus'},
          ]);
      final users = await client.get('users', Deserializer.list(User.fromJson));
      expect(users.map((u) => u.name), ['Ada', 'Linus']);
    });

    test('deserializes paginated responses', () async {
      adapter.responder = (_) => jsonBody({
            'count': 1,
            'results': [
              {'id': 3, 'name': 'Grace'}
            ],
          });
      final users = await client.get('users', Deserializer.paginated('results', User.fromJson));
      expect(users.single.name, 'Grace');
    });

    test('serializes JsonSerializable body with ISO dates', () async {
      await client.post(
        'users',
        Deserializer.object(User.fromJson),
        body: User(id: 9, name: 'New', joined: DateTime.utc(2026, 1, 2)),
      );
      expect(jsonDecode(adapter.bodies.last), {
        'id': 9,
        'name': 'New',
        'joined': '2026-01-02T00:00:00.000Z',
      });
    });

    test('wrong shape raises a serialization error', () async {
      adapter.responder = (_) => jsonBody([1, 2]);
      expect(
        () => client.get('users/1', Deserializer.object(User.fromJson)),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', NetworkErrorType.serialization)),
      );
    });

    test('204 with noBody deserializer succeeds', () async {
      adapter.responder = (_) => jsonBody(null, status: 204);
      await client.delete('users/1');
      expect(adapter.last.method, 'DELETE');
    });
  });

  group('headers and session', () {
    test('adds config, session and bearer headers', () async {
      await client.get('users/1', Deserializer.raw, headers: {'X-Custom': 'yes'});
      final h = adapter.last.headers;
      expect(adapter.last.uri.toString(), 'https://api.test/v1/users/1');
      expect(h['Authorization'], 'Bearer abc');
      expect(h['X-Customer-Id'], '42');
      expect(h['X-Platform'], 'android');
      expect(h['X-Platform-Version'], '1.2.3');
      expect(h['X-Api-Key'], 'key');
      expect(h['X-Custom'], 'yes');
    });

    test('external requests skip auth and config headers', () async {
      await client.get('https://other.test/x', Deserializer.raw, isExternal: true);
      expect(adapter.last.uri.host, 'other.test');
      expect(adapter.last.headers.containsKey('Authorization'), isFalse);
      expect(adapter.last.headers.containsKey('X-Api-Key'), isFalse);
    });

    test('drops null query parameters', () async {
      await client.get('users', Deserializer.raw, queryParameters: {'page': 2, 'q': null});
      expect(adapter.last.uri.queryParameters, {'page': '2'});
    });
  });

  group('errors', () {
    test('401 calls unauthorized handler', () async {
      adapter.responder = (_) => jsonBody({'detail': 'Token expired'}, status: 401);
      await expectLater(
        client.get('me', Deserializer.raw),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', NetworkErrorType.unauthorized)
            .having((e) => e.message, 'message', 'Token expired')),
      );
      expect(unauthorizedCalls, 1);
    });

    test('401 on external request does not log out', () async {
      adapter.responder = (_) => jsonBody({}, status: 401);
      await expectLater(
        client.get('https://other.test', Deserializer.raw, isExternal: true),
        throwsA(isA<ApiException>()),
      );
      expect(unauthorizedCalls, 0);
    });

    test('500 uses friendly message', () async {
      adapter.responder = (_) => jsonBody({'trace': '...'}, status: 500);
      await expectLater(
        client.get('x', Deserializer.raw),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', ApiException.serverErrorMessage)),
      );
    });

    test('400 exposes field errors and typed error body', () async {
      adapter.responder = (_) => jsonBody({
            'code': 'invalid',
            'email': ['Enter a valid email.'],
          }, status: 400);
      try {
        await client.post('users', Deserializer.raw, body: {'email': 'x'});
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.type, NetworkErrorType.validation);
        expect(e.fieldErrors, {'email': 'Enter a valid email.', 'code': 'invalid'});
        expect(e.message, 'Enter a valid email.');
        expect(e.decodeData(ErrorBody.fromJson)?.code, 'invalid');
      }
    });

    test('ApiResult.guard wraps failures', () async {
      adapter.responder = (_) => jsonBody({'message': 'nope'}, status: 404);
      final result = await ApiResult.guard(() => client.get('x', Deserializer.raw));
      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.type, NetworkErrorType.notFound);
      expect(result.errorOrNull?.message, 'nope');
    });
  });

  group('upload / download', () {
    test('uploadDocument sends multipart with files and fields', () async {
      final progress = <int>[];
      await client.uploadDocument(
        'documents',
        Deserializer.raw,
        files: [
          UploadableFile.fromBytes(Uint8List.fromList([1, 2, 3]),
              fileName: 'id.pdf', fieldName: 'document'),
        ],
        fields: {'type': 'ID', 'tags': ['a', 'b']},
        onSendProgress: (sent, _) => progress.add(sent),
      );
      final body = adapter.bodies.last;
      expect(adapter.last.contentType, startsWith('multipart/form-data'));
      expect(body, contains('name="document"; filename="id.pdf"'));
      expect(body, contains('content-type: application/pdf'));
      expect(body, contains('name="type"'));
      expect('name="tags"'.allMatches(body).length, 2);
      expect(adapter.last.headers['Authorization'], 'Bearer abc');
      expect(progress, isNotEmpty);
    });

    test('downloadBytes returns raw bytes', () async {
      adapter.responder = (_) => ResponseBody.fromBytes([9, 8, 7], 200);
      final bytes = await client.downloadDocumentBytes('documents/1/file');
      expect(bytes, [9, 8, 7]);
    });

    test('download saves with Content-Disposition name and de-duplicates', () async {
      final dir = await Directory.systemTemp.createTemp('gn_test');
      addTearDown(() => dir.delete(recursive: true));
      adapter.responder = (_) => ResponseBody.fromBytes(
            [1, 2, 3],
            200,
            headers: {
              'content-disposition': ['attachment; filename="statement.pdf"'],
            },
          );
      final first = await client.downloadDocument('documents/1', saveDirectory: dir.path);
      final second = await client.downloadDocument('documents/1', saveDirectory: dir.path);
      expect(first.fileName, 'statement.pdf');
      expect(second.fileName, 'statement(1).pdf');
      expect(await File(second.path).readAsBytes(), [1, 2, 3]);
    });
  });

  group('controllers', () {
    test('FetchController tracks loading/data', () async {
      final c = FetchController(client, 'users/', Deserializer.object(User.fromJson));
      final future = c.fetch(id: 1);
      expect(c.loading, isTrue);
      await future;
      expect(c.loading, isFalse);
      expect(c.data?.name, 'Ada');
      expect(adapter.last.uri.path, '/v1/users/1/');
    });

    test('SubmitController posts without id, patches with id', () async {
      final c = SubmitController(client, Deserializer.object(User.fromJson));
      await c.submit(endpoint: 'users/', body: {'name': 'Ada'});
      expect(adapter.last.method, 'POST');
      await c.submit(endpoint: 'users/', id: 1, body: {'name': 'Ada'});
      expect(adapter.last.method, 'PATCH');
      expect(adapter.last.uri.path, '/v1/users/1/');
      expect(c.success, isTrue);
    });

    test('SubmitController exposes and edits field errors', () async {
      adapter.responder = (_) => jsonBody({'name': ['Required'], 'age': ['Too low']}, status: 400);
      final c = SubmitController(client, Deserializer.raw);
      await c.submit(endpoint: 'users/', body: {});
      expect(c.fieldErrors, {'name': 'Required', 'age': 'Too low'});
      c.updateErrors({'name': null});
      expect(c.fieldErrors, {'age': 'Too low'});
    });

    test('DeleteController deletes by id', () async {
      adapter.responder = (_) => jsonBody(null, status: 204);
      final c = DeleteController(client);
      final result = await c.delete(endpoint: 'users', id: 5);
      expect(result.isSuccess, isTrue);
      expect(adapter.last.uri.path, '/v1/users/5/');
    });
  });
}
