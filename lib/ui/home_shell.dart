import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/endpoint.dart';
import '../models/mock_project.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/postman_import_dialog.dart';
import 'editor/endpoint_editor.dart';
import 'flows/flows_view.dart';
import 'logs/logs_view.dart';
import 'phone_shell.dart';
import 'settings/project_settings_view.dart';
import 'share/share_view.dart';
import 'sidebar/endpoints_list.dart';
import 'sidebar/project_switcher.dart';
import 'sidebar/server_control_card.dart';
import 'widgets/help_tip.dart';
import 'widgets/helpers.dart';
import 'widgets/logo.dart';
import 'widgets/responsive.dart';

enum MainTab { editor, logs, flows, share, settings }

extension MainTabInfo on MainTab {
  String get label => switch (this) {
    MainTab.editor => 'Endpoints',
    MainTab.logs => 'Live requests',
    MainTab.flows => 'Flows',
    MainTab.share => 'Share and expose',
    MainTab.settings => 'Project settings',
  };

  String get railLabel => switch (this) {
    MainTab.editor => 'Endpoints',
    MainTab.logs => 'Live',
    MainTab.flows => 'Flows',
    MainTab.share => 'Share',
    MainTab.settings => 'Project',
  };

  String get help => switch (this) {
    MainTab.editor =>
      'Design the endpoints your mock server answers: the method, the path '
          'and the responses it sends back.',
    MainTab.logs =>
      'Every request that reaches the server, as it happens, with the '
          'response it got. Use it to see what your app is really calling.',
    MainTab.flows =>
      'Send scripted traffic to your mocks, step by step or many users at '
          'once, and measure speed and errors.',
    MainTab.share =>
      'Make the mock server reachable from phones on your Wi-Fi or from '
          'anywhere through a public link.',
    MainTab.settings =>
      'Project-wide options: port, proxy to a real API, default delay and '
          'headers added to every response.',
  };

  IconData get icon => switch (this) {
    MainTab.editor => Icons.api,
    MainTab.logs => Icons.receipt_long_outlined,
    MainTab.flows => Icons.account_tree_outlined,
    MainTab.share => Icons.wifi_tethering,
    MainTab.settings => Icons.tune,
  };
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _railWidth = 76.0;
  static const _handleWidth = 5.0;

  /// The main area keeps at least this much room next to the side panel.
  static const _minMainWidth = 480.0;

  MainTab _tab = MainTab.editor;
  bool _panelOpen = true;

  /// Dragging the divider only rebuilds the panel's [SizedBox], not the
  /// whole shell (the endpoint editor in particular).
  final _panelWidth = ValueNotifier<double>(300);

  @override
  void dispose() {
    _panelWidth.dispose();
    super.dispose();
  }

  void _select(MainTab t) => setState(() {
    if (t == _tab) {
      _panelOpen = !_panelOpen; // re-clicking the active item collapses
      return;
    }
    _tab = t;
    // Side by side the panel comes back with any section. When it floats
    // over the content (tablets), only Endpoints opens it: covering Live or
    // Share with the endpoint list on every switch got in the way.
    final floating =
        MediaQuery.sizeOf(context).width < Breakpoints.floatingPanel;
    _panelOpen = !floating || t == MainTab.editor;
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.phone) {
      return PhoneShell(
        tab: _tab,
        onTab: (t) => setState(() => _tab = t),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    // Only whether there is a project: log traffic and edits must not
    // rebuild the shell (and with it the editor).
    final hasProject = context.select<AppState, bool>(
      (a) => a.selectedProject != null,
    );
    final narrow = width < Breakpoints.floatingPanel;
    final showPanel = hasProject && _panelOpen;
    final maxPanel = (width - _railWidth - _handleWidth - _minMainWidth).clamp(
      240.0,
      520.0,
    );

    final panel = ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          const ProjectSwitcher(),
          const Divider(height: 1),
          const ServerControlCard(),
          const Divider(height: 1),
          Expanded(
            child: EndpointsList(
              onSelect: () => setState(() {
                _tab = MainTab.editor;
                if (narrow) _panelOpen = false;
              }),
            ),
          ),
        ],
      ),
    );

    final main = Column(
      children: [
        _Header(tab: _tab),
        const Divider(height: 1),
        Expanded(
          child: ColoredBox(
            color: scheme.surface,
            child: hasProject ? _MainArea(tab: _tab) : const NoProjectsView(),
          ),
        ),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          _NavRail(tab: _tab, panelOpen: _panelOpen, onSelect: _select),
          Expanded(
            child: narrow
                // Narrow windows: the panel floats over the main area.
                ? Stack(
                    children: [
                      Positioned.fill(child: main),
                      if (showPanel) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            key: const ValueKey('panel-scrim'),
                            onTap: () => setState(() => _panelOpen = false),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 300,
                          child: Material(
                            key: const ValueKey('floating-panel'),
                            elevation: 8,
                            child: panel,
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      if (showPanel) ...[
                        ValueListenableBuilder<double>(
                          valueListenable: _panelWidth,
                          builder: (context, w, child) => SizedBox(
                            width: w.clamp(240.0, maxPanel),
                            child: child,
                          ),
                          child: panel,
                        ),
                        _PanelResizeHandle(
                          width: _panelWidth,
                          max: maxPanel,
                          color: scheme.outlineVariant,
                        ),
                      ],
                      Expanded(child: main),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The section shown next to the side panel.
class _MainArea extends StatelessWidget {
  const _MainArea({required this.tab});

  final MainTab tab;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case MainTab.editor:
        // Rebuilds only when the selection changes, not on every log line.
        final project = context.select<AppState, MockProject?>(
          (a) => a.selectedProject,
        );
        final ep = context.select<AppState, Endpoint?>(
          (a) => a.selectedEndpoint,
        );
        if (ep == null || project == null) return const _NoEndpointSelected();
        return EndpointEditor(
          key: ValueKey(ep.id),
          endpoint: ep,
          project: project,
        );
      case MainTab.logs:
        return const LogsView();
      case MainTab.flows:
        return const FlowsView();
      case MainTab.share:
        return const ShareView();
      case MainTab.settings:
        return const ProjectSettingsView();
    }
  }
}

/// The draggable divider between the side panel and the main area.
class _PanelResizeHandle extends StatefulWidget {
  const _PanelResizeHandle({
    required this.width,
    required this.max,
    required this.color,
  });

  final ValueNotifier<double> width;
  final double max;
  final Color color;

  @override
  State<_PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<_PanelResizeHandle> {
  double _startX = 0;
  double _startWidth = 0;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Measured from where the drag started, so the panel edge stays under
      // the pointer even after hitting a limit.
      onHorizontalDragStart: (d) {
        _startX = d.globalPosition.dx;
        _startWidth = widget.width.value.clamp(240.0, widget.max);
      },
      onHorizontalDragUpdate: (d) => widget.width.value =
          (_startWidth + d.globalPosition.dx - _startX).clamp(240.0, widget.max),
      child: SizedBox(
        width: _HomeShellState._handleWidth,
        child: Center(child: VerticalDivider(width: 1, color: widget.color)),
      ),
    ),
  );
}

// ---------------- Navigation rail ----------------

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.tab,
    required this.panelOpen,
    required this.onSelect,
  });

  final MainTab tab;
  final bool panelOpen;
  final ValueChanged<MainTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final guideMode = context.select<AppState, bool>((a) => a.guideMode);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: _HomeShellState._railWidth,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      // Scrolls on short windows instead of overflowing.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Tooltip(
                    message: 'Mock Studio by dhiva labs',
                    child: LogoMark(size: 38),
                  ),
                  const SizedBox(height: 18),
                  for (final t in MainTab.values)
                    _RailItem(
                      icon: t.icon,
                      label: t.railLabel,
                      tooltip: t.label,
                      help:
                          '${t.help}${t == tab ? ' Click again to hide the side panel.' : ''}',
                      selected: t == tab,
                      dimmed: t == tab && !panelOpen,
                      liveBadge: t == MainTab.logs,
                      onTap: () => onSelect(t),
                    ),
                  const Spacer(),
                  _ImportMenu(app: app),
                  _RailItem(
                    icon: Icons.school_outlined,
                    label: 'Guide',
                    tooltip: 'Guide mode',
                    help: guideMode
                        ? 'On: extra hints are shown across the app for '
                              'newcomers. Click to hide them.'
                        : 'Off: click to show extra hints across the app.',
                    selected: guideMode,
                    onTap: () => app.setGuideMode(!guideMode),
                  ),
                  _RailItem(
                    icon: dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: dark ? 'Light' : 'Dark',
                    tooltip: dark ? 'Light mode' : 'Dark mode',
                    help:
                        'Switch the Teal theme between light and dark. More '
                        'options are in Settings.',
                    onTap: () => toggleDarkMode(app, dark: dark),
                  ),
                  _RailItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    tooltip: 'Settings',
                    help:
                        'Theme, light or dark mode, the projects folder and '
                        'version information.',
                    onTap: () => showAppSettingsDialog(context),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches the Teal theme between light and dark.
void toggleDarkMode(AppState app, {required bool dark}) {
  app.setThemeId(AppThemeId.teal);
  app.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.help = '',
    this.selected = false,
    this.dimmed = false,
    this.liveBadge = false,
  });

  /// Explanation shown under [tooltip] in the hover card.
  final String help;

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  /// Selected section whose side panel is collapsed.
  final bool dimmed;

  /// Shows the live request count on the icon.
  final bool liveBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final glyph = Icon(icon, size: 21, color: color);
    return HelpHover(
      help,
      title: tooltip,
      essential: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Material(
          color: selected && !dimmed
              ? scheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: 60,
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  liveBadge ? LiveRequestsBadge(child: glyph) : glyph,
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The number of logged requests on top of [child]. Only this badge
/// rebuilds when requests arrive.
class LiveRequestsBadge extends StatelessWidget {
  const LiveRequestsBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final count = context.select<AppState, int>((a) {
      final p = a.selectedProject;
      return p == null ? 0 : a.logsFor(p.id).length;
    });
    final scheme = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
      child: child,
    );
  }
}

/// Menu entries for the import actions; their values go to [runImport].
List<PopupMenuEntry<String>> importMenuEntries() => const [
  PopupMenuItem(
    value: 'postman',
    child: ListTile(
      leading: Icon(Icons.rocket_launch_outlined),
      title: Text('From Postman collection'),
      dense: true,
    ),
  ),
  PopupMenuItem(
    value: 'openapi',
    child: ListTile(
      leading: Icon(Icons.api_outlined),
      title: Text('From OpenAPI / Swagger'),
      dense: true,
    ),
  ),
  PopupMenuItem(
    value: 'project',
    child: ListTile(
      leading: Icon(Icons.file_open_outlined),
      title: Text('Mock Studio project file'),
      dense: true,
    ),
  ),
];

/// Runs the import picked from [importMenuEntries].
Future<void> runImport(BuildContext context, AppState app, String kind) =>
    switch (kind) {
      'postman' => importPostmanDialog(context, app),
      'openapi' => importOpenApiDialog(context, app),
      'project' => importProjectFileDialog(context, app),
      _ => Future<void>.value(),
    };

/// Rail button with the import options.
class _ImportMenu extends StatelessWidget {
  const _ImportMenu({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip:
          'Import: create endpoints from a Postman collection, an '
          'OpenAPI / Swagger file or a Mock Studio project file.',
      position: PopupMenuPosition.under,
      onSelected: (v) => runImport(context, app, v),
      itemBuilder: (_) => importMenuEntries(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: SizedBox(
          width: 60,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_outlined,
                size: 21,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                'Import',
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Header ----------------

/// Section title with a breadcrumb, and the server status at a glance.
class _Header extends StatelessWidget {
  const _Header({required this.tab});

  final MainTab tab;

  @override
  Widget build(BuildContext context) {
    final (projectName, endpoint) = context
        .select<AppState, (String?, ({String name, String folder})?)>((a) {
          final e = tab == MainTab.editor ? a.selectedEndpoint : null;
          return (
            a.selectedProject?.name,
            e == null ? null : (name: e.name, folder: e.folder),
          );
        });
    final scheme = Theme.of(context).colorScheme;
    final dim = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    Widget chevron() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, size: 16, color: scheme.outline),
    );
    return Container(
      height: 52,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.only(left: 18, right: 12),
      child: Row(
        children: [
          Icon(tab.icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                if (projectName != null) ...[
                  Flexible(
                    child: Text(
                      projectName,
                      overflow: TextOverflow.ellipsis,
                      style: dim,
                    ),
                  ),
                  chevron(),
                ],
                Flexible(
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: endpoint == null
                        ? const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          )
                        : dim,
                  ),
                ),
                if (endpoint != null) ...[
                  if (endpoint.folder.isNotEmpty)
                    for (final f in endpoint.folder.split('/')) ...[
                      chevron(),
                      Flexible(
                        child: Text(
                          f,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dim,
                        ),
                      ),
                    ],
                  chevron(),
                  Flexible(
                    flex: 2,
                    child: Text(
                      endpoint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (projectName != null) const ServerPill(),
        ],
      ),
    );
  }
}

/// Server status at a glance; tapping it starts or stops the server.
/// [compact] is the phone version for an app bar.
class ServerPill extends StatelessWidget {
  const ServerPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (port, running) = context.select<AppState, (int?, bool)>((a) {
      final p = a.selectedProject;
      return (p?.port, p != null && a.isRunning(p.id));
    });
    if (port == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = running ? AppTheme.success : scheme.onSurfaceVariant;
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: running ? color.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: running ? color.withValues(alpha: 0.5) : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 7),
          Text(
            running
                ? (compact ? 'Running' : 'Running · :$port')
                : 'Stopped',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: running ? color : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return HelpHover(
      running
          ? 'Your mocks are live at this address. '
                '${compact ? 'Tap' : 'Click'} to stop the server.'
          : 'Nothing is served yet. ${compact ? 'Tap' : 'Click'} to start '
                'the server for this project.',
      title: running ? 'Server running' : 'Server stopped',
      example: 'http://localhost:$port',
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 24 : 20),
        onTap: () => _toggle(context),
        // Phones: a 48 px tall touch target around the pill.
        child: compact
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(widthFactor: 1, child: pill),
                ),
              )
            : pill,
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final app = context.read<AppState>();
    final project = app.selectedProject;
    if (project == null) return;
    if (app.isRunning(project.id)) {
      await app.stopServer(project);
      return;
    }
    final err = await app.startServer(project);
    if (!context.mounted) return;
    showToast(
      context,
      err ?? 'Server started on port ${project.port}',
      error: err != null,
    );
  }
}

// ---------------- App settings ----------------

/// Appearance plus app-wide actions (projects folder, about).
Future<void> showAppSettingsDialog(BuildContext context) {
  final app = context.read<AppState>();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: app,
      builder: (ctx, _) {
        final scheme = Theme.of(ctx).colorScheme;
        Text label(String s) => Text(
          s,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        );
        return AlertDialog(
          // Scrolls on short phone screens instead of overflowing.
          scrollable: true,
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, size: 20),
              SizedBox(width: 10),
              Flexible(child: Text('Settings')),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    label('Theme'),
                    const HelpTip(
                      'Teal has light and dark versions. Graphite and orange '
                      'is a dark theme shared with ApiWorkbench.',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SegmentedButton<AppThemeId>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in AppThemeId.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {app.themeId},
                  onSelectionChanged: (s) => app.setThemeId(s.first),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    label('Mode'),
                    const HelpTip(
                      'System follows your desktop light or dark setting.',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in ThemeMode.values)
                      ButtonSegment(
                        value: m,
                        enabled: app.themeId == AppThemeId.teal,
                        label: Text(switch (m) {
                          ThemeMode.system => 'System',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                      ),
                  ],
                  selected: {app.themeMode},
                  onSelectionChanged: (s) => app.setThemeMode(s.first),
                ),
                if (app.themeId == AppThemeId.graphite)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: label('Graphite and orange is dark only.'),
                  ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: app.hoverHelp,
                  onChanged: app.setHoverHelp,
                  title: const Text('Hover help'),
                  subtitle: Text(
                    'Show an explanation when you point at a field, button '
                    'or badge. Turn off once you know your way around.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Copy projects folder path'),
                  subtitle: const Text(
                    'Each project is one JSON file you can commit to git.',
                  ),
                  onTap: () async {
                    final dir = await app.projectsDir();
                    if (ctx.mounted) {
                      copyToClipboard(
                        ctx,
                        dir,
                        label: 'Projects folder path copied:\n$dir',
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Mock Studio'),
                  onTap: () => showAboutMockStudio(ctx),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

// ---------------- Empty states ----------------

class _NoEndpointSelected extends StatelessWidget {
  const _NoEndpointSelected();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.touch_app_outlined, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Pick an endpoint',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Select one in the side panel, or create a new one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
}

/// Shown when there is no project yet.
class NoProjectsView extends StatelessWidget {
  const NoProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 64),
              const SizedBox(height: 18),
              Text(
                'Create your first mock API',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'A project is a group of mock endpoints served on one port. '
                'Start from scratch or import an existing API.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => createProjectDialog(context, app),
                icon: const Icon(Icons.add),
                label: const Text('Create a project'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => importPostmanDialog(context, app),
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Import a Postman collection'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => importOpenApiDialog(context, app),
                icon: const Icon(Icons.api_outlined),
                label: const Text('Import OpenAPI / Swagger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
