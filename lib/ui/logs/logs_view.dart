import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/request_log.dart';
import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';
import '../../theme/app_theme.dart';

/// Live request log for the selected project, with search and a detail pane.
class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  String _query = '';
  bool _onlyErrors = false;
  String? _selectedId;
  final _scroll = ScrollController();

  // What the list showed last build, to keep the rows the user is reading
  // in place when new requests arrive above them.
  String? _newestId;
  String? _topShownId;
  String _shownFilter = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Newest requests are inserted at the top. When the list is scrolled
  /// down, move the scroll offset by the inserted rows (all rows have the
  /// same [extent]) before this frame is laid out, so what's on screen
  /// doesn't jump. At the very top the new rows simply appear.
  void _anchor(List<RequestLog> all, List<RequestLog> shown, double extent) {
    final filter = '$_query|$_onlyErrors';
    final newest = all.isEmpty ? null : all.first.id;
    if (_scroll.hasClients &&
        filter == _shownFilter &&
        newest != _newestId &&
        _topShownId != null) {
      final position = _scroll.position;
      final inserted = shown.indexWhere((l) => l.id == _topShownId);
      if (inserted > 0 && position.pixels > 0) {
        position.correctPixels(position.pixels + inserted * extent);
      }
    }
    _newestId = newest;
    _shownFilter = filter;
    _topShownId = shown.isEmpty ? null : shown.first.id;
  }

  void _open(RequestLog log, bool narrow) {
    if (narrow) {
      // Phones and narrow windows: the details get their own page; the
      // system back button returns to the list.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => _LogDetailPage(log: log)));
      return;
    }
    setState(() => _selectedId = log.id == _selectedId ? null : log.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final project = app.selectedProject!;
    final running = app.isRunning(project.id);
    final all = app.logsFor(project.id);
    var logs = all;

    if (_onlyErrors) logs = logs.where((l) => l.isError).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      logs = logs
          .where(
            (l) =>
                l.fullPath.toLowerCase().contains(q) ||
                l.method.toLowerCase().contains(q) ||
                l.statusCode.toString().contains(q) ||
                (l.matchedEndpointName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 720;
        final selected = narrow || _selectedId == null
            ? null
            : logs.where((l) => l.id == _selectedId).firstOrNull;
        final extent = _LogRow.extentFor(context);
        _anchor(all, logs, extent);
        return Column(
          children: [
            _toolbar(context, app, project.id, running, logs.isEmpty, narrow),
            const Divider(height: 1),
            Expanded(
              child: logs.isEmpty
                  ? _EmptyLogs(running: running)
                  : Row(
                      children: [
                        Expanded(
                          flex: selected != null ? 3 : 5,
                          child: ListView.builder(
                            controller: _scroll,
                            itemExtent: extent,
                            itemCount: logs.length,
                            // Rows follow their request when new ones are
                            // inserted above (no hover card or ink jumping
                            // to a different row).
                            findChildIndexCallback: (key) {
                              final id = (key as ValueKey<String>).value;
                              final i = logs.indexWhere((l) => l.id == id);
                              return i < 0 ? null : i;
                            },
                            itemBuilder: (_, i) => _LogRow(
                              key: ValueKey(logs[i].id),
                              log: logs[i],
                              compact: box.maxWidth < 560,
                              selected: logs[i].id == _selectedId && !narrow,
                              onTap: () => _open(logs[i], narrow),
                            ),
                          ),
                        ),
                        if (selected != null) ...[
                          Container(
                            width: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          Expanded(
                            flex: 3,
                            child: _LogDetail(
                              log: selected,
                              onClose: () => setState(() => _selectedId = null),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(
    BuildContext context,
    AppState app,
    String projectId,
    bool running,
    bool empty,
    bool narrow,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final status = [
      RunningDot(running),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          running ? 'Listening for requests' : 'Server stopped',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
      const HelpTip(
        'Every request that reaches this project\'s server, newest first. '
        'Tap one to see its headers and body. Only the latest 500 are kept, '
        'and the list is cleared when you quit.',
        title: 'Live requests',
        example: 'curl http://localhost:8080/users',
      ),
    ];
    final search = SizedBox(
      height: isPhone(context) ? 44 : 38,
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Filter by path, method, status…',
          prefixIcon: Icon(Icons.search, size: 18),
          suffixIcon: HelpTip(
            'Shows only requests whose path, query, method, status code or '
            'matched endpoint name contains this text. Upper or lower case '
            'does not matter.',
            title: 'Filter',
            example: '404, post or /users',
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
    final errorsOnly = HelpHover(
      'Shows only responses with status 400 or higher, such as 404 for a '
      'path no endpoint matches, or 500 server errors.',
      title: 'Errors only',
      example: '401, 404, 500',
      child: FilterChip(
        label: const Text('Errors only'),
        selected: _onlyErrors,
        onSelected: (v) => setState(() => _onlyErrors = v),
      ),
    );
    final clear = IconButton(
      tooltip: 'Clear all logged requests',
      icon: const Icon(Icons.delete_sweep_outlined),
      onPressed: empty ? null : () => app.clearLogs(projectId),
    );
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: search),
                clear,
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // The status takes all the room the chip leaves.
                Expanded(child: Row(children: status)),
                errorsOnly,
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          ...status.take(2),
          Text(
            running ? 'Listening for requests' : 'Server stopped',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          status.last,
          const SizedBox(width: 12),
          Expanded(child: search),
          const SizedBox(width: 10),
          errorsOnly,
          const SizedBox(width: 8),
          clear,
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final RequestLog log;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _LogRow({
    super.key,
    required this.log,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  /// Every row has this height (two lines plus padding, following the text
  /// size), which keeps scrolling cheap and the list steady while requests
  /// arrive.
  static double extentFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 26 + scaler.scale(17) + scaler.scale(16);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm:ss').format(log.timestamp);
    final duration = HelpHover(
      'How long the mock took to answer, including any delay you set on the '
      'endpoint or project.',
      title: 'Duration',
      example: '812 ms with an 800 ms delay',
      child: Text(
        '${log.durationMs} ms',
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
    );
    final clock = HelpHover(
      'When the request arrived: '
      '${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp)}',
      title: 'Time',
      child: Text(
        time,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
    final what = _what(context);
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          child: Row(
            children: [
              StatusBadge(log.statusCode),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MethodBadgeString(log.method),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelpHover(
                      'The address the client asked for, with its query '
                      'string. Tap the row to see headers and bodies.',
                      title: 'Path',
                      example: '/users/42?expand=orders',
                      child: Text(
                        log.fullPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Phones: duration and time share the second line,
                        // after everything the endpoint name can use.
                        if (compact)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: what,
                            ),
                          )
                        else
                          Flexible(child: what),
                        if (compact) ...[
                          const SizedBox(width: 8),
                          duration,
                          const SizedBox(width: 8),
                          clock,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                duration,
                const SizedBox(width: 10),
                clock,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Proxied, unmatched, or the endpoint and response that answered.
  Widget _what(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (log.proxied) {
      return HelpHover(
        'No endpoint matched, so the request was forwarded to the proxy '
        'base URL in Project settings and the real reply was passed back.',
        title: 'Proxied',
        example: '/payments → https://api.example.com/payments',
        child: _tag(context, 'proxied', AppTheme.violet),
      );
    }
    if (log.unmatched) {
      return HelpHover(
        'No enabled endpoint matches this method and path, so the mock '
        'answered 404. Add an endpoint for it, or set a proxy base URL in '
        'Project settings.',
        title: 'No match',
        example: 'GET /user, but the endpoint is /users',
        child: _tag(context, 'no match', scheme.error),
      );
    }
    if (log.matchedEndpointName == null) return const SizedBox.shrink();
    return HelpHover(
      'The endpoint that answered, then the label of the response it sent.',
      title: 'Matched endpoint',
      example: 'Get user · Success',
      child: Text(
        '${log.matchedEndpointName}'
        '${log.responseLabel != null ? ' · ${log.responseLabel}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A request's details as a full page (phones and narrow windows).
class _LogDetailPage extends StatelessWidget {
  const _LogDetailPage({required this.log});

  final RequestLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            StatusBadge(log.statusCode),
            const SizedBox(width: 8),
            MethodBadgeString(log.method),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                log.fullPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
          ],
        ),
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      body: ColoredBox(
        color: scheme.surface,
        child: SafeArea(top: false, child: _LogDetailBody(log: log)),
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  final RequestLog log;
  final VoidCallback onClose;
  const _LogDetail({required this.log, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              StatusBadge(log.statusCode),
              const SizedBox(width: 8),
              MethodBadgeString(log.method),
              const SizedBox(width: 10),
              Expanded(
                child: HelpHover(
                  log.fullPath,
                  title: 'Full path',
                  child: Text(
                    log.fullPath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close details',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _LogDetailBody(log: log)),
      ],
    );
  }
}

/// Timing, the matched endpoint, headers and bodies of one request.
class _LogDetailBody extends StatelessWidget {
  const _LogDetailBody({required this.log});

  final RequestLog log;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _kv(
          context,
          'Time',
          DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp),
          help: 'When the request arrived, to the millisecond.',
        ),
        _kv(
          context,
          'Duration',
          '${log.durationMs} ms',
          help:
              'From receiving the request to sending the reply, '
              'including any delay set on the endpoint or project.',
          example: '812 ms with an 800 ms delay',
        ),
        if (log.matchedEndpointName != null)
          _kv(
            context,
            'Matched endpoint',
            log.matchedEndpointName!,
            help:
                'The endpoint whose method and path fit this request. '
                'Click it in the Endpoints list to change its reply.',
            example: 'GET /users/:id fits /users/42',
          ),
        if (log.responseLabel != null)
          _kv(
            context,
            'Response',
            log.responseLabel!,
            help:
                'Which of the endpoint\'s responses was sent, by its '
                'label. It can also be a note from the server.',
            example: 'CORS preflight, Auth required, No match',
          ),
        const SizedBox(height: 14),
        _sectionLabel(
          context,
          'Request headers',
          'Extra details the client sent with the request, one per '
              'line as name: value.',
          example: 'authorization: Bearer abc123',
        ),
        CodeBox(_formatMap(log.requestHeaders)),
        if (log.requestBody.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionLabel(
            context,
            'Request body',
            'Data the client sent, such as JSON from a form. Very long '
                'bodies are cut short in this log.',
            example: '{"email": "ana@example.com"}',
          ),
          CodeBox(log.requestBody),
        ],
        const SizedBox(height: 14),
        _sectionLabel(
          context,
          'Response headers',
          'Headers sent back with the reply. For matched endpoints this '
              'includes CORS and global headers from Project settings.',
          example: 'content-type: application/json',
        ),
        CodeBox(_formatMap(log.responseHeaders)),
        const SizedBox(height: 14),
        _sectionLabel(
          context,
          'Response body',
          'The body sent back, with template tokens already filled in. '
              'Very long bodies are cut short in this log.',
          example: '{{uuid}} becomes 3f2c9a1e-…',
        ),
        CodeBox(log.responseBody),
      ],
    );
  }

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

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    String? help,
    String? example,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Align(
              alignment: Alignment.centerLeft,
              child: help == null
                  ? Text(k, style: style)
                  : LabelWithHelp(k, help, example: example, style: style),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMap(Map<String, String> m) {
    if (m.isEmpty) return '(none)';
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

class _EmptyLogs extends StatelessWidget {
  final bool running;
  const _EmptyLogs({required this.running});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            size: 48,
            color: scheme.outline,
          ),
          const SizedBox(height: 14),
          Text(
            running ? 'Waiting for requests…' : 'Server not running',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            running
                ? 'Every request that hits your mock server\nwill appear here in real time.'
                : 'Start the server, then send a request to see it logged here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
