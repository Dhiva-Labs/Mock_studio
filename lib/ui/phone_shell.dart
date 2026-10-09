import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_project.dart';
import '../state/app_state.dart';
import 'editor/endpoint_editor.dart';
import 'flows/flows_view.dart';
import 'home_shell.dart';
import 'logs/logs_view.dart';
import 'settings/project_settings_view.dart';
import 'share/share_view.dart';
import 'sidebar/endpoints_list.dart';
import 'sidebar/project_switcher.dart';
import 'sidebar/server_control_card.dart';
import 'widgets/badges.dart';
import 'widgets/logo.dart';

/// The phone layout: an app bar with the project and server status, a
/// bottom navigation bar for the sections, and the endpoint editor as a
/// full-screen page pushed over the endpoint list (master/detail).
///
/// The pages live in a nested [Navigator], so the Android back button (and
/// the app bar's back arrow) returns from the editor or a request's details
/// to the list instead of closing the app.
class PhoneShell extends StatefulWidget {
  const PhoneShell({super.key, required this.tab, required this.onTab});

  final MainTab tab;
  final ValueChanged<MainTab> onTab;

  @override
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> {
  static const _homeKey = ValueKey('phone-home');
  static const _editorKey = ValueKey('phone-editor');

  final _navigator = GlobalKey<NavigatorState>();
  bool _editorOpen = false;

  void _openEditor() {
    if (widget.tab != MainTab.editor) widget.onTab(MainTab.editor);
    setState(() => _editorOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasEndpoint = context.select<AppState, bool>(
      (a) => a.selectedEndpoint != null,
    );
    final showEditor =
        _editorOpen && hasEndpoint && widget.tab == MainTab.editor;
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        pages: [
          MaterialPage<void>(
            key: _homeKey,
            child: _PhoneHome(
              tab: widget.tab,
              onTab: widget.onTab,
              onOpenEditor: _openEditor,
            ),
          ),
          if (showEditor)
            const MaterialPage<void>(
              key: _editorKey,
              child: _PhoneEditorPage(),
            ),
        ],
        onDidRemovePage: (page) {
          if (page.key == _editorKey && _editorOpen && mounted) {
            setState(() => _editorOpen = false);
          }
        },
      ),
    );
  }
}

class _PhoneHome extends StatelessWidget {
  const _PhoneHome({
    required this.tab,
    required this.onTab,
    required this.onOpenEditor,
  });

  final MainTab tab;
  final ValueChanged<MainTab> onTab;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final projectName = context.select<AppState, String?>(
      (a) => a.selectedProject?.name,
    );
    final hasProject = projectName != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: hasProject,
        title: Builder(
          builder: (context) => _ProjectTitle(
            name: projectName,
            onTap: hasProject ? Scaffold.of(context).openDrawer : null,
          ),
        ),
        actions: [
          if (hasProject) const ServerPill(compact: true),
          const _PhoneMenu(),
        ],
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      drawer: hasProject ? const _PhoneDrawer() : null,
      body: ColoredBox(
        color: scheme.surface,
        child: hasProject ? _body() : const NoProjectsView(),
      ),
      bottomNavigationBar: hasProject
          ? NavigationBar(
              selectedIndex: tab.index,
              onDestinationSelected: (i) => onTab(MainTab.values[i]),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 68,
              destinations: [
                for (final t in MainTab.values)
                  NavigationDestination(
                    icon: t == MainTab.logs
                        ? LiveRequestsBadge(child: Icon(t.icon))
                        : Icon(t.icon),
                    label: t.railLabel,
                    tooltip: t.label,
                  ),
              ],
            )
          : null,
    );
  }

  Widget _body() => switch (tab) {
    MainTab.editor => EndpointsList(onSelect: onOpenEditor),
    MainTab.logs => const LogsView(),
    MainTab.flows => const FlowsView(),
    MainTab.share => const ShareView(),
    MainTab.settings => const ProjectSettingsView(),
  };
}

/// Logo and project name; tapping opens the drawer with the project
/// switcher and server controls.
class _ProjectTitle extends StatelessWidget {
  const _ProjectTitle({required this.name, required this.onTap});

  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LogoMark(size: 26),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name ?? 'Mock Studio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (onTap != null)
          Icon(Icons.unfold_more, size: 18, color: scheme.onSurfaceVariant),
      ],
    );
    if (onTap == null) {
      return Padding(padding: const EdgeInsets.only(left: 16), child: title);
    }
    return Tooltip(
      message: 'Switch project and control the server',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: title,
          ),
        ),
      ),
    );
  }
}

/// Import, guide mode, theme and settings.
class _PhoneMenu extends StatelessWidget {
  const _PhoneMenu();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Import, guide, theme and settings',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'guide':
            app.setGuideMode(!app.guideMode);
          case 'theme':
            toggleDarkMode(app, dark: dark);
          case 'settings':
            showAppSettingsDialog(context);
          default:
            runImport(context, app, v);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            'IMPORT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ...importMenuEntries(),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<String>(
          value: 'guide',
          checked: app.guideMode,
          child: const Text('Guide mode'),
        ),
        PopupMenuItem<String>(
          value: 'theme',
          child: ListTile(
            leading: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(dark ? 'Light mode' : 'Dark mode'),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

/// Project switcher and server controls.
class _PhoneDrawer extends StatelessWidget {
  const _PhoneDrawer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const LogoMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mock Studio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'by dhiva labs',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const ProjectSwitcher(),
            const Divider(height: 1),
            const ServerControlCard(),
          ],
        ),
      ),
    );
  }
}

/// The endpoint editor as a full-screen page.
class _PhoneEditorPage extends StatelessWidget {
  const _PhoneEditorPage();

  @override
  Widget build(BuildContext context) {
    final project = context.select<AppState, MockProject?>(
      (a) => a.selectedProject,
    );
    final ep = context.select<AppState, Endpoint?>((a) => a.selectedEndpoint);
    // Name and method are edited on this page; the title follows them.
    final (name, method) = context.select<AppState, (String, HttpMethodType?)>(
      (a) => (a.selectedEndpoint?.name ?? '', a.selectedEndpoint?.method),
    );
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (method != null) ...[
              MethodBadge(method, compact: true),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                name.isEmpty ? 'Endpoint' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: const [ServerPill(compact: true), SizedBox(width: 8)],
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      body: ColoredBox(
        color: scheme.surface,
        child: ep == null || project == null
            ? const SizedBox.expand()
            : SafeArea(
                top: false,
                child: EndpointEditor(
                  key: ValueKey(ep.id),
                  endpoint: ep,
                  project: project,
                ),
              ),
      ),
    );
  }
}
