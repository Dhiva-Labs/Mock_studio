import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/services/mock_server.dart';
import 'package:mock_studio/services/sample_data.dart';

void main() {
  late MockServer server;
  late int port;
  late String base;

  setUp(() async {
    port = 8199;
    final project = MockProject.fromJson(SampleData.welcomeProject().toJson());
    project.port = port;
    server = MockServer(project: project, onLog: (_) {});
    await server.start();
    base = 'http://localhost:$port';
  });

  tearDown(() async {
    await server.stop();
  });

  test('health endpoint returns 200 with templated time', () async {
    final res = await http.get(Uri.parse('$base/health'));
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['status'], 'ok');
    expect(body['time'], isNotEmpty);
    expect(body['time'], isNot(contains('{{'))); // token was rendered
  });

  test('path param is echoed back', () async {
    final res = await http.get(Uri.parse('$base/users/42'));
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['id'], '42');
    expect(body['email'], contains('@'));
  });

  test('conditional login: correct password 200, wrong 401', () async {
    final ok = await http.post(
      Uri.parse('$base/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'password': 'secret'}),
    );
    expect(ok.statusCode, 200);
    expect(jsonDecode(ok.body)['token'], isNotEmpty);

    final bad = await http.post(
      Uri.parse('$base/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'password': 'wrong'}),
    );
    expect(bad.statusCode, 401);
  });

  test('unmatched route returns a helpful 404', () async {
    final res = await http.get(Uri.parse('$base/nope'));
    expect(res.statusCode, 404);
    expect(jsonDecode(res.body)['error'], 'not_found');
  });

  test('CORS preflight is answered', () async {
    final res = await http.Request('OPTIONS', Uri.parse('$base/health')).send();
    expect(res.statusCode, 204);
    expect(res.headers['access-control-allow-origin'], '*');
  });

  test('HEAD falls back to the GET route with an empty body', () async {
    final res = await http.head(Uri.parse('$base/health'));
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], contains('application/json'));
    expect(res.body, isEmpty);
  });
}
