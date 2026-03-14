import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/scanner/presentation/camera_screen.dart';
import '../../features/scanner/presentation/analysing_screen.dart';
import '../../features/scanner/presentation/results_screen.dart';
import '../../features/devices/presentation/device_list_screen.dart';
import '../../features/devices/presentation/device_detail_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide router using go_router with a ShellRoute for bottom tab navigation.
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // ── Shell route for bottom tabs ────────────────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/devices',
          builder: (context, state) => const DeviceListScreen(),
        ),
      ],
    ),

    // ── Full-screen routes (no bottom tabs) ────────────────────────────
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/scan/analysing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final imagePath = state.extra as String? ?? '';
        return AnalysingScreen(imagePath: imagePath);
      },
    ),
    GoRoute(
      path: '/scan/results',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final scanId = state.extra as String? ?? '';
        return ResultsScreen(scanId: scanId);
      },
    ),
    GoRoute(
      path: '/devices/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DeviceDetailScreen(deviceId: id);
      },
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignupScreen(),
    ),
  ],
);

/// Scaffold wrapper that provides the persistent bottom navigation bar.
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/devices')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          selectedLabelStyle: AppTypography.nav,
          unselectedLabelStyle: AppTypography.nav,
          onTap: (i) {
            switch (i) {
              case 0:
                context.go('/');
              case 1:
                context.go('/devices');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.devices_outlined), activeIcon: Icon(Icons.devices), label: 'Devices'),
          ],
        ),
      ),
    );
  }
}
