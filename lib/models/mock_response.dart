import 'package:uuid/uuid.dart';

import 'enums.dart';

const _uuid = Uuid();

/// A single condition evaluated against an incoming request.
class RuleCondition {
  ConditionSource source;

  /// The name/key to read (query param name, header name, JSON path, etc.).
  /// Ignored for [ConditionSource.method].
  String key;

  ConditionOperator operator;

  /// The value to compare against. Ignored for [ConditionOperator.exists].
  String value;

  RuleCondition({
    this.source = ConditionSource.query,
    this.key = '',
    this.operator = ConditionOperator.equals,
    this.value = '',
  });

  RuleCondition copy() =>
      RuleCondition(source: source, key: key, operator: operator, value: value);

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'key': key,
    'operator': operator.name,
    'value': value,
  };

  factory RuleCondition.fromJson(Map<String, dynamic> j) => RuleCondition(
    source: ConditionSourceX.fromString(j['source'] as String?),
    key: (j['key'] as String?) ?? '',
    operator: ConditionOperatorX.fromString(j['operator'] as String?),
    value: (j['value'] as String?) ?? '',
  );

  String describe() {
    final where = source == ConditionSource.method
        ? 'method'
        : '${source.label} "$key"';
    if (operator == ConditionOperator.exists) return '$where exists';
    return '$where ${operator.label} "$value"';
  }
}

/// A response variant. In [ResponseStrategy.rules], [conditions] decide whether
/// it is used; in other strategies conditions are ignored.
class MockResponse {
  String id;

  /// Human label shown in the UI (e.g. "Success", "Not found", "Rate limited").
  String label;

  int statusCode;
  BodyType bodyType;
  String body;

  /// Extra response headers. Content-Type is added automatically from bodyType
  /// unless overridden here.
  Map<String, String> headers;

  /// Conditions (ALL must match) for rule-based selection.
  List<RuleCondition> conditions;

  /// Weight for random strategy. Higher = more likely.
  int weight;

  /// Per-response latency override in ms; null uses the endpoint default.
  int? delayMs;

  FaultType fault;

  MockResponse({
    String? id,
    this.label = 'Response',
    this.statusCode = 200,
    this.bodyType = BodyType.json,
    this.body = '{\n  "message": "Hello from Mock Studio"\n}',
    Map<String, String>? headers,
    List<RuleCondition>? conditions,
    this.weight = 1,
    this.delayMs,
    this.fault = FaultType.none,
  }) : id = id ?? _uuid.v4(),
       headers = headers ?? {},
       conditions = conditions ?? [];

  MockResponse copy() => MockResponse(
    id: _uuid.v4(),
    label: label,
    statusCode: statusCode,
    bodyType: bodyType,
    body: body,
    headers: Map.of(headers),
    conditions: conditions.map((c) => c.copy()).toList(),
    weight: weight,
    delayMs: delayMs,
    fault: fault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'statusCode': statusCode,
    'bodyType': bodyType.name,
    'body': body,
    'headers': headers,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'weight': weight,
    'delayMs': delayMs,
    'fault': fault.name,
  };

  factory MockResponse.fromJson(Map<String, dynamic> j) => MockResponse(
    id: j['id'] as String?,
    label: (j['label'] as String?) ?? 'Response',
    statusCode: (j['statusCode'] as num?)?.toInt() ?? 200,
    bodyType: BodyTypeX.fromString(j['bodyType'] as String?),
    body: (j['body'] as String?) ?? '',
    headers:
        (j['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        {},
    conditions:
        (j['conditions'] as List?)
            ?.map((e) => RuleCondition.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    weight: (j['weight'] as num?)?.toInt() ?? 1,
    delayMs: (j['delayMs'] as num?)?.toInt(),
    fault: FaultTypeX.fromString(j['fault'] as String?),
  );
}
