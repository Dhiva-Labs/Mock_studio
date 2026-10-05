import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/load_flow.dart';
import '../../models/mock_project.dart';
import '../../state/app_state.dart';
import '../widgets/helpers.dart';
import 'flow_results.dart';

/// Flows: scripted multi-endpoint journeys run by many concurrent virtual
/// users, with live latency / throughput statistics.
class FlowsView extends StatefulWidget {
  const FlowsView({super.key});

  @override
  State<FlowsView> createState() => _FlowsViewState();
}

class _FlowsViewState extends State<FlowsView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final flows = project.flows;
    final selected =
        flows.where((f) => f.id == _selectedId).firstOrNull ??
        flows.firstOrNull;

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: _FlowList(
            project: project,
            selectedId: selected?.id,
            onSelect: (id) => setState(() => _selectedId = id),
          ),
        ),
        Container(
          width: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        Expanded(
          child: selected == null
              ? _EmptyFlows(onCreate: (f) => setState(() => _selectedId = f.id))
              : _FlowEditor(
                  key: ValueKey(selected.id),
                  project: project,
                  flow: selected,
                ),
        ),
      ],
    );
  }
}

Future<LoadFlow> _createFlow(
  BuildContext context, {
  required bool fromEndpoints,
}) {
  final app = context.read<AppState>();
  final project = app.selectedProject!;
  final flow = fromEndpoints
      ? AppState.flowFromEndpoints(project)
      : LoadFlow(
          name: 'Flow ${project.flows.length + 1}',
          steps: [FlowStep(path: '/health')],
        );
  return app.addFlow(project, flow);
}

class _FlowList extends StatelessWidget {
  final MockProject project;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _FlowList({
    required this.project,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
          child: Row(
            children: [
              const Expanded(child: SectionLabel('Flows')),
              PopupMenuButton<bool>(
                tooltip: 'New flow',
                icon: const Icon(Icons.add),
                onSelected: (fromEndpoints) async {
                  final f = await _createFlow(
                    context,
                    fromEndpoints: fromEndpoints,
                  );
                  onSelect(f.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: false,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.note_add_outlined),
                      title: Text('Blank flow'),
                    ),
                  ),
                  PopupMenuItem(
                    value: true,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.playlist_add),
                      title: Text('From all endpoints'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final f in project.flows)
                ListenableBuilder(
                  listenable: app.flowSession(f.id),
                  builder: (context, _) {
                    final running = app.isFlowRunning(f.id);
                    final sel = f.id == selectedId;
                    return Material(
                      color: sel
                          ? scheme.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        leading: Icon(
                          running ? Icons.bolt : Icons.account_tree_outlined,
                          size: 18,
                          color: running ? scheme.primary : null,
                        ),
                        title: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${f.steps.length} step${f.steps.length == 1 ? '' : 's'}'
                          ' · ${f.virtualUsers} VU${running ? ' · running' : ''}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onTap: () => onSelect(f.id),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'More',
                          icon: const Icon(Icons.more_horiz, size: 18),
                          onSelected: (v) async {
                            if (v == 'dup') {
                              final copy = await app.addFlow(project, f.copy());
                              onSelect(copy.id);
                            } else if (v == 'del') {
                              await app.deleteFlow(project, f);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'dup',
                              child: Text('Duplicate'),
                            ),
                            PopupMenuItem(value: 'del', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyFlows extends StatelessWidget {
  final ValueChanged<LoadFlow> onCreate;
  const _EmptyFlows({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 14),
            Text('No flows yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'A flow calls several endpoints in order, like a real user '
              'journey, while many virtual users run it at the same time. '
              'Use it to test realistic, concurrent traffic.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () async =>
                      onCreate(await _createFlow(context, fromEndpoints: true)),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Build from endpoints'),
                ),
                OutlinedButton.icon(
                  onPressed: () async => onCreate(
                    await _createFlow(context, fromEndpoints: false),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Blank flow'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowEditor extends StatefulWidget {
  final MockProject project;
  final LoadFlow flow;
  const _FlowEditor({super.key, required this.project, required this.flow});

  @override
  State<_FlowEditor> createState() => _FlowEditorState();
}

class _FlowEditorState extends State<_FlowEditor> {
  Timer? _saveTimer;

  LoadFlow get flow => widget.flow;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _mutate(VoidCallback change, {bool rebuild = true}) {
    rebuild ? setState(change) : change();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<AppState>().saveProject(widget.project);
    });
  }

  Future<void> _run(AppState app) async {
    final project = widget.project;
    if (flow.targetUrl.trim().isEmpty && !app.isRunning(project.id)) {
      final err = await app.startServer(project);
      if (err != null) {
        if (mounted) showToast(context, err, error: true);
        return;
      }
      if (mounted) showToast(context, 'Started the mock server for this run');
    }
    await app.flowSession(flow.id).start(flow, app.flowBaseUrl(project, flow));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final session = app.flowSession(flow.id);
    final guide = context.select<AppState, bool>((a) => a.guideMode);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: flow.name,
                decoration: const InputDecoration(labelText: 'Flow name'),
                onChanged: (v) => _mutate(() => flow.name = v, rebuild: false),
              ),
            ),
            const SizedBox(width: 12),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => session.isRunning
                  ? FilledButton.tonalIcon(
                      onPressed: session.stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    )
                  : FilledButton.icon(
                      onPressed: flow.steps.any((s) => s.enabled)
                          ? () => _run(app)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run flow'),
                    ),
            ),
          ],
        ),
        if (guide) ...[
          const SizedBox(height: 12),
          const HintCard(
            'Each virtual user runs the steps below. "One by one" mimics a '
            'real user journey: capture a value with Extract (e.g. token = '
            'body.token) and reuse it later as {{vars.token}}. "All at once" '
            'fires every step simultaneously. {{vu}} and {{iteration}} are '
            'also available, plus the usual {{uuid}} / {{faker.*}} tokens.',
          ),
        ],
        const SizedBox(height: 16),
        _section(
          context,
          icon: Icons.speed,
          title: 'Load profile',
          child: _LoadProfile(
            flow: flow,
            port: widget.project.port,
            onChanged: _mutate,
          ),
        ),
        const SizedBox(height: 14),
        _section(
          context,
          icon: Icons.format_list_numbered,
          title: 'Steps',
          trailing: _AddStepButton(
            endpoints: widget.project.endpoints,
            onAdd: (s) => _mutate(() => flow.steps.add(s)),
          ),
          child: Column(
            children: [
              if (flow.steps.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No steps yet — add one from your endpoints.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (var i = 0; i < flow.steps.length; i++)
                _StepCard(
                  key: ValueKey(flow.steps[i].id),
                  index: i,
                  count: flow.steps.length,
                  step: flow.steps[i],
                  sequential: flow.mode == StepMode.sequential,
                  onChanged: _mutate,
                  onMove: (delta) => _mutate(() {
                    final s = flow.steps.removeAt(i);
                    flow.steps.insert(i + delta, s);
                  }),
                  onDelete: () => _mutate(() => flow.steps.removeAt(i)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _section(
          context,
          icon: Icons.insights,
          title: 'Results',
          child: FlowResults(session: session),
        ),
      ],
    );
  }
}

Widget _section(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget child,
  Widget? trailing,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _LoadProfile extends StatelessWidget {
  final LoadFlow flow;
  final int port;
  final void Function(VoidCallback change, {bool rebuild}) onChanged;
  const _LoadProfile({
    required this.flow,
    required this.port,
    required this.onChanged,
  });

  Widget _num(
    String label,
    int value,
    ValueChanged<int> set, {
    String? helper,
    int max = 100000,
  }) {
    return SizedBox(
      width: 150,
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label, helperText: helper),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(() => set(n.clamp(0, max)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _num(
              'Virtual users',
              flow.virtualUsers,
              (v) => flow.virtualUsers = v < 1 ? 1 : v,
              helper: 'Run at the same time',
              max: 1000,
            ),
            _num(
              'Iterations / user',
              flow.iterations,
              (v) => flow.iterations = v < 1 ? 1 : v,
              helper: flow.durationSec > 0 ? 'Ignored (duration set)' : null,
            ),
            _num(
              'Duration (s)',
              flow.durationSec,
              (v) => flow.durationSec = v,
              helper: '0 = use iterations',
            ),
            _num(
              'Ramp-up (s)',
              flow.rampUpSec,
              (v) => flow.rampUpSec = v,
              helper: 'Stagger user starts',
            ),
            _num(
              'Think time (ms)',
              flow.thinkTimeMs,
              (v) => flow.thinkTimeMs = v,
              helper: 'Pause between steps',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<StepMode>(
              segments: [
                for (final m in StepMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(m.label),
                    icon: Icon(
                      m == StepMode.sequential
                          ? Icons.linear_scale
                          : Icons.call_split,
                    ),
                  ),
              ],
              selected: {flow.mode},
              onSelectionChanged: (s) => onChanged(() => flow.mode = s.first),
            ),
            if (flow.mode == StepMode.sequential)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: flow.stopOnFailure,
                    onChanged: (v) => onChanged(() => flow.stopOnFailure = v),
                  ),
                  const SizedBox(width: 6),
                  const Text('Stop iteration on first failed step'),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: flow.targetUrl,
          decoration: InputDecoration(
            labelText: 'Target base URL',
            hintText: 'http://127.0.0.1:$port  (this project\'s mock server)',
            helperText:
                'Leave empty to hit this project. Set a URL to load-test '
                'another server or a real API you own.',
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          onChanged: (v) => onChanged(() => flow.targetUrl = v, rebuild: false),
        ),
      ],
    );
  }
}

class _AddStepButton extends StatelessWidget {
  final List<Endpoint> endpoints;
  final ValueChanged<FlowStep> onAdd;
  const _AddStepButton({required this.endpoints, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Endpoint?>(
      tooltip: 'Add step',
      onSelected: (ep) => onAdd(
        ep == null
            ? FlowStep(path: '/')
            : FlowStep(
                name: ep.name,
                method: ep.method == HttpMethodType.any
                    ? 'GET'
                    : ep.method.label,
                path: ep.normalizedPath.replaceAllMapped(
                  RegExp(r':([A-Za-z0-9_]+)'),
                  (_) => '{{vu}}',
                ),
                headers: ep.requireAuth ? {ep.authHeader: 'Bearer test'} : {},
              ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: null,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.add),
            title: Text('Custom request'),
          ),
        ),
        if (endpoints.isNotEmpty) const PopupMenuDivider(),
        for (final ep in endpoints)
          PopupMenuItem(
            value: ep,
            child: Text(
              '${ep.method.label}  ${ep.normalizedPath}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 4),
            Text('Add step'),
          ],
        ),
      ),
    );
  }
}

const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'];

class _StepCard extends StatefulWidget {
  final int index;
  final int count;
  final FlowStep step;
  final bool sequential;
  final void Function(VoidCallback change, {bool rebuild}) onChanged;
  final ValueChanged<int> onMove;
  final VoidCallback onDelete;
  const _StepCard({
    super.key,
    required this.index,
    required this.count,
    required this.step,
    required this.sequential,
    required this.onChanged,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _open = false;

  FlowStep get step => widget.step;

  static String _linesOf(Map<String, String> m, String sep) =>
      m.entries.map((e) => '${e.key}$sep${e.value}').join('\n');

  static Map<String, String> _parseLines(String text, String sep) {
    final out = <String, String>{};
    for (final line in text.split('\n')) {
      final i = line.indexOf(sep);
      if (i <= 0) continue;
      final k = line.substring(0, i).trim();
      if (k.isNotEmpty) out[k] = line.substring(i + sep.length).trim();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: step.enabled ? 0.35 : 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  widget.sequential ? '${widget.index + 1}' : '•',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Checkbox(
                value: step.enabled,
                onChanged: (v) =>
                    widget.onChanged(() => step.enabled = v ?? true),
              ),
              DropdownButton<String>(
                value: _methods.contains(step.method) ? step.method : 'GET',
                underline: const SizedBox.shrink(),
                isDense: true,
                items: [
                  for (final m in _methods)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        m,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) => widget.onChanged(() => step.method = v!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: step.path,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '/path/{{vars.id}}',
                  ),
                  style: mono,
                  onChanged: (v) =>
                      widget.onChanged(() => step.path = v, rebuild: false),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: TextFormField(
                  initialValue: step.expectStatus,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'any < 400',
                    labelText: 'Expect',
                  ),
                  style: mono,
                  onChanged: (v) => widget.onChanged(
                    () => step.expectStatus = v,
                    rebuild: false,
                  ),
                ),
              ),
              IconButton(
                tooltip: _open ? 'Hide details' : 'Headers, body & extract',
                icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _open = !_open),
              ),
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: widget.index > 0 ? () => widget.onMove(-1) : null,
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward, size: 18),
                onPressed: widget.index < widget.count - 1
                    ? () => widget.onMove(1)
                    : null,
              ),
              IconButton(
                tooltip: 'Remove step',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 8, 8, 6),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: step.name,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Step name (optional)',
                    ),
                    onChanged: (v) =>
                        widget.onChanged(() => step.name = v, rebuild: false),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _linesOf(step.headers, ': '),
                          minLines: 3,
                          maxLines: 6,
                          style: mono,
                          decoration: const InputDecoration(
                            labelText: 'Headers',
                            hintText: 'Authorization: Bearer {{vars.token}}',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (v) => widget.onChanged(
                            () => step.headers = _parseLines(v, ':'),
                            rebuild: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: _linesOf(step.extract, ' = '),
                          minLines: 3,
                          maxLines: 6,
                          style: mono,
                          decoration: InputDecoration(
                            labelText: 'Extract into variables',
                            hintText:
                                'token = body.token\nid = body.items.0.id\n'
                                'etag = header.etag',
                            helperText: widget.sequential
                                ? null
                                : 'Only useful in "One by one" mode',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (v) => widget.onChanged(
                            () => step.extract = _parseLines(v, '='),
                            rebuild: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: step.body,
                    minLines: 3,
                    maxLines: 10,
                    style: mono,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      hintText: '{"email": "{{faker.email}}"}',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (v) =>
                        widget.onChanged(() => step.body = v, rebuild: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
