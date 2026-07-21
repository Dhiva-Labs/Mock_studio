/// Matches a concrete request path against an endpoint path template.
///
/// Templates support:
///   `:name`  named segment, captured into pathParams
///   `*`      wildcard for a single segment (captured as `wildcard0`, ...)
///   `**`     tail wildcard matching the rest of the path (captured as `rest`)
class RouteMatch {
  final Map<String, String> params;
  const RouteMatch(this.params);
}

class RouteMatcher {
  /// Returns a [RouteMatch] if [requestPath] fits [template], else null.
  static RouteMatch? match(String template, String requestPath) {
    final t = _split(template);
    final r = _split(requestPath);

    final params = <String, String>{};
    var wildcardIndex = 0;

    var ti = 0, ri = 0;
    while (ti < t.length) {
      final seg = t[ti];

      if (seg == '**') {
        // Tail wildcard: consume the remainder.
        params['rest'] = r.sublist(ri).join('/');
        return RouteMatch(params);
      }

      if (ri >= r.length) return null; // template longer than path

      if (seg.startsWith(':')) {
        params[seg.substring(1)] = Uri.decodeComponent(r[ri]);
      } else if (seg == '*') {
        params['wildcard$wildcardIndex'] = Uri.decodeComponent(r[ri]);
        wildcardIndex++;
      } else if (seg != r[ri]) {
        return null; // literal mismatch
      }
      ti++;
      ri++;
    }

    if (ri != r.length) return null; // path longer than template
    return RouteMatch(params);
  }

  static List<String> _split(String path) {
    var p = path.trim();
    // Drop query/fragment defensively.
    final q = p.indexOf('?');
    if (q >= 0) p = p.substring(0, q);
    p = p.replaceAll(RegExp(r'^/+|/+$'), '');
    if (p.isEmpty) return const [];
    return p.split('/');
  }

  /// How specific a template is, for ranking overlapping matches. Higher wins:
  /// literal segments beat params beat wildcards.
  static int specificity(String template) {
    final segs = _split(template);
    var score = 0;
    for (final s in segs) {
      if (s == '**') {
        score += 0;
      } else if (s == '*' || s.startsWith(':')) {
        score += 1;
      } else {
        score += 3;
      }
    }
    return score;
  }
}
