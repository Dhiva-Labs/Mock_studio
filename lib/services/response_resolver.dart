import 'dart:convert';
import 'dart:math';

import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_response.dart';
import 'template_engine.dart';

/// Selects which [MockResponse] an endpoint should return for a request.
class ResponseResolver {
  static final _rng = Random();

  static MockResponse select(
    Endpoint endpoint,
    TemplateContext ctx,
    String method,
  ) {
    if (endpoint.responses.isEmpty) return MockResponse();

    switch (endpoint.strategy) {
      case ResponseStrategy.single:
        return endpoint.responses.first;

      case ResponseStrategy.sequence:
        final idx = endpoint.sequenceCursor % endpoint.responses.length;
        endpoint.sequenceCursor =
            (endpoint.sequenceCursor + 1) % endpoint.responses.length;
        return endpoint.responses[idx];

      case ResponseStrategy.random:
        final total = endpoint.responses.fold<int>(
          0,
          (s, r) => s + max(1, r.weight),
        );
        var roll = _rng.nextInt(total);
        for (final r in endpoint.responses) {
          roll -= max(1, r.weight);
          if (roll < 0) return r;
        }
        return endpoint.responses.first;

      case ResponseStrategy.rules:
        for (final r in endpoint.responses) {
          if (r.conditions.isEmpty) {
            continue; // default fall-through handled below
          }
          if (r.conditions.every((c) => _evaluate(c, ctx, method))) {
            return r;
          }
        }
        // Fall back to the first response without conditions, else the first.
        return endpoint.responses.firstWhere(
          (r) => r.conditions.isEmpty,
          orElse: () => endpoint.responses.first,
        );
    }
  }

  static bool _evaluate(RuleCondition c, TemplateContext ctx, String method) {
    final actual = _readSource(c, ctx, method);
    switch (c.operator) {
      case ConditionOperator.exists:
        return actual != null && actual.isNotEmpty;
      case ConditionOperator.equals:
        return actual == c.value;
      case ConditionOperator.notEquals:
        return actual != c.value;
      case ConditionOperator.contains:
        return actual != null && actual.contains(c.value);
      case ConditionOperator.regex:
        if (actual == null) return false;
        try {
          return RegExp(c.value).hasMatch(actual);
        } catch (_) {
          return false;
        }
      case ConditionOperator.greaterThan:
        final a = num.tryParse(actual ?? '');
        final b = num.tryParse(c.value);
        return a != null && b != null && a > b;
      case ConditionOperator.lessThan:
        final a = num.tryParse(actual ?? '');
        final b = num.tryParse(c.value);
        return a != null && b != null && a < b;
    }
  }

  static String? _readSource(
    RuleCondition c,
    TemplateContext ctx,
    String method,
  ) {
    switch (c.source) {
      case ConditionSource.method:
        return method.toUpperCase();
      case ConditionSource.query:
        return ctx.query[c.key];
      case ConditionSource.pathParam:
        return ctx.pathParams[c.key];
      case ConditionSource.header:
        final key = c.key.toLowerCase();
        for (final e in ctx.headers.entries) {
          if (e.key.toLowerCase() == key) return e.value;
        }
        return null;
      case ConditionSource.bodyJson:
        return _jsonPath(ctx.bodyJson, c.key);
    }
  }

  static String? _jsonPath(Map<String, dynamic>? root, String path) {
    if (root == null || path.isEmpty) return null;
    dynamic current = root;
    for (final part in path.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    if (current == null) return null;
    if (current is Map || current is List) return jsonEncode(current);
    return current.toString();
  }
}
