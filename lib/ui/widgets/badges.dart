import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../theme/app_theme.dart';

/// A coloured pill showing an HTTP method.
class MethodBadge extends StatelessWidget {
  final HttpMethodType method;
  final double fontSize;
  final bool compact;
  const MethodBadge(
    this.method, {
    super.key,
    this.fontSize = 11,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.methodColor(method);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: 0.3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A coloured pill showing an HTTP method from a raw string (for logs).
class MethodBadgeString extends StatelessWidget {
  final String method;
  const MethodBadgeString(this.method, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.methodColorFromString(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// A coloured pill showing an HTTP status code.
class StatusBadge extends StatelessWidget {
  final int code;
  const StatusBadge(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(code);
    final label = code == 0 ? 'RST' : code.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A small status dot (running / stopped).
class RunningDot extends StatelessWidget {
  final bool running;
  const RunningDot(this.running, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = running
        ? const Color(0xFF16A34A)
        : Theme.of(context).colorScheme.outline;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: running
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
