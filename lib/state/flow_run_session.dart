import 'package:flutter/foundation.dart';

import '../models/load_flow.dart';
import '../services/flow_runner.dart';

/// Live state of one flow's run. Listened to directly by the Flows view so
/// ~4 progress updates a second don't rebuild the rest of the app.
class FlowRunSession extends ChangeNotifier {
  IsolateFlowRun? _run;
  RunSnapshot? snapshot;
  DateTime? startedAt;

  bool get isRunning => _run != null;

  Future<void> start(LoadFlow flow, String baseUrl) async {
    if (isRunning) return;
    snapshot = null;
    startedAt = DateTime.now();
    final run = _run = IsolateFlowRun(
      // Snapshot the definition so edits during a run don't affect it.
      flow: LoadFlow.fromJson(flow.toJson()),
      baseUrl: baseUrl,
      onSnapshot: (s) {
        snapshot = s;
        if (s.done) _run = null;
        notifyListeners();
      },
    );
    notifyListeners();
    await run.start();
  }

  void stop() => _run?.stop();

  @override
  void dispose() {
    _run?.stop();
    super.dispose();
  }
}
