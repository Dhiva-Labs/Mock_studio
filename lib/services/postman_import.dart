import 'dart:convert';

import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_response.dart';
import 'template_engine.dart';

/// Result of converting a Postman collection into mock endpoints.
class PostmanMockImport {
  /// Collection name (`info.name`).
  String name;

  /// Collection description ('' if none).
  String description;

  final List<Endpoint> endpoints;

  /// Folders seen while walking the collection (nested ones included).
  int folders = 0;

  /// Requests converted into endpoints.
  int requests = 0;

  /// Saved examples converted into responses.
  int examples = 0;

  /// Human-readable notes about anything that didn't convert cleanly.
  final List<String> warnings;

  PostmanMockImport({
    this.name = '',
    this.description = '',
    List<Endpoint>? endpoints,
    List<String>? warnings,
  }) : endpoints = endpoints ?? [],
       warnings = warnings ?? [];
}

/// Request header that picks a saved example by name, as Postman's own mock
/// servers do. Examples that can't be told apart by query string get a rule
/// on it so every example stays reachable.
const postmanResponseNameHeader = 'x-mock-response-name';

/// Converts a Postman collection (v2.1, v2.0, v1, or a loose request item /
/// item list) into mock endpoints: one per request, one response per saved
/// example.
///
/// Throws [FormatException] with a readable message for non-JSON input,
/// environment files and other JSON that isn't a collection.
PostmanMockImport importPostmanToMocks(String raw) {
  if (raw.trim().isEmpty) {
    throw const FormatException('The file is empty.');
  }
  final Object? doc;
  try {
    doc = jsonDecode(raw);
  } on FormatException {
    throw const FormatException(
      'This file isn\'t valid JSON. In Postman, export the collection as '
      '"Collection v2.1" and import that file.',
    );
  }
  return _PostmanConverter().convert(doc);
}

class _PostmanConverter {
  final result = PostmanMockImport();

  /// Collection variables with a usable value, for example bodies/headers.
  final _vars = <String, String>{};

  // Aggregated warning inputs; turned into sentences once at the end.
  var _noExamples = 0;
  var _queryAuth = 0;
  final _unresolvedVars = <String>{};
  final _wildcardVars = <String>{};
  final _unknownMethods = <String>{};
  var _unknownMethodCount = 0;
  final _hostPathPrefixes = <String, String>{};

  static final _wholeVar = RegExp(r'^\{\{\s*([^{}]+?)\s*\}\}$');
  static final _anyVar = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');
  static final _scheme = RegExp(r'^[^/?#]*://');

  /// Headers that describe the original transfer, not the payload; the mock
  /// server sets its own.
  static const _droppedHeaders = {
    'content-length',
    'transfer-encoding',
    'date',
    'connection',
    'keep-alive',
    'content-encoding',
  };

  /// Auth schemes Postman sends in the Authorization header.
  static const _authorizationSchemes = {
    'bearer',
    'basic',
    'digest',
    'oauth1',
    'oauth2',
    'hawk',
    'awsv4',
    'ntlm',
    'edgegrid',
    'jwt',
    'asap',
    'akamai',
  };

  /// Postman dynamic variables with a Mock Studio template equivalent.
  static const _dynamicVars = {
    r'$guid': '{{uuid}}',
    r'$randomUUID': '{{uuid}}',
    r'$timestamp': '{{timestamp}}',
    r'$isoTimestamp': '{{now}}',
    r'$randomInt': '{{randomInt(0,1000)}}',
    r'$randomFullName': '{{faker.name}}',
    r'$randomFirstName': '{{faker.firstName}}',
    r'$randomLastName': '{{faker.lastName}}',
    r'$randomEmail': '{{faker.email}}',
    r'$randomExampleEmail': '{{faker.email}}',
    r'$randomCity': '{{faker.city}}',
    r'$randomCompanyName': '{{faker.company}}',
    r'$randomPhoneNumber': '{{faker.phone}}',
    r'$randomBoolean': '{{faker.bool}}',
    r'$randomWord': '{{faker.word}}',
    r'$randomHexColor': '{{faker.color}}',
  };

  PostmanMockImport convert(Object? doc) {
    if (doc is Map && doc['collection'] is Map && doc['item'] == null) {
      doc = doc['collection']; // Postman API export wrapper
    }

    if (doc is List) {
      if (!doc.any(_isItem)) throw _notACollection();
      result.name = 'Postman requests';
      _walk(doc, const [], null);
    } else if (doc is Map) {
      if (doc['values'] is List &&
          (doc.containsKey('_postman_variable_scope') ||
              (doc['item'] == null && doc['requests'] == null))) {
        throw const FormatException(
          'This is a Postman environment (or globals) file — it only holds '
          'variables, not requests. Export the collection itself and import '
          'that instead.',
        );
      }
      if (doc['openapi'] != null || doc['swagger'] != null) {
        throw const FormatException(
          'This looks like an OpenAPI document, not a Postman collection — '
          'use the OpenAPI import instead.',
        );
      }
      final info = doc['info'] is Map ? doc['info'] as Map : const {};
      if (doc['requests'] is List || doc['item'] != null) {
        result.name = _string(info['name'] ?? doc['name']).trim();
        result.description = _text(info['description'] ?? doc['description']);
        _readVariables(doc['variable'] ?? doc['variables']);
      }

      if (doc['requests'] is List) {
        _walk(_v1Items(doc), const [], null);
      } else if (doc['item'] is List || doc['item'] is Map) {
        final items = doc['item'];
        _walk(items is List ? items : [items], const [], _auth(doc['auth']));
      } else if (doc.containsKey('request')) {
        _walk([doc], const [], null); // a single request item
      } else {
        throw _notACollection();
      }
    } else {
      throw _notACollection();
    }

    if (result.requests == 0) {
      throw const FormatException('No requests found in this collection.');
    }
    if (result.name.isEmpty) result.name = 'Postman collection';
    _finishWarnings();
    return result;
  }

  FormatException _notACollection() => const FormatException(
    'This JSON isn\'t a Postman collection — expected "info" and "item" '
    '(v2.x) or "requests" (v1). In Postman, use Export → Collection v2.1.',
  );

  static bool _isItem(Object? e) =>
      e is Map && (e.containsKey('request') || e.containsKey('item'));

  // ---------------------------------------------------------------------------
  // Walking

  void _walk(List items, List<String> folderPath, Map? inheritedAuth) {
    for (final item in items) {
      if (item is! Map) continue;
      final children = item['item'];
      if (children is List || children is Map) {
        result.folders++;
        _walk(
          children is List ? children : [children],
          [...folderPath, _folderName(item['name'])],
          _inheritAuth(item['auth'], inheritedAuth),
        );
      } else if (item.containsKey('request')) {
        _convertRequest(item, folderPath.join('/'), inheritedAuth);
      }
    }
  }

  static String _folderName(Object? name) {
    final n = _string(name).trim();
    // '/' is the folder separator in Endpoint.folder.
    return n.isEmpty ? 'Untitled folder' : n.replaceAll('/', '∕');
  }

  void _convertRequest(Map item, String folder, Map? inheritedAuth) {
    var request = item['request'];
    if (request is String) request = {'url': request};
    if (request is! Map) request = const {};

    final methodName = _string(request['method']).trim().toUpperCase();
    final method = _method(methodName.isEmpty ? 'GET' : methodName);
    final url = request['url'];
    final path = _path(url);

    final name = _string(item['name']).trim();
    var description = _text(request['description']);
    if (description.isEmpty) description = _text(item['description']);

    final responses = _responses(item, url);
    final ep = Endpoint(
      name: name.isEmpty ? '${method.label} $path' : name,
      method: method,
      path: path,
      description: description,
      folder: folder,
      strategy: responses.length > 1
          ? ResponseStrategy.rules
          : ResponseStrategy.single,
      responses: responses,
    );

    final authHeader = _authHeader(
      _inheritAuth(request['auth'], inheritedAuth),
    );
    if (authHeader != null) {
      ep.requireAuth = true;
      ep.authHeader = authHeader;
    }

    result.endpoints.add(ep);
    result.requests++;
  }

  HttpMethodType _method(String name) {
    for (final m in HttpMethodType.values) {
      if (m != HttpMethodType.any && m.label == name) return m;
    }
    _unknownMethods.add(name);
    _unknownMethodCount++;
    return HttpMethodType.any;
  }

  // ---------------------------------------------------------------------------
  // Paths

  /// The path part of a Postman URL as a route template.
  String _path(Object? url) {
    List<String> segments;
    var host = '';
    if (url is Map) {
      final rawPath = url['path'];
      final h = url['host'];
      host = h is List ? h.map(_string).join('.') : _string(h);
      if (rawPath is List) {
        segments = [
          for (final s in rawPath) _string(s is Map ? s['value'] : s),
        ];
      } else if (rawPath is String) {
        segments = rawPath.split('/');
      } else {
        final split = _splitRaw(_string(url['raw']));
        host = split.host;
        segments = split.path.split('/');
      }
    } else {
      final split = _splitRaw(_string(url));
      host = split.host;
      segments = split.path.split('/');
    }

    _noteHostPathPrefix(host.trim());
    final converted = [
      for (final s in segments)
        if (s.trim().isNotEmpty) _segment(s.trim()),
    ];
    return '/${converted.join('/')}';
  }

  /// Splits a raw URL into host and path, dropping scheme, query and fragment.
  /// Like Postman, anything before the first '/' (after the scheme) is the
  /// host, so `{{baseUrl}}/users` → `/users`.
  static ({String host, String path}) _splitRaw(String raw) {
    var s = raw.trim();
    final cut = s.indexOf(RegExp('[?#]'));
    if (cut >= 0) s = s.substring(0, cut);
    s = s.replaceFirst(_scheme, '');
    if (s.startsWith('/')) return (host: '', path: s);
    final slash = s.indexOf('/');
    if (slash < 0) return (host: s, path: '');
    return (host: s.substring(0, slash), path: s.substring(slash));
  }

  String _segment(String seg) {
    final whole = _wholeVar.firstMatch(seg);
    if (whole != null) {
      final name = whole
          .group(1)!
          .replaceFirst(r'$', '')
          .replaceAll(RegExp(r'\s+'), '_');
      return name.isEmpty ? '*' : ':$name';
    }
    if (!seg.contains('{{')) return seg;
    // A variable inside a segment (`v{{version}}`): use the collection's value
    // if it has one, else match any value in that position.
    final resolved = _substitute(seg, record: false);
    if (!resolved.contains('{{')) return resolved;
    for (final m in _anyVar.allMatches(resolved)) {
      _wildcardVars.add(m.group(1)!);
    }
    return '*';
  }

  /// Remembers when a host-only variable like `{{baseUrl}}` also carries a
  /// path, since that prefix is dropped from the mock paths.
  void _noteHostPathPrefix(String host) {
    final m = _wholeVar.firstMatch(host);
    if (m == null) return;
    final value = _vars[m.group(1)!];
    if (value == null) return;
    final prefix = _splitRaw(value).path.replaceAll(RegExp(r'/+$'), '');
    if (prefix.isNotEmpty) _hostPathPrefixes[m.group(1)!] = prefix;
  }

  // ---------------------------------------------------------------------------
  // Responses

  List<MockResponse> _responses(Map item, Object? requestUrl) {
    final examples = item['response'] is List
        ? (item['response'] as List).whereType<Map>().toList()
        : <Map>[];
    if (examples.isEmpty) {
      _noExamples++;
      return [
        MockResponse(
          label: 'Default',
          statusCode: 200,
          bodyType: BodyType.json,
          body: '{\n  "ok": true\n}',
        ),
      ];
    }

    final converted = [
      for (var i = 0; i < examples.length; i++)
        (example: examples[i], response: _example(examples[i], i)),
    ];
    result.examples += converted.length;

    // The first 2xx example is the default: first in the list and, under the
    // rules strategy, the unconditioned fall-through response.
    final ok = converted.indexWhere(
      (c) => c.response.statusCode >= 200 && c.response.statusCode < 300,
    );
    if (ok > 0) converted.insert(0, converted.removeAt(ok));

    if (converted.length > 1) {
      final requestQuery = _query(requestUrl);
      for (final c in converted.skip(1)) {
        c.response.conditions.addAll(
          _exampleConditions(c.example, c.response, requestQuery),
        );
      }
    }
    return [for (final c in converted) c.response];
  }

  MockResponse _example(Map ex, int index) {
    final name = _string(ex['name']).trim();
    var code = _int(ex['code']) ?? 200;
    if (code < 100 || code > 599) code = 200;
    final headers = _headers(ex['header']);
    final body = _substitute(_string(ex['body']));
    String? contentType;
    headers.forEach((k, v) {
      if (k.toLowerCase() == 'content-type') contentType = v;
    });
    return MockResponse(
      label: name.isEmpty ? 'Example ${index + 1}' : name,
      statusCode: code,
      headers: headers,
      body: body,
      bodyType: _bodyType(body, ex['_postman_previewlanguage'], contentType),
    );
  }

  /// Query params that distinguish an example from its request (e.g.
  /// `?status=404`) become `equals` rules. Examples with none get a rule on
  /// [postmanResponseNameHeader] instead, so they can still be requested.
  List<RuleCondition> _exampleConditions(
    Map example,
    MockResponse response,
    Map<String, String> requestQuery,
  ) {
    final original = example['originalRequest'];
    final exampleQuery = original is Map
        ? _query(original['url'])
        : <String, String>{};
    final conditions = <RuleCondition>[];
    exampleQuery.forEach((key, value) {
      final resolved = _substitute(value, record: false);
      if (resolved.contains('{{') || requestQuery[key] == value) return;
      conditions.add(
        RuleCondition(
          source: ConditionSource.query,
          key: key,
          operator: ConditionOperator.equals,
          value: resolved,
        ),
      );
    });
    if (conditions.isNotEmpty) return conditions;
    return [
      RuleCondition(
        source: ConditionSource.header,
        key: postmanResponseNameHeader,
        operator: ConditionOperator.equals,
        value: response.label,
      ),
    ];
  }

  Map<String, String> _query(Object? url) {
    final out = <String, String>{};
    if (url is Map && url['query'] is List) {
      for (final q in (url['query'] as List).whereType<Map>()) {
        if (q['disabled'] == true) continue;
        final key = _string(q['key']);
        if (key.isEmpty) continue;
        out[_decode(key)] = _decode(_string(q['value']));
      }
      return out;
    }
    var raw = url is Map ? _string(url['raw']) : _string(url);
    final q = raw.indexOf('?');
    if (q < 0) return out;
    raw = raw.substring(q + 1);
    final hash = raw.indexOf('#');
    if (hash >= 0) raw = raw.substring(0, hash);
    for (final pair in raw.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final key = eq < 0 ? pair : pair.substring(0, eq);
      out[_decode(key)] = eq < 0 ? '' : _decode(pair.substring(eq + 1));
    }
    return out;
  }

  static String _decode(String s) {
    try {
      return Uri.decodeQueryComponent(s);
    } catch (_) {
      return s;
    }
  }

  Map<String, String> _headers(Object? raw) {
    final pairs = <(String, String)>[];
    if (raw is List) {
      for (final h in raw.whereType<Map>()) {
        if (h['disabled'] == true || h['enabled'] == false) continue;
        pairs.add((_string(h['key'] ?? h['name']), _string(h['value'])));
      }
    } else if (raw is String) {
      for (final line in const LineSplitter().convert(raw)) {
        final colon = line.indexOf(':');
        if (colon > 0) {
          pairs.add((line.substring(0, colon), line.substring(colon + 1)));
        }
      }
    }

    final out = <String, String>{};
    for (final (rawKey, rawValue) in pairs) {
      final key = rawKey.trim();
      if (key.isEmpty || _droppedHeaders.contains(key.toLowerCase())) continue;
      final value = _substitute(rawValue.trim());
      final existing = out.keys
          .where((k) => k.toLowerCase() == key.toLowerCase())
          .firstOrNull;
      if (existing == null) {
        out[key] = value;
      } else {
        out[existing] = '${out[existing]}, $value';
      }
    }
    return out;
  }

  static BodyType _bodyType(
    String body,
    Object? previewLanguage,
    String? contentType,
  ) {
    if (body.trim().isEmpty) return BodyType.none;
    final hint =
        _languageHint(_string(previewLanguage).toLowerCase()) ??
        _contentTypeHint((contentType ?? '').toLowerCase());
    if (hint == BodyType.json) {
      return _isJson(body) ? BodyType.json : BodyType.text;
    }
    if (hint != null) return hint;

    final t = body.trimLeft();
    final lower = t.toLowerCase();
    if ((t.startsWith('{') || t.startsWith('[')) && _isJson(body)) {
      return BodyType.json;
    }
    if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
      return BodyType.html;
    }
    if (t.startsWith('<')) return BodyType.xml;
    return BodyType.text;
  }

  static BodyType? _languageHint(String lang) => switch (lang) {
    'json' => BodyType.json,
    'xml' => BodyType.xml,
    'html' => BodyType.html,
    'text' || 'raw' || 'plain' || 'javascript' => BodyType.text,
    _ => null,
  };

  static BodyType? _contentTypeHint(String ct) {
    if (ct.contains('json')) return BodyType.json;
    if (ct.contains('html')) return BodyType.html;
    if (ct.contains('xml')) return BodyType.xml;
    if (ct.startsWith('text/')) return BodyType.text;
    return null;
  }

  /// JSON, tolerating template tokens in value positions (`{"id": {{id}}}`).
  static bool _isJson(String body) {
    for (final candidate in [
      body,
      body.replaceAll(TemplateEngine.tokenPattern, '0'),
    ]) {
      try {
        jsonDecode(candidate);
        return true;
      } on FormatException {
        // try the next candidate
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Variables

  void _readVariables(Object? raw) {
    if (raw is! List) return;
    for (final v in raw.whereType<Map>()) {
      if (v['disabled'] == true) continue;
      final key = _string(v['key'] ?? v['id']).trim();
      final value = v['value'];
      // Empty values are usually filled in by scripts at runtime.
      if (key.isEmpty || value == null || '$value'.isEmpty) continue;
      _vars[key] = value is String ? value : jsonEncode(value);
    }
  }

  /// Replaces collection variables with their values and Postman dynamic
  /// variables with Mock Studio tokens. Anything else is left in place and,
  /// if [record], noted for the unresolved-variables warning.
  String _substitute(String text, {bool record = true, int depth = 0}) {
    if (!text.contains('{{')) return text;
    return text.replaceAllMapped(_anyVar, (m) {
      final name = m.group(1)!;
      final dynamicToken = _dynamicVars[name];
      if (dynamicToken != null) return dynamicToken;
      final value = _vars[name];
      if (value != null) {
        return depth < 3
            ? _substitute(value, record: record, depth: depth + 1)
            : value;
      }
      if (record && !_isMockStudioToken(m.group(0)!)) _unresolvedVars.add(name);
      return m.group(0)!;
    });
  }

  static final _emptyContext = TemplateContext(
    pathParams: const {},
    query: const {},
    headers: const {},
    rawBody: '',
  );

  /// Tokens like `{{uuid}}` that Mock Studio fills in itself at runtime.
  static bool _isMockStudioToken(String token) =>
      TemplateEngine.render(token, _emptyContext) != token;

  // ---------------------------------------------------------------------------
  // Auth

  /// A request or folder's own auth, or the inherited one when it has none or
  /// says `inherit`. `noauth` is returned as-is so it stops inheritance.
  static Map? _inheritAuth(Object? own, Map? inherited) =>
      _auth(own) ?? inherited;

  static Map? _auth(Object? raw) {
    if (raw is! Map) return null;
    final type = _string(raw['type']).trim().toLowerCase();
    if (type.isEmpty || type == 'inherit') return null;
    return raw;
  }

  /// The header the mock should require for [auth], or null when the request
  /// is unauthenticated or sends its credentials in the query string.
  String? _authHeader(Map? auth) {
    if (auth == null) return null;
    final type = _string(auth['type']).trim().toLowerCase();
    if (type == 'apikey') {
      if (_string(_authAttr(auth, type, 'in')).toLowerCase() == 'query') {
        _queryAuth++;
        return null;
      }
      final key = _substitute(
        _string(_authAttr(auth, type, 'key')),
        record: false,
      ).trim();
      return key.isEmpty || key.contains('{{') ? 'X-API-Key' : key;
    }
    if (!_authorizationSchemes.contains(type)) return null;
    final addTo = _string(_authAttr(auth, type, 'addTokenTo')).toLowerCase();
    if (addTo.startsWith('query')) {
      _queryAuth++;
      return null;
    }
    return 'Authorization';
  }

  /// Reads an auth attribute from v2.1 `[{key, value}]` or v2.0 map form.
  static Object? _authAttr(Map auth, String type, String key) {
    final attrs = auth[type];
    if (attrs is Map) return attrs[key];
    if (attrs is List) {
      for (final a in attrs.whereType<Map>()) {
        if (a['key'] == key) return a['value'];
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Postman v1

  /// Rebuilds a v1 collection (`requests` + `folders` keyed by id, ordered by
  /// `order` / `folders_order`) as v2-shaped items.
  List<Map> _v1Items(Map doc) {
    final requestList = (doc['requests'] as List).whereType<Map>().toList();
    final requests = <String, Map>{
      for (var i = 0; i < requestList.length; i++)
        _string(requestList[i]['id'] ?? '#$i'): requestList[i],
    };
    final folders = <String, Map>{
      if (doc['folders'] is List)
        for (final f in (doc['folders'] as List).whereType<Map>())
          _string(f['id']): f,
    };
    final usedRequests = <String>{};
    final usedFolders = <String>{};

    Map? requestItem(Object? id) {
      final key = _string(id);
      final r = requests[key];
      if (r == null || !usedRequests.add(key)) return null;
      return _v1Request(r, requests);
    }

    List<String> ids(Object? list) =>
        list is List ? list.map(_string).toList() : const [];

    Map? folderItem(String id) {
      final f = folders[id];
      if (f == null || !usedFolders.add(id)) return null;
      final requestIds = f['order'] is List
          ? ids(f['order'])
          : [
              for (final e in requests.entries)
                if (_string(e.value['folder']) == id) e.key,
            ];
      return {
        'name': f['name'],
        'item': [
          for (final sub in ids(f['folders_order'])) ?folderItem(sub),
          for (final r in requestIds) ?requestItem(r),
        ],
      };
    }

    final nested = {for (final f in folders.values) ...ids(f['folders_order'])};
    final rootFolders = doc['folders_order'] is List
        ? ids(doc['folders_order'])
        : [
            for (final id in folders.keys)
              if (!nested.contains(id)) id,
          ];
    final items = <Map>[
      for (final id in rootFolders) ?folderItem(id),
      for (final id in folders.keys) ?folderItem(id),
      for (final id in ids(doc['order'])) ?requestItem(id),
    ];
    // Requests no folder or order list mentions still get imported.
    items.addAll([for (final id in requests.keys) ?requestItem(id)]);
    return items;
  }

  Map _v1Request(Map r, Map<String, Map> requests) {
    final helper = _string(r['currentHelper']);
    return {
      'name': r['name'],
      'request': {
        'method': r['method'],
        'url': r['url'],
        'description': r['description'],
        if (helper.isNotEmpty && helper != 'normal')
          'auth': {'type': 'bearer'}, // every v1 helper uses Authorization
      },
      'response': [
        if (r['responses'] is List)
          for (final res in (r['responses'] as List).whereType<Map>())
            {
              'name': res['name'],
              'code': res['responseCode'] is Map
                  ? (res['responseCode'] as Map)['code']
                  : res['responseCode'],
              'header': res['headers'],
              'body': res['text'],
              '_postman_previewlanguage': res['language'],
              'originalRequest': {
                'url': switch (res['request']) {
                  final Map req => req['url'],
                  final String id => requests[id]?['url'],
                  _ => null,
                },
              },
            },
      ],
    };
  }

  // ---------------------------------------------------------------------------
  // Warnings

  void _finishWarnings() {
    final w = result.warnings;
    if (_noExamples > 0) {
      w.add(
        '${_count(_noExamples, 'request')} had no saved examples; '
        '${_noExamples == 1 ? 'it' : 'they'} got a default 200 response — '
        'add examples in Postman or edit the responses here.',
      );
    }
    if (_unknownMethodCount > 0) {
      w.add(
        '${_count(_unknownMethodCount, 'request')} used methods Mock Studio '
        'can\'t match exactly (${_unknownMethods.join(', ')}), so '
        '${_unknownMethodCount == 1 ? 'it was' : 'they were'} imported as ANY.',
      );
    }
    if (_queryAuth > 0) {
      w.add(
        '${_count(_queryAuth, 'request')} '
        '${_queryAuth == 1 ? 'sends' : 'send'} credentials as a query '
        'parameter; Mock Studio can only require auth headers, so auth isn\'t '
        'enforced on ${_queryAuth == 1 ? 'it' : 'them'}.',
      );
    }
    _hostPathPrefixes.forEach((name, prefix) {
      w.add(
        'The {{$name}} variable includes the path "$prefix", which isn\'t part '
        'of the imported paths — call the mock without it, or add it to the '
        'endpoint paths.',
      );
    });
    if (_wildcardVars.isNotEmpty) {
      w.add(
        'Some path segments mixed text with variables '
        '(${_names(_wildcardVars)}); they were turned into * and match any '
        'value.',
      );
    }
    if (_unresolvedVars.isNotEmpty) {
      w.add(
        'Some Postman variables have no value in the collection and are '
        'returned as-is in responses: ${_names(_unresolvedVars)}. Replace '
        'them with fixed values or Mock Studio tokens like {{params.id}}.',
      );
    }
    _duplicateWarning();
  }

  void _duplicateWarning() {
    final seen = <String>{};
    var duplicates = 0;
    String? example;
    for (final ep in result.endpoints) {
      // Param names don't affect matching: /users/:id == /users/:userId.
      final shape = ep.normalizedPath
          .split('/')
          .map((s) => s.startsWith(':') || s == '*' ? ':' : s)
          .join('/');
      if (!seen.add('${ep.method.label} $shape')) {
        duplicates++;
        example ??= '${ep.method.label} ${ep.normalizedPath}';
      }
    }
    if (duplicates == 0) return;
    final one = duplicates == 1;
    result.warnings.add(
      '${_count(duplicates, 'endpoint')} ${one ? 'repeats' : 'repeat'} a '
      'method and path imported earlier (e.g. $example). Mock Studio answers '
      'with the first matching endpoint, so '
      '${one ? 'the duplicate is' : 'the duplicates are'} never reached — '
      'merge the examples or change the paths.',
    );
  }

  static String _count(int n, String noun) =>
      '$n ${n == 1 ? noun : '${noun}s'}';

  static String _names(Set<String> names) {
    final shown = names.take(5).map((n) => '{{$n}}').join(', ');
    return names.length > 5 ? '$shown and ${names.length - 5} more' : shown;
  }

  // ---------------------------------------------------------------------------
  // Helpers

  static String _string(Object? v) => v == null ? '' : '$v';

  /// Postman descriptions are a string or `{content, type}`.
  static String _text(Object? v) {
    if (v is Map) return _string(v['content']).trim();
    return _string(v).trim();
  }

  static int? _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
