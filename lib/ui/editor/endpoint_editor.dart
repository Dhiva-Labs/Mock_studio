import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/mock_project.dart';
import '../../models/mock_response.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/helpers.dart';
import 'response_card.dart';
import 'test_bar.dart';

class EndpointEditor extends StatefulWidget {
  final Endpoint endpoint;
  final MockProject project;
  const EndpointEditor({
    super.key,
    required this.endpoint,
    required this.project,
  });

  @override
  State<EndpointEditor> createState() => _EndpointEditorState();
}

class _EndpointEditorState extends State<EndpointEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _descCtrl;
  Timer? _saveTimer;
  bool _advancedOpen = false;

  Endpoint get ep => widget.endpoint;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: ep.name);
    _pathCtrl = TextEditingController(text: ep.path);
    _descCtrl = TextEditingController(text: ep.description);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save({bool immediate = false}) {
    _saveTimer?.cancel();
    if (immediate) {
      context.read<AppState>().saveProject(widget.project);
      return;
    }
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<AppState>().saveProject(widget.project);
    });
  }

  void _mutate(VoidCallback change, {bool immediate = false}) {
    setState(change);
    _save(immediate: immediate);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final running = app.isRunning(widget.project.id);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _headerRow(scheme),
              const SizedBox(height: 14),
              TestBar(endpoint: ep, project: widget.project, running: running),
              const SizedBox(height: 20),
              _strategySection(scheme, app),
              const SizedBox(height: 18),
              _responsesSection(scheme),
              const SizedBox(height: 18),
              _advancedSection(scheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method selector.
        _MethodDropdown(
          value: ep.method,
          onChanged: (m) => _mutate(() => ep.method = m, immediate: true),
        ),
        const SizedBox(width: 10),
        // Path.
        Expanded(
          flex: 3,
          child: TextField(
            controller: _pathCtrl,
            decoration: InputDecoration(
              hintText: '/users/:id',
              hintStyle: const TextStyle(fontFamily: 'monospace'),
              suffixIcon: IconButton(
                tooltip: 'Path syntax help',
                icon: const Icon(Icons.help_outline, size: 18),
                onPressed: _showPathHelp,
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            onChanged: (v) => _mutate(
              () => ep.path = v.isEmpty || v.startsWith('/') ? v : '/$v',
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Enabled toggle.
        Column(
          children: [
            Switch(
              value: ep.enabled,
              onChanged: (v) => _mutate(() => ep.enabled = v, immediate: true),
            ),
            Text(
              ep.enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _strategySection(ColorScheme scheme, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Endpoint name',
            hintText: 'e.g. Get user by id',
            prefixIcon: Icon(Icons.label_outline, size: 18),
          ),
          onChanged: (v) => _mutate(() => ep.name = v),
        ),
        const SizedBox(height: 16),
        const SectionLabel('How should this endpoint respond?'),
        _StrategySelector(
          value: ep.strategy,
          onChanged: (s) => _mutate(() => ep.strategy = s, immediate: true),
        ),
        if (app.guideMode) ...[
          const SizedBox(height: 10),
          HintCard(ep.strategy.hint),
        ],
      ],
    );
  }

  Widget _responsesSection(ColorScheme scheme) {
    final showConditions = ep.strategy == ResponseStrategy.rules;
    final showWeight = ep.strategy == ResponseStrategy.random;
    final showOrder = ep.strategy == ResponseStrategy.sequence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          ep.strategy == ResponseStrategy.single
              ? 'Response'
              : 'Responses (${ep.responses.length})',
          trailing:
              ep.strategy == ResponseStrategy.single && ep.responses.length <= 1
              ? null
              : TextButton.icon(
                  onPressed: () => _mutate(
                    () => ep.responses.add(
                      MockResponse(
                        label: 'Response ${ep.responses.length + 1}',
                        statusCode: showConditions ? 200 : 200,
                      ),
                    ),
                    immediate: true,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add response'),
                ),
        ),
        ...ep.responses.asMap().entries.map((entry) {
          final i = entry.key;
          final resp = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ResponseCard(
              key: ValueKey(resp.id),
              response: resp,
              index: i,
              showConditions: showConditions,
              showWeight: showWeight,
              showOrder: showOrder,
              canDelete: ep.responses.length > 1,
              onChanged: () => _save(),
              onDelete: () =>
                  _mutate(() => ep.responses.removeAt(i), immediate: true),
              onDuplicate: () => _mutate(
                () => ep.responses.insert(i + 1, resp.copy()),
                immediate: true,
              ),
            ),
          );
        }),
        if (ep.strategy == ResponseStrategy.single && ep.responses.length <= 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () => _mutate(() {
                ep.strategy = ResponseStrategy.rules;
                ep.responses.add(
                  MockResponse(label: 'Alternate response', statusCode: 400),
                );
              }, immediate: true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add another response (switches to conditional rules)',
              ),
            ),
          ),
      ],
    );
  }

  Widget _advancedSection(ColorScheme scheme) {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Text(
                    'Advanced settings',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  if (ep.defaultDelayMs > 0 ||
                      ep.requireAuth ||
                      ep.jitterMs > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'active',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    _advancedOpen ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedOpen) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Latency simulation'),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Base delay (ms)',
                          value: ep.defaultDelayMs,
                          onChanged: (v) =>
                              _mutate(() => ep.defaultDelayMs = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Random jitter (ms)',
                          value: ep.jitterMs,
                          onChanged: (v) => _mutate(() => ep.jitterMs = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Authentication'),
                  Row(
                    children: [
                      Switch(
                        value: ep.requireAuth,
                        onChanged: (v) =>
                            _mutate(() => ep.requireAuth = v, immediate: true),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Require an auth header (returns 401 if missing)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (ep.requireAuth)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        initialValue: ep.authHeader,
                        decoration: const InputDecoration(
                          labelText: 'Required header name',
                        ),
                        onChanged: (v) => _mutate(() => ep.authHeader = v),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const SectionLabel('Description / notes'),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Optional notes about what this endpoint does…',
                    ),
                    onChanged: (v) => _mutate(() => ep.description = v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPathHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Path patterns'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PathHelpRow('/users', 'Matches exactly /users'),
              _PathHelpRow(
                '/users/:id',
                'Captures a segment. :id is available as {{params.id}}',
              ),
              _PathHelpRow('/files/*', 'Matches any single segment'),
              _PathHelpRow('/assets/**', 'Matches the rest of the path'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _MethodDropdown extends StatelessWidget {
  final HttpMethodType value;
  final ValueChanged<HttpMethodType> onChanged;
  const _MethodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.methodColor(value);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HttpMethodType>(
          value: value,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          isDense: true,
          items: HttpMethodType.values
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.methodColor(m),
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (_) => HttpMethodType.values
              .map(
                (m) => Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minWidth: 62),
                  child: Text(
                    value.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (m) => m == null ? null : onChanged(m),
        ),
      ),
    );
  }
}

class _StrategySelector extends StatelessWidget {
  final ResponseStrategy value;
  final ValueChanged<ResponseStrategy> onChanged;
  const _StrategySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ResponseStrategy.values.map((s) {
        final selected = s == value;
        final icon = switch (s) {
          ResponseStrategy.single => Icons.looks_one_outlined,
          ResponseStrategy.rules => Icons.rule_folder_outlined,
          ResponseStrategy.sequence => Icons.repeat,
          ResponseStrategy.random => Icons.shuffle,
        };
        return InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.6)
                  : null,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }
}

class _PathHelpRow extends StatelessWidget {
  final String pattern;
  final String desc;
  const _PathHelpRow(this.pattern, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              pattern,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
