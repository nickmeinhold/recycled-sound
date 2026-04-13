import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale matching the Recycled Sound design system.
///
/// Uses Inter via Google Fonts — a highly-legible sans-serif that renders well
/// at all sizes, important for an accessibility-focused app.
abstract final class AppTypography {
  static TextStyle get _base => GoogleFonts.inter(color: AppColors.text);

  // ── Headings ───────────────────────────────────────────────────────────
  static TextStyle get h1 =>
      _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get h2 =>
      _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static TextStyle get h3 =>
      _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get h4 =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);

  // ── Body ───────────────────────────────────────────────────────────────
  static TextStyle get body =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  // ── UI elements ────────────────────────────────────────────────────────
  static TextStyle get caption => _base.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.4);
  static TextStyle get label =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get chip =>
      _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get button =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get nav =>
      _base.copyWith(fontSize: 9, fontWeight: FontWeight.w500, height: 1.2);

  // ── Scanner / T2 HUD monospace ──────────────────────────────────────
  // Used by the live scanner HUD and confirmation screen for the
  // technical readout aesthetic.

  static const _monoBase = TextStyle(fontFamily: 'monospace');

  /// HUD field label (e.g. "MAKE", "COLOUR").
  static TextStyle get monoLabel => _monoBase.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF888888),
      letterSpacing: 1.0);

  /// HUD field value — detected.
  static TextStyle get monoValue => _monoBase.copyWith(
      fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3);

  /// HUD field value — large (confirmation screen).
  static TextStyle get monoValueLarge => _monoBase.copyWith(
      fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3);

  /// HUD small text (cross-ref flash, badges).
  static TextStyle get monoSmall => _monoBase.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5);

  /// HUD micro text (swatch labels, brand palette badge).
  static TextStyle get monoMicro => _monoBase.copyWith(
      fontSize: 8,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8);

  /// HUD status text (counter, button labels).
  static TextStyle get monoStatus => _monoBase.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2);

  /// HUD button/action text.
  static TextStyle get monoButton => _monoBase.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500);
}
