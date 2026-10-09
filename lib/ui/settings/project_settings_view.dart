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
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';

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
    // What this page shows from outside; logged requests don't rebuild it.
    final (_, running, guideMode, recordings, _) = context
        .select<AppState, (String?, bool, bool, bool, String)>((a) {
          final p = a.selectedProject!;
          return (
            p.id,
            a.isRunning(p.id),
            a.guideMode,
            a.pendingRecordings.isNotEmpty,
            p.proxyBaseUrl,
          );
        });
    final app = context.read<AppState>();
    final project = app.selectedProject!;

    return ListView(
      padding: EdgeInsets.all(isPhone(context) ? 12 : 20),
      children: [
        _Card(
          icon: Icons.settings_ethernet,
          title: 'Server',
          help:
              'How this project\'s mock server listens: which port it uses '
              'and whether browser apps may call it.',
          example: 'http://localhost:${project.port}',
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
                  const HelpTip(
                    'The number apps add after the host to reach this mock. '
                    'Pick one from 1024 to 65535 that nothing else uses. It '
                    'can only change while the server is stopped.',
                    title: 'Port',
                    example: '8080 → http://localhost:8080',
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
                title: const LabelWithHelp(
                  'Enable CORS',
                  'Browsers block a web page from calling a server on another '
                      'address unless the server allows it. Keep this on when '
                      'a web app calls this mock.',
                  example: 'a React app on localhost:3000 calling :8080',
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
          help:
              'Lets the mock stand in front of a real API: your endpoints '
              'answer what they match, and everything else goes to the real '
              'server.',
          example: '/payments mocked, /users from the real API',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (guideMode)
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
                  suffixIcon: HelpTip(
                    'A request that matches none of your endpoints is sent on '
                    'to this server, and its real reply is passed back. Leave '
                    'it empty to answer 404 instead.',
                    title: 'Passthrough base URL',
                    example: 'https://api.example.com',
                  ),
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
                title: const LabelWithHelp(
                  'Record proxied responses',
                  'While on, each reply from the real server is listed below. '
                      'Save as mock turns one into an endpoint with the same '
                      'method, path, status and body. Needs a base URL above.',
                  example: 'GET /users 200 → Save as mock',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Capture real responses so you can save them as mock endpoints',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              if (recordings) const _RecordingsPanel(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          icon: Icons.public,
          title: 'Global response settings',
          help:
              'Settings applied to every endpoint in this project at once, on '
              'top of each endpoint\'s own settings.',
          example: 'a delay and a header for all endpoints',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  initialValue: project.globalDelayMs.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Global delay (ms)',
                    helperText: 'Added to every mocked response',
                    suffixIcon: HelpTip(
                      'Extra wait before each endpoint answers, on top of its '
                      'own delay, to see how your app copes with a slow '
                      'network. Proxied and 404 replies are not delayed.',
                      title: 'Global delay',
                      example: '800 = 0.8 s',
                    ),
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
          help:
              'Changes are saved automatically to the file below. To share '
              'the project, use Export to file in the project menu.',
          example: 'payments-api-1a2b3c4d.json',
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
  const _RecordingsPanel();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    context.select<AppState, int>((a) => a.pendingRecordings.length);
    final scheme = Theme.of(context).colorScheme;
    final recordings = app.pendingRecordings;
    final narrow = isPhone(context);
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
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LabelWithHelp(
                    '${recordings.length} recorded response${recordings.length == 1 ? '' : 's'}',
                    'Real replies captured through the proxy. Up to 20 show at a '
                        'time, and saving one as a mock removes it from this list. '
                        'They are kept until you quit or press Clear.',
                    example: 'POST /orders 201 → Save as mock',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
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
                      // Phones: icon only, to leave room for the path.
                      if (narrow)
                        IconButton(
                          tooltip: 'Save as mock',
                          onPressed: () => _saveAsMock(context, app, rec),
                          icon: const Icon(Icons.save_outlined, size: 18),
                        )
                      else
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

  /// Stable row keys: removing a row must not shift text into the next.
  late List<Key> _keys;

  @override
  void initState() {
    super.initState();
    _pairs = widget.headers.entries.toList();
    _keys = [for (final _ in _pairs) UniqueKey()];
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LabelWithHelp(
                    'Global headers (added to every response)'.toUpperCase(),
                    'Headers sent with every reply from your endpoints. '
                    "Proxied replies don't get them.",
                    example: 'Cache-Control: no-store',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _pairs.add(const MapEntry('', ''));
                    _keys.add(UniqueKey());
                  });
                  widget.onMutated();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        ..._pairs.asMap().entries.map((entry) {
          final i = entry.key;
          final name = TextFormField(
            initialValue: entry.value.key,
            decoration: const InputDecoration(
              hintText: 'Header name',
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            onChanged: (v) {
              _pairs[i] = MapEntry(v, _pairs[i].value);
              _sync();
            },
          );
          final value = TextFormField(
            initialValue: entry.value.value,
            decoration: const InputDecoration(hintText: 'Value', isDense: true),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            onChanged: (v) {
              _pairs[i] = MapEntry(_pairs[i].key, v);
              _sync();
            },
          );
          final remove = IconButton(
            tooltip: 'Remove header',
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _pairs.removeAt(i);
                _keys.removeAt(i);
              });
              _sync();
              widget.onMutated();
            },
          );
          return Padding(
            key: _keys[i],
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 400
                  ? Row(
                      children: [
                        Expanded(flex: 2, child: name),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: value),
                        remove,
                      ],
                    )
                  // Narrow: name and remove button above, value below.
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: name),
                            remove,
                          ],
                        ),
                        const SizedBox(height: 6),
                        value,
                      ],
                    ),
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
  final String? help;
  final String? example;
  final Widget child;
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.help,
    this.example,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isPhone(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: help == null
                      ? Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        )
                      : LabelWithHelp(
                          title,
                          help!,
                          example: example,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
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
