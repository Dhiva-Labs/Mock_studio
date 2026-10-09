import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../models/mock_project.dart';
import '../../theme/app_theme.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';

/// A "try it" bar under the endpoint header. Shows the call URL and can send a
/// live request to the running server, displaying the response inline.
class TestBar extends StatefulWidget {
  final Endpoint endpoint;
  final MockProject project;
  final bool running;
  const TestBar({
    super.key,
    required this.endpoint,
    required this.project,
    required this.running,
  });

  @override
  State<TestBar> createState() => _TestBarState();
}

class _TestBarState extends State<TestBar> {
  late final TextEditingController _pathCtrl;
  final TextEditingController _bodyCtrl = TextEditingController(
    text: '{\n  "name": "Test"\n}',
  );
  bool _sending = false;
  bool _expanded = false;
  _TestResult? _result;

  Endpoint get ep => widget.endpoint;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: _concretePath());
  }

  @override
  void didUpdateWidget(covariant TestBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the concrete path roughly in sync when the template changes.
    if (oldWidget.endpoint.path != ep.path) {
      _pathCtrl.text = _concretePath();
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Replaces `:params` / wildcards with sample values so the URL is callable.
  String _concretePath() {
    var p = ep.normalizedPath;
    p = p.replaceAllMapped(RegExp(r':([A-Za-z0-9_]+)'), (m) => '1');
    p = p.replaceAll('**', 'sample/path');
    p = p.replaceAll('*', 'sample');
    return p;
  }

  String get _baseUrl => 'http://localhost:${widget.project.port}';
  String get _fullUrl =>
      '$_baseUrl${_pathCtrl.text.startsWith('/') ? '' : '/'}${_pathCtrl.text}';

  String get _anyNote => ep.method == HttpMethodType.any
      ? ' ANY endpoints are tested with GET.'
      : '';

  bool get _hasBody =>
      ep.method == HttpMethodType.post ||
      ep.method == HttpMethodType.put ||
      ep.method == HttpMethodType.patch ||
      ep.method == HttpMethodType.any;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: LayoutBuilder(
              builder: (context, box) => _urlRow(context, box.maxWidth < 520),
            ),
          ),
          if (!widget.running)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: scheme.errorContainer.withValues(alpha: 0.25),
              child: Text(
                'Start the server to send a live test request: tap Stopped '
                'at the top, or Start server.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_hasBody && widget.running)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      // A 48 px touch target on phones.
                      constraints: BoxConstraints(
                        minHeight: isPhone(context) ? 48 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Request body',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const HelpTip(
                            'JSON sent as the body of the test request. Edit '
                            'it to try rules that check body fields.',
                            title: 'Request body',
                            example: '{"name": "Test"}',
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded)
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                      decoration: const InputDecoration(isDense: true),
                    ),
                ],
              ),
            ),
          if (_result != null) _ResultPanel(result: _result!),
        ],
      ),
    );
  }

  /// The test URL with copy, cURL, open and Send. [narrow]: the actions go
  /// on a second line and the base URL drops its scheme to leave room for
  /// the path.
  Widget _urlRow(BuildContext context, bool narrow) {
    final scheme = Theme.of(context).colorScheme;
    final url = Expanded(
      child: HelpHover(
        'The address of this endpoint on your computer. :params and '
        'wildcards are filled with sample values; edit the path to try '
        'others.',
        title: 'Test URL',
        example: '/users/7?page=2',
        child: TextField(
          controller: _pathCtrl,
          decoration: InputDecoration(
            isDense: true,
            prefixText: narrow ? 'localhost:${widget.project.port}' : _baseUrl,
            prefixStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
    final actions = [
      _iconAction(
        Icons.copy,
        'Copy URL',
        () => copyToClipboard(context, _fullUrl, label: 'URL copied'),
      ),
      _iconAction(
        Icons.terminal,
        'Copy as cURL command',
        () => copyToClipboard(context, _curl(), label: 'cURL command copied'),
      ),
      if (ep.method == HttpMethodType.get)
        _iconAction(Icons.open_in_new, 'Open in browser', _openInBrowser),
    ];
    final send = HelpHover(
      widget.running
          ? 'Sends a real request to your running mock server and shows the '
                'response below. Required auth headers are added for '
                'you.$_anyNote'
          : 'Start the server first: tap Stopped at the top, or Start server '
                'in the side panel.',
      title: 'Send test request',
      child: FilledButton.icon(
        onPressed: widget.running && !_sending ? _send : null,
        icon: _sending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Send'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
    if (narrow) {
      return Column(
        children: [
          Row(
            children: [
              MethodBadge(ep.method, compact: true),
              const SizedBox(width: 8),
              url,
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [...actions, const Spacer(), send]),
        ],
      );
    }
    return Row(
      children: [
        MethodBadge(ep.method, compact: true),
        const SizedBox(width: 8),
        url,
        const SizedBox(width: 8),
        ...actions,
        const SizedBox(width: 4),
        send,
      ],
    );
  }

  Widget _iconAction(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      tooltip: tip,
      iconSize: 17,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  String _curl() {
    final b = StringBuffer(
      'curl -X ${ep.method == HttpMethodType.any ? 'GET' : ep.method.label} ',
    );
    b.write("'$_fullUrl'");
    if (_hasBody) {
      b.write(" \\\n  -H 'Content-Type: application/json'");
      b.write(" \\\n  -d '${_bodyCtrl.text.replaceAll("'", r"\'")}'");
    }
    if (ep.requireAuth) {
      b.write(" \\\n  -H '${ep.authHeader}: Bearer YOUR_TOKEN'");
    }
    return b.toString();
  }

  Future<void> _openInBrowser() async {
    try {
      await Process.run('xdg-open', [_fullUrl]);
    } catch (_) {
      if (mounted) copyToClipboard(context, _fullUrl, label: 'URL copied');
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _result = null;
    });
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(_fullUrl);
      final method = ep.method == HttpMethodType.any ? 'GET' : ep.method.label;
      final req = http.Request(method, uri);
      if (_hasBody) {
        req.headers['content-type'] = 'application/json';
        req.body = _bodyCtrl.text;
      }
      if (ep.requireAuth) {
        req.headers[ep.authHeader] = 'Bearer test-token';
      }
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      sw.stop();
      setState(() {
        _result = _TestResult(
          statusCode: res.statusCode,
          durationMs: sw.elapsedMilliseconds,
          body: _prettify(res.body, res.headers['content-type']),
          headers: res.headers,
        );
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _result = _TestResult(
          statusCode: 0,
          durationMs: sw.elapsedMilliseconds,
          body: 'Request failed: $e',
          headers: const {},
        );
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _prettify(String body, String? contentType) {
    if (contentType != null && contentType.contains('json')) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
      } catch (_) {}
    }
    return body;
  }
}

class _TestResult {
  final int statusCode;
  final int durationMs;
  final String body;
  final Map<String, String> headers;
  _TestResult({
    required this.statusCode,
    required this.durationMs,
    required this.body,
    required this.headers,
  });
}

class _ResultPanel extends StatelessWidget {
  final _TestResult result;
  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.statusColor(result.statusCode);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(result.statusCode),
              const SizedBox(width: 10),
              HelpHover(
                'Round-trip time for the test request, including any '
                'simulated delay.',
                title: 'Response time',
                example: '850 ms',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${result.durationMs} ms',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              HelpHover(
                'What the mock server sent back for your test request. JSON '
                'is shown indented for readability.',
                title: 'Test response',
                child: Text(
                  'Response',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                result.body,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
