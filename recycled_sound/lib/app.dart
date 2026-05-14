import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget — configures theming, routing, and global providers.
///
/// [router] override is intended for widget tests that want to skip the
/// `/boot` diagnostic splash and land directly on Home.
class RecycledSoundApp extends StatelessWidget {
  const RecycledSoundApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Recycled Sound',
      theme: AppTheme.light,
      routerConfig: router ?? appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
