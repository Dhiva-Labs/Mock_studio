import 'package:uuid/uuid.dart';

import 'enums.dart';
import 'mock_response.dart';

const _uuid = Uuid();

/// A single mock endpoint: a method + path template and one or more responses.
class Endpoint {
  String id;
  String name;
  HttpMethodType method;

  /// Path template, e.g. `/users/:id` or `/files/*`. Leading slash optional.
  String path;

  bool enabled;

  ResponseStrategy strategy;
  List<MockResponse> responses;

  /// Default latency in ms applied unless a response overrides it.
  int defaultDelayMs;

  /// Randomised extra latency 0..jitterMs added to the delay.
  int jitterMs;

  /// If true, this endpoint requires an Authorization header / api key.
  bool requireAuth;

  /// Name of the header expected when [requireAuth] is on (e.g. Authorization).
  String authHeader;

  /// Optional description shown to the user; also used as docs.
  String description;

  /// Folder path in the endpoint tree, segments joined by '/' ('' = root).
  /// Organisational only; it does not affect routing.
  String folder;

  /// Runtime cursor for sequence strategy (not persisted).
  int sequenceCursor = 0;

  Endpoint({
    String? id,
    this.name = 'New endpoint',
    this.method = HttpMethodType.get,
    this.path = '/hello',
    this.enabled = true,
    this.strategy = ResponseStrategy.single,
    List<MockResponse>? responses,
    this.defaultDelayMs = 0,
    this.jitterMs = 0,
    this.requireAuth = false,
    this.authHeader = 'Authorization',
    this.description = '',
    this.folder = '',
  }) : id = id ?? _uuid.v4(),
       responses = responses ?? [MockResponse()];

  String get normalizedPath {
    var p = path.trim();
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }

  Endpoint copy() => Endpoint(
    id: _uuid.v4(),
    name: '$name (copy)',
    method: method,
    path: path,
    enabled: enabled,
    strategy: strategy,
    responses: responses.map((r) => r.copy()).toList(),
    defaultDelayMs: defaultDelayMs,
    jitterMs: jitterMs,
    requireAuth: requireAuth,
    authHeader: authHeader,
    description: description,
    folder: folder,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'method': method.name,
    'path': path,
    'enabled': enabled,
    'strategy': strategy.name,
    'responses': responses.map((r) => r.toJson()).toList(),
    'defaultDelayMs': defaultDelayMs,
    'jitterMs': jitterMs,
    'requireAuth': requireAuth,
    'authHeader': authHeader,
    'description': description,
    if (folder.isNotEmpty) 'folder': folder,
  };

  factory Endpoint.fromJson(Map<String, dynamic> j) => Endpoint(
    id: j['id'] as String?,
    name: (j['name'] as String?) ?? 'Endpoint',
    method: HttpMethodTypeX.fromString(j['method'] as String?),
    path: (j['path'] as String?) ?? '/',
    enabled: (j['enabled'] as bool?) ?? true,
    strategy: ResponseStrategyX.fromString(j['strategy'] as String?),
    responses:
        (j['responses'] as List?)
            ?.map((e) => MockResponse.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [MockResponse()],
    defaultDelayMs: (j['defaultDelayMs'] as num?)?.toInt() ?? 0,
    jitterMs: (j['jitterMs'] as num?)?.toInt() ?? 0,
    requireAuth: (j['requireAuth'] as bool?) ?? false,
    authHeader: (j['authHeader'] as String?) ?? 'Authorization',
    description: (j['description'] as String?) ?? '',
    folder: (j['folder'] as String?) ?? '',
  );
}
