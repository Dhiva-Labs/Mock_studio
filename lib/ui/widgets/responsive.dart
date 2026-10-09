import 'package:flutter/material.dart';

/// Window widths where the layout changes.
abstract final class Breakpoints {
  /// Below this the app uses the phone shell: a bottom navigation bar and
  /// full-screen pages instead of the rail and side panel.
  static const double phone = 600;

  /// Below this (and above [phone]) the side panel floats over the content.
  static const double floatingPanel = 900;
}

/// Whether the window is phone-sized.
bool isPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.phone;

/// Theme tweaks for phone-sized windows, so touch targets and dialogs behave
/// the same on a narrow desktop window as on a real phone.
ThemeData phoneTheme(ThemeData base) => base.copyWith(
  visualDensity: VisualDensity.standard,
  materialTapTargetSize: MaterialTapTargetSize.padded,
  dialogTheme: base.dialogTheme.copyWith(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
  ),
);

/// Two widgets side by side when there is room, otherwise stacked.
class AdaptivePair extends StatelessWidget {
  const AdaptivePair({
    super.key,
    required this.first,
    required this.second,
    this.minWidth = 420,
    this.spacing = 12,
    this.firstFlex = 1,
    this.secondFlex = 1,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget first;
  final Widget second;

  /// Narrower than this, [second] goes under [first].
  final double minWidth;
  final double spacing;
  final int firstFlex;
  final int secondFlex;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth >= minWidth
        ? Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(flex: firstFlex, child: first),
              SizedBox(width: spacing),
              Expanded(flex: secondFlex, child: second),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, SizedBox(height: spacing), second],
          ),
  );
}
