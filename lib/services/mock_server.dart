import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_project.dart';
import '../models/mock_response.dart';
import '../models/request_log.dart';
import 'response_resolver.dart';
import 'route_matcher.dart';
import 'template_engine.dart';

const _uuid = Uuid();

/// A recorded proxy response the UI can convert into a mock endpoint.
class RecordedCall {
  final String method;
  final String path;
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  RecordedCall(
    this.method,
    this.path,
    this.statusCode,
    this.body,
    this.headers,
  );
}

/// Wraps a running [HttpServer] serving one [MockProject].
class MockServer {
  final MockProject project;
  final void Function(RequestLog log) onLog;
  final void Function(RecordedCall call)? onRecord;

  HttpServer? _server;
  http.Client? _proxyClient;
  final _random = Random();

  /// Bodies kept in the request log are clipped to this many characters so a
  /// few large payloads can't balloon memory (500 logs x N MB each).
  static const maxLoggedBodyChars = 64 * 1024;

  /// Hop-by-hop / encoding headers that must not be forwarded verbatim.
  static const _hopHeaders = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding',
    'upgrade',
    'te',
    'trailer',
    'content-length',
    'content-encoding',
  };

  MockServer({required this.project, required this.onLog, this.onRecord});

  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;

  /// Starts listening on 0.0.0.0:[project.port]. Throws on bind failure
  /// (e.g. port in use) so the caller can surface a friendly message.
  Future<void> start() async {
    if (_server != null) return;
    final handler = const shelf.Pipeline().addHandler(_handle);
    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      project.port,
    );
    _server!.autoCompress = true;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _proxyClient?.close();
    _proxyClient = null;
  }

  Future<shelf.Response> _handle(shelf.Request request) async {
    final started = DateTime.now();
    final method = request.method;
    final path = '/${request.url.path}';
    final reqHeaders = _flattenHeaders(request.headersAll);

    // Read the body once (used for templating/rules and logging). Decode
    // leniently so binary uploads don't make the handler throw.
    final reqBytes = await _readBytes(request);
    final reqBody = utf8.decode(reqBytes, allowMalformed: true);

    // CORS preflight.
    if (method == 'OPTIONS' && project.corsEnabled) {
      final res = shelf.Response(
        204,
        headers: {..._corsHeaders(), ..._globalHeaders()},
      );
      _emitLog(
        started,
        request,
        reqHeaders,
        reqBody,
        null,
        res.statusCode,
        _corsHeaders(),
        '',
        false,
        false,
        'CORS preflight',
      );
      return res;
    }

    // Find the best matching, enabled endpoint. A HEAD request with no explicit
    // HEAD endpoint falls back to the matching GET route (per HTTP semantics);
    // the body is stripped from the response below.
    Endpoint? matched;
    RouteMatch? bestMatch;
    for (final matchMethod
        in method == 'HEAD' ? const ['HEAD', 'GET'] : [method]) {
      var bestScore = -1;
      for (final ep in project.endpoints) {
        if (!ep.enabled) continue;
        if (!ep.method.matches(matchMethod)) continue;
        final m = RouteMatcher.match(ep.normalizedPath, path);
        if (m == null) continue;
        final score = RouteMatcher.specificity(ep.normalizedPath);
        if (score > bestScore) {
          bestScore = score;
          matched = ep;
          bestMatch = m;
        }
      }
      if (matched != null) break;
    }

    if (matched == null) {
      return _handleUnmatched(
        started,
        request,
        reqHeaders,
        reqBytes,
        reqBody,
        method,
        path,
      );
    }

    final ctx = TemplateContext(
      pathParams: bestMatch!.params,
      query: request.url.queryParameters,
      headers: reqHeaders,
      rawBody: reqBody,
    );

    // Auth gate.
    if (matched.requireAuth) {
      final hasAuth = ctx.headers.entries.any(
        (e) =>
            e.key.toLowerCase() == matched!.authHeader.toLowerCase() &&
            e.value.trim().isNotEmpty,
      );
      if (!hasAuth) {
        final body = jsonEncode({
          'error': 'unauthorized',
          'message': 'Missing ${matched.authHeader} header',
        });
        final res = shelf.Response(
          401,
          body: body,
          headers: {
            'content-type': 'application/json',
            ..._corsHeaders(),
            ..._globalHeaders(),
          },
        );
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          matched,
          401,
          {'content-type': 'application/json'},
          body,
          false,
          false,
          'Auth required',
        );
        return res;
      }
    }

    final chosen = ResponseResolver.select(matched, ctx, method);

    // Latency: global + endpoint default + jitter + per-response override.
    final delay =
        (chosen.delayMs ?? matched.defaultDelayMs) +
        project.globalDelayMs +
        (matched.jitterMs > 0 ? _random.nextInt(matched.jitterMs + 1) : 0);
    if (delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    // Fault injection.
    final faultRes = await _applyFault(
      chosen,
      request,
      started,
      reqHeaders,
      reqBody,
      matched,
    );
    if (faultRes != null) return faultRes;

    // Render body + headers with the template engine. HEAD requests carry the
    // same headers as GET but no message body.
    final renderedBody = (chosen.bodyType == BodyType.none || method == 'HEAD')
        ? ''
        : TemplateEngine.render(chosen.body, ctx);
    final renderedHeaders = <String, String>{};
    chosen.headers.forEach((k, v) {
      renderedHeaders[k] = TemplateEngine.render(v, ctx);
    });

    final headers = <String, String>{
      if (chosen.bodyType != BodyType.none)
        'content-type': chosen.bodyType.contentType,
      ...renderedHeaders,
      if (project.corsEnabled) ..._corsHeaders(),
      ..._globalHeaders(),
    };

    final res = shelf.Response(
      chosen.statusCode,
      body: renderedBody,
      headers: headers,
    );
    _emitLog(
      started,
      request,
      reqHeaders,
      reqBody,
      matched,
      chosen.statusCode,
      headers,
      renderedBody,
      false,
      false,
      chosen.label,
    );
    return res;
  }

  Future<shelf.Response> _handleUnmatched(
    DateTime started,
    shelf.Request request,
    Map<String, String> reqHeaders,
    List<int> reqBytes,
    String reqBody,
    String method,
    String path,
  ) async {
    // Proxy passthrough if configured.
    if (project.proxyBaseUrl.trim().isNotEmpty) {
      try {
        final base = project.proxyBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
        final target = Uri.parse(
          '$base$path${request.url.query.isEmpty ? '' : '?${request.url.query}'}',
        );
        final proxyReq = http.Request(method, target);
        proxyReq.bodyBytes = reqBytes;
        reqHeaders.forEach((k, v) {
          final lk = k.toLowerCase();
          if (lk != 'host' && !_hopHeaders.contains(lk)) {
            proxyReq.headers[k] = v;
          }
        });
        // One pooled client per server keeps connections alive across calls.
        final client = _proxyClient ??= http.Client();
        final streamed = await client
            .send(proxyReq)
            .timeout(const Duration(seconds: 30));
        final proxied = await http.Response.fromStream(streamed);

        // The client transparently decompresses, so drop content-encoding and
        // length; forward the raw bytes so binary payloads aren't corrupted.
        final headers = <String, String>{};
        proxied.headers.forEach((k, v) {
          if (!_hopHeaders.contains(k.toLowerCase())) headers[k] = v;
        });
        if (project.corsEnabled) headers.addAll(_corsHeaders());
        final proxiedText = utf8.decode(
          proxied.bodyBytes,
          allowMalformed: true,
        );

        if (project.recordProxy && onRecord != null) {
          onRecord!(
            RecordedCall(
              method,
              path,
              proxied.statusCode,
              proxiedText,
              headers,
            ),
          );
        }

        final res = shelf.Response(
          proxied.statusCode,
          body: proxied.bodyBytes,
          headers: headers,
        );
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          null,
          proxied.statusCode,
          headers,
          proxiedText,
          true,
          false,
          'Proxied → $base',
        );
        return res;
      } catch (e) {
        final body = jsonEncode({
          'error': 'proxy_failed',
          'message': e.toString(),
        });
        final res = shelf.Response(
          502,
          body: body,
          headers: {'content-type': 'application/json', ..._corsHeaders()},
        );
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          null,
          502,
          {'content-type': 'application/json'},
          body,
          true,
          true,
          'Proxy failed',
        );
        return res;
      }
    }

    // Default 404 with a helpful hint.
    final body = jsonEncode({
      'error': 'not_found',
      'message': 'No mock endpoint matched $method $path',
      'hint': 'Add this endpoint in Mock Studio, or enable proxy passthrough.',
    });
    final res = shelf.Response(
      404,
      body: body,
      headers: {
        'content-type': 'application/json',
        if (project.corsEnabled) ..._corsHeaders(),
        ..._globalHeaders(),
      },
    );
    _emitLog(
      started,
      request,
      reqHeaders,
      reqBody,
      null,
      404,
      {'content-type': 'application/json'},
      body,
      false,
      true,
      'No match',
    );
    return res;
  }

  /// Returns a fault response if one applies, else null to continue normally.
  Future<shelf.Response?> _applyFault(
    MockResponse chosen,
    shelf.Request request,
    DateTime started,
    Map<String, String> reqHeaders,
    String reqBody,
    Endpoint matched,
  ) async {
    switch (chosen.fault) {
      case FaultType.none:
        return null;
      case FaultType.hang:
        // Hold the connection open for a long time (timeout testing).
        await Future<void>.delayed(const Duration(seconds: 120));
        return null;
      case FaultType.emptyResponse:
        final res = shelf.Response(
          chosen.statusCode,
          body: '',
          headers: _corsHeaders(),
        );
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          matched,
          chosen.statusCode,
          {},
          '',
          false,
          false,
          'Fault: empty',
        );
        return res;
      case FaultType.malformedBody:
        final garbage = String.fromCharCodes(
          List.generate(48, (_) => _random.nextInt(94) + 32),
        );
        final res = shelf.Response(
          chosen.statusCode,
          body: '{"truncated": $garbage',
          headers: {'content-type': 'application/json', ..._corsHeaders()},
        );
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          matched,
          chosen.statusCode,
          {'content-type': 'application/json'},
          '<malformed>',
          false,
          false,
          'Fault: malformed',
        );
        return res;
      case FaultType.connectionReset:
        _emitLog(
          started,
          request,
          reqHeaders,
          reqBody,
          matched,
          0,
          {},
          '',
          false,
          false,
          'Fault: connection reset',
        );
        if (request.canHijack) {
          // Take over the socket and close it without a response. hijack()
          // throws a HijackException that shelf_io must see, so don't catch it.
          request.hijack((channel) => channel.sink.close());
        }
        // Hijack unavailable: fall back to an abrupt 502.
        return shelf.Response(502, body: '');
    }
  }

  Map<String, String> _corsHeaders() => {
    'access-control-allow-origin': '*',
    'access-control-allow-methods':
        'GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD',
    'access-control-allow-headers': '*',
    'access-control-max-age': '86400',
  };

  Map<String, String> _globalHeaders() => Map.of(project.globalHeaders);

  static Future<List<int>> _readBytes(shelf.Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static String _clip(String s) => s.length <= maxLoggedBodyChars
      ? s
      : '${s.substring(0, maxLoggedBodyChars)}\n… [truncated ${s.length - maxLoggedBodyChars} chars]';

  Map<String, String> _flattenHeaders(Map<String, List<String>> h) {
    return h.map((k, v) => MapEntry(k, v.join(', ')));
  }

  void _emitLog(
    DateTime started,
    shelf.Request request,
    Map<String, String> reqHeaders,
    String reqBody,
    Endpoint? matched,
    int status,
    Map<String, String> resHeaders,
    String resBody,
    bool proxied,
    bool unmatched,
    String? responseLabel,
  ) {
    onLog(
      RequestLog(
        id: _uuid.v4(),
        timestamp: started,
        method: request.method,
        path: '/${request.url.path}',
        query: request.url.query,
        requestHeaders: reqHeaders,
        requestBody: _clip(reqBody),
        matchedEndpointId: matched?.id,
        matchedEndpointName: matched?.name,
        responseLabel: responseLabel,
        statusCode: status,
        responseHeaders: resHeaders,
        responseBody: _clip(resBody),
        proxied: proxied,
        unmatched: unmatched,
        durationMs: DateTime.now().difference(started).inMilliseconds,
      ),
    );
  }
}
