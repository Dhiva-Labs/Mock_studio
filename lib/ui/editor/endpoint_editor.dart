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
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';
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
    // Only what the editor shows from outside: request logs and edits
    // elsewhere don't rebuild it. The enabled flag can also be flipped from
    // the endpoint list's menu.
    final (running, guideMode, _) = context
        .select<AppState, (bool, bool, bool)>(
          (a) => (a.isRunning(widget.project.id), a.guideMode, ep.enabled),
        );
    final scheme = Theme.of(context).colorScheme;
    final pad = isPhone(context) ? 12.0 : 20.0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 40),
            children: [
              _headerRow(scheme),
              const SizedBox(height: 14),
              TestBar(endpoint: ep, project: widget.project, running: running),
              const SizedBox(height: 20),
              _strategySection(scheme, guideMode),
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
    final methodHelp = httpMethodHelp(ep.method.label);
    final method = HelpHover(
      'The request method this endpoint answers. '
      '${methodHelp.title}: ${methodHelp.message}',
      title: 'HTTP method',
      example: '${ep.method.label} ${ep.normalizedPath}',
      child: _MethodDropdown(
        value: ep.method,
        onChanged: (m) => _mutate(() => ep.method = m, immediate: true),
      ),
    );
    final path = TextField(
      controller: _pathCtrl,
      decoration: InputDecoration(
        hintText: '/users/:id',
        hintStyle: const TextStyle(fontFamily: 'monospace'),
        suffixIcon: HelpHover(
          'The path clients call. :id captures one segment, * matches '
          'any single segment and ** matches the rest. Click to see '
          'all patterns.',
          title: 'URL path',
          example: '/users/:id matches /users/42',
          child: IconButton(
            icon: const Icon(Icons.help_outline, size: 18),
            onPressed: _showPathHelp,
          ),
        ),
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      onChanged: (v) =>
          _mutate(() => ep.path = v.isEmpty || v.startsWith('/') ? v : '/$v'),
    );
    final enabledHelp =
        'When off, the server ignores this endpoint without deleting it, '
        "and requests are handled as if it didn't exist.";
    final enabledLabel = Text(
      ep.enabled ? 'Enabled' : 'Disabled',
      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
    );
    final toggle = Switch(
      value: ep.enabled,
      onChanged: (v) => _mutate(() => ep.enabled = v, immediate: true),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 480) {
          // Phones: method and switch on one line, the path under them.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  method,
                  const Spacer(),
                  HelpHover(
                    enabledHelp,
                    title: 'Enabled',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        enabledLabel,
                        const SizedBox(width: 6),
                        toggle,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              path,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            method,
            const SizedBox(width: 10),
            Expanded(flex: 3, child: path),
            const SizedBox(width: 10),
            HelpHover(
              enabledHelp,
              title: 'Enabled',
              child: Column(children: [toggle, enabledLabel]),
            ),
          ],
        );
      },
    );
  }

  Widget _strategySection(ColorScheme scheme, bool guideMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Endpoint name',
            hintText: 'e.g. Get user by id',
            prefixIcon: Icon(Icons.label_outline, size: 18),
            suffixIcon: HelpTip(
              'A friendly name shown in the endpoint list and the Live '
              "request log. It doesn't affect which requests match.",
              title: 'Endpoint name',
              example: 'Get user by id',
            ),
          ),
          onChanged: (v) => _mutate(() => ep.name = v),
        ),
        const SizedBox(height: 16),
        const _HelpSectionLabel(
          'How should this endpoint respond?',
          'Decides which of the responses below is sent for each request. '
              'Hover an option to see how it works.',
          title: 'Response strategy',
        ),
        _StrategySelector(
          value: ep.strategy,
          onChanged: (s) => _mutate(() => ep.strategy = s, immediate: true),
        ),
        if (guideMode) ...[
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
        _HelpSectionLabel(
          ep.strategy == ResponseStrategy.single
              ? 'Response'
              : 'Responses (${ep.responses.length})',
          _responsesHelp(ep.strategy),
          title: 'Responses',
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
                  const Flexible(
                    child: LabelWithHelp(
                      'Advanced settings',
                      'Optional extras for this endpoint: simulated '
                          'slowness, a required auth header, and notes. '
                          'Click to show or hide them.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ep.defaultDelayMs > 0 ||
                      ep.requireAuth ||
                      ep.jitterMs > 0)
                    HelpHover(
                      'A delay, jitter or required auth header is turned on '
                      'for this endpoint.',
                      title: 'Advanced settings in use',
                      child: Container(
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
                  const _HelpSectionLabel(
                    'Latency simulation',
                    'Slows this endpoint down so you can see how your app '
                        'handles a slow API. The global delay in Project '
                        'settings is added on top.',
                    example: '800 ms base + up to 200 ms jitter',
                  ),
                  AdaptivePair(
                    minWidth: 360,
                    first: _NumberField(
                      label: 'Base delay (ms)',
                      helpTitle: 'Base delay',
                      help:
                          'Milliseconds to wait before every response '
                          "from this endpoint. A response's own delay "
                          'override replaces it.',
                      example: '500 = half a second',
                      value: ep.defaultDelayMs,
                      onChanged: (v) => _mutate(() => ep.defaultDelayMs = v),
                    ),
                    second: _NumberField(
                      label: 'Random jitter (ms)',
                      helpTitle: 'Random jitter',
                      help:
                          'Adds a random extra wait, from 0 up to this '
                          'many milliseconds, to each request so timings '
                          'vary like a real network.',
                      example: '200 = each request waits 0-200 ms longer',
                      value: ep.jitterMs,
                      onChanged: (v) => _mutate(() => ep.jitterMs = v),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _HelpSectionLabel(
                    'Authentication',
                    'Checks that requests send a credentials header, so you '
                        'can test logged-in and logged-out cases. Any non-empty '
                        'value is accepted.',
                    example: 'Authorization: Bearer abc123',
                  ),
                  Row(
                    children: [
                      HelpHover(
                        'When on, requests without the header get a 401 '
                        'Unauthorized error instead of your responses.',
                        title: 'Require auth header',
                        example: '401 {"error": "unauthorized", ...}',
                        child: Switch(
                          value: ep.requireAuth,
                          onChanged: (v) => _mutate(
                            () => ep.requireAuth = v,
                            immediate: true,
                          ),
                        ),
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
                          suffixIcon: HelpTip(
                            'The header requests must include. Only its '
                            'presence is checked, not the value.',
                            title: 'Required header name',
                            example: 'X-API-Key',
                          ),
                        ),
                        onChanged: (v) => _mutate(() => ep.authHeader = v),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const _HelpSectionLabel(
                    'Description / notes',
                    'Notes for you or your team about this endpoint. They are '
                        "saved with the project and don't change responses.",
                  ),
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
        // Scrolls on short phone screens.
        scrollable: true,
        title: const Text('Path patterns'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PathHelpRow(
                '/users',
                'Matches exactly /users. Query strings are ignored, so '
                    '/users?page=2 matches too.',
              ),
              _PathHelpRow(
                '/users/:id',
                'Captures one segment: /users/42 matches and {{params.id}} '
                    'is 42.',
              ),
              _PathHelpRow(
                '/files/*',
                'Matches any single segment, like /files/report. Available '
                    'as {{params.wildcard0}}.',
              ),
              _PathHelpRow(
                '/assets/**',
                'Matches everything after it, like /assets/img/logo.png. '
                    'Available as {{params.rest}}.',
              ),
              SizedBox(height: 8),
              Text(
                'If several endpoints match a request, the most specific '
                'wins: fixed text beats :params and *, which beat **.',
                style: TextStyle(fontSize: 13),
              ),
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
          // Full 48 px height as a touch target on phones.
          isDense: !isPhone(context),
          items: HttpMethodType.values
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: HelpHover(
                    httpMethodHelp(m.label).message,
                    title: httpMethodHelp(m.label).title,
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
    // Taller options on phones (44 px touch targets).
    final vertical = isPhone(context) ? 14.0 : 9.0;
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
        final help = _strategyHelp(s);
        return HelpHover(
          help.message,
          title: s.label,
          example: help.example,
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(s),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
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
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String helpTitle;
  final String help;
  final String example;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumberField({
    required this.label,
    required this.helpTitle,
    required this.help,
    required this.example,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: HelpTip(help, title: helpTitle, example: example),
      ),
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

/// Hover help for each response strategy option.
({String message, String example}) _strategyHelp(ResponseStrategy s) =>
    switch (s) {
      ResponseStrategy.single => (
        message:
            'Always sends the first response. Use it when the endpoint only '
            'needs one answer.',
        example: 'GET /health → 200 {"status": "ok"}',
      ),
      ResponseStrategy.rules => (
        message:
            'Checks responses from top to bottom and sends the first one '
            'whose conditions all match. A response with no conditions is '
            'the fallback.',
        example: '?role=admin → 200, anything else → 403',
      ),
      ResponseStrategy.sequence => (
        message:
            'Sends the responses in order, one per request, then starts '
            'again from the first. Useful for testing retries or polling.',
        example: '1st call 503, 2nd call 200, 3rd call 503',
      ),
      ResponseStrategy.random => (
        message:
            "Picks a response at random for each request. Each response's "
            'weight sets how likely it is.',
        example: 'weights 9 and 1 → about 90% and 10%',
      ),
    };

/// Help for the responses section, matching the selected strategy.
String _responsesHelp(ResponseStrategy s) => switch (s) {
  ResponseStrategy.single =>
    'What the server sends back: a status code, a body and optional headers. '
        'Click a response to expand or collapse it.',
  ResponseStrategy.rules =>
    'Checked from top to bottom. The first response whose conditions all '
        'match is sent; one with no conditions is the fallback.',
  ResponseStrategy.sequence =>
    'Sent in this order, one per request. After the last one it starts '
        'again from the first.',
  ResponseStrategy.random =>
    'One is picked at random for each request. Give a response a higher '
        'weight to make it more likely.',
};

/// A [SectionLabel]-style heading with a help icon after the text.
class _HelpSectionLabel extends StatelessWidget {
  final String text;
  final String help;
  final String? title;
  final String? example;
  final Widget? trailing;
  const _HelpSectionLabel(
    this.text,
    this.help, {
    this.title,
    this.example,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
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
                HelpTip(help, title: title ?? text, example: example, size: 14),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
