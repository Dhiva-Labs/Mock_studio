import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mock_project.dart';
import '../../state/app_state.dart';
import '../dialogs/dialogs.dart';
import '../widgets/help_tip.dart';
import '../widgets/responsive.dart';
import '../../theme/app_theme.dart';

class ProjectSwitcher extends StatelessWidget {
  const ProjectSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    // The menu reads the project list when it opens; the button itself only
    // shows the selected project's name.
    context.select<AppState, (String?, String?)>(
      (a) => (a.selectedProject?.id, a.selectedProject?.name),
    );
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: HelpHover(
              'Click to switch project or create a new one. Each project has '
              'its own endpoints and port, and several can run at once.',
              title: 'Current project',
              example: 'Payments API :8080, Users API :8081',
              child: PopupMenuButton<String>(
                // The HelpHover above explains this control.
                tooltip: '',
                offset: const Offset(0, 44),
                onSelected: (id) {
                  if (id == '__new__') {
                    createProjectDialog(context, app);
                  } else {
                    app.selectProject(id);
                  }
                },
                itemBuilder: (_) => [
                  ...app.projects.map(
                    (p) => PopupMenuItem(
                      value: p.id,
                      child: Row(
                        children: [
                          HelpHover(
                            app.isRunning(p.id)
                                ? 'This project\'s server is running.'
                                : 'This project\'s server is stopped.',
                            title: app.isRunning(p.id) ? 'Running' : 'Stopped',
                            child: Icon(
                              app.isRunning(p.id)
                                  ? Icons.play_circle
                                  : Icons.folder_outlined,
                              size: 18,
                              color: app.isRunning(p.id)
                                  ? AppTheme.success
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          HelpHover(
                            'The port this project\'s server listens on.',
                            title: 'Port',
                            example: 'http://localhost:${p.port}',
                            child: Text(
                              ':${p.port}',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: '__new__',
                    child: HelpHover(
                      'Creates an empty project with its own name and port, for '
                      'mocking another API.',
                      title: 'New project',
                      example: 'Payments API on port 8081',
                      child: ListTile(
                        leading: Icon(Icons.add),
                        title: Text('New project'),
                        dense: true,
                      ),
                    ),
                  ),
                ],
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: isPhone(context) ? 48 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project?.name ?? 'No project',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.unfold_more,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Rename, duplicate, export or delete this project',
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) => _onProjectMenu(context, app, project!, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.drive_file_rename_outline),
                  title: Text('Rename'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: HelpHover(
                  'Makes a full copy, with endpoints, settings and flows, on '
                  'the next free port. Handy for trying changes safely.',
                  title: 'Duplicate project',
                  example: 'Payments API (copy) on 8081',
                  child: ListTile(
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Duplicate'),
                    dense: true,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: HelpHover(
                  'Saves the project as a .json file to back it up or share '
                  'it. Others load it with Import, then Mock Studio project '
                  'file.',
                  title: 'Export to file',
                  example: 'payments-api.mockstudio.json',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Export to file'),
                    dense: true,
                  ),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onProjectMenu(
    BuildContext context,
    AppState app,
    MockProject project,
    String v,
  ) async {
    switch (v) {
      case 'rename':
        await renameProjectDialog(context, app, project);
        break;
      case 'duplicate':
        // A fresh id: servers, logs and the project file are keyed by it.
        final copy = MockProject.fromJson(project.toJson()..remove('id'));
        copy.name = '${project.name} (copy)';
        await app.addProject(copy);
        break;
      case 'export':
        await exportProjectDialog(context, app, project);
        break;
      case 'delete':
        await confirmDeleteProject(context, app, project);
        break;
    }
  }
}
