import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'dialogs/dialogs.dart';
import 'editor/endpoint_editor.dart';
import 'logs/logs_view.dart';
import 'settings/project_settings_view.dart';
import 'share/share_view.dart';
import 'sidebar/endpoints_list.dart';
import 'sidebar/project_switcher.dart';
import 'sidebar/server_control_card.dart';
import 'widgets/helpers.dart';

enum MainTab { editor, logs, share, settings }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  MainTab _tab = MainTab.editor;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject;

    return Scaffold(
      body: Column(
        children: [
          _TopBar(),
          const Divider(height: 1),
          Expanded(
            child: project == null
                ? _NoProjects()
                : Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            const ProjectSwitcher(),
                            const Divider(height: 1),
                            const ServerControlCard(),
                            const Divider(height: 1),
                            Expanded(
                              child: EndpointsList(
                                onSelect: () =>
                                    setState(() => _tab = MainTab.editor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _MainTabBar(
                              tab: _tab,
                              logCount: app.logsFor(project.id).length,
                              onChanged: (t) => setState(() => _tab = t),
                            ),
                            const Divider(height: 1),
                            Expanded(child: _buildMain(app)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain(AppState app) {
    switch (_tab) {
      case MainTab.editor:
        final ep = app.selectedEndpoint;
        if (ep == null) return const _NoEndpointSelected();
        return EndpointEditor(
          key: ValueKey(ep.id),
          endpoint: ep,
          project: app.selectedProject!,
        );
      case MainTab.logs:
        return const LogsView();
      case MainTab.share:
        return const ShareView();
      case MainTab.settings:
        return const ProjectSettingsView();
    }
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dns_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Mock Studio',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'by dhiva labs',
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _GuideToggle(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Toggle light / dark',
            icon: Icon(
              app.themeMode == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : app.themeMode == ThemeMode.light
                  ? Icons.light_mode_outlined
                  : Icons.brightness_auto_outlined,
            ),
            onPressed: () {
              final next = switch (app.themeMode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              app.setThemeMode(next);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _onMenu(context, app, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_open_outlined),
                  title: Text('Import project file'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'openapi',
                child: ListTile(
                  leading: Icon(Icons.api_outlined),
                  title: Text('Import from OpenAPI / Swagger'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'folder',
                child: ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('Show projects folder'),
                  dense: true,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About Mock Studio'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, AppState app, String v) async {
    switch (v) {
      case 'import':
        await importProjectFileDialog(context, app);
        break;
      case 'openapi':
        await importOpenApiDialog(context, app);
        break;
      case 'folder':
        final dir = await app.projectsDir();
        if (context.mounted) {
          copyToClipboard(
            context,
            dir,
            label: 'Projects folder path copied:\n$dir',
          );
        }
        break;
      case 'about':
        if (context.mounted) showAboutMockStudio(context);
        break;
    }
  }
}

class _GuideToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: app.guideMode
          ? 'Guide mode is ON — helpful hints shown. Click to hide.'
          : 'Guide mode is OFF. Click to show helpful hints.',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => app.setGuideMode(!app.guideMode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: app.guideMode
                ? scheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.school_outlined,
                size: 16,
                color: app.guideMode ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Guide',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: app.guideMode
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainTabBar extends StatelessWidget {
  final MainTab tab;
  final int logCount;
  final ValueChanged<MainTab> onChanged;
  const _MainTabBar({
    required this.tab,
    required this.logCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _TabButton(
            icon: Icons.edit_outlined,
            label: 'Endpoint',
            selected: tab == MainTab.editor,
            onTap: () => onChanged(MainTab.editor),
          ),
          _TabButton(
            icon: Icons.receipt_long_outlined,
            label: 'Live Requests',
            badge: logCount > 0
                ? (logCount > 999 ? '999+' : '$logCount')
                : null,
            selected: tab == MainTab.logs,
            onTap: () => onChanged(MainTab.logs),
          ),
          _TabButton(
            icon: Icons.share_outlined,
            label: 'Share & Expose',
            selected: tab == MainTab.share,
            onTap: () => onChanged(MainTab.share),
          ),
          _TabButton(
            icon: Icons.tune,
            label: 'Project Settings',
            selected: tab == MainTab.settings,
            onTap: () => onChanged(MainTab.settings),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoEndpointSelected extends StatelessWidget {
  const _NoEndpointSelected();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Select an endpoint on the left,',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          Text(
            'or create a new one to get started.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoProjects extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'A project is a group of mock endpoints served on one port. '
              'Create one to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => createProjectDialog(context, app),
              icon: const Icon(Icons.add),
              label: const Text('Create a project'),
            ),
          ],
        ),
      ),
    );
  }
}
