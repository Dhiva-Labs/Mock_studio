import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mock_studio/models/endpoint.dart';
import 'package:mock_studio/models/enums.dart';
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/models/mock_response.dart';
import 'package:mock_studio/models/request_log.dart';
import 'package:mock_studio/services/mock_server.dart';

void main() {
  test('proxy forwards gzip upstreams and binary bodies intact', () async {
    final binary = List<int>.generate(256, (i) => i);
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..autoCompress = true;
    upstream.listen((req) {
      if (req.uri.path == '/bin') {
        req.response.headers.contentType = ContentType.binary;
        req.response.add(binary);
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'hello': 'wörld', 'pad': 'x' * 2000}));
      }
      req.response.close();
    });

    final logs = <RequestLog>[];
    final server = MockServer(
      project: MockProject(
        port: 8197,
        proxyBaseUrl: 'http://127.0.0.1:${upstream.port}',
      ),
      onLog: logs.add,
    );
    await server.start();
    try {
      final json = await http.get(
        Uri.parse('http://127.0.0.1:8197/data'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(json.statusCode, 200);
      expect(jsonDecode(utf8.decode(json.bodyBytes))['hello'], 'wörld');

      final bin = await http.get(Uri.parse('http://127.0.0.1:8197/bin'));
      expect(bin.bodyBytes, binary);
      expect(logs.every((l) => l.proxied), isTrue);
    } finally {
      await server.stop();
      await upstream.close(force: true);
    }
  });

  test('connection reset fault drops the socket without a response', () async {
    final server = MockServer(
      project: MockProject(
        port: 8196,
        endpoints: [
          Endpoint(
            method: HttpMethodType.get,
            path: '/reset',
            responses: [MockResponse(fault: FaultType.connectionReset)],
          ),
        ],
      ),
      onLog: (_) {},
    );
    await server.start();
    try {
      await expectLater(
        http.get(Uri.parse('http://127.0.0.1:8196/reset')),
        throwsA(isA<http.ClientException>()),
      );
    } finally {
      await server.stop();
    }
  });

  test('binary request bodies no longer crash the handler', () async {
    final logs = <RequestLog>[];
    final server = MockServer(
      project: MockProject(port: 8195, endpoints: [Endpoint(path: '/up')]),
      onLog: logs.add,
    );
    await server.start();
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8195/up'),
        headers: {'content-type': 'application/octet-stream'},
        body: [0xff, 0xfe, 0x00, 0xc3],
      );
      expect(res.statusCode, 404); // GET-only endpoint, but handled cleanly
      expect(logs, hasLength(1));
    } finally {
      await server.stop();
    }
  });
}
