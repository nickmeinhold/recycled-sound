import 'package:flutter/material.dart';

/// Recycled Sound 15-color palette, derived from the design system wireframes.
///
/// The palette centers on a teal-green primary that evokes sustainability and
/// hearing health, with an orange accent for calls to action.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF2A7D5F);
  static const primaryLight = Color(0xFFE8F5EE);
  static const accent = Color(0xFFE67E22);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const background = Color(0xFFF5F5F0);
  static const surface = Color(0xFFF9FAFB);
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFD1D5DB);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // ── Info / Legal ───────────────────────────────────────────────────────
  static const infoBg = Color(0xFFDBEAFE);
  static const infoText = Color(0xFF1E40AF);
  static const legalBg = Color(0xFFFFFBEB);
}
