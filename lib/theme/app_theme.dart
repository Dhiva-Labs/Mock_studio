import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Mock Studio visual theme. A calm indigo/teal system with strong, consistent
/// colour coding for HTTP methods and status codes so both experts and
/// newcomers can scan the UI at a glance.
class AppTheme {
  static const seed = Color(0xFF5B54E8); // indigo-violet
  static const _radius = 12.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
    );
  }

  static const String mono = 'monospace';

  /// A distinct, consistent colour for each HTTP method.
  static Color methodColor(HttpMethodType m) {
    switch (m) {
      case HttpMethodType.get:
        return const Color(0xFF16A34A); // green
      case HttpMethodType.post:
        return const Color(0xFF2563EB); // blue
      case HttpMethodType.put:
        return const Color(0xFFD97706); // amber
      case HttpMethodType.patch:
        return const Color(0xFF7C3AED); // violet
      case HttpMethodType.delete:
        return const Color(0xFFDC2626); // red
      case HttpMethodType.head:
        return const Color(0xFF0891B2); // cyan
      case HttpMethodType.options:
        return const Color(0xFF64748B); // slate
      case HttpMethodType.any:
        return const Color(0xFF6B7280); // gray
    }
  }

  static Color methodColorFromString(String method) {
    return methodColor(HttpMethodTypeX.fromString(method.toLowerCase()));
  }

  /// Colour for an HTTP status code family.
  static Color statusColor(int code) {
    if (code == 0) return const Color(0xFF991B1B); // reset/aborted
    if (code < 200) return const Color(0xFF64748B);
    if (code < 300) return const Color(0xFF16A34A);
    if (code < 400) return const Color(0xFF0891B2);
    if (code < 500) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
}
