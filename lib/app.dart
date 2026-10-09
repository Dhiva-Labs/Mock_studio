import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';
import 'ui/widgets/logo.dart';
import 'ui/widgets/responsive.dart';

class MockStudioApp extends StatelessWidget {
  const MockStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Select only what the root needs so log traffic doesn't rebuild it.
    final themeMode = context.select<AppState, ThemeMode>((a) => a.themeMode);
    final themeId = context.select<AppState, AppThemeId>((a) => a.themeId);
    final isLoaded = context.select<AppState, bool>((a) => a.isLoaded);
    final graphite = themeId == AppThemeId.graphite;
    return MaterialApp(
      title: 'Mock Studio',
      debugShowCheckedModeBanner: false,
      theme: graphite ? AppTheme.graphite() : AppTheme.light(),
      darkTheme: graphite ? AppTheme.graphite() : AppTheme.dark(),
      // Graphite is dark only.
      themeMode: graphite ? ThemeMode.dark : themeMode,
      // Switch themes in one frame. A cross-fade would flip the method and
      // status colours (which follow brightness) halfway through while every
      // other colour is still blending, and rebuild the whole tree for each
      // animation frame.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        final theme = Theme.of(context);
        // Always wrapped in a Theme so crossing the phone breakpoint keeps
        // the tree shape (and the navigator's state) intact.
        return Theme(
          data: isPhone(context) ? phoneTheme(theme) : theme,
          child: _PaletteScope(
            dark: theme.brightness == Brightness.dark,
            child: child!,
          ),
        );
      },
      home: isLoaded ? const HomeShell() : const _SplashScreen(),
    );
  }
}

/// Keeps [AppTheme.isDark] in sync with the resolved theme and rebuilds the
/// whole tree when it flips, so method/status colours (which read the flag
/// rather than the inherited theme) update everywhere without losing state.
class _PaletteScope extends StatefulWidget {
  const _PaletteScope({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  State<_PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<_PaletteScope> {
  @override
  void initState() {
    super.initState();
    AppTheme.isDark = widget.dark;
  }

  @override
  void didUpdateWidget(_PaletteScope old) {
    super.didUpdateWidget(old);
    if (old.dark == widget.dark) return;
    AppTheme.isDark = widget.dark;
    // Rebuild everything below in this same frame (the subtree is being
    // built right now, so marking descendants dirty is allowed). Doing it a
    // frame later showed one frame of old method/status colours on widgets
    // that don't depend on the theme.
    void walk(Element e) {
      e.markNeedsBuild();
      e.visitChildren(walk);
    }

    (context as Element).visitChildren(walk);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoMark(size: 72),
            const SizedBox(height: 20),
            Text(
              'Mock Studio',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'by dhiva labs',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
