import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/load_flow.dart';
import 'template_engine.dart';

/// Fixed-size latency histogram: memory stays constant no matter how many
/// requests are recorded (1 ms resolution < 1 s, 10 ms < 10 s, 100 ms < 130 s).
class LatencyHistogram {
  static const _size = 3101;
  final Int32List _buckets = Int32List(_size);
  int count = 0;
  int sumMs = 0;
  int minMs = 0;
  int maxMs = 0;

  static int _index(int ms) {
    if (ms < 1000) return ms < 0 ? 0 : ms;
    if (ms < 10000) return 1000 + (ms - 1000) ~/ 10;
    if (ms < 130000) return 1900 + (ms - 10000) ~/ 100;
    return _size - 1;
  }

  static int _valueOf(int index) {
    if (index < 1000) return index;
    if (index < 1900) return 1000 + (index - 1000) * 10;
    return 10000 + (index - 1900) * 100;
  }

  void record(int ms) {
    _buckets[_index(ms)]++;
    if (count == 0 || ms < minMs) minMs = ms;
    if (ms > maxMs) maxMs = ms;
    count++;
    sumMs += ms;
  }

  double get meanMs => count == 0 ? 0 : sumMs / count;

  /// Approximate [p]th percentile (0–100) in ms.
  int percentile(double p) {
    if (count == 0) return 0;
    final target = max(1, (count * p / 100).ceil());
    var seen = 0;
    for (var i = 0; i < _size; i++) {
      seen += _buckets[i];
      if (seen >= target) return min(_valueOf(i), maxMs);
    }
    return maxMs;
  }
}

/// Aggregated results for one step (immutable, safe to send across isolates).
class StepSummary {
  final String name;
  final String method;
  final String path;
  final int count;
  final int ok;
  final int failed;
  final double meanMs;
  final int minMs;
  final int p50Ms;
  final int p95Ms;
  final int p99Ms;
  final int maxMs;
  final Map<int, int> statusCounts;
  final Map<String, int> topErrors;

  const StepSummary({
    required this.name,
    required this.method,
    required this.path,
    required this.count,
    required this.ok,
    required this.failed,
    required this.meanMs,
    required this.minMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.statusCounts,
    required this.topErrors,
  });
}

/// A point-in-time view of a run, emitted periodically and at the end.
class RunSnapshot {
  final int elapsedMs;
  final int totalRequests;
  final int ok;
  final int failed;
  final int iterationsDone;
  final int activeUsers;

  /// Planned number of requests, or 0 for duration-based runs.
  final int plannedRequests;
  final int durationMs;
  final bool done;
  final bool stopped;
  final String? fatalError;
  final int p50Ms;
  final int p95Ms;
  final int p99Ms;
  final double meanMs;
  final List<StepSummary> steps;

  /// Requests completed in each of the most recent seconds (oldest first),
  /// with the matching failure counts.
  final List<int> perSecond;
  final List<int> errorsPerSecond;

  const RunSnapshot({
    required this.elapsedMs,
    required this.totalRequests,
    required this.ok,
    required this.failed,
    required this.iterationsDone,
    required this.activeUsers,
    required this.plannedRequests,
    required this.durationMs,
    required this.done,
    required this.stopped,
    required this.fatalError,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.meanMs,
    required this.steps,
    required this.perSecond,
    required this.errorsPerSecond,
  });

  double get requestsPerSecond =>
      elapsedMs <= 0 ? 0 : totalRequests * 1000 / elapsedMs;

  double get errorRate => totalRequests == 0 ? 0 : failed / totalRequests;

  /// 0–1 completion estimate, or null when it can't be known.
  double? get progress {
    if (done) return 1;
    if (plannedRequests > 0) return min(1, totalRequests / plannedRequests);
    if (durationMs > 0) return min(1, elapsedMs / durationMs);
    return null;
  }

  static RunSnapshot failedToStart(String error) => RunSnapshot(
    elapsedMs: 0,
    totalRequests: 0,
    ok: 0,
    failed: 0,
    iterationsDone: 0,
    activeUsers: 0,
    plannedRequests: 0,
    durationMs: 0,
    done: true,
    stopped: false,
    fatalError: error,
    p50Ms: 0,
    p95Ms: 0,
    p99Ms: 0,
    meanMs: 0,
    steps: const [],
    perSecond: const [],
    errorsPerSecond: const [],
  );
}

class _StepStats {
  final FlowStep step;
  final hist = LatencyHistogram();
  int ok = 0;
  int failed = 0;
  final statusCounts = <int, int>{};
  final errors = <String, int>{};
  _StepStats(this.step);

  void record(int status, int ms, bool success, String? error) {
    hist.record(ms);
    success ? ok++ : failed++;
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    if (error != null) {
      // Keep a handful of distinct messages; count the rest under existing keys.
      if (errors.containsKey(error) || errors.length < 5) {
        errors[error] = (errors[error] ?? 0) + 1;
      }
    }
  }

  StepSummary summary() => StepSummary(
    name: step.displayName,
    method: step.method,
    path: step.path,
    count: hist.count,
    ok: ok,
    failed: failed,
    meanMs: hist.meanMs,
    minMs: hist.minMs,
    p50Ms: hist.percentile(50),
    p95Ms: hist.percentile(95),
    p99Ms: hist.percentile(99),
    maxMs: hist.maxMs,
    statusCounts: Map.of(statusCounts),
    topErrors: Map.of(errors),
  );
}

/// Drives a [LoadFlow]: spawns virtual users that run the steps concurrently
/// against [baseUrl] and aggregates latency/status statistics.
///
/// Pure Dart (no Flutter), so it can run inside a background isolate.
class FlowRunner {
  final LoadFlow flow;
  final String baseUrl;
  final Duration requestTimeout;

  FlowRunner({
    required this.flow,
    required this.baseUrl,
    this.requestTimeout = const Duration(seconds: 30),
  });

  static const _timelineSeconds = 120;
  static final _varToken = RegExp(
    r'\{\{\s*(vars\.[^}\s]+|vu|iteration)\s*\}\}',
  );
  static final _emptyCtx = TemplateContext(
    pathParams: const {},
    query: const {},
    headers: const {},
    rawBody: '',
  );

  bool _stopping = false;
  final _total = LatencyHistogram();
  late final List<_StepStats> _stats;
  final _perSecond = <int>[];
  final _errorsPerSecond = <int>[];
  final _clock = Stopwatch();
  int _iterationsDone = 0;
  int _activeUsers = 0;
  int _planned = 0;

  /// Asks the run to finish: in-flight requests complete, no new ones start.
  void stop() => _stopping = true;

  Future<RunSnapshot> run({
    void Function(RunSnapshot snapshot)? onProgress,
    Duration progressInterval = const Duration(milliseconds: 250),
  }) async {
    final steps = flow.steps.where((s) => s.enabled).toList();
    if (steps.isEmpty) {
      return RunSnapshot.failedToStart('This flow has no enabled steps.');
    }
    _stats = [for (final s in steps) _StepStats(s)];
    final users = flow.virtualUsers.clamp(1, 1000).toInt();
    final durationMs = max(0, flow.durationSec) * 1000;
    if (durationMs == 0) {
      _planned = users * max<int>(1, flow.iterations) * steps.length;
    }

    final inner = HttpClient()
      ..maxConnectionsPerHost = flow.mode == StepMode.parallel
          ? users * steps.length
          : users
      ..idleTimeout = const Duration(seconds: 15)
      ..connectionTimeout = requestTimeout;
    final client = IOClient(inner);

    _clock.start();
    final ticker = onProgress == null
        ? null
        : Timer.periodic(progressInterval, (_) => onProgress(_snapshot()));

    try {
      await Future.wait([
        for (var u = 0; u < users; u++)
          _virtualUser(client, steps, u + 1, users, durationMs),
      ]);
    } finally {
      ticker?.cancel();
      _clock.stop();
      client.close();
    }
    final last = _snapshot(done: true);
    onProgress?.call(last);
    return last;
  }

  bool _keepGoing(int iteration, int durationMs) {
    if (_stopping) return false;
    if (durationMs > 0) return _clock.elapsedMilliseconds < durationMs;
    return iteration < max(1, flow.iterations);
  }

  Future<void> _virtualUser(
    http.Client client,
    List<FlowStep> steps,
    int vu,
    int users,
    int durationMs,
  ) async {
    if (flow.rampUpSec > 0 && users > 1) {
      await _sleep(flow.rampUpSec * 1000 * (vu - 1) ~/ users);
    }
    _activeUsers++;
    try {
      for (var it = 0; _keepGoing(it, durationMs); it++) {
        final vars = <String, String>{};
        if (flow.mode == StepMode.parallel) {
          await Future.wait([
            for (var i = 0; i < steps.length; i++)
              _execute(client, i, steps[i], vars, vu, it),
          ]);
          await _sleep(flow.thinkTimeMs);
        } else {
          for (var i = 0; i < steps.length; i++) {
            if (_stopping) break;
            final ok = await _execute(client, i, steps[i], vars, vu, it);
            if (!ok && flow.stopOnFailure) break;
            await _sleep(flow.thinkTimeMs);
          }
        }
        _iterationsDone++;
      }
    } finally {
      _activeUsers--;
    }
  }

  Future<void> _sleep(int ms) async {
    if (ms <= 0) return;
    // Sleep in slices so a stop request isn't held up by a long pause.
    final end = _clock.elapsedMilliseconds + ms;
    while (!_stopping && _clock.elapsedMilliseconds < end) {
      await Future<void>.delayed(
        Duration(milliseconds: min(200, end - _clock.elapsedMilliseconds)),
      );
    }
  }

  String _render(String template, Map<String, String> vars, int vu, int it) {
    if (!template.contains('{{')) return template;
    final withVars = template.replaceAllMapped(_varToken, (m) {
      final key = m.group(1)!;
      if (key == 'vu') return '$vu';
      if (key == 'iteration') return '${it + 1}';
      return vars[key.substring(5)] ?? m.group(0)!;
    });
    return TemplateEngine.render(withVars, _emptyCtx);
  }

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base${path.startsWith('/') ? '' : '/'}$path');
  }

  /// Runs one step, records stats and extracts variables. Returns success.
  Future<bool> _execute(
    http.Client client,
    int index,
    FlowStep step,
    Map<String, String> vars,
    int vu,
    int it,
  ) async {
    final sw = Stopwatch()..start();
    var status = 0;
    String? error;
    var success = false;
    try {
      final req = http.Request(
        step.method.toUpperCase(),
        _uri(_render(step.path, vars, vu, it)),
      );
      step.headers.forEach((k, v) {
        if (k.trim().isNotEmpty) req.headers[k] = _render(v, vars, vu, it);
      });
      final body = _render(step.body, vars, vu, it);
      if (body.isNotEmpty) {
        req.body = body;
        final hasType = req.headers.keys.any(
          (k) => k.toLowerCase() == 'content-type',
        );
        if (!hasType) {
          final t = body.trimLeft();
          req.headers['content-type'] = t.startsWith('{') || t.startsWith('[')
              ? 'application/json'
              : 'text/plain';
        }
      }

      final streamed = await client.send(req).timeout(requestTimeout);
      final res = await http.Response.fromStream(
        streamed,
      ).timeout(requestTimeout);
      sw.stop();
      status = res.statusCode;
      success = step.accepts(status);
      if (!success) error = 'Unexpected status $status';
      if (step.extract.isNotEmpty) _extract(step, res, vars);
    } on TimeoutException {
      error = 'Timed out after ${requestTimeout.inSeconds}s';
    } catch (e) {
      error = _shortError(e);
    }
    if (sw.isRunning) sw.stop();

    final ms = sw.elapsedMilliseconds;
    _stats[index].record(status, ms, success, error);
    _total.record(ms);
    _bumpTimeline(success);
    return success;
  }

  void _extract(FlowStep step, http.Response res, Map<String, String> vars) {
    Object? json;
    var parsed = false;
    step.extract.forEach((name, source) {
      final src = source.trim();
      String? value;
      if (src == 'status') {
        value = '${res.statusCode}';
      } else if (src.startsWith('header.')) {
        value = res.headers[src.substring(7).toLowerCase()];
      } else {
        if (!parsed) {
          parsed = true;
          try {
            json = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
          } catch (_) {}
        }
        final path = src.startsWith('body.') ? src.substring(5) : src;
        value = TemplateEngine.jsonPath(json, path);
      }
      if (value != null) vars[name.trim()] = value;
    });
  }

  void _bumpTimeline(bool success) {
    final second = _clock.elapsedMilliseconds ~/ 1000;
    while (_perSecond.length <= second) {
      _perSecond.add(0);
      _errorsPerSecond.add(0);
    }
    _perSecond[second]++;
    if (!success) _errorsPerSecond[second]++;
    // Drop history older than the window so long soak runs stay bounded.
    final excess = _perSecond.length - _timelineSeconds * 2;
    if (excess > 0) {
      _perSecond.removeRange(0, excess);
      _errorsPerSecond.removeRange(0, excess);
    }
  }

  static String _shortError(Object e) {
    if (e is SocketException) {
      return 'Connection failed: ${e.osError?.message ?? e.message}';
    }
    if (e is http.ClientException) return 'Client error: ${e.message}';
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  RunSnapshot _snapshot({bool done = false}) {
    var ok = 0, failed = 0;
    for (final s in _stats) {
      ok += s.ok;
      failed += s.failed;
    }
    List<int> tail(List<int> l) => List.unmodifiable(
      l.length <= _timelineSeconds ? l : l.sublist(l.length - _timelineSeconds),
    );
    return RunSnapshot(
      elapsedMs: _clock.elapsedMilliseconds,
      totalRequests: _total.count,
      ok: ok,
      failed: failed,
      iterationsDone: _iterationsDone,
      activeUsers: _activeUsers,
      plannedRequests: _planned,
      durationMs: max(0, flow.durationSec) * 1000,
      done: done,
      stopped: done && _stopping,
      fatalError: null,
      p50Ms: _total.percentile(50),
      p95Ms: _total.percentile(95),
      p99Ms: _total.percentile(99),
      meanMs: _total.meanMs,
      steps: [for (final s in _stats) s.summary()],
      perSecond: tail(_perSecond),
      errorsPerSecond: tail(_errorsPerSecond),
    );
  }
}

/// Runs a [FlowRunner] in a background isolate so load generation never
/// competes with the UI (or the in-process mock server) for the main thread.
class IsolateFlowRun {
  final LoadFlow flow;
  final String baseUrl;
  final void Function(RunSnapshot snapshot) onSnapshot;

  Isolate? _isolate;
  SendPort? _control;
  ReceivePort? _port;
  ReceivePort? _errors;
  Timer? _killTimer;
  bool _finished = false;

  IsolateFlowRun({
    required this.flow,
    required this.baseUrl,
    required this.onSnapshot,
  });

  Future<void> start() async {
    final port = _port = ReceivePort();
    final errors = _errors = ReceivePort();
    port.listen((msg) {
      if (msg is SendPort) {
        _control = msg;
      } else if (msg is RunSnapshot) {
        onSnapshot(msg);
        if (msg.done) _finish();
      }
    });
    errors.listen((e) {
      final text = e is List && e.isNotEmpty ? '${e.first}' : '$e';
      onSnapshot(RunSnapshot.failedToStart('Runner crashed: $text'));
      _finish();
    });
    try {
      _isolate = await Isolate.spawn(
        _entry,
        (port.sendPort, flow, baseUrl),
        onError: errors.sendPort,
        debugName: 'flow-runner',
      );
    } catch (e) {
      onSnapshot(RunSnapshot.failedToStart('Could not start runner: $e'));
      _finish();
    }
  }

  /// Graceful stop; force-kills the isolate if it doesn't wind down quickly.
  void stop() {
    if (_finished) return;
    _control?.send('stop');
    _killTimer ??= Timer(const Duration(seconds: 5), () {
      _isolate?.kill(priority: Isolate.immediate);
      _finish();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _killTimer?.cancel();
    _port?.close();
    _errors?.close();
    _isolate = null;
  }

  static Future<void> _entry((SendPort, LoadFlow, String) args) async {
    final (out, flow, baseUrl) = args;
    final control = ReceivePort();
    out.send(control.sendPort);
    final runner = FlowRunner(flow: flow, baseUrl: baseUrl);
    control.listen((msg) {
      if (msg == 'stop') runner.stop();
    });
    await runner.run(onProgress: out.send);
    control.close();
  }
}
