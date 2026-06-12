import 'package:flutter/material.dart';

/// TStore design tokens (DMX-inspired blue + yellow accent).
class AppColors {
  // Primary — interactive blue (chips, tabs, links)
  static const Color primary = Color(0xFF288AD6);
  static const Color primaryDark = Color(0xFF0D2B57); // Navy CTA (Xác nhận)
  static const Color primaryTint = Color(0xFFE8F4FC);
  static const Color secondary = Color(0xFF1A6BB5);
  static const Color accent = Color(0xFFFFC107); // Tab / bottom-nav indicator

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A6BB5), primary],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D4A8C), Color(0xFF288AD6)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTint, Color(0xFFF0F9FF)],
  );

  // Neutral
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);
  static const Color outline = Color(0xFFCBD5E1);
  static const Color chipBorder = Color(0xFFE2E8F0);

  // Text
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1E293B);
  static const Color onSurfaceVariant = Color(0xFF64748B);

  // Status (business semantics)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color points = Color(0xFFFFC107);
  static const Color premium = Color(0xFFD946EF);

  /// DMX-style soft card shadow (0,4,16 @ 6% black).
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = softShadow;

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
