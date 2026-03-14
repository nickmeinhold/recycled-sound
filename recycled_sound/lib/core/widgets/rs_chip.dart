import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Status chip with five semantic variants.
enum RsChipVariant { success, warning, error, info, neutral }

class RsChip extends StatelessWidget {
  const RsChip({
    super.key,
    required this.label,
    this.variant = RsChipVariant.neutral,
  });

  final String label;
  final RsChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      RsChipVariant.success => (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
        ),
      RsChipVariant.warning => (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
        ),
      RsChipVariant.error => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        ),
      RsChipVariant.info => (AppColors.infoBg, AppColors.infoText),
      RsChipVariant.neutral => (
          AppColors.border.withValues(alpha: 0.3),
          AppColors.textMuted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: AppTypography.chip.copyWith(color: fg)),
    );
  }
}
