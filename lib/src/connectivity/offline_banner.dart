import 'dart:async';

import 'package:flutter/material.dart';

import 'connectivity_service.dart';

/// Wrap your app (e.g. in `MaterialApp.builder`) to show a banner while
/// offline — the Flutter take on the RN `BackgroundTasks` snack indicator.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    required this.child,
    this.message = 'You are offline',
    this.service,
    this.backgroundColor,
    this.textStyle,
  });

  final Widget child;
  final String message;
  final ConnectivityService? service;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityService _service = widget.service ?? ConnectivityService();
  StreamSubscription<bool>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _service.isOnline.then(_update);
    _subscription = _service.onStatusChange.listen(_update);
  }

  void _update(bool online) {
    if (mounted && _offline == online) setState(() => _offline = !online);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _offline
              ? Material(
                  color: widget.backgroundColor ?? theme.colorScheme.inverseSurface,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, size: 18, color: theme.colorScheme.onInverseSurface),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: widget.textStyle ??
                                  theme.textTheme.bodyMedium
                                      ?.copyWith(color: theme.colorScheme.onInverseSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
