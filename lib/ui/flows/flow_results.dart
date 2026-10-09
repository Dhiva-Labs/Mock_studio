import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/flow_runner.dart';
import '../../state/flow_run_session.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';

/// Live statistics for a flow run: headline tiles, a throughput chart and a
/// per-step latency table. Rebuilds only from its [session].
class FlowResults extends StatelessWidget {
  final FlowRunSession session;
  const FlowResults({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final s = session.snapshot;
        if (s == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              session.isRunning
                  ? 'Starting virtual users…'
                  : 'Run the flow to see throughput, latency percentiles and '
                        'per-step results here.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        if (s.fatalError != null) {
          return Text(s.fatalError!, style: TextStyle(color: scheme.error));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLine(snapshot: s, running: session.isRunning),
            const SizedBox(height: 12),
            LayoutBuilder(
              // At least two tiles per line on phones.
              builder: (context, box) =>
                  _tiles(s, box.maxWidth < 274 ? (box.maxWidth - 10) / 2 : 132),
            ),
            const SizedBox(height: 18),
            if (s.perSecond.isNotEmpty) ...[
              _ThroughputChart(snapshot: s),
              const SizedBox(height: 18),
            ],
            _StepTable(steps: s.steps),
          ],
        );
      },
    );
  }

  Widget _tiles(RunSnapshot s, double width) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Tile(
        'Requests',
        _int(s.totalRequests),
        title: 'Requests',
        help: 'Total requests sent so far, including failed ones.',
        example: '5 users × 10 iterations × 3 steps = 150',
      ),
      _Tile(
        'Req / sec',
        s.requestsPerSecond.toStringAsFixed(1),
        title: 'Requests per second',
        help:
            'Throughput: how many requests finished per second, on '
            'average, since the run started. Higher means more load '
            'handled.',
        example: '600 requests in 5 s = 120 req/s',
      ),
      _Tile(
        'Failed',
        '${_int(s.failed)} (${(s.errorRate * 100).toStringAsFixed(1)}%)',
        alert: s.failed > 0,
        title: 'Failed and error rate',
        help:
            'Requests with a status outside the step\'s Expect '
            'list, a timeout (30 s) or a connection error. The '
            'percentage is the error rate.',
        example: '5 of 1,000 failed = 0.5%',
      ),
      _Tile(
        'p50',
        '${s.p50Ms} ms',
        title: 'p50 (median)',
        help:
            'Half of all requests were faster than this and half '
            'slower. It is the typical response time.',
        example: 'p50 12 ms: half took under 12 ms',
      ),
      _Tile(
        'p95',
        '${s.p95Ms} ms',
        title: 'p95',
        help:
            '95% of requests were faster than this; only the slowest '
            '1 in 20 took longer. A good guide to what most users '
            'feel.',
        example: 'p95 80 ms: 19 in 20 took under 80 ms',
      ),
      _Tile(
        'p99',
        '${s.p99Ms} ms',
        title: 'p99',
        help:
            '99% of requests were faster than this; only 1 in 100 '
            'took longer. It shows the worst delays a few users hit.',
        example: 'p99 250 ms: 1 in 100 took longer',
      ),
      _Tile(
        'Avg',
        '${s.meanMs.toStringAsFixed(1)} ms',
        title: 'Average',
        help:
            'Mean response time of all requests. A few very slow '
            'ones can pull it up, so compare it with p50 and p95.',
        example: 'total time ÷ number of requests',
      ),
      _Tile(
        'Active users',
        '${s.activeUsers}',
        title: 'Active users',
        help:
            'Virtual users running right now. It climbs during '
            'ramp-up and drops to 0 as users finish.',
        example: '50 while all users run',
      ),
    ].map((t) => SizedBox(width: width, child: t)).toList(),
  );
}

String _int(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _elapsed(int ms) {
  final sec = ms ~/ 1000;
  return sec < 60
      ? '${(ms / 1000).toStringAsFixed(1)}s'
      : '${sec ~/ 60}m ${sec % 60}s';
}

class _StatusLine extends StatelessWidget {
  final RunSnapshot snapshot;
  final bool running;
  const _StatusLine({required this.snapshot, required this.running});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = snapshot;
    final label = running
        ? 'Running · ${_elapsed(s.elapsedMs)} · ${s.iterationsDone} iterations done'
        : '${s.stopped ? 'Stopped' : 'Finished'} in ${_elapsed(s.elapsedMs)} · '
              '${s.iterationsDone} iterations';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              running
                  ? Icons.bolt
                  : s.failed == 0
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 18,
              color: running
                  ? scheme.primary
                  : s.failed == 0
                  ? scheme.primary
                  : scheme.error,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const HelpTip(
              'One iteration is one virtual user going through all the steps '
              'once. The bar below shows how far the run has got.',
              title: 'Iterations',
              example: '50 users × 10 iterations = 500',
            ),
          ],
        ),
        const SizedBox(height: 8),
        HelpHover(
          'How much of the planned requests or duration is done. It slides '
          'back and forth when the total can\'t be known.',
          title: 'Progress',
          child: LinearProgressIndicator(
            value: running ? s.progress : 1,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;
  final String title;
  final String help;
  final String? example;
  const _Tile(
    this.label,
    this.value, {
    required this.title,
    required this.help,
    this.example,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HelpHover(
      help,
      title: title,
      example: example,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: alert
                ? scheme.error.withValues(alpha: 0.5)
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (alert) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Requests completed per second (OK stacked under failed) with a hover
/// tooltip per bar. One y-axis; failures use the reserved error colour.
class _ThroughputChart extends StatefulWidget {
  final RunSnapshot snapshot;
  const _ThroughputChart({required this.snapshot});

  @override
  State<_ThroughputChart> createState() => _ThroughputChartState();
}

class _ThroughputChartState extends State<_ThroughputChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.snapshot;
    final total = s.perSecond;
    final errors = s.errorsPerSecond;
    // The first second shown, relative to the start of the run.
    final firstSecond = max(0, s.elapsedMs ~/ 1000 + 1 - total.length);
    final hover = _hover != null && _hover! < total.length ? _hover : null;
    final ink = scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: LabelWithHelp(
                  'Throughput (requests / second)',
                  'Requests finished in each second of the run, split into OK '
                      'and failed. Hover a bar for exact numbers. The last 2 '
                      'minutes are shown.',
                  example: 't = 12s · 340 requests · 2 failed',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            HelpHover(
              'Requests whose status matched the step\'s Expect list.',
              title: 'OK',
              child: _Legend(color: scheme.primary, label: 'OK'),
            ),
            const SizedBox(width: 12),
            HelpHover(
              'Requests with an unexpected status, a timeout or a connection '
              'error.',
              title: 'Failed',
              child: _Legend(color: scheme.error, label: 'Failed'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: hover == null
              ? null
              : Text(
                  't = ${firstSecond + hover}s · ${total[hover]} requests'
                  '${errors[hover] > 0 ? ' · ${errors[hover]} failed' : ''}',
                  style: TextStyle(fontSize: 12, color: ink),
                ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            void track(Offset p) {
              final slot = c.maxWidth / max(total.length, 1);
              final i = (p.dx / slot).floor();
              setState(() => _hover = i >= 0 && i < total.length ? i : null);
            }

            return MouseRegion(
              onHover: (e) => track(e.localPosition),
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                onPanDown: (d) => track(d.localPosition),
                child: CustomPaint(
                  size: Size(c.maxWidth, 120),
                  painter: _BarsPainter(
                    total: total,
                    errors: errors,
                    ok: scheme.primary,
                    failed: scheme.error,
                    grid: scheme.outlineVariant.withValues(alpha: 0.5),
                    surface: scheme.surface,
                    hover: hover,
                    labelStyle: TextStyle(fontSize: 10.5, color: ink),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> total;
  final List<int> errors;
  final Color ok;
  final Color failed;
  final Color grid;
  final Color surface;
  final int? hover;
  final TextStyle labelStyle;

  _BarsPainter({
    required this.total,
    required this.errors,
    required this.ok,
    required this.failed,
    required this.grid,
    required this.surface,
    required this.hover,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final peak = total.fold<int>(1, max);
    const top = 14.0;
    final h = size.height - top;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      gridPaint,
    );
    canvas.drawLine(Offset(0, top), Offset(size.width, top), gridPaint);
    final tp = TextPainter(
      text: TextSpan(text: '$peak/s', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width, 0));

    final slot = size.width / max(total.length, 1);
    final barW = max(1.0, min(14.0, slot - 2));
    for (var i = 0; i < total.length; i++) {
      if (total[i] == 0) continue;
      final x = i * slot + (slot - barW) / 2;
      final fullH = h * total[i] / peak;
      final errH = h * errors[i] / peak;
      final dim = hover != null && hover != i;
      final okColor = dim ? ok.withValues(alpha: 0.45) : ok;
      final errColor = dim ? failed.withValues(alpha: 0.45) : failed;
      final r = Radius.circular(min(4, barW / 2));
      final okH = fullH - errH;
      if (okH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - okH, barW, okH),
            topLeft: errH > 0 ? Radius.zero : r,
            topRight: errH > 0 ? Radius.zero : r,
          ),
          Paint()..color = okColor,
        );
      }
      if (errH > 0) {
        // 2px surface gap between the stacked segments.
        final gap = okH > 0 ? 2.0 : 0.0;
        final y = size.height - fullH;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barW, max(1, errH - gap)),
            topLeft: r,
            topRight: r,
          ),
          Paint()..color = errColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.total != total || old.hover != hover || old.ok != ok;
}

class _StepTable extends StatelessWidget {
  final List<StepSummary> steps;
  const _StepTable({required this.steps});

  /// Below this width the table scrolls sideways instead of squeezing the
  /// numbers into slivers.
  static const _minWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const num = TextStyle(
      fontSize: 12.5,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    TableRow row(List<Widget> cells, {bool header = false}) => TableRow(
      decoration: header
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            )
          : null,
      children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
            child: c,
          ),
      ],
    );
    Widget h(String t, String help, {String? title, String? example}) =>
        HelpHover(
          help,
          title: title ?? t,
          example: example,
          child: Text(
            t,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
    Widget n(String t, {Color? color}) => Text(
      t,
      textAlign: TextAlign.right,
      maxLines: 1,
      style: num.copyWith(color: color),
    );

    final table = Table(
      columnWidths: const {0: FlexColumnWidth(3)},
      defaultColumnWidth: const FlexColumnWidth(1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row([
          Align(
            alignment: Alignment.centerLeft,
            child: h(
              'Step',
              'The step\'s name, or its method and path when it has no name.',
            ),
          ),
          h(
            'Calls',
            'Requests sent for this step.',
            example: '50 users × 10 iterations = 500 calls',
          ),
          h(
            'Failed',
            'Calls with an unexpected status, a timeout or a connection '
                'error.',
          ),
          h('Avg', 'Mean time per call, in milliseconds.', title: 'Average'),
          h(
            'p50',
            'Half of the calls were faster than this, in milliseconds.',
            title: 'p50 (median)',
          ),
          h('p95', '95% of the calls were faster than this, in milliseconds.'),
          h('p99', '99% of the calls were faster than this, in milliseconds.'),
          h('Max', 'The slowest single call, in milliseconds.'),
        ], header: true),
        for (final s in steps)
          row([
            Row(
              children: [
                // Long methods (OPTIONS, DELETE) can't push the name out.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 70),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MethodBadgeString(s.method),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            n(_int(s.count)),
            n(_int(s.failed), color: s.failed > 0 ? scheme.error : null),
            n(s.meanMs.toStringAsFixed(1)),
            n('${s.p50Ms}'),
            n('${s.p95Ms}'),
            n('${s.p99Ms}'),
            n('${s.maxMs}'),
          ]),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LabelWithHelp(
          'Per step',
          'The same numbers for each step, so you can spot which endpoint is '
              'slow or failing.',
          example: 'POST /login p95 300 ms vs GET /me p95 20 ms',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= _minWidth
              ? table
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: _minWidth, child: table),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          'Latencies in milliseconds.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        for (final s in steps)
          if (s.statusCounts.isNotEmpty || s.topErrors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (final e in s.statusCounts.entries)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge(e.key),
                        const SizedBox(width: 3),
                        HelpHover(
                          'How many calls of this step got this status.',
                          title: 'Count',
                          example: '200 ×1,500',
                          child: Text('×${_int(e.value)}', style: num),
                        ),
                      ],
                    ),
                  for (final e in s.topErrors.entries)
                    HelpHover(
                      'Why calls failed, and how many times. Up to 5 '
                      'different messages are kept per step.',
                      title: 'Error',
                      example: 'Unexpected status 401 (×210)',
                      child: Text(
                        '${e.key} (×${e.value})',
                        style: TextStyle(fontSize: 12, color: scheme.error),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
