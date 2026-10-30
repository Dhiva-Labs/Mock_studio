import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/endpoint.dart';
import '../../models/mock_project.dart';
import '../../services/openapi_import.dart';
import '../../services/sample_data.dart';
import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';

Future<void> createProjectDialog(BuildContext context, AppState app) async {
  final nameCtrl = TextEditingController(text: 'New API');
  final portCtrl = TextEditingController(text: '${_suggestPort(app)}');
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Scrolls above the on-screen keyboard on phones.
      scrollable: true,
      title: const Row(
        children: [
          Flexible(child: Text('New project')),
          HelpTip(
            'A project is one mock API: a set of endpoints served together on '
            'one port and saved as one file.',
            title: 'Project',
            example: 'Payments API on port 8080',
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Project name',
                  hintText: 'e.g. Payments API',
                  suffixIcon: HelpTip(
                    'A label for you, shown in the project list. Name it after '
                    'the API you are mocking; you can rename it later.',
                    title: 'Project name',
                    example: 'Payments API',
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  helperText: 'The server will listen on this port',
                  suffixIcon: HelpTip(
                    'Your app reaches the mock at this number. Pick one from '
                    '1024 to 65535 that nothing else uses. If another project '
                    'has it, the next free number is used.',
                    title: 'Port',
                    example: '8080 → http://localhost:8080',
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final p = int.tryParse(v ?? '');
                  if (p == null || p < 1 || p > 65535) {
                    return 'Enter a port 1–65535';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx);
            await app.createProject(
              nameCtrl.text.trim(),
              port: int.parse(portCtrl.text),
            );
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

int _suggestPort(AppState app) {
  final used = app.projects.map((p) => p.port).toSet();
  var p = 8080;
  while (used.contains(p)) {
    p++;
  }
  return p;
}

Future<void> renameProjectDialog(
  BuildContext context,
  AppState app,
  MockProject project,
) async {
  final ctrl = TextEditingController(text: project.name);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: const Text('Rename project'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project name',
            suffixIcon: HelpTip(
              'Only the display name changes. The port, endpoints and saved '
              'file stay the same.',
              title: 'Project name',
              example: 'Payments API v2',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            project.name = ctrl.text.trim().isEmpty
                ? project.name
                : ctrl.text.trim();
            await app.saveProject(project);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> confirmDeleteProject(
  BuildContext context,
  AppState app,
  MockProject project,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: const Text('Delete project?'),
      content: Text(
        '"${project.name}" and all its ${project.endpoints.length} endpoints will be '
        'permanently removed. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () async {
            await app.deleteProject(project);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Future<void> exportProjectDialog(
  BuildContext context,
  AppState app,
  MockProject project,
) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export project',
      fileName:
          '${project.name.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-').toLowerCase()}.mockstudio.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;
    await app.exportProject(project, path);
    if (context.mounted) showToast(context, 'Exported to $path');
  } catch (e) {
    if (context.mounted) showToast(context, 'Export failed: $e', error: true);
  }
}

Future<void> importProjectFileDialog(BuildContext context, AppState app) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import a Mock Studio project',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final project = await app.importProjectFile(result.files.single.path!);
    if (context.mounted) showToast(context, 'Imported "${project.name}"');
  } catch (e) {
    if (context.mounted) showToast(context, 'Import failed: $e', error: true);
  }
}

Future<void> importOpenApiDialog(BuildContext context, AppState app) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Import OpenAPI / Swagger file',
    type: FileType.custom,
    allowedExtensions: ['json', 'yaml', 'yml'],
  );
  if (result == null || result.files.single.path == null) return;
  try {
    final content = await File(result.files.single.path!).readAsString();
    final endpoints = OpenApiImporter.import(content);
    final project = MockProject(
      name: 'Imported API',
      endpoints: endpoints,
      port: _suggestPort(app),
    );
    await app.addProject(project);
    if (context.mounted) {
      showToast(
        context,
        'Imported ${endpoints.length} endpoints from OpenAPI spec',
      );
    }
  } catch (e) {
    if (context.mounted) {
      showToast(context, 'Could not import: $e', error: true);
    }
  }
}

/// The "new endpoint" flow: choose a blank endpoint or start from a template.
Future<void> newEndpointDialog(
  BuildContext context,
  AppState app, {
  VoidCallback? onCreated,
}) async {
  final templates = SampleData.endpointTemplates();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.add_road_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add an endpoint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Start from scratch, or pick a ready-made template.',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const HelpTip(
                    'Templates are ordinary endpoints with useful settings '
                    'already filled in, such as a delay or random errors. You '
                    'can change everything after adding one.',
                    title: 'Blank or template',
                    example: 'Slow endpoint: a 2 s delay',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: HelpHover(
                'Adds a simple endpoint returning a JSON message, ready for '
                'you to change the method, path and response.',
                title: 'Blank endpoint',
                example:
                    'GET /hello → 200 {"message": "Hello from Mock Studio"}',
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await app.addEndpoint(app.selectedProject!, Endpoint());
                    onCreated?.call();
                  },
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Blank endpoint'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Divider(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemCount: templates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final t = templates[i];
                  final sample = t.build();
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: MethodBadge(sample.method, compact: true),
                      title: Text(
                        t.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        t.subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add, size: 18),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await app.addEndpoint(app.selectedProject!, t.build());
                        onCreated?.call();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showAboutMockStudio(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'Mock Studio',
    applicationVersion: '1.2.1 · by dhiva labs',
    applicationIcon: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.dns_rounded, color: Colors.white),
    ),
    children: [
      const SizedBox(height: 8),
      const Text(
        'A production-grade mock server for building, exposing and testing HTTP endpoints — '
        'usable by seasoned developers and complete beginners alike.',
      ),
    ],
  );
}
