import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/load_flow.dart';
import '../../models/mock_project.dart';
import '../../state/app_state.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';
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
    // Rebuild when the list of flows changes, not on every logged request.
    context.select<AppState, (String?, int)>((a) {
      final p = a.selectedProject;
      return (
        p?.id,
        Object.hashAll([
          for (final f in p?.flows ?? const <LoadFlow>[])
            Object.hash(f.id, f.name, f.steps.length, f.virtualUsers),
        ]),
      );
    });
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final flows = project.flows;
    final selected =
        flows.where((f) => f.id == _selectedId).firstOrNull ??
        flows.firstOrNull;
    void select(String id) => setState(() => _selectedId = id);
    final editor = selected == null
        ? _EmptyFlows(onCreate: (f) => select(f.id))
        : _FlowEditor(
            key: ValueKey(selected.id),
            project: project,
            flow: selected,
          );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 640) {
          // Phones and narrow windows: pick the flow from a bar on top.
          return Column(
            children: [
              _FlowPicker(
                project: project,
                selected: selected,
                onSelect: select,
              ),
              const Divider(height: 1),
              Expanded(child: editor),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 240,
              child: _FlowList(
                project: project,
                selectedId: selected?.id,
                onSelect: select,
              ),
            ),
            Container(
              width: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            Expanded(child: editor),
          ],
        );
      },
    );
  }
}

/// The "+" menu: a blank flow or one built from every endpoint.
Widget _newFlowButton(BuildContext context, ValueChanged<String> onSelect) =>
    PopupMenuButton<bool>(
      tooltip: 'New flow',
      icon: const Icon(Icons.add),
      onSelected: (fromEndpoints) async {
        final f = await _createFlow(context, fromEndpoints: fromEndpoints);
        onSelect(f.id);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: false,
          child: _blankFlowHover(
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.note_add_outlined),
              title: Text('Blank flow'),
            ),
          ),
        ),
        PopupMenuItem(
          value: true,
          child: _fromEndpointsHover(
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.playlist_add),
              title: Text('From all endpoints'),
            ),
          ),
        ),
      ],
    );

/// Duplicate or delete [flow].
Widget _flowActions(
  AppState app,
  MockProject project,
  LoadFlow flow,
  ValueChanged<String> onSelect,
) => PopupMenuButton<String>(
  tooltip: 'Duplicate or delete this flow',
  icon: const Icon(Icons.more_horiz, size: 18),
  onSelected: (v) async {
    if (v == 'dup') {
      final copy = await app.addFlow(project, flow.copy());
      onSelect(copy.id);
    } else if (v == 'del') {
      await app.deleteFlow(project, flow);
    }
  },
  itemBuilder: (_) => const [
    PopupMenuItem(value: 'dup', child: Text('Duplicate')),
    PopupMenuItem(value: 'del', child: Text('Delete')),
  ],
);

/// Narrow layouts: the flow list as a drop-down with the same actions.
class _FlowPicker extends StatelessWidget {
  final MockProject project;
  final LoadFlow? selected;
  final ValueChanged<String> onSelect;
  const _FlowPicker({
    required this.project,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final flow = selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          if (flow == null)
            Expanded(
              child: _sectionLabel(
                context,
                'Flows',
                'A flow is a load test for your own mocks. Many virtual users '
                    'call your endpoints at the same time, and you see how '
                    'fast and how reliably they answer.',
                example: '50 users log in, then GET /orders, 20 times each',
              ),
            )
          else ...[
            ListenableBuilder(
              listenable: app.flowSession(flow.id),
              builder: (context, _) {
                final running = app.isFlowRunning(flow.id);
                return Icon(
                  running ? Icons.bolt : Icons.account_tree_outlined,
                  size: 18,
                  color: running ? scheme.primary : scheme.onSurfaceVariant,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: flow.id,
                  isExpanded: true,
                  items: [
                    for (final f in project.flows)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                  onChanged: (id) => id == null ? null : onSelect(id),
                ),
              ),
            ),
            _flowActions(app, project, flow, onSelect),
          ],
          _newFlowButton(context, onSelect),
        ],
      ),
    );
  }
}

Widget _fromEndpointsHover({required Widget child}) => HelpHover(
  'Adds one step for every enabled endpoint, so you can load-test the whole '
  'mock at once. Path parameters are filled with the virtual user number.',
  title: 'Build from endpoints',
  example: '/users/:id becomes /users/{{vu}}',
  child: child,
);

Widget _blankFlowHover({required Widget child}) => HelpHover(
  'Starts with a single step that you edit or add to.',
  title: 'Blank flow',
  example: 'GET /health',
  child: child,
);

/// Same look as [SectionLabel], with a help icon beside the text.
Widget _sectionLabel(
  BuildContext context,
  String text,
  String help, {
  String? example,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        HelpTip(help, title: text, example: example, size: 14),
      ],
    ),
  );
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
              Expanded(
                child: _sectionLabel(
                  context,
                  'Flows',
                  'A flow is a load test for your own mocks. Many virtual '
                      'users call your endpoints at the same time, and you see '
                      'how fast and how reliably they answer.',
                  example: '50 users log in, then GET /orders, 20 times each',
                ),
              ),
              _newFlowButton(context, onSelect),
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
                        subtitle: HelpHover(
                          'How many requests one round has, and how many '
                          'simulated users (VU, virtual users) run it at the '
                          'same time.',
                          title: 'Steps and virtual users',
                          example: '3 steps · 50 VU',
                          child: Text(
                            '${f.steps.length} step${f.steps.length == 1 ? '' : 's'}'
                            ' · ${f.virtualUsers} VU${running ? ' · running' : ''}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        onTap: () => onSelect(f.id),
                        trailing: _flowActions(app, project, f, onSelect),
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
                _fromEndpointsHover(
                  child: FilledButton.icon(
                    onPressed: () async => onCreate(
                      await _createFlow(context, fromEndpoints: true),
                    ),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Build from endpoints'),
                  ),
                ),
                _blankFlowHover(
                  child: OutlinedButton.icon(
                    onPressed: () async => onCreate(
                      await _createFlow(context, fromEndpoints: false),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Blank flow'),
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
      padding: EdgeInsets.all(isPhone(context) ? 12 : 20),
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: flow.name,
                decoration: const InputDecoration(
                  labelText: 'Flow name',
                  suffixIcon: HelpTip(
                    'A label for this flow in the list on the left.',
                    title: 'Flow name',
                    example: 'Checkout journey',
                  ),
                ),
                onChanged: (v) => _mutate(() => flow.name = v, rebuild: false),
              ),
            ),
            const SizedBox(width: 12),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => session.isRunning
                  ? HelpHover(
                      'Ends the run early. Requests already in flight finish, '
                      'and the results so far stay on screen.',
                      title: 'Stop the run',
                      child: FilledButton.tonalIcon(
                        onPressed: session.stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                      ),
                    )
                  : HelpHover(
                      flow.steps.any((s) => s.enabled)
                          ? 'Starts the load test with the settings below. If '
                                'it targets this project and the server is '
                                'stopped, the server is started for you.'
                          : 'Add or enable at least one step first.',
                      title: 'Run flow',
                      child: FilledButton.icon(
                        onPressed: flow.steps.any((s) => s.enabled)
                            ? () => _run(app)
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Run flow'),
                      ),
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
          help:
              'How much traffic to send: how many users, for how long, and how '
              'quickly they join.',
          example: '50 users for 30 s, joining over 10 s',
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
          help:
              'The requests each virtual user makes in one round (an '
              'iteration), top to bottom. Untick a step to skip it without '
              'deleting it.',
          example: 'POST /login, then GET /orders',
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
          help:
              'Live numbers from the latest run. They reset when you run the '
              'flow again and are not saved.',
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
  String? help,
  String? example,
  Widget? trailing,
}) {
  final scheme = Theme.of(context).colorScheme;
  final side = isPhone(context) ? 12.0 : 16.0;
  return Container(
    padding: EdgeInsets.fromLTRB(side, 12, side, 16),
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
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: help == null
                    ? Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : LabelWithHelp(
                        title,
                        help,
                        example: example,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
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
    required String help,
    String? example,
    String? helper,
    int max = 100000,
    double width = 160,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          suffixIcon: HelpTip(help, title: label, example: example),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 30,
          ),
        ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    // Two fields per line, or one on very narrow screens.
    builder: (context, box) =>
        _build(context, box.maxWidth < 332 ? box.maxWidth : 160),
  );

  Widget _build(BuildContext context, double w) {
    final modes = SegmentedButton<StepMode>(
      segments: [
        for (final m in StepMode.values)
          ButtonSegment(
            value: m,
            label: _modeHover(m, Text(m.label)),
            icon: _modeHover(
              m,
              Icon(
                m == StepMode.sequential
                    ? Icons.linear_scale
                    : Icons.call_split,
              ),
            ),
          ),
      ],
      selected: {flow.mode},
      onSelectionChanged: (s) => onChanged(() => flow.mode = s.first),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _num(
              width: w,
              'Virtual users',
              flow.virtualUsers,
              (v) => flow.virtualUsers = v < 1 ? 1 : v,
              helper: 'Run at the same time',
              max: 1000,
              help:
                  'How many simulated users run the steps at the same time, '
                  'from 1 to 1000. Each one repeats the whole list of steps.',
              example: '50',
            ),
            _num(
              width: w,
              'Iterations / user',
              flow.iterations,
              (v) => flow.iterations = v < 1 ? 1 : v,
              helper: flow.durationSec > 0 ? 'Ignored (duration set)' : null,
              help:
                  'How many rounds each user makes through all the steps. '
                  'Ignored when a duration is set.',
              example: '5 users × 10 iterations × 3 steps = 150 requests',
            ),
            _num(
              width: w,
              'Duration (s)',
              flow.durationSec,
              (v) => flow.durationSec = v,
              helper: '0 = use iterations',
              help:
                  'Run for this many seconds instead of a set number of '
                  'iterations. Users repeat the steps until time is up; '
                  'ramp-up counts toward it.',
              example: '30 (0 = use iterations)',
            ),
            _num(
              width: w,
              'Ramp-up (s)',
              flow.rampUpSec,
              (v) => flow.rampUpSec = v,
              helper: 'Stagger user starts',
              help:
                  'Spread user start times over this many seconds instead of '
                  'starting everyone at once, to see how the mock copes as '
                  'load grows.',
              example: '10 users over 10 s = 1 new user per second',
            ),
            _num(
              width: w,
              'Think time (ms)',
              flow.thinkTimeMs,
              (v) => flow.thinkTimeMs = v,
              helper: 'Pause between steps',
              help:
                  'How long each user waits after a step, like a person '
                  'reading a page. In "All at once" mode the pause comes after '
                  'each round instead.',
              example: '500 = half a second',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Scrolls sideways if even one line is too narrow for it.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: modes,
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
                  const Flexible(
                    child: LabelWithHelp(
                      'Stop iteration on first failed step',
                      'When a step fails, the user skips the rest of that round '
                          'and starts the next one. Use it when later steps '
                          'depend on an earlier one.',
                      example: 'login fails, so GET /orders is skipped',
                    ),
                  ),
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
            suffixIcon: const HelpTip(
              'The address each step\'s path is added to. Leave it empty to '
              'test this project\'s mock. A step whose path is a full '
              'http:// or https:// URL ignores it.',
              title: 'Target base URL',
              example: 'http://localhost:3000 + /users',
            ),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          onChanged: (v) => onChanged(() => flow.targetUrl = v, rebuild: false),
        ),
      ],
    );
  }
}

Widget _modeHover(StepMode mode, Widget child) => mode == StepMode.sequential
    ? HelpHover(
        'Runs the steps in order, each waiting for the previous reply. A '
        'later step can use values extracted from an earlier one.',
        title: 'One by one',
        example: 'POST /login, then GET /me with {{vars.token}}',
        child: child,
      )
    : HelpHover(
        'Sends every step of a round at the same moment, to test bursts of '
        'parallel calls. Extracted values are not passed between steps.',
        title: 'All at once',
        example: 'GET /a, /b and /c together',
        child: child,
      );

class _AddStepButton extends StatelessWidget {
  final List<Endpoint> endpoints;
  final ValueChanged<FlowStep> onAdd;
  const _AddStepButton({required this.endpoints, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Endpoint?>(
      tooltip: 'Add a step from one of your endpoints or a custom request',
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
          child: HelpHover(
            'A blank step you fill in yourself, for example to call a path or '
            'URL that is not one of your endpoints.',
            title: 'Custom request',
            example: 'GET https://example.com/health',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.add),
              title: Text('Custom request'),
            ),
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: isPhone(context) ? 12 : 4,
        ),
        child: const Row(
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
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 600;
          return Column(
            children: [
              if (narrow) ..._narrowHeader(context) else _wideHeader(context),
              if (_open) _details(narrow: box.maxWidth < 480),
            ],
          );
        },
      ),
    );
  }

  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12.5);

  Widget _order(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    return HelpHover(
      widget.sequential
          ? 'Steps run in this order. Use the arrows to move one.'
          : 'In "All at once" mode steps have no order; they all start '
                'together.',
      title: 'Step order',
      child: SizedBox(
        width: width,
        child: Text(
          widget.sequential ? '${widget.index + 1}' : '•',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _enabled() => HelpHover(
    'Include this step in runs. Untick it to skip the step without deleting '
    'it.',
    title: 'Step enabled',
    child: Checkbox(
      value: step.enabled,
      onChanged: (v) => widget.onChanged(() => step.enabled = v ?? true),
    ),
  );

  Widget _method(BuildContext context) => DropdownButton<String>(
    value: _methods.contains(step.method) ? step.method : 'GET',
    underline: const SizedBox.shrink(),
    // Full height as a touch target on phones.
    isDense: !isPhone(context),
    items: [
      for (final m in _methods)
        DropdownMenuItem(
          value: m,
          child: HelpHover(
            httpMethodHelp(m).message,
            title: httpMethodHelp(m).title,
            child: Text(
              m,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
    ],
    onChanged: (v) => widget.onChanged(() => step.method = v!),
  );

  Widget _path() => TextFormField(
    initialValue: step.path,
    decoration: const InputDecoration(
      isDense: true,
      hintText: '/path/{{vars.id}}',
      suffixIcon: HelpTip(
        'Added to the target URL. Use {{vars.name}} for a value extracted '
        'earlier, {{vu}} for the user number, {{iteration}} for the round, '
        'or tokens like {{uuid}}.',
        title: 'Path',
        example: '/orders/{{vars.orderId}}',
      ),
      suffixIconConstraints: BoxConstraints(minWidth: 30, minHeight: 30),
    ),
    style: _mono,
    onChanged: (v) => widget.onChanged(() => step.path = v, rebuild: false),
  );

  Widget _expect() => TextFormField(
    initialValue: step.expectStatus,
    decoration: const InputDecoration(
      isDense: true,
      hintText: 'any < 400',
      label: LabelWithHelp(
        'Expect',
        'Status codes that count as success. Leave it empty to accept '
            'anything below 400; any other code counts as failed.',
        example: '200, 2xx or 200,201,404',
      ),
    ),
    style: _mono,
    onChanged: (v) =>
        widget.onChanged(() => step.expectStatus = v, rebuild: false),
  );

  Widget _expandButton() => IconButton(
    tooltip: _open ? 'Hide details' : 'Show name, headers, body and extract',
    icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
    onPressed: () => setState(() => _open = !_open),
  );

  /// One line: everything side by side.
  Widget _wideHeader(BuildContext context) => Row(
    children: [
      _order(context, 26),
      _enabled(),
      _method(context),
      const SizedBox(width: 8),
      Expanded(child: _path()),
      const SizedBox(width: 8),
      SizedBox(width: 96, child: _expect()),
      _expandButton(),
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
  );

  /// Narrow: order, checkbox, method and actions on top; path and expected
  /// status below. Moving and removing go in a menu.
  List<Widget> _narrowHeader(BuildContext context) => [
    Row(
      children: [
        _order(context, 22),
        _enabled(),
        _method(context),
        const Spacer(),
        _expandButton(),
        PopupMenuButton<String>(
          tooltip: 'Move or remove this step',
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) => switch (v) {
            'up' => widget.onMove(-1),
            'down' => widget.onMove(1),
            _ => widget.onDelete(),
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'up',
              enabled: widget.index > 0,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_upward),
                title: Text('Move up'),
              ),
            ),
            PopupMenuItem(
              value: 'down',
              enabled: widget.index < widget.count - 1,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_downward),
                title: Text('Move down'),
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline),
                title: Text('Remove step'),
              ),
            ),
          ],
        ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Row(
        children: [
          Expanded(child: _path()),
          const SizedBox(width: 8),
          SizedBox(width: 96, child: _expect()),
        ],
      ),
    ),
  ];

  Widget _details({required bool narrow}) => Padding(
    padding: EdgeInsets.fromLTRB(narrow ? 4 : 34, 8, narrow ? 4 : 8, 6),
    child: Column(
      children: [
        TextFormField(
          initialValue: step.name,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Step name (optional)',
            suffixIcon: HelpTip(
              'Shown in the results table. Leave it empty to use the method '
              'and path.',
              title: 'Step name',
              example: 'Log in',
            ),
          ),
          onChanged: (v) =>
              widget.onChanged(() => step.name = v, rebuild: false),
        ),
        const SizedBox(height: 10),
        AdaptivePair(
          minWidth: 440,
          spacing: 10,
          first: TextFormField(
            initialValue: _linesOf(step.headers, ': '),
            minLines: 3,
            maxLines: 6,
            style: _mono,
            decoration: const InputDecoration(
              label: LabelWithHelp(
                'Headers',
                'Request headers, one per line as Name: value. Values can use '
                    '{{vars.name}}, {{vu}} and tokens like {{uuid}}.',
                example: 'Authorization: Bearer {{vars.token}}',
              ),
              hintText: 'Authorization: Bearer {{vars.token}}',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => widget.onChanged(
              () => step.headers = _parseLines(v, ':'),
              rebuild: false,
            ),
          ),
          second: TextFormField(
            initialValue: _linesOf(step.extract, ' = '),
            minLines: 3,
            maxLines: 6,
            style: _mono,
            decoration: InputDecoration(
              label: const LabelWithHelp(
                'Extract into variables',
                'Saves values from this step\'s reply for later steps, one per '
                    'line as name = source. Source is body.<path>, '
                    'header.<name> or status. Values reset each iteration.',
                example: 'token = body.token, then {{vars.token}}',
              ),
              hintText:
                  'token = body.token\nid = body.items.0.id\netag = header.etag',
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
        const SizedBox(height: 10),
        TextFormField(
          initialValue: step.body,
          minLines: 3,
          maxLines: 10,
          style: _mono,
          decoration: const InputDecoration(
            label: LabelWithHelp(
              'Body',
              'Data sent with the request. A body starting with { or [ is '
                  'sent as JSON unless Headers set a Content-Type. Tokens like '
                  '{{vars.name}} work here.',
              example: '{"email": "{{faker.email}}"}',
            ),
            hintText: '{"email": "{{faker.email}}"}',
            alignLabelWithHint: true,
          ),
          onChanged: (v) =>
              widget.onChanged(() => step.body = v, rebuild: false),
        ),
      ],
    ),
  );
}
