/// Implement on request models so the [RequestSerializer] can encode them.
///
/// Works with hand-written models and with `json_serializable`/`freezed`
/// generated `toJson()` methods.
abstract interface class JsonSerializable {
  Object? toJson();
}

typedef FromJson<T> = T Function(Map<String, dynamic> json);
