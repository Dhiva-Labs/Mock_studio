import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_response.dart';

/// Generates mock endpoints from an OpenAPI / Swagger document (JSON or YAML).
/// Uses response examples when present, otherwise synthesises a body from the
/// response schema.
class OpenApiImporter {
  static List<Endpoint> import(String source) {
    final doc = _parse(source);
    final paths = doc['paths'];
    if (paths is! Map) {
      throw const FormatException(
        'No "paths" section found — is this an OpenAPI file?',
      );
    }

    final endpoints = <Endpoint>[];
    paths.forEach((pathKey, pathItem) {
      if (pathItem is! Map) return;
      pathItem.forEach((methodKey, operation) {
        final method = HttpMethodTypeX.fromString(methodKey.toString());
        if (!_isHttpMethod(methodKey.toString())) return;
        if (operation is! Map) return;

        final template = _convertPath(pathKey.toString());
        final summary =
            (operation['summary'] ??
                    operation['operationId'] ??
                    '$methodKey $pathKey')
                .toString();
        final responses = _buildResponses(operation, doc);

        endpoints.add(
          Endpoint(
            name: summary,
            method: method,
            path: template,
            strategy: responses.length > 1
                ? ResponseStrategy.rules
                : ResponseStrategy.single,
            responses: responses,
            description: (operation['description'] ?? '').toString(),
          ),
        );
      });
    });

    if (endpoints.isEmpty) {
      throw const FormatException('No operations found in the document.');
    }
    return endpoints;
  }

  static List<MockResponse> _buildResponses(Map operation, Map doc) {
    final result = <MockResponse>[];
    final responses = operation['responses'];
    if (responses is Map) {
      responses.forEach((code, respObj) {
        final status = int.tryParse(code.toString()) ?? 200;
        String body = '';
        if (respObj is Map) {
          final content = respObj['content'];
          if (content is Map) {
            final appJson = content['application/json'];
            if (appJson is Map) {
              final example =
                  appJson['example'] ??
                  (appJson['examples'] is Map
                      ? (appJson['examples'] as Map).values.first is Map
                            ? ((appJson['examples'] as Map).values.first
                                  as Map)['value']
                            : null
                      : null);
              if (example != null) {
                body = const JsonEncoder.withIndent(
                  '  ',
                ).convert(_normalize(example));
              } else if (appJson['schema'] is Map) {
                body = const JsonEncoder.withIndent(
                  '  ',
                ).convert(_fromSchema(appJson['schema'] as Map, doc, 0));
              }
            }
          }
          if (body.isEmpty) {
            body = jsonEncode({
              'message': (respObj['description'] ?? 'OK').toString(),
            });
          }
        }
        result.add(
          MockResponse(
            label: '$status ${_statusText(status)}',
            statusCode: status,
            bodyType: BodyType.json,
            body: body.isEmpty ? '{}' : body,
          ),
        );
      });
    }
    if (result.isEmpty) {
      result.add(MockResponse(label: '200 OK', statusCode: 200, body: '{}'));
    }
    // Put the first 2xx first so "single" strategy picks a success.
    result.sort((a, b) {
      final aok = a.statusCode >= 200 && a.statusCode < 300 ? 0 : 1;
      final bok = b.statusCode >= 200 && b.statusCode < 300 ? 0 : 1;
      return aok.compareTo(bok);
    });
    return result;
  }

  /// Recursively synthesises example data from a JSON schema.
  static dynamic _fromSchema(Map schema, Map doc, int depth) {
    if (depth > 6) return null;
    if (schema[r'$ref'] is String) {
      final resolved = _resolveRef(schema[r'$ref'] as String, doc);
      if (resolved != null) return _fromSchema(resolved, doc, depth + 1);
    }
    if (schema['example'] != null) return _normalize(schema['example']);
    final type = schema['type']?.toString();
    switch (type) {
      case 'object':
        final props = schema['properties'];
        final out = <String, dynamic>{};
        if (props is Map) {
          props.forEach((k, v) {
            if (v is Map) out[k.toString()] = _fromSchema(v, doc, depth + 1);
          });
        }
        return out;
      case 'array':
        final items = schema['items'];
        if (items is Map) return [_fromSchema(items, doc, depth + 1)];
        return [];
      case 'integer':
        return 0;
      case 'number':
        return 0;
      case 'boolean':
        return true;
      case 'string':
        final fmt = schema['format']?.toString();
        if (fmt == 'date-time') return '2024-01-01T00:00:00Z';
        if (fmt == 'email') return 'user@example.com';
        if (fmt == 'uuid') return '00000000-0000-4000-8000-000000000000';
        return 'string';
      default:
        if (schema['properties'] is Map) {
          return _fromSchema({...schema, 'type': 'object'}, doc, depth);
        }
        return null;
    }
  }

  static Map? _resolveRef(String ref, Map doc) {
    if (!ref.startsWith('#/')) return null;
    dynamic current = doc;
    for (final part in ref.substring(2).split('/')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current is Map ? current : null;
  }

  static Map<String, dynamic> _parse(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('{')) {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    }
    final yaml = loadYaml(source);
    return _normalize(yaml) as Map<String, dynamic>;
  }

  /// Converts YAML maps/lists into plain JSON-serialisable structures.
  static dynamic _normalize(dynamic node) {
    if (node is YamlMap || node is Map) {
      return {
        for (final e in (node as Map).entries)
          e.key.toString(): _normalize(e.value),
      };
    }
    if (node is YamlList || node is List) {
      return [for (final e in (node as List)) _normalize(e)];
    }
    return node;
  }

  /// `/users/{id}` → `/users/:id`
  static String _convertPath(String openApiPath) {
    return openApiPath.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (m) => ':${m.group(1)}',
    );
  }

  static bool _isHttpMethod(String s) => const {
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options',
  }.contains(s.toLowerCase());

  static String _statusText(int code) {
    switch (code) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Server Error';
      default:
        return '';
    }
  }
}
