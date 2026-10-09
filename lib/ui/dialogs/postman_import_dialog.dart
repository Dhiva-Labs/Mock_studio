import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/mock_project.dart';
import '../../services/postman_import.dart';
import '../../state/app_state.dart';
import '../widgets/help_tip.dart';

/// Turn Postman collections (files or pasted JSON) into mock endpoints: each
/// request becomes an endpoint and its saved examples become its responses.
/// The user reviews what will be created before choosing a new or existing
/// project.
Future<void> importPostmanDialog(
  BuildContext context,
  AppState app, {
  String? projectId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PostmanDialog(app: app, projectId: projectId),
);

class _PostmanDialog extends StatefulWidget {
  const _PostmanDialog({required this.app, this.projectId});

  final AppState app;
  final String? projectId;

  @override
  State<_PostmanDialog> createState() => _PostmanDialogState();
}

class _PostmanDialogState extends State<_PostmanDialog> {
  final _paste = TextEditingController();
  final _imports = <PostmanMockImport>[];
  final _errors = <String>[];
  bool _busy = false;

  /// Destination: null creates a new project per collection.
  late String? _target = widget.projectId;
  bool? _group;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _add(String label, String text) {
    try {
      _imports.add(importPostmanToMocks(text));
    } on FormatException catch (e) {
      _errors.add('$label: ${e.message}');
    } catch (e) {
      _errors.add('$label: could not be read ($e).');
    }
  }

  Future<void> _chooseFiles() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Postman collections',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
        withData: true,
      );
      for (final f in picked?.files ?? <PlatformFile>[]) {
        final bytes =
            f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytes == null) {
          _errors.add('${f.name}: could not be read.');
          continue;
        }
        _add(f.name, utf8.decode(bytes, allowMalformed: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addPasted() {
    final text = _paste.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _add('Pasted JSON', text);
      _paste.clear();
    });
  }

  int get _endpoints => _imports.fold(0, (s, i) => s + i.endpoints.length);

  bool get _groupByCollection => _group ?? _imports.length > 1;

  Future<void> _import() async {
    final app = widget.app;
    final target = app.projects.where((p) => p.id == _target).firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (target != null) {
      for (final imp in _imports) {
        for (final e in imp.endpoints) {
          if (_groupByCollection) {
            final group = imp.name.replaceAll('/', '∕');
            e.folder = e.folder.isEmpty ? group : '$group/${e.folder}';
          }
          target.endpoints.add(e);
        }
      }
      await app.saveProject(target);
      app.selectProject(target.id);
      _toast(messenger, 'Added $_endpoints endpoints to "${target.name}"');
      return;
    }
    for (final imp in _imports) {
      await app.addProject(
        MockProject(
          name: imp.name,
          description: imp.description,
          endpoints: imp.endpoints,
          port: 8080,
        ),
      );
    }
    _toast(
      messenger,
      _imports.length == 1
          ? 'Created "${_imports.single.name}" with $_endpoints endpoints'
          : 'Created ${_imports.length} projects with $_endpoints endpoints',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _imports.isNotEmpty;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          const Flexible(child: Text('Import from Postman')),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Each request becomes a mock endpoint, and its saved '
                'examples become the responses. Collections v2.0 and v2.1, '
                'single requests and folders are supported.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              HelpHover(
                'Pick one or more collection .json files exported from '
                'Postman.',
                title: 'Choose files',
                example: 'Postman: Export, then Collection v2.1',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _busy ? null : _chooseFiles,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Icon(
                                Icons.upload_file,
                                size: 28,
                                color: scheme.primary,
                              ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose files',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _imports.isEmpty
                              ? '.json exported from Postman'
                              : 'Added: ${_imports.map((i) => i.name).join(', ')}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paste,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Or paste Postman JSON here',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HelpTip(
                          'Paste a whole collection, a folder or a single '
                          'request as JSON, then press Add. You can add '
                          'several before importing.',
                          title: 'Paste JSON',
                          example: '{"info": {...}, "item": [...]}',
                        ),
                        TextButton(
                          onPressed: _addPasted,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (final e in _errors)
                _note(context, Icons.error_outline, scheme.error, e),
              if (ready) ...[const SizedBox(height: 16), _summary(context)],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: ready ? _import : null,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Import'),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    int sum(int Function(PostmanMockImport) f) =>
        _imports.fold(0, (s, i) => s + f(i));
    Widget stat(
      int n,
      String label, {
      required String title,
      required String help,
      String? example,
    }) => Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: HelpHover(
          help,
          title: title,
          example: example,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$n',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                n == 1 ? label : '${label}s',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
    final projects = widget.app.projects;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stat(
                _endpoints,
                'endpoint',
                title: 'Endpoints',
                help:
                    'Each Postman request becomes one mock endpoint with the '
                    'same method and path.',
                example: 'GET {{baseUrl}}/users becomes GET /users',
              ),
              stat(
                sum((i) => i.folders),
                'folder',
                title: 'Folders',
                help:
                    'Postman folders become folders in the endpoint list. '
                    "They only organise the list; URLs don't change.",
                example: 'Customers/GET /customers',
              ),
              stat(
                sum((i) => i.examples),
                'saved example',
                title: 'Saved examples',
                help:
                    'Sample responses saved with a request in Postman. Each '
                    'becomes one of its responses; requests without one get a '
                    'default 200 response.',
                example: '200 OK and 404 Not found for GET /users/:id',
              ),
            ],
          ),
          for (final w in _imports.expand((i) => i.warnings))
            _note(context, Icons.info_outline, scheme.tertiary, w),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _target ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              label: LabelWithHelp(
                'Import into',
                'A new project is named after the collection and gets the '
                    'next free port. An existing project keeps its endpoints and '
                    'gets these added alongside them.',
                example: 'Existing: Payments API (:8080)',
              ),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  _imports.length > 1
                      ? 'New projects (one per collection)'
                      : 'A new project',
                ),
              ),
              for (final p in projects)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    'Existing: ${p.name} (:${p.port})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) =>
                setState(() => _target = (v == null || v.isEmpty) ? null : v),
          ),
          if (_target != null)
            // Own Material so the tile's ink isn't hidden by this coloured box.
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _groupByCollection,
                onChanged: (v) => setState(() => _group = v),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _imports.length == 1
                            ? 'Put them in a folder named "${_imports.single.name}"'
                            : 'Put each collection in its own folder',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const HelpTip(
                      'Keeps the imported endpoints together in the endpoint '
                      "list. Folders only organise the list; they don't change "
                      'any URL paths.',
                      title: 'Group in a folder',
                      example: 'Stripe API/Customers/GET /v1/customers',
                    ),
                  ],
                ),
                subtitle: Text(
                  'Existing endpoints are left as they are.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, IconData icon, Color color, String t) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

void _toast(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));
