import 'dart:convert';

import 'json_serializable.dart';

/// Turns a decoded response body (Map/List/String/null) into [T].
///
/// ```dart
/// Deserializer.object(User.fromJson)       // {...}      -> User
/// Deserializer.list(User.fromJson)         // [{...}]    -> List<User>
/// Deserializer.paginated('results', User.fromJson) // {results: [...]} -> List<User>
/// Deserializer.noBody                      // ignores body -> void
/// Deserializer.raw                         // untouched dynamic
/// ```
class Deserializer<T> {
  const Deserializer(this._convert);

  final T Function(Object? data) _convert;

  T deserialize(Object? data) => _convert(_normalise(data));

  static Deserializer<T> object<T>(FromJson<T> fromJson) =>
      Deserializer<T>((data) => fromJson(_asMap(data)));

  static Deserializer<List<T>> list<T>(FromJson<T> fromJson) =>
      Deserializer<List<T>>(
        (data) => _asList(data).map((e) => fromJson(_asMap(e))).toList(),
      );

  /// List nested under [key], e.g. Django REST `{"count": 2, "results": [...]}`.
  static Deserializer<List<T>> paginated<T>(String key, FromJson<T> fromJson) =>
      Deserializer<List<T>>(
        (data) => _asList(_asMap(data)[key]).map((e) => fromJson(_asMap(e))).toList(),
      );

  static final Deserializer<void> noBody = Deserializer<void>((_) {});

  static final Deserializer<dynamic> raw = Deserializer<dynamic>((data) => data);

  static final Deserializer<Map<String, dynamic>> map =
      Deserializer<Map<String, dynamic>>(_asMap);

  static final Deserializer<String> string =
      Deserializer<String>((data) => data is String ? data : jsonEncode(data));

  /// Bodies may arrive as a JSON string when the server sends a wrong
  /// Content-Type; decode those so model factories always get Map/List.
  static Object? _normalise(Object? data) {
    if (data is String && data.isNotEmpty) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(data);
        } on FormatException {
          return data;
        }
      }
    }
    return data;
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    throw FormatException('Expected a JSON object but got ${data.runtimeType}');
  }

  static List<Object?> _asList(Object? data) {
    if (data is List) return data;
    throw FormatException('Expected a JSON array but got ${data.runtimeType}');
  }
}
