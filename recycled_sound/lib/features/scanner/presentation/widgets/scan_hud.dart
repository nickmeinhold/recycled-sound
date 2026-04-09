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
    this.detectedColour,
    this.detectedColourRgb,
    this.colourConfidence = 0.0,
    this.colourConfirmed = false,
    this.onColourTap,
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

  /// Detected colour name from the stabiliser, e.g. "Champagne".
  final String? detectedColour;

  /// The palette reference colour for the swatch.
  final Color? detectedColourRgb;

  /// Colour detection confidence 0.0–1.0 (fills over ~8 frames).
  final double colourConfidence;

  /// Whether the colour has reached consensus or been manually confirmed.
  final bool colourConfirmed;

  /// Called when the user taps the colour row to open the picker.
  final VoidCallback? onColourTap;

  bool get _hasDetections =>
      detectedBrand != null || detectedModel != null || detectedColour != null;
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
            if (detectedColour != null) ...[
              const SizedBox(height: 4),
              _ColourRow(
                colour: detectedColour!,
                colourRgb: detectedColourRgb,
                confidence: colourConfidence,
                confirmed: colourConfirmed,
                onTap: onColourTap,
              ),
            ],
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

/// Colour detection row with swatch and tap-to-confirm interaction.
class _ColourRow extends StatelessWidget {
  const _ColourRow({
    required this.colour,
    required this.colourRgb,
    required this.confidence,
    required this.confirmed,
    this.onTap,
  });

  final String colour;
  final Color? colourRgb;
  final double confidence;
  final bool confirmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: confirmed ? onTap : null, // Only tappable once confirmed (to correct)
      child: Row(
        children: [
          // Status: filling circle while building confidence, checkmark when done
          if (confirmed)
            const Icon(Icons.check_circle, size: 16, color: AppColors.success)
          else
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: confidence,
                strokeWidth: 2,
                color: AppColors.success,
                backgroundColor: const Color(0x33FFFFFF),
              ),
            ),
          const SizedBox(width: 8),
          // Field label
          const SizedBox(
            width: 52,
            child: Text(
              'COLOUR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0x99FFFFFF),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Colour swatch — opacity grows with confidence
          if (colourRgb != null) ...[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colourRgb!.withValues(alpha: 0.4 + 0.6 * confidence),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: const Color(0x55FFFFFF),
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Colour name — opacity grows with confidence
          Expanded(
            child: Text(
              colour,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: confirmed ? FontWeight.w600 : FontWeight.w400,
                color: confirmed
                    ? AppColors.success
                    : AppColors.success.withValues(
                        alpha: 0.3 + 0.7 * confidence),
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Edit badge — only after confirmed
          if (confirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: const Color(0x33FFFFFF),
              ),
              child: const Text(
                'EDIT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99FFFFFF),
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
