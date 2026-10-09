import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Colour theme family. Teal has light and dark variants; Graphite is dark
/// only. Shared with ApiWorkbench so the two apps look like one family.
enum AppThemeId { teal, graphite }

extension AppThemeIdX on AppThemeId {
  String get label => switch (this) {
    AppThemeId.teal => 'Teal',
    AppThemeId.graphite => 'Graphite and orange',
  };

  static AppThemeId fromString(String? s) =>
      AppThemeId.values.asNameMap()[s] ?? AppThemeId.teal;
}

/// One complete colour set.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.containers,
    required this.border,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.text,
    required this.textDim,
    required this.tertiary,
    required this.danger,
    required this.dangerSoft,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;

  /// surfaceContainerLowest → highest.
  final List<Color> containers;
  final Color border;
  final Color outline;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color text;
  final Color textDim;
  final Color tertiary;
  final Color danger;
  final Color dangerSoft;
}

const _tealLight = _Palette(
  brightness: Brightness.light,
  bg: Color(0xFFF6F7F9),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF1F3F6),
  containers: [
    Color(0xFFFFFFFF),
    Color(0xFFF6F7F9),
    Color(0xFFF1F3F6),
    Color(0xFFECEFF3),
    Color(0xFFE6E9EE),
  ],
  border: Color(0xFFE1E5EB),
  outline: Color(0xFF98A2B3),
  accent: Color(0xFF0E8C8C),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFE2F3F3),
  text: Color(0xFF1F2430),
  textDim: Color(0xFF667085),
  tertiary: Color(0xFF2F7BD9),
  danger: Color(0xFFD64545),
  dangerSoft: Color(0xFFFDECEC),
);

const _tealDark = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF12161C),
  surface: Color(0xFF1A2028),
  surfaceAlt: Color(0xFF222A34),
  containers: [
    Color(0xFF151A21),
    Color(0xFF1A2028),
    Color(0xFF1E252E),
    Color(0xFF222A34),
    Color(0xFF28313C),
  ],
  border: Color(0xFF2A323D),
  outline: Color(0xFF5A6675),
  accent: Color(0xFF3CC3C3),
  onAccent: Color(0xFF06282A),
  accentSoft: Color(0xFF173A3D),
  text: Color(0xFFE7ECF2),
  textDim: Color(0xFF8D99A8),
  tertiary: Color(0xFF5EA2F0),
  danger: Color(0xFFEF6A6A),
  dangerSoft: Color(0xFF3A1D20),
);

const _graphite = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF1B1B1D),
  surface: Color(0xFF232326),
  surfaceAlt: Color(0xFF2C2C30),
  containers: [
    Color(0xFF1F1F22),
    Color(0xFF232326),
    Color(0xFF28282B),
    Color(0xFF2C2C30),
    Color(0xFF333338),
  ],
  border: Color(0xFF36363B),
  outline: Color(0xFF6A6A72),
  accent: Color(0xFFFF7A30),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFF3A2A20),
  text: Color(0xFFEDEDED),
  textDim: Color(0xFF9A9AA2),
  tertiary: Color(0xFF4FA3F7),
  danger: Color(0xFFF2555A),
  dangerSoft: Color(0xFF3D2024),
);

/// Mock Studio visual theme, with strong, consistent colour coding for HTTP
/// methods and status codes so both experts and newcomers can scan the UI.
class AppTheme {
  static const _radius = 12.0;

  /// Set by the app root on every build; method/status colours pick their
  /// light or dark tone from it.
  static bool isDark = false;

  static ThemeData light() => _build(_tealLight);
  static ThemeData dark() => _build(_tealDark);
  static ThemeData graphite() => _build(_graphite);

  static ThemeData _build(_Palette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.text,
      secondary: p.accent,
      onSecondary: p.onAccent,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.text,
      tertiary: p.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: p.tertiary.withValues(alpha: 0.25),
      onTertiaryContainer: p.text,
      error: p.danger,
      onError: Colors.white,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.text,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textDim,
      surfaceContainerLowest: p.containers[0],
      surfaceContainerLow: p.containers[1],
      surfaceContainer: p.containers[2],
      surfaceContainerHigh: p.containers[3],
      surfaceContainerHighest: p.containers[4],
      outline: p.outline,
      outlineVariant: p.border,
      inverseSurface: p.text,
      onInverseSurface: p.surface,
      inversePrimary: p.accentSoft,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.surface,
      fontFamily: 'Roboto',
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: TextStyle(color: p.textDim),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(p.accent, 1.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accentSoft : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.text : p.textDim,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onAccent),
        side: BorderSide(color: p.textDim, width: 1.4),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: p.border),
        selectedColor: p.accentSoft,
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        selectedTileColor: p.accentSoft,
        selectedColor: p.text,
        iconColor: p.textDim,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.text,
        unselectedLabelColor: p.textDim,
        indicatorColor: p.accent,
        dividerColor: p.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: p.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.surface),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: p.brightness == Brightness.dark ? 0.45 : 0.12,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        textStyle: TextStyle(color: p.text, fontSize: 12.5, height: 1.4),
        waitDuration: const Duration(milliseconds: 350),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.textDim.withValues(alpha: 0.35)),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }

  static const String mono = 'monospace';

  static Color _tone(int light, int dark) => Color(isDark ? dark : light);

  /// Success / warning / danger tones that work on the current background.
  static Color get success => _tone(0xFF1E9E5A, 0xFF4CC38A);
  static Color get warning => _tone(0xFFB87A00, 0xFFE8B04B);
  static Color get danger => _tone(0xFFD64545, 0xFFEF6A6A);
  static Color get info => _tone(0xFF2F7BD9, 0xFF5EA2F0);
  static Color get violet => _tone(0xFF8A5CD6, 0xFFB48CF2);

  /// A distinct, consistent colour for each HTTP method (same scheme as
  /// ApiWorkbench and Postman: GET green, POST amber, PUT blue).
  static Color methodColor(HttpMethodType m) {
    switch (m) {
      case HttpMethodType.get:
        return success;
      case HttpMethodType.post:
        return warning;
      case HttpMethodType.put:
        return info;
      case HttpMethodType.patch:
        return violet;
      case HttpMethodType.delete:
        return danger;
      case HttpMethodType.head:
        return _tone(0xFF0F8FA3, 0xFF55C6D8);
      case HttpMethodType.options:
      case HttpMethodType.any:
        return _tone(0xFF667085, 0xFF8D99A8);
    }
  }

  static Color methodColorFromString(String method) {
    return methodColor(HttpMethodTypeX.fromString(method.toLowerCase()));
  }

  /// Colour for an HTTP status code family.
  static Color statusColor(int code) {
    if (code == 0) return danger; // reset/aborted
    if (code < 200) return _tone(0xFF667085, 0xFF8D99A8);
    if (code < 300) return success;
    if (code < 400) return info;
    if (code < 500) return warning;
    return danger;
  }
}
