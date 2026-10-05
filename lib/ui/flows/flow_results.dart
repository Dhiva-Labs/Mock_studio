import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/flow_runner.dart';
import '../../state/flow_run_session.dart';
import '../widgets/badges.dart';

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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Tile('Requests', _int(s.totalRequests)),
                _Tile('Req / sec', s.requestsPerSecond.toStringAsFixed(1)),
                _Tile(
                  'Failed',
                  '${_int(s.failed)} (${(s.errorRate * 100).toStringAsFixed(1)}%)',
                  alert: s.failed > 0,
                ),
                _Tile('p50', '${s.p50Ms} ms'),
                _Tile('p95', '${s.p95Ms} ms'),
                _Tile('p99', '${s.p99Ms} ms'),
                _Tile('Avg', '${s.meanMs.toStringAsFixed(1)} ms'),
                _Tile('Active users', '${s.activeUsers}'),
              ],
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: running ? s.progress : 1,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;
  const _Tile(this.label, this.value, {this.alert = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
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
            const Text(
              'Throughput (requests / second)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Spacer(),
            _Legend(color: scheme.primary, label: 'OK'),
            const SizedBox(width: 12),
            _Legend(color: scheme.error, label: 'Failed'),
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
    Widget h(String t) => Text(
      t,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
    Widget n(String t, {Color? color}) => Text(
      t,
      textAlign: TextAlign.right,
      style: num.copyWith(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Per step',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Table(
          columnWidths: const {0: FlexColumnWidth(3)},
          defaultColumnWidth: const FlexColumnWidth(1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            row([
              Align(alignment: Alignment.centerLeft, child: h('Step')),
              h('Calls'),
              h('Failed'),
              h('Avg'),
              h('p50'),
              h('p95'),
              h('p99'),
              h('Max'),
            ], header: true),
            for (final s in steps)
              row([
                Row(
                  children: [
                    MethodBadgeString(s.method),
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
                        Text('×${_int(e.value)}', style: num),
                      ],
                    ),
                  for (final e in s.topErrors.entries)
                    Text(
                      '${e.key} (×${e.value})',
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
