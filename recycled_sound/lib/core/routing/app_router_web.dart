import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/devices/presentation/device_detail_screen.dart';
import '../../features/devices/presentation/device_list_screen.dart';

/// Web-target router.
///
/// Deliberately excludes scanner routes — the scanner pipeline depends on
/// tflite_flutter (dart:ffi) and ML Kit (camera), neither of which compile
/// on the web target. The web app is admin-shaped: review the register,
/// manage matching, surface the impact dashboard. Scanner is mobile-only.
final webRouter = GoRouter(
  initialLocation: '/devices',
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, _) => '/devices',
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const _WebShell(child: DeviceListScreen()),
    ),
    GoRoute(
      path: '/devices/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return _WebShell(child: DeviceDetailScreen(deviceId: id));
      },
    ),
  ],
);

/// Minimal admin shell — sidebar nav goes here in PR D. For PR C the
/// device list IS the entire admin experience, so the shell is just a
/// branded app bar.
class _WebShell extends StatelessWidget {
  const _WebShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
    );
  }
}
