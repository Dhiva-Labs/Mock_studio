/// A record of one request handled by a running mock server.
class RequestLog {
  final String id;
  final DateTime timestamp;
  final String method;
  final String path;
  final String query;
  final Map<String, String> requestHeaders;
  final String requestBody;

  /// Which endpoint matched, or null for a 404 / proxied request.
  final String? matchedEndpointId;
  final String? matchedEndpointName;

  /// Label of the response variant chosen (rule/sequence/etc.).
  final String? responseLabel;

  final int statusCode;
  final Map<String, String> responseHeaders;
  final String responseBody;

  /// True if this request was forwarded to a proxy target.
  final bool proxied;

  /// True if it matched no endpoint and no proxy (returned 404).
  final bool unmatched;

  /// Total handling time in milliseconds (including simulated latency).
  final int durationMs;

  RequestLog({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.path,
    required this.query,
    required this.requestHeaders,
    required this.requestBody,
    required this.matchedEndpointId,
    required this.matchedEndpointName,
    required this.responseLabel,
    required this.statusCode,
    required this.responseHeaders,
    required this.responseBody,
    required this.proxied,
    required this.unmatched,
    required this.durationMs,
  });

  bool get isError => statusCode >= 400;

  String get fullPath => query.isEmpty ? path : '$path?$query';
}
