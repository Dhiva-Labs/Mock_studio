import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mock_project.dart';
import '../../state/app_state.dart';
import '../dialogs/dialogs.dart';

class ProjectSwitcher extends StatelessWidget {
  const ProjectSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: 'Switch project',
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
                        Icon(
                          app.isRunning(p.id)
                              ? Icons.play_circle
                              : Icons.folder_outlined,
                          size: 18,
                          color: app.isRunning(p.id)
                              ? const Color(0xFF16A34A)
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          ':${p.port}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: '__new__',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('New project'),
                    dense: true,
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Project actions',
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
                child: ListTile(
                  leading: Icon(Icons.copy_outlined),
                  title: Text('Duplicate'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Export to file'),
                  dense: true,
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
        final copy = MockProject.fromJson(project.toJson());
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
