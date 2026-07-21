import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/request_log.dart';
import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/helpers.dart';

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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final running = app.isRunning(project.id);
    var logs = app.logsFor(project.id);

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

    final selected = _selectedId == null
        ? null
        : logs
              .where((l) => l.id == _selectedId)
              .cast<RequestLog?>()
              .firstWhere((_) => true, orElse: () => null);

    return Column(
      children: [
        // Toolbar.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              RunningDot(running),
              const SizedBox(width: 8),
              Text(
                running ? 'Listening for requests' : 'Server stopped',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Filter by path, method, status…',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Errors only'),
                selected: _onlyErrors,
                onSelected: (v) => setState(() => _onlyErrors = v),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear logs',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: logs.isEmpty
                    ? null
                    : () => app.clearLogs(project.id),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: logs.isEmpty
              ? _EmptyLogs(running: running)
              : Row(
                  children: [
                    Expanded(
                      flex: selected != null ? 3 : 5,
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) => _LogRow(
                          log: logs[i],
                          selected: logs[i].id == _selectedId,
                          onTap: () => setState(
                            () => _selectedId = logs[i].id == _selectedId
                                ? null
                                : logs[i].id,
                          ),
                        ),
                      ),
                    ),
                    if (selected != null) ...[
                      Container(
                        width: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
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
  }
}

class _LogRow extends StatelessWidget {
  final RequestLog log;
  final bool selected;
  final VoidCallback onTap;
  const _LogRow({
    required this.log,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm:ss').format(log.timestamp);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              StatusBadge(log.statusCode),
              const SizedBox(width: 8),
              SizedBox(width: 54, child: MethodBadgeString(log.method)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.fullPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                    Row(
                      children: [
                        if (log.proxied)
                          _tag(context, 'proxied', const Color(0xFF7C3AED))
                        else if (log.unmatched)
                          _tag(context, 'no match', scheme.error)
                        else if (log.matchedEndpointName != null)
                          Flexible(
                            child: Text(
                              '${log.matchedEndpointName}${log.responseLabel != null ? ' · ${log.responseLabel}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${log.durationMs} ms',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Text(
                time,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
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
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
                child: Text(
                  log.fullPath,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv(
                context,
                'Time',
                DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp),
              ),
              _kv(context, 'Duration', '${log.durationMs} ms'),
              if (log.matchedEndpointName != null)
                _kv(context, 'Matched endpoint', log.matchedEndpointName!),
              if (log.responseLabel != null)
                _kv(context, 'Response', log.responseLabel!),
              const SizedBox(height: 14),
              const SectionLabel('Request headers'),
              CodeBox(_formatMap(log.requestHeaders)),
              if (log.requestBody.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionLabel('Request body'),
                CodeBox(log.requestBody),
              ],
              const SizedBox(height: 14),
              const SectionLabel('Response headers'),
              CodeBox(_formatMap(log.responseHeaders)),
              const SizedBox(height: 14),
              const SectionLabel('Response body'),
              CodeBox(log.responseBody),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
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
