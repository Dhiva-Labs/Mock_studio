// Shared enumerations used across Mock Studio models.

/// HTTP methods an endpoint can match. [any] matches every method.
enum HttpMethodType { any, get, post, put, patch, delete, head, options }

extension HttpMethodTypeX on HttpMethodType {
  String get label => this == HttpMethodType.any ? 'ANY' : name.toUpperCase();

  /// Whether this endpoint definition matches an incoming request method.
  bool matches(String requestMethod) {
    if (this == HttpMethodType.any) return true;
    return label == requestMethod.toUpperCase();
  }

  static HttpMethodType fromString(String? value) {
    if (value == null) return HttpMethodType.get;
    final v = value.toLowerCase();
    return HttpMethodType.values.firstWhere(
      (e) => e.name == v,
      orElse: () => HttpMethodType.get,
    );
  }
}

/// The kind of body a response returns; drives content-type + editor hints.
enum BodyType { json, text, html, xml, none }

extension BodyTypeX on BodyType {
  String get label {
    switch (this) {
      case BodyType.json:
        return 'JSON';
      case BodyType.text:
        return 'Text';
      case BodyType.html:
        return 'HTML';
      case BodyType.xml:
        return 'XML';
      case BodyType.none:
        return 'Empty';
    }
  }

  String get contentType {
    switch (this) {
      case BodyType.json:
        return 'application/json';
      case BodyType.text:
        return 'text/plain';
      case BodyType.html:
        return 'text/html';
      case BodyType.xml:
        return 'application/xml';
      case BodyType.none:
        return 'text/plain';
    }
  }

  static BodyType fromString(String? value) {
    return BodyType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BodyType.json,
    );
  }
}

/// How an endpoint decides which of its responses to send.
enum ResponseStrategy {
  /// Always use the first (default) response.
  single,

  /// Evaluate rule conditions; fall through to the default response.
  rules,

  /// Cycle through responses in order, one per request.
  sequence,

  /// Pick a response randomly, weighted by each response's weight.
  random,
}

extension ResponseStrategyX on ResponseStrategy {
  String get label {
    switch (this) {
      case ResponseStrategy.single:
        return 'Single response';
      case ResponseStrategy.rules:
        return 'Conditional rules';
      case ResponseStrategy.sequence:
        return 'Sequence (round-robin)';
      case ResponseStrategy.random:
        return 'Random / weighted';
    }
  }

  String get hint {
    switch (this) {
      case ResponseStrategy.single:
        return 'Always returns the same response.';
      case ResponseStrategy.rules:
        return 'Returns different responses based on the request (query, header, body).';
      case ResponseStrategy.sequence:
        return 'Returns each response in turn — great for testing retries.';
      case ResponseStrategy.random:
        return 'Picks a response at random by weight — simulate a flaky service.';
    }
  }

  static ResponseStrategy fromString(String? value) {
    return ResponseStrategy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ResponseStrategy.single,
    );
  }
}

/// Where a rule reads its value from.
enum ConditionSource { query, header, pathParam, bodyJson, method }

extension ConditionSourceX on ConditionSource {
  String get label {
    switch (this) {
      case ConditionSource.query:
        return 'Query param';
      case ConditionSource.header:
        return 'Header';
      case ConditionSource.pathParam:
        return 'Path param';
      case ConditionSource.bodyJson:
        return 'Body field (JSON path)';
      case ConditionSource.method:
        return 'HTTP method';
    }
  }

  static ConditionSource fromString(String? value) {
    return ConditionSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConditionSource.query,
    );
  }
}

/// Comparison operator for a rule condition.
enum ConditionOperator {
  equals,
  notEquals,
  contains,
  exists,
  regex,
  greaterThan,
  lessThan,
}

extension ConditionOperatorX on ConditionOperator {
  String get label {
    switch (this) {
      case ConditionOperator.equals:
        return 'equals';
      case ConditionOperator.notEquals:
        return 'does not equal';
      case ConditionOperator.contains:
        return 'contains';
      case ConditionOperator.exists:
        return 'exists';
      case ConditionOperator.regex:
        return 'matches regex';
      case ConditionOperator.greaterThan:
        return 'greater than';
      case ConditionOperator.lessThan:
        return 'less than';
    }
  }

  static ConditionOperator fromString(String? value) {
    return ConditionOperator.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConditionOperator.equals,
    );
  }
}

/// A deliberate fault injected before/instead of a normal response.
enum FaultType {
  none,

  /// Close the socket immediately with no response.
  connectionReset,

  /// Send the response's status code with an empty body.
  emptyResponse,

  /// Return malformed/garbage bytes.
  malformedBody,

  /// Never respond (hang) — good for timeout testing.
  hang,
}

extension FaultTypeX on FaultType {
  String get label {
    switch (this) {
      case FaultType.none:
        return 'No fault';
      case FaultType.connectionReset:
        return 'Drop connection';
      case FaultType.emptyResponse:
        return 'Empty response';
      case FaultType.malformedBody:
        return 'Malformed body';
      case FaultType.hang:
        return 'Hang (never respond)';
    }
  }

  static FaultType fromString(String? value) {
    return FaultType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FaultType.none,
    );
  }
}
