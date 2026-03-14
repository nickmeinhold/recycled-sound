import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A label-value row used to display device specifications.
///
/// Optionally shows a confidence indicator and an edit action.
class RsSpecRow extends StatelessWidget {
  const RsSpecRow({
    super.key,
    required this.label,
    required this.value,
    this.confidence,
    this.onEdit,
  });

  final String label;
  final String value;

  /// Confidence percentage (0–100). Shows a colored dot when provided.
  final int? confidence;

  /// Called when the user taps the edit (pencil) icon.
  final VoidCallback? onEdit;

  Color _confidenceColor() {
    final c = confidence ?? 0;
    if (c >= 90) return AppColors.success;
    if (c >= 70) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 100,
            child: Text(label, style: AppTypography.caption),
          ),
          // Confidence dot
          if (confidence != null) ...[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _confidenceColor(),
                shape: BoxShape.circle,
              ),
            ),
          ],
          // Value
          Expanded(
            child: Text(value, style: AppTypography.body),
          ),
          // Edit button
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
