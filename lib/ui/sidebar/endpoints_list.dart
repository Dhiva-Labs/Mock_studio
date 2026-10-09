import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/mock_project.dart';
import '../../state/app_state.dart';
import '../dialogs/dialogs.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';
import '../widgets/responsive.dart';

/// The project's endpoints as a folder tree (folders are organisational
/// only; they never change routing).
class EndpointsList extends StatefulWidget {
  final VoidCallback onSelect;
  const EndpointsList({super.key, required this.onSelect});

  @override
  State<EndpointsList> createState() => _EndpointsListState();
}

/// A folder node; children are [_Folder]s and [Endpoint]s in project order.
class _Folder {
  _Folder(this.name, this.path);
  final String name;
  final String path;
  final children = <Object>[];

  int get count => children.fold(0, (s, c) => s + (c is _Folder ? c.count : 1));
}

class _EndpointsListState extends State<EndpointsList> {
  String _query = '';

  /// Folders are open by default; this holds the collapsed ones.
  final Set<String> _collapsed = {};

  bool _matches(Endpoint e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.name.toLowerCase().contains(q) ||
        e.path.toLowerCase().contains(q) ||
        e.folder.toLowerCase().contains(q) ||
        e.method.label.toLowerCase().contains(q);
  }

  _Folder _tree(MockProject project) {
    final root = _Folder(project.name, '');
    final index = <String, _Folder>{'': root};
    for (final e in project.endpoints) {
      if (!_matches(e)) continue;
      var parent = root;
      var path = '';
      if (e.folder.isNotEmpty) {
        for (final seg in e.folder.split('/')) {
          path = path.isEmpty ? seg : '$path/$seg';
          final p = parent;
          parent = index.putIfAbsent(path, () {
            final f = _Folder(seg, path);
            p.children.add(f);
            return f;
          });
        }
      }
      parent.children.add(e);
    }
    return root;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    // Rebuild for changes to the list itself, not for every logged request
    // or keystroke elsewhere.
    context.select<AppState, (String?, String?, int)>((a) {
      final p = a.selectedProject;
      return (
        p?.id,
        a.selectedEndpointId,
        Object.hashAll([
          for (final e in p?.endpoints ?? const <Endpoint>[])
            Object.hash(e.id, e.name, e.path, e.method, e.folder, e.enabled),
        ]),
      );
    });
    final phone = isPhone(context);
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final tree = _tree(project);
    final rows = <Widget>[];
    _rows(app, project, tree, 0, rows);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
          child: Row(
            children: [
              const LabelWithHelp(
                'Endpoints',
                'Each endpoint is a method and path your mock server answers, '
                    'like GET /users/:id. Folders only organise the list; they '
                    "don't change the URL.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${project.endpoints.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'New endpoint',
                icon: const Icon(Icons.add, size: 20),
                onPressed: () =>
                    newEndpointDialog(context, app, onCreated: widget.onSelect),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: phone ? 44 : 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search endpoints',
                suffixIcon: const HelpTip(
                  'Matches endpoint names, paths, folders and methods.',
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyEndpoints(
                  hasAny: project.endpoints.isNotEmpty,
                  onNew: () => newEndpointDialog(
                    context,
                    app,
                    onCreated: widget.onSelect,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  children: rows,
                ),
        ),
      ],
    );
  }

  void _rows(
    AppState app,
    MockProject project,
    _Folder folder,
    int depth,
    List<Widget> out,
  ) {
    for (final child in folder.children) {
      if (child is _Folder) {
        final open = _query.isNotEmpty || !_collapsed.contains(child.path);
        out.add(
          _FolderRow(
            folder: child,
            depth: depth,
            open: open,
            onTap: () => setState(
              () => open
                  ? _collapsed.add(child.path)
                  : _collapsed.remove(child.path),
            ),
            onRename: () => _renameFolder(app, project, child),
            onUngroup: () => _ungroup(app, project, child),
          ),
        );
        if (open) _rows(app, project, child, depth + 1, out);
      } else if (child is Endpoint) {
        out.add(
          _EndpointTile(
            endpoint: child,
            depth: depth,
            selected: app.selectedEndpointId == child.id,
            onTap: () {
              app.selectEndpoint(child.id);
              widget.onSelect();
            },
            onMove: () => _moveEndpoint(app, project, child),
          ),
        );
      }
    }
  }

  bool _inFolder(Endpoint e, String path) =>
      e.folder == path || e.folder.startsWith('$path/');

  Future<void> _renameFolder(
    AppState app,
    MockProject project,
    _Folder f,
  ) async {
    final name = await _prompt(context, 'Rename folder', f.name);
    if (name == null || name.isEmpty || name == f.name) return;
    final parent = f.path.contains('/')
        ? f.path.substring(0, f.path.lastIndexOf('/'))
        : '';
    final renamed = [
      if (parent.isNotEmpty) parent,
      name.replaceAll('/', '∕'),
    ].join('/');
    for (final e in project.endpoints.where((e) => _inFolder(e, f.path))) {
      e.folder = renamed + e.folder.substring(f.path.length);
    }
    await app.saveProject(project);
  }

  /// Moves the folder's contents up one level and removes the folder.
  Future<void> _ungroup(AppState app, MockProject project, _Folder f) async {
    final parent = f.path.contains('/')
        ? f.path.substring(0, f.path.lastIndexOf('/'))
        : '';
    for (final e in project.endpoints.where((e) => _inFolder(e, f.path))) {
      final rest = e.folder.substring(f.path.length).replaceFirst('/', '');
      e.folder = [
        if (parent.isNotEmpty) parent,
        if (rest.isNotEmpty) rest,
      ].join('/');
    }
    await app.saveProject(project);
  }

  Future<void> _moveEndpoint(
    AppState app,
    MockProject project,
    Endpoint e,
  ) async {
    final folders = {
      for (final x in project.endpoints)
        if (x.folder.isNotEmpty) x.folder,
    }.toList()..sort();
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _MoveDialog(initial: e.folder, folders: folders),
    );
    if (picked == null) return;
    e.folder = picked
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('/');
    await app.saveProject(project);
  }
}

/// Picks or types the folder to move an endpoint to. Owns its text
/// controller so it lives until the dialog's closing animation is over.
class _MoveDialog extends StatefulWidget {
  const _MoveDialog({required this.initial, required this.folders});

  final String initial;
  final List<String> folders;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Move to folder'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder',
              hintText: 'Users/Admin — empty for the top level',
            ),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          if (widget.folders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in widget.folders)
                  ActionChip(
                    label: Text(f.replaceAll('/', ' › ')),
                    onPressed: () => Navigator.pop(context, f),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
        child: const Text('Move'),
      ),
    ],
  );
}

Future<String?> _prompt(BuildContext context, String title, String initial) =>
    showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(title: title, initial: initial),
    );

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
        child: const Text('Rename'),
      ),
    ],
  );
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.depth,
    required this.open,
    required this.onTap,
    required this.onRename,
    required this.onUngroup,
  });

  final _Folder folder;
  final int depth;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onUngroup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        // Taller rows on phones for comfortable touch targets.
        height: isPhone(context) ? 48 : 34,
        child: Row(
          children: [
            SizedBox(width: 4.0 + depth * 14),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              open ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            HelpHover(
              'Endpoints in this folder, including its subfolders. Folders '
              "only organise the list; they don't change any URL.",
              title: '${folder.count} endpoint${folder.count == 1 ? '' : 's'}',
              child: Text(
                '${folder.count}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Folder actions',
              iconSize: 16,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              onSelected: (v) => v == 'rename' ? onRename() : onUngroup(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename folder'),
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'ungroup',
                  child: ListTile(
                    leading: Icon(Icons.folder_off_outlined),
                    title: Text('Ungroup'),
                    subtitle: Text('Keeps the endpoints'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  final Endpoint endpoint;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMove;
  const _EndpointTile({
    required this.endpoint,
    required this.depth,
    required this.selected,
    required this.onTap,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Opacity(
            opacity: endpoint.enabled ? 1 : 0.5,
            child: _disabledHint(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.0 + depth * 14, 6, 0, 6),
                child: Row(
                  children: [
                    MethodBadge(endpoint.method, compact: true, fontSize: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            endpoint.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            endpoint.normalizedPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Endpoint actions',
                      icon: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        switch (v) {
                          case 'toggle':
                            endpoint.enabled = !endpoint.enabled;
                            app.saveProject(app.selectedProject!);
                          case 'move':
                            onMove();
                          case 'duplicate':
                            app.duplicateEndpoint(
                              app.selectedProject!,
                              endpoint,
                            );
                          case 'delete':
                            app.deleteEndpoint(app.selectedProject!, endpoint);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: ListTile(
                            leading: Icon(
                              endpoint.enabled
                                  ? Icons.toggle_on
                                  : Icons.toggle_off_outlined,
                            ),
                            title: Text(
                              endpoint.enabled ? 'Disable' : 'Enable',
                            ),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'move',
                          child: ListTile(
                            leading: Icon(Icons.drive_file_move_outline),
                            title: Text('Move to folder…'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: ListTile(
                            leading: Icon(Icons.copy_outlined),
                            title: Text('Duplicate'),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: scheme.error,
                            ),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: scheme.error),
                            ),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Disabled endpoints explain themselves on hover.
  Widget _disabledHint({required Widget child}) => endpoint.enabled
      ? child
      : HelpHover(
          'The server ignores this endpoint until you enable it again from '
          'its ⋯ menu or the switch in the editor.',
          title: 'Disabled',
          child: child,
        );
}

class _EmptyEndpoints extends StatelessWidget {
  final bool hasAny;
  final VoidCallback onNew;
  const _EmptyEndpoints({required this.hasAny, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAny ? Icons.search_off : Icons.api_outlined,
              size: 40,
              color: scheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasAny ? 'No matches' : 'No endpoints yet',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!hasAny) ...[
              const SizedBox(height: 6),
              Text(
                'Add your first endpoint to\nstart serving mock responses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New endpoint'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
