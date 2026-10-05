import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mock_studio/models/load_flow.dart';
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/services/flow_runner.dart';
import 'package:mock_studio/services/mock_server.dart';
import 'package:mock_studio/services/sample_data.dart';

void main() {
  group('LatencyHistogram', () {
    test('percentiles stay close to the true values', () {
      final h = LatencyHistogram();
      for (var i = 1; i <= 1000; i++) {
        h.record(i);
      }
      expect(h.count, 1000);
      expect(h.minMs, 1);
      expect(h.maxMs, 1000);
      expect(h.percentile(50), inInclusiveRange(495, 505));
      expect(h.percentile(99), inInclusiveRange(985, 1000));
    });
  });

  group('FlowStep.accepts', () {
    test('handles classes, lists and the default', () {
      expect(FlowStep.statusMatches('', 204), isTrue);
      expect(FlowStep.statusMatches('', 404), isFalse);
      expect(FlowStep.statusMatches('2xx', 201), isTrue);
      expect(FlowStep.statusMatches('200, 401', 401), isTrue);
      expect(FlowStep.statusMatches('4xx', 500), isFalse);
    });
  });

  group('FlowRunner against a live mock server', () {
    late MockServer server;
    const port = 8198;
    const base = 'http://127.0.0.1:$port';

    setUp(() async {
      final project = MockProject.fromJson(
        SampleData.welcomeProject().toJson(),
      );
      project.port = port;
      server = MockServer(project: project, onLog: (_) {});
      await server.start();
    });

    tearDown(() => server.stop());

    test('sequential flow chains extracted values across steps', () async {
      final flow = LoadFlow(
        virtualUsers: 4,
        iterations: 3,
        steps: [
          FlowStep(
            method: 'POST',
            path: '/login',
            body: '{"password": "secret"}',
            expectStatus: '200',
            extract: {'token': 'body.token'},
          ),
          // Echoes the path param back, proving {{vars.token}} was resolved.
          FlowStep(
            method: 'GET',
            path: '/users/{{vars.token}}',
            expectStatus: '2xx',
            extract: {'echo': 'id'},
          ),
          FlowStep(path: '/health'),
        ],
      );
      final snapshots = <RunSnapshot>[];
      final result = await FlowRunner(
        flow: flow,
        baseUrl: base,
      ).run(onProgress: snapshots.add);

      expect(result.done, isTrue);
      expect(result.totalRequests, 4 * 3 * 3);
      expect(result.failed, 0);
      expect(result.iterationsDone, 12);
      expect(result.progress, 1);
      expect(result.steps.map((s) => s.count), [12, 12, 12]);
      expect(snapshots.last.done, isTrue);
    });

    test('failures are counted and stop the iteration', () async {
      final flow = LoadFlow(
        virtualUsers: 2,
        iterations: 2,
        steps: [
          FlowStep(
            method: 'POST',
            path: '/login',
            body: '{"password": "wrong"}',
            expectStatus: '200',
          ),
          FlowStep(path: '/health'),
        ],
      );
      final result = await FlowRunner(flow: flow, baseUrl: base).run();
      expect(result.steps[0].failed, 4);
      expect(result.steps[0].statusCounts[401], 4);
      expect(result.steps[1].count, 0); // never reached
    });

    test('parallel mode fires every step each iteration', () async {
      final flow = LoadFlow(
        mode: StepMode.parallel,
        virtualUsers: 3,
        iterations: 5,
        steps: [
          FlowStep(path: '/health'),
          FlowStep(path: '/users/{{vu}}'),
          FlowStep(path: '/nope', expectStatus: '404'),
        ],
      );
      final result = await FlowRunner(flow: flow, baseUrl: base).run();
      expect(result.totalRequests, 3 * 5 * 3);
      expect(result.failed, 0);
    });

    test('stop() ends a duration run early', () async {
      final flow = LoadFlow(
        virtualUsers: 2,
        durationSec: 30,
        steps: [FlowStep(path: '/health')],
      );
      final runner = FlowRunner(flow: flow, baseUrl: base);
      final future = runner.run();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      runner.stop();
      final result = await future.timeout(const Duration(seconds: 5));
      expect(result.stopped, isTrue);
      expect(result.totalRequests, greaterThan(0));
    });

    test('runs inside a background isolate', () async {
      final flow = LoadFlow(
        virtualUsers: 2,
        iterations: 2,
        steps: [FlowStep(path: '/health')],
      );
      // The isolate needs a server in its own reachable process: ours is fine.
      final done = Completer<RunSnapshot>();
      final run = IsolateFlowRun(
        flow: flow,
        baseUrl: base,
        onSnapshot: (s) {
          if (s.done && !done.isCompleted) done.complete(s);
        },
      );
      await run.start();
      final result = await done.future.timeout(const Duration(seconds: 10));
      expect(result.fatalError, isNull);
      expect(result.totalRequests, 4);
    });
  });
}
