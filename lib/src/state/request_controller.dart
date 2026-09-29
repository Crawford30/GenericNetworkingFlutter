import 'package:flutter/foundation.dart';

import '../error/api_exception.dart';
import '../response/api_result.dart';

/// Loading/data/error state for one kind of request, as a [ChangeNotifier]
/// so it works with `ListenableBuilder`, Provider, Riverpod or plain setState.
class RequestController<T> extends ChangeNotifier {
  RequestController({T? initialData}) : _data = initialData;

  bool _loading = false;
  bool _success = false;
  T? _data;
  ApiException? _error;
  Map<String, String> _fieldErrors = {};
  bool _disposed = false;
  int _generation = 0;

  bool get loading => _loading;
  bool get success => _success;
  T? get data => _data;
  ApiException? get error => _error;
  bool get hasError => _error != null;

  /// Per-field validation messages from the last error, editable via
  /// [updateErrors] (e.g. clear a field's error once the user edits it).
  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  /// Runs [action], tracking state. With [background] the loader is not shown
  /// (silent refresh). Only the latest call updates state.
  @protected
  Future<ApiResult<T>> run(
    Future<T> Function() action, {
    bool background = false,
    void Function(T data)? onSuccess,
    void Function(ApiException error)? onError,
  }) async {
    final generation = ++_generation;
    _error = null;
    _fieldErrors = {};
    _success = false;
    if (!background) _loading = true;
    _notify();

    final result = await ApiResult.guard(action);
    if (_disposed || generation != _generation) return result;

    switch (result) {
      case Success(:final data):
        _data = data;
        _success = true;
        onSuccess?.call(data);
      case Failure(:final error):
        _error = error;
        _fieldErrors = Map.of(error.fieldErrors);
        onError?.call(error);
    }
    _loading = false;
    _notify();
    return result;
  }

  /// Merge field errors in; pass `null` to clear them all. A `null`-valued
  /// entry removes that single field.
  void updateErrors(Map<String, String?>? errors) {
    if (errors == null) {
      _fieldErrors = {};
    } else {
      for (final entry in errors.entries) {
        entry.value == null
            ? _fieldErrors.remove(entry.key)
            : _fieldErrors[entry.key] = entry.value!;
      }
    }
    _notify();
  }

  void clearError() {
    _error = null;
    _fieldErrors = {};
    _notify();
  }

  void reset() {
    _generation++;
    _loading = false;
    _success = false;
    _data = null;
    _error = null;
    _fieldErrors = {};
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// `'users/'` + `42` -> `'users/42/'` (Django style), or `'users/42'` when
/// [trailingSlash] is false.
String resolveEndpoint(String endpoint, Object? id, {bool trailingSlash = true}) {
  if (id == null) return endpoint;
  final base = endpoint.endsWith('/') ? endpoint : '$endpoint/';
  return trailingSlash ? '$base$id/' : '$base$id';
}
