import 'dart:convert';
import 'dart:math';

/// Context passed to the template engine describing the incoming request.
class TemplateContext {
  final Map<String, String> pathParams;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String rawBody;

  TemplateContext({
    required this.pathParams,
    required this.query,
    required this.headers,
    required this.rawBody,
  });

  Map<String, dynamic>? _bodyJsonCache;
  bool _bodyParsed = false;

  Map<String, dynamic>? get bodyJson {
    if (_bodyParsed) return _bodyJsonCache;
    _bodyParsed = true;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) _bodyJsonCache = decoded;
    } catch (_) {}
    return _bodyJsonCache;
  }
}

/// Mustache-flavoured template engine with request data and faker helpers.
///
/// Supported tokens (inside `{{ ... }}`):
///   `params.<name>`      path parameter
///   `query.<name>`       query string parameter
///   `header.<name>`      request header (case-insensitive)
///   `body.<json.path>`   dotted path into the JSON request body
///   uuid               a random v4 UUID
///   now / now.iso      current timestamp (ISO 8601)
///   now.unix           current unix seconds
///   timestamp          alias for now.unix
///   randomInt(a,b)     random integer in [a,b]
///   faker.name / faker.firstName / faker.lastName
///   faker.email / faker.uuid / faker.city / faker.phone
///   faker.bool / faker.color / faker.company / faker.word
class TemplateEngine {
  static final _rng = Random();
  static final _token = RegExp(r'\{\{\s*([^}]+?)\s*\}\}');
  static final _randomInt = RegExp(
    r'^randomInt\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)$',
  );

  /// Public regex used by the UI to detect/strip template tokens.
  static RegExp get tokenPattern => _token;

  static const _firstNames = [
    'Ava',
    'Liam',
    'Maya',
    'Noah',
    'Zoe',
    'Ethan',
    'Aria',
    'Kai',
    'Isla',
    'Leo',
    'Nora',
    'Ravi',
    'Priya',
    'Ken',
    'Sana',
    'Omar',
  ];
  static const _lastNames = [
    'Sharma',
    'Patel',
    'Kim',
    'Silva',
    'Nguyen',
    'Khan',
    'Rossi',
    'Cohen',
    'Adebayo',
    'Novak',
    'Reyes',
    'Haddad',
    'Ivanov',
    'Costa',
    'Meyer',
  ];
  static const _cities = [
    'Bengaluru',
    'Lagos',
    'Lisbon',
    'Osaka',
    'Austin',
    'Nairobi',
    'Toronto',
    'Berlin',
    'Jakarta',
    'Bogota',
  ];
  static const _companies = [
    'Northwind',
    'Acme',
    'Globex',
    'Umbra',
    'Initech',
    'Hooli',
    'Stark Labs',
    'Wayne Co',
    'Cyberdyne',
    'Soylent',
  ];
  static const _words = [
    'lorem',
    'ipsum',
    'dolor',
    'amet',
    'consectetur',
    'nebula',
    'quantum',
    'harbor',
    'ember',
    'ridge',
    'delta',
    'zephyr',
  ];
  static const _colors = [
    '#EF4444',
    '#F59E0B',
    '#10B981',
    '#3B82F6',
    '#8B5CF6',
    '#EC4899',
  ];

  /// Renders [template], substituting tokens from [ctx]. Unknown tokens are
  /// left as-is so the user can see the mistake in the response.
  static String render(String template, TemplateContext ctx) {
    // Most bodies/headers have no tokens; skip the regex pass entirely.
    if (!template.contains('{{')) return template;
    return template.replaceAllMapped(_token, (m) {
      final expr = m.group(1)!.trim();
      final value = _resolve(expr, ctx);
      return value ?? m.group(0)!;
    });
  }

  static String? _resolve(String expr, TemplateContext ctx) {
    // randomInt(a,b)
    final ri = _randomInt.firstMatch(expr);
    if (ri != null) {
      final a = int.parse(ri.group(1)!);
      final b = int.parse(ri.group(2)!);
      final lo = min(a, b), hi = max(a, b);
      return (lo + _rng.nextInt(hi - lo + 1)).toString();
    }

    final lower = expr.toLowerCase();
    switch (lower) {
      case 'uuid':
      case 'faker.uuid':
        return _uuidV4();
      case 'now':
      case 'now.iso':
        return DateTime.now().toUtc().toIso8601String();
      case 'now.unix':
      case 'timestamp':
        return (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      case 'faker.name':
        return '${_pick(_firstNames)} ${_pick(_lastNames)}';
      case 'faker.firstname':
        return _pick(_firstNames);
      case 'faker.lastname':
        return _pick(_lastNames);
      case 'faker.email':
        return '${_pick(_firstNames).toLowerCase()}.${_pick(_lastNames).toLowerCase()}@example.com';
      case 'faker.city':
        return _pick(_cities);
      case 'faker.company':
        return _pick(_companies);
      case 'faker.word':
        return _pick(_words);
      case 'faker.color':
        return _pick(_colors);
      case 'faker.phone':
        return '+1-${_rng.nextInt(900) + 100}-${_rng.nextInt(900) + 100}-${(_rng.nextInt(9000) + 1000)}';
      case 'faker.bool':
        return _rng.nextBool().toString();
      case 'randomint':
        return _rng.nextInt(1000).toString();
    }

    // Dotted accessors.
    if (expr.startsWith('params.')) {
      return ctx.pathParams[expr.substring(7)];
    }
    if (expr.startsWith('query.')) {
      return ctx.query[expr.substring(6)];
    }
    if (expr.startsWith('header.')) {
      final key = expr.substring(7).toLowerCase();
      for (final e in ctx.headers.entries) {
        if (e.key.toLowerCase() == key) return e.value;
      }
      return null;
    }
    if (expr.startsWith('body.')) {
      return _jsonPath(ctx.bodyJson, expr.substring(5));
    }
    return null;
  }

  /// Reads a dotted path (with numeric list indices) out of decoded JSON.
  static String? jsonPath(Object? root, String path) => _jsonPath(root, path);

  static String? _jsonPath(Object? root, String path) {
    if (root == null) return null;
    dynamic current = root;
    for (final part in path.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List) {
        final idx = int.tryParse(part);
        if (idx != null && idx >= 0 && idx < current.length) {
          current = current[idx];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    if (current == null) return null;
    if (current is Map || current is List) return jsonEncode(current);
    return current.toString();
  }

  static String _pick(List<String> list) => list[_rng.nextInt(list.length)];

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    final b = [for (var i = 0; i < 16; i++) hex(i)];
    return '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  /// The list of tokens surfaced in the UI's "insert variable" helper.
  static const List<({String token, String desc})> palette = [
    (token: '{{params.id}}', desc: 'A value from the URL path'),
    (token: '{{query.page}}', desc: 'A query-string parameter'),
    (token: '{{header.Authorization}}', desc: 'A request header'),
    (token: '{{body.email}}', desc: 'A field from the JSON request body'),
    (token: '{{uuid}}', desc: 'A random unique id'),
    (token: '{{now}}', desc: 'Current time (ISO 8601)'),
    (token: '{{timestamp}}', desc: 'Current unix timestamp'),
    (token: '{{randomInt(1,100)}}', desc: 'A random number in a range'),
    (token: '{{faker.name}}', desc: 'A random full name'),
    (token: '{{faker.email}}', desc: 'A random email address'),
    (token: '{{faker.city}}', desc: 'A random city'),
    (token: '{{faker.company}}', desc: 'A random company name'),
  ];
}
