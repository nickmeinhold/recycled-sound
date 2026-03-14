import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Analysing screen (Screen 1C) — animated progress while "processing".
///
/// In the MVP, this simulates processing with a timer. Once the Cloud Function
/// is wired up, it will wait for the actual response.
class AnalysingScreen extends StatefulWidget {
  const AnalysingScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<AnalysingScreen> createState() => _AnalysingScreenState();
}

class _AnalysingScreenState extends State<AnalysingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _stepIndex = 0;

  static const _steps = [
    'Uploading image…',
    'Detecting hearing aid…',
    'Identifying brand & model…',
    'Matching specifications…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _advanceSteps();
  }

  Future<void> _advanceSteps() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _stepIndex = i);
    }
    // Simulated delay before navigating to results
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      context.pushReplacement('/scan/results', extra: 'mock-001');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rotating scan icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.rotate(
                    angle: _controller.value * 6.28,
                    child: child,
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.center_focus_strong,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Analysing…', style: AppTypography.h2),
                const SizedBox(height: 24),

                // Step indicators
                ...List.generate(_steps.length, (i) {
                  final isComplete = i < _stepIndex;
                  final isCurrent = i == _stepIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isComplete
                              ? Icons.check_circle
                              : isCurrent
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                          size: 20,
                          color: isComplete || isCurrent
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _steps[i],
                          style: AppTypography.body.copyWith(
                            color: isComplete || isCurrent
                                ? AppColors.text
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
