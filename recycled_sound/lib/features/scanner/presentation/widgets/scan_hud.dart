import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Bottom HUD panel for the live scanner.
///
/// Shows detected features with confidence labels, cross-reference
/// status, and contextual guidance. Visual treatment: frosted dark
/// panel with monospace readout.
class ScanHud extends StatelessWidget {
  const ScanHud({
    super.key,
    required this.detectedBrand,
    required this.detectedModel,
    required this.brandConfidence,
    required this.crossRefText,
    required this.showHint,
    required this.onReview,
    required this.onFallback,
  });

  final String? detectedBrand;
  final String? detectedModel;

  /// Confidence label for brand match: "EXACT" or "FUZZY ≤1".
  final String? brandConfidence;

  /// Transient cross-reference text, e.g. "23 OTICON DEVICES IN DATABASE".
  final String? crossRefText;

  final bool showHint;
  final VoidCallback onReview;
  final VoidCallback onFallback;

  bool get _hasDetections => detectedBrand != null || detectedModel != null;
  bool get _isComplete => detectedBrand != null && detectedModel != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xDD000000)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cross-reference flash
          if (crossRefText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                crossRefText!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0x88FFFFFF),
                  letterSpacing: 1.0,
                ),
              ),
            ),

          // Detection readout
          if (_hasDetections) ...[
            _FeatureRow(
              field: 'MAKE',
              value: detectedBrand,
              detected: detectedBrand != null,
              confidence: brandConfidence,
            ),
            const SizedBox(height: 4),
            _FeatureRow(
              field: 'MODEL',
              value: detectedModel,
              detected: detectedModel != null,
            ),
            const SizedBox(height: 12),
          ],

          // Instruction / hint
          if (!_hasDetections && !showHint)
            Text(
              'Slowly rotate the hearing aid',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),

          if (!_hasDetections && showHint) ...[
            Text(
              'Try holding closer',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onFallback,
              child: Text(
                'Or take a photo instead',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],

          if (_hasDetections && !_isComplete)
            Text(
              'Keep rotating for model',
              style: AppTypography.caption.copyWith(
                color: AppColors.white.withValues(alpha: 0.5),
              ),
            ),

          // Review button
          if (_isComplete) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Review Results'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single feature row in the HUD readout.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.field,
    required this.value,
    required this.detected,
    this.confidence,
  });

  final String field;
  final String? value;
  final bool detected;

  /// Optional confidence label, e.g. "EXACT" or "FUZZY ≤1".
  final String? confidence;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          detected ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: detected
              ? AppColors.success
              : AppColors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            field,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0x99FFFFFF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value ?? '- - -',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: detected ? FontWeight.w600 : FontWeight.w400,
              color: detected ? AppColors.success : const Color(0x44FFFFFF),
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Confidence badge
        if (detected && confidence != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: const Color(0x33FFFFFF),
            ),
            child: Text(
              confidence!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0x99FFFFFF),
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
