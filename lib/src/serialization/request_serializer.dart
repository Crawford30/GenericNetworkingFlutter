import 'dart:convert';

import 'json_serializable.dart';

/// Converts request bodies into JSON-safe values.
///
/// Handles [JsonSerializable], objects exposing a `toJson()` method,
/// [DateTime] (ISO-8601, like the Swift encoder), enums (by name), and nested
/// maps/lists of those.
class RequestSerializer {
  const RequestSerializer();

  Object? serialize(Object? body) {
    if (body == null || body is String || body is num || body is bool) {
      return body;
    }
    if (body is JsonSerializable) return serialize(body.toJson());
    if (body is DateTime) return body.toUtc().toIso8601String();
    if (body is Enum) return body.name;
    if (body is Map) {
      return body.map((k, v) => MapEntry(k.toString(), serialize(v)));
    }
    if (body is Iterable) return body.map(serialize).toList();
    try {
      // ignore: avoid_dynamic_calls
      return serialize((body as dynamic).toJson());
    } on NoSuchMethodError {
      throw ArgumentError(
        '${body.runtimeType} cannot be serialized. '
        'Implement JsonSerializable or add a toJson() method.',
      );
    }
  }

  String encode(Object? body) => jsonEncode(serialize(body));
}
