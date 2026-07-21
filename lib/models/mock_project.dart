import 'package:uuid/uuid.dart';

import 'endpoint.dart';

const _uuid = Uuid();

/// A workspace grouping endpoints for one API/app under test. Serialises to a
/// single JSON file so it can be committed to a repo and shared.
class MockProject {
  String id;
  String name;
  String description;

  /// Port the embedded server listens on.
  int port;

  /// Enable permissive CORS so browser apps can call the mock directly.
  bool corsEnabled;

  /// When set, requests that match no endpoint are proxied to this base URL.
  String proxyBaseUrl;

  /// If true, proxied responses can be recorded into new endpoints.
  bool recordProxy;

  /// Global artificial latency (ms) added to every response.
  int globalDelayMs;

  /// Headers injected into every response.
  Map<String, String> globalHeaders;

  List<Endpoint> endpoints;

  /// File path on disk once saved (not serialised into the file itself).
  String? filePath;

  MockProject({
    String? id,
    this.name = 'New project',
    this.description = '',
    this.port = 8080,
    this.corsEnabled = true,
    this.proxyBaseUrl = '',
    this.recordProxy = false,
    this.globalDelayMs = 0,
    Map<String, String>? globalHeaders,
    List<Endpoint>? endpoints,
    this.filePath,
  }) : id = id ?? _uuid.v4(),
       globalHeaders = globalHeaders ?? {},
       endpoints = endpoints ?? [];

  Map<String, dynamic> toJson() => {
    'mockstudioVersion': 1,
    'id': id,
    'name': name,
    'description': description,
    'port': port,
    'corsEnabled': corsEnabled,
    'proxyBaseUrl': proxyBaseUrl,
    'recordProxy': recordProxy,
    'globalDelayMs': globalDelayMs,
    'globalHeaders': globalHeaders,
    'endpoints': endpoints.map((e) => e.toJson()).toList(),
  };

  factory MockProject.fromJson(Map<String, dynamic> j, {String? filePath}) =>
      MockProject(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? 'Project',
        description: (j['description'] as String?) ?? '',
        port: (j['port'] as num?)?.toInt() ?? 8080,
        corsEnabled: (j['corsEnabled'] as bool?) ?? true,
        proxyBaseUrl: (j['proxyBaseUrl'] as String?) ?? '',
        recordProxy: (j['recordProxy'] as bool?) ?? false,
        globalDelayMs: (j['globalDelayMs'] as num?)?.toInt() ?? 0,
        globalHeaders:
            (j['globalHeaders'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            {},
        endpoints:
            (j['endpoints'] as List?)
                ?.map((e) => Endpoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        filePath: filePath,
      );

  MockProject copyWith({String? name, int? port}) => MockProject(
    id: id,
    name: name ?? this.name,
    description: description,
    port: port ?? this.port,
    corsEnabled: corsEnabled,
    proxyBaseUrl: proxyBaseUrl,
    recordProxy: recordProxy,
    globalDelayMs: globalDelayMs,
    globalHeaders: Map.of(globalHeaders),
    endpoints: endpoints,
    filePath: filePath,
  );
}
