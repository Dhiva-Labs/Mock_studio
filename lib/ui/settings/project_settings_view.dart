import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/mock_response.dart';
import '../../services/mock_server.dart';
import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/helpers.dart';

/// Project-level configuration: port, CORS, proxy/record, global delay/headers.
class ProjectSettingsView extends StatefulWidget {
  const ProjectSettingsView({super.key});

  @override
  State<ProjectSettingsView> createState() => _ProjectSettingsViewState();
}

class _ProjectSettingsViewState extends State<ProjectSettingsView> {
  Timer? _saveTimer;

  void _save(AppState app) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) app.saveProject(app.selectedProject!);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final project = app.selectedProject!;
    final running = app.isRunning(project.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Card(
          icon: Icons.settings_ethernet,
          title: 'Server',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      initialValue: project.port.toString(),
                      enabled: !running,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        helperText: running ? 'Stop server to change' : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final p = int.tryParse(v);
                        if (p != null && p > 0 && p <= 65535) {
                          project.port = p;
                          _save(app);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: project.corsEnabled,
                onChanged: (v) => setState(() {
                  project.corsEnabled = v;
                  _save(app);
                }),
                title: const Text(
                  'Enable CORS',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Allow browser apps from any origin to call this mock (adds Access-Control-* headers)',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          icon: Icons.swap_horiz,
          title: 'Proxy passthrough',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.guideMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HintCard(
                    'Requests that don\'t match any endpoint can be forwarded to a real API. '
                    'Turn on "record" to capture those responses and turn them into mocks with one click.',
                  ),
                ),
              TextFormField(
                initialValue: project.proxyBaseUrl,
                decoration: const InputDecoration(
                  labelText: 'Forward unmatched requests to (base URL)',
                  hintText: 'https://api.example.com',
                  prefixIcon: Icon(Icons.link, size: 18),
                ),
                onChanged: (v) {
                  project.proxyBaseUrl = v.trim();
                  _save(app);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: project.recordProxy,
                onChanged: project.proxyBaseUrl.trim().isEmpty
                    ? null
                    : (v) => setState(() {
                        project.recordProxy = v;
                        _save(app);
                      }),
                title: const Text(
                  'Record proxied responses',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Capture real responses so you can save them as mock endpoints',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              if (app.pendingRecordings.isNotEmpty) _RecordingsPanel(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          icon: Icons.public,
          title: 'Global response settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  initialValue: project.globalDelayMs.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Global delay (ms)',
                    helperText: 'Added to every response',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    project.globalDelayMs = int.tryParse(v) ?? 0;
                    _save(app);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _GlobalHeadersEditor(
                headers: project.globalHeaders,
                onChanged: () => _save(app),
                onMutated: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          icon: Icons.folder_outlined,
          title: 'Storage',
          child: FutureBuilder<String>(
            future: app.projectsDir(),
            builder: (context, snap) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This project is saved as a JSON file you can commit to git or share.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (project.filePath != null) CodeBox(project.filePath!),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecordingsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final recordings = app.pendingRecordings;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fiber_manual_record, size: 14, color: scheme.error),
              const SizedBox(width: 8),
              Text(
                '${recordings.length} recorded response${recordings.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => app.clearRecordings(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recordings
              .take(20)
              .map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      MethodBadgeString(rec.method),
                      const SizedBox(width: 8),
                      StatusBadge(rec.statusCode),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _saveAsMock(context, app, rec),
                        icon: const Icon(Icons.save_outlined, size: 15),
                        label: const Text('Save as mock'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _saveAsMock(
    BuildContext context,
    AppState app,
    RecordedCall rec,
  ) async {
    final endpoint = Endpoint(
      name: '${rec.method} ${rec.path}',
      method: HttpMethodTypeX.fromString(rec.method.toLowerCase()),
      path: rec.path,
      responses: [
        MockResponse(
          label: '${rec.statusCode} (recorded)',
          statusCode: rec.statusCode,
          bodyType: (rec.headers['content-type'] ?? '').contains('json')
              ? BodyType.json
              : BodyType.text,
          body: rec.body,
        ),
      ],
    );
    await app.addEndpoint(app.selectedProject!, endpoint);
    app.pendingRecordings.remove(rec);
    if (context.mounted) {
      showToast(context, 'Saved "${endpoint.name}" as a mock endpoint');
    }
  }
}

class _GlobalHeadersEditor extends StatefulWidget {
  final Map<String, String> headers;
  final VoidCallback onChanged;
  final VoidCallback onMutated;
  const _GlobalHeadersEditor({
    required this.headers,
    required this.onChanged,
    required this.onMutated,
  });

  @override
  State<_GlobalHeadersEditor> createState() => _GlobalHeadersEditorState();
}

class _GlobalHeadersEditorState extends State<_GlobalHeadersEditor> {
  late List<MapEntry<String, String>> _pairs;

  @override
  void initState() {
    super.initState();
    _pairs = widget.headers.entries.toList();
  }

  void _sync() {
    widget.headers
      ..clear()
      ..addEntries(_pairs.where((e) => e.key.trim().isNotEmpty));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Global headers (added to every response)',
          trailing: TextButton.icon(
            onPressed: () {
              setState(() => _pairs.add(const MapEntry('', '')));
              widget.onMutated();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
          ),
        ),
        ..._pairs.asMap().entries.map((entry) {
          final i = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: entry.value.key,
                    decoration: const InputDecoration(
                      hintText: 'Header name',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onChanged: (v) {
                      _pairs[i] = MapEntry(v, _pairs[i].value);
                      _sync();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: entry.value.value,
                    decoration: const InputDecoration(
                      hintText: 'Value',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onChanged: (v) {
                      _pairs[i] = MapEntry(_pairs[i].key, v);
                      _sync();
                    },
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() => _pairs.removeAt(i));
                    _sync();
                    widget.onMutated();
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
