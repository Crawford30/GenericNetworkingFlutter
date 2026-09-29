import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Online/offline stream — the Flutter take on `useNetworkListener`.
///
/// Note: reports whether a network interface is up, not whether the internet
/// is actually reachable.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  Future<bool> get isOnline async => _isOnline(await _connectivity.checkConnectivity());

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
