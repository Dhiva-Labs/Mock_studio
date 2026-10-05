import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_studio/models/load_flow.dart';
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/services/flow_runner.dart';
import 'package:mock_studio/services/sample_data.dart';
import 'package:mock_studio/state/app_state.dart';
import 'package:mock_studio/state/flow_run_session.dart';
import 'package:mock_studio/ui/flows/flow_results.dart';

RunSnapshot _snapshot() => RunSnapshot(
  elapsedMs: 12500,
  totalRequests: 48210,
  ok: 48000,
  failed: 210,
  iterationsDone: 16070,
  activeUsers: 50,
  plannedRequests: 60000,
  durationMs: 0,
  done: false,
  stopped: false,
  fatalError: null,
  p50Ms: 3,
  p95Ms: 18,
  p99Ms: 41,
  meanMs: 5.2,
  steps: const [
    StepSummary(
      name: 'Login with a fairly long descriptive step name',
      method: 'POST',
      path: '/login',
      count: 16070,
      ok: 15860,
      failed: 210,
      meanMs: 6.1,
      minMs: 1,
      p50Ms: 4,
      p95Ms: 20,
      p99Ms: 44,
      maxMs: 120,
      statusCounts: {200: 15860, 401: 210},
      topErrors: {'Unexpected status 401': 210},
    ),
  ],
  perSecond: List.generate(13, (i) => 3000 + i * 100),
  errorsPerSecond: List.generate(13, (i) => i.isEven ? 20 : 0),
);

void main() {
  testWidgets('results panel renders a live snapshot without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = FlowRunSession()..snapshot = _snapshot();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FlowResults(session: session)),
        ),
      ),
    );
    expect(find.text('48,210'), findsOneWidget);
    expect(find.text('Throughput (requests / second)'), findsOneWidget);
    expect(find.text('Per step'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('flowFromEndpoints turns every enabled endpoint into a step', () {
    final project = MockProject.fromJson(SampleData.welcomeProject().toJson());
    final flow = AppState.flowFromEndpoints(project);
    expect(flow.steps.length, project.endpoints.where((e) => e.enabled).length);
    expect(flow.steps.any((s) => s.path.contains('{{vu}}')), isTrue);
  });

  test('flows round-trip through project JSON and stay optional', () {
    final project = MockProject(
      flows: [
        LoadFlow(
          name: 'Checkout',
          mode: StepMode.parallel,
          steps: [
            FlowStep(method: 'POST', path: '/login', extract: {'t': 'token'}),
          ],
        ),
      ],
    );
    final back = MockProject.fromJson(project.toJson());
    expect(back.flows.single.name, 'Checkout');
    expect(back.flows.single.mode, StepMode.parallel);
    expect(back.flows.single.steps.single.extract, {'t': 'token'});
    expect(MockProject().toJson().containsKey('flows'), isFalse);
  });
}
