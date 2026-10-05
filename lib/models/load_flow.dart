import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// How the steps of one flow iteration are executed by a virtual user.
enum StepMode {
  /// Steps run one by one, in order; later steps can use extracted variables.
  sequential,

  /// All steps of an iteration fire at the same time.
  parallel,
}

extension StepModeX on StepMode {
  String get label =>
      this == StepMode.sequential ? 'One by one' : 'All at once';

  static StepMode fromString(String? value) => StepMode.values.firstWhere(
    (e) => e.name == value,
    orElse: () => StepMode.sequential,
  );
}

/// One HTTP call inside a [LoadFlow].
///
/// [path], [headers] and [body] are templates: besides the usual tokens
/// (`{{uuid}}`, `{{faker.name}}`, `{{randomInt(1,9)}}`…) they can use
/// `{{vars.<name>}}` (values extracted by earlier steps), `{{vu}}` (virtual
/// user number) and `{{iteration}}`.
class FlowStep {
  String id;
  String name;
  String method;
  String path;
  Map<String, String> headers;
  String body;

  /// Accepted statuses, e.g. `2xx`, `200`, `200,201,404`. Empty = any < 400.
  String expectStatus;

  /// Variables to capture from the response: name → source, where source is
  /// `body.<json.path>` (or a bare JSON path), `header.<name>` or `status`.
  Map<String, String> extract;

  bool enabled;

  FlowStep({
    String? id,
    this.name = '',
    this.method = 'GET',
    this.path = '/',
    Map<String, String>? headers,
    this.body = '',
    this.expectStatus = '',
    Map<String, String>? extract,
    this.enabled = true,
  }) : id = id ?? _uuid.v4(),
       headers = headers ?? {},
       extract = extract ?? {};

  String get displayName => name.trim().isEmpty ? '$method $path' : name;

  FlowStep copy() => FlowStep(
    name: name,
    method: method,
    path: path,
    headers: Map.of(headers),
    body: body,
    expectStatus: expectStatus,
    extract: Map.of(extract),
    enabled: enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'method': method,
    'path': path,
    'headers': headers,
    'body': body,
    'expectStatus': expectStatus,
    'extract': extract,
    'enabled': enabled,
  };

  factory FlowStep.fromJson(Map<String, dynamic> j) => FlowStep(
    id: j['id'] as String?,
    name: (j['name'] as String?) ?? '',
    method: ((j['method'] as String?) ?? 'GET').toUpperCase(),
    path: (j['path'] as String?) ?? '/',
    headers: _stringMap(j['headers']),
    body: (j['body'] as String?) ?? '',
    expectStatus: (j['expectStatus'] as String?) ?? '',
    extract: _stringMap(j['extract']),
    enabled: (j['enabled'] as bool?) ?? true,
  );

  /// Whether [status] satisfies [expectStatus].
  bool accepts(int status) => statusMatches(expectStatus, status);

  static bool statusMatches(String spec, int status) {
    final s = spec.trim();
    if (s.isEmpty) return status > 0 && status < 400;
    for (final raw in s.split(',')) {
      final part = raw.trim().toLowerCase();
      if (part.isEmpty) continue;
      if (part.length == 3 && part.endsWith('xx')) {
        final cls = int.tryParse(part[0]);
        if (cls != null && status ~/ 100 == cls) return true;
      } else if (int.tryParse(part) == status) {
        return true;
      }
    }
    return false;
  }
}

/// A scripted, concurrent traffic scenario: [virtualUsers] users each run the
/// [steps] repeatedly, either for [iterations] rounds or for [durationSec].
class LoadFlow {
  String id;
  String name;
  List<FlowStep> steps;
  StepMode mode;

  /// Number of concurrent simulated users.
  int virtualUsers;

  /// Rounds per virtual user. Ignored when [durationSec] > 0.
  int iterations;

  /// Run for this many seconds instead of a fixed iteration count (0 = off).
  int durationSec;

  /// Seconds over which virtual users are started (0 = all at once).
  int rampUpSec;

  /// Pause after each step (sequential) or iteration (parallel), in ms.
  int thinkTimeMs;

  /// Base URL to target. Empty = this project's local mock server.
  String targetUrl;

  /// Abort an iteration at the first failed step (sequential mode only).
  bool stopOnFailure;

  LoadFlow({
    String? id,
    this.name = 'New flow',
    List<FlowStep>? steps,
    this.mode = StepMode.sequential,
    this.virtualUsers = 5,
    this.iterations = 10,
    this.durationSec = 0,
    this.rampUpSec = 0,
    this.thinkTimeMs = 0,
    this.targetUrl = '',
    this.stopOnFailure = true,
  }) : id = id ?? _uuid.v4(),
       steps = steps ?? [];

  LoadFlow copy() => LoadFlow(
    name: '$name (copy)',
    steps: steps.map((s) => s.copy()).toList(),
    mode: mode,
    virtualUsers: virtualUsers,
    iterations: iterations,
    durationSec: durationSec,
    rampUpSec: rampUpSec,
    thinkTimeMs: thinkTimeMs,
    targetUrl: targetUrl,
    stopOnFailure: stopOnFailure,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode.name,
    'virtualUsers': virtualUsers,
    'iterations': iterations,
    'durationSec': durationSec,
    'rampUpSec': rampUpSec,
    'thinkTimeMs': thinkTimeMs,
    'targetUrl': targetUrl,
    'stopOnFailure': stopOnFailure,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  factory LoadFlow.fromJson(Map<String, dynamic> j) => LoadFlow(
    id: j['id'] as String?,
    name: (j['name'] as String?) ?? 'Flow',
    mode: StepModeX.fromString(j['mode'] as String?),
    virtualUsers: (j['virtualUsers'] as num?)?.toInt() ?? 5,
    iterations: (j['iterations'] as num?)?.toInt() ?? 10,
    durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
    rampUpSec: (j['rampUpSec'] as num?)?.toInt() ?? 0,
    thinkTimeMs: (j['thinkTimeMs'] as num?)?.toInt() ?? 0,
    targetUrl: (j['targetUrl'] as String?) ?? '',
    stopOnFailure: (j['stopOnFailure'] as bool?) ?? true,
    steps:
        (j['steps'] as List?)
            ?.map((e) => FlowStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

Map<String, String> _stringMap(Object? raw) =>
    (raw as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
