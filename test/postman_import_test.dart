import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mock_studio/models/endpoint.dart';
import 'package:mock_studio/models/enums.dart';
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/services/mock_server.dart';
import 'package:mock_studio/services/postman_import.dart';

/// A realistic v2.1 export: nested folders, inherited auth, string and object
/// URLs, several examples per request and collection variables.
Map<String, dynamic> shopCollection() => {
  'info': {
    '_postman_id': '6f1c2d4e-0000-4000-8000-000000000001',
    'name': 'Shop API',
    'description': 'Demo shop',
    'schema':
        'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  },
  'auth': {
    'type': 'bearer',
    'bearer': [
      {'key': 'token', 'value': '{{token}}', 'type': 'string'},
    ],
  },
  'event': [
    {
      'listen': 'prerequest',
      'script': {
        'exec': ['console.log("hi")'],
      },
    },
  ],
  'variable': [
    {'key': 'baseUrl', 'value': 'https://api.shop.test/v1'},
    {'key': 'currency', 'value': 'EUR'},
    {'key': 'token', 'value': ''},
  ],
  'item': [
    {
      'name': 'Users',
      'item': [
        {
          'name': 'List users',
          'request': {
            'method': 'GET',
            'header': [],
            'url': {
              'raw': '{{baseUrl}}/users?page=1',
              'host': ['{{baseUrl}}'],
              'path': ['users'],
              'query': [
                {'key': 'page', 'value': '1'},
              ],
            },
            'description': {'content': 'Paged list', 'type': 'text/plain'},
          },
          'response': [
            {
              'name': 'Users page',
              'originalRequest': {
                'method': 'GET',
                'url': {
                  'raw': '{{baseUrl}}/users?page=1',
                  'host': ['{{baseUrl}}'],
                  'path': ['users'],
                  'query': [
                    {'key': 'page', 'value': '1'},
                  ],
                },
              },
              'status': 'OK',
              'code': 200,
              '_postman_previewlanguage': 'json',
              'header': [
                {
                  'key': 'Content-Type',
                  'value': 'application/json; charset=utf-8',
                },
                {'key': 'Content-Length', 'value': '57'},
                {'key': 'Date', 'value': 'Mon, 06 Oct 2026 10:00:00 GMT'},
                {'key': 'Connection', 'value': 'keep-alive'},
                {'key': 'Transfer-Encoding', 'value': 'chunked'},
                {'key': 'Content-Encoding', 'value': 'gzip'},
                {'key': 'X-Request-Id', 'value': '{{\$guid}}'},
                {'key': 'X-Debug', 'value': 'on', 'disabled': true},
              ],
              'cookie': [],
              'body':
                  '[\n  {"id": 1, "name": "Ada"},\n  {"id": 2, "name": "Linus"}\n]',
            },
          ],
        },
        {
          'name': 'Get user',
          'request': {
            'method': 'GET',
            'url': '{{baseUrl}}/users/:id',
            'body': {'mode': 'raw', 'raw': 'ignored'},
          },
          'response': [
            {
              'name': 'User missing',
              'originalRequest': {
                'method': 'GET',
                'url': {
                  'raw': '{{baseUrl}}/users/:id?status=404',
                  'host': ['{{baseUrl}}'],
                  'path': ['users', ':id'],
                  'query': [
                    {'key': 'status', 'value': '404'},
                  ],
                },
              },
              'code': 404,
              '_postman_previewlanguage': 'json',
              'header': [
                {'key': 'Content-Type', 'value': 'application/json'},
              ],
              'body': '{"error": "not_found", "traceId": "{{traceId}}"}',
            },
            {
              'name': 'User found',
              'originalRequest': {
                'method': 'GET',
                'url': '{{baseUrl}}/users/:id',
              },
              'code': 200,
              '_postman_previewlanguage': 'json',
              'header': [
                {'key': 'Content-Type', 'value': 'application/json'},
              ],
              'body': '{"id": 42, "name": "Ada", "currency": "{{currency}}"}',
            },
            {
              'name': 'Server error',
              'originalRequest': {
                'method': 'GET',
                'url': '{{baseUrl}}/users/:id',
              },
              'code': 500,
              'header': [],
              'body': '{"error": "boom"}',
            },
          ],
        },
        {
          'name': 'Admin/Ops',
          'auth': {'type': 'noauth'},
          'item': [
            {
              'name': 'Health',
              'request': {'method': 'GET', 'url': '{{baseUrl}}/admin/health'},
              'response': [],
            },
          ],
        },
      ],
    },
    {
      'name': 'Orders',
      'auth': {
        'type': 'apikey',
        'apikey': [
          {'key': 'key', 'value': 'X-Api-Key'},
          {'key': 'value', 'value': '{{apiKey}}'},
          {'key': 'in', 'value': 'header'},
        ],
      },
      'item': [
        {
          'name': 'Get order',
          'request': {
            'method': 'GET',
            'url': {
              'raw': '{{baseUrl}}/orders/{{orderId}}',
              'host': ['{{baseUrl}}'],
              'path': ['orders', '{{orderId}}'],
            },
          },
          'response': [
            {
              'name': 'Order XML',
              'code': 200,
              '_postman_previewlanguage': 'xml',
              'header': [
                {'key': 'Content-Type', 'value': 'application/xml'},
              ],
              'body': '<order id="7"><total>12.50</total></order>',
            },
          ],
        },
        {
          'name': 'Cancel order',
          'request': {
            'method': 'DELETE',
            'auth': {'type': 'noauth'},
            'url': '{{baseUrl}}/orders/{{orderId}}',
          },
          'response': [
            {'name': 'Cancelled', 'code': 204, 'header': [], 'body': ''},
          ],
        },
        {
          'name': 'Search orders',
          'request': {
            'method': 'GET',
            'auth': {
              'type': 'apikey',
              'apikey': [
                {'key': 'key', 'value': 'api_key'},
                {'key': 'in', 'value': 'query'},
              ],
            },
            'url': 'https://shop.test/orders?q=shoes',
          },
          'response': [
            {
              'name': 'Results page',
              'code': 200,
              '_postman_previewlanguage': 'html',
              'body': '<!DOCTYPE html><html><body>2 orders</body></html>',
            },
          ],
        },
      ],
    },
    {
      'name': 'Ping',
      'request': {
        'method': 'GET',
        'auth': {'type': 'inherit'},
        'url': 'http://localhost:3000/ping#top',
      },
      'response': [
        {'name': 'Pong', 'code': 200, 'body': 'pong'},
      ],
    },
  ],
};

PostmanMockImport importMap(Object json) =>
    importPostmanToMocks(jsonEncode(json));

/// Imports a single loose request item and returns its endpoint.
Endpoint single(Object url, {String method = 'GET', List? response}) {
  final result = importMap({
    'name': 'Probe',
    'request': {'method': method, 'url': url},
    'response': ?response,
  });
  return result.endpoints.single;
}

Endpoint byName(PostmanMockImport r, String name) =>
    r.endpoints.firstWhere((e) => e.name == name);

void main() {
  group('collection v2.1', () {
    late PostmanMockImport result;
    setUp(() => result = importMap(shopCollection()));

    test('reads metadata and counts', () {
      expect(result.name, 'Shop API');
      expect(result.description, 'Demo shop');
      expect(result.folders, 3);
      expect(result.requests, 7);
      expect(result.examples, 8);
      expect(result.endpoints, hasLength(7));
    });

    test('maps nested folders, escaping "/" in folder names', () {
      expect(result.endpoints.map((e) => e.folder).toList(), [
        'Users',
        'Users',
        'Users/Admin∕Ops',
        'Orders',
        'Orders',
        'Orders',
        '',
      ]);
    });

    test('keeps only the path of string and object URLs', () {
      expect(result.endpoints.map((e) => '${e.method.label} ${e.path}'), [
        'GET /users',
        'GET /users/:id',
        'GET /admin/health',
        'GET /orders/:orderId',
        'DELETE /orders/:orderId',
        'GET /orders',
        'GET /ping',
      ]);
    });

    test('takes names and string or {content} descriptions', () {
      final list = byName(result, 'List users');
      expect(list.description, 'Paged list');
      expect(byName(result, 'Get user').description, '');
    });

    test('filters transport headers and keeps Content-Type', () {
      final r = byName(result, 'List users').responses.single;
      expect(r.headers, {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Request-Id': '{{uuid}}', // Postman {{$guid}} → Mock Studio token
      });
      expect(r.bodyType, BodyType.json);
      expect(r.label, 'Users page');
    });

    test('puts the 2xx example first and turns the rest into rules', () {
      final ep = byName(result, 'Get user');
      expect(ep.strategy, ResponseStrategy.rules);
      expect(ep.responses.map((r) => '${r.statusCode} ${r.label}'), [
        '200 User found',
        '404 User missing',
        '500 Server error',
      ]);

      final [found, missing, error] = ep.responses;
      expect(found.conditions, isEmpty); // the fall-through default
      expect(found.body, '{"id": 42, "name": "Ada", "currency": "EUR"}');

      expect(missing.conditions.single.toJson(), {
        'source': 'query',
        'key': 'status',
        'operator': 'equals',
        'value': '404',
      });
      // No distinguishing query: selectable by name, like Postman mocks.
      expect(error.conditions.single.toJson(), {
        'source': 'header',
        'key': postmanResponseNameHeader,
        'operator': 'equals',
        'value': 'Server error',
      });
      expect(error.bodyType, BodyType.json); // sniffed, no hints given
    });

    test('a single example uses the single strategy', () {
      final ep = byName(result, 'Get order');
      expect(ep.strategy, ResponseStrategy.single);
      expect(ep.responses.single.bodyType, BodyType.xml);
      expect(ep.responses.single.conditions, isEmpty);
    });

    test('requests without examples get a default 200', () {
      final ep = byName(result, 'Health');
      expect(ep.responses, hasLength(1));
      final r = ep.responses.single;
      expect(r.label, 'Default');
      expect(r.statusCode, 200);
      expect(r.bodyType, BodyType.json);
      expect(jsonDecode(r.body), {'ok': true});
    });

    test('empty bodies become BodyType.none', () {
      final r = byName(result, 'Cancel order').responses.single;
      expect(r.statusCode, 204);
      expect(r.bodyType, BodyType.none);
    });

    test('resolves auth through folders and collection', () {
      String auth(String name) {
        final ep = byName(result, name);
        return ep.requireAuth ? ep.authHeader : '-';
      }

      expect(auth('List users'), 'Authorization'); // collection bearer
      expect(auth('Health'), '-'); // folder noauth
      expect(auth('Get order'), 'X-Api-Key'); // folder apikey header
      expect(auth('Cancel order'), '-'); // request noauth
      expect(auth('Search orders'), '-'); // apikey in query
      expect(auth('Ping'), 'Authorization'); // explicit inherit
    });

    test('emits one aggregated warning per issue', () {
      expect(result.warnings, hasLength(4));
      expect(
        result.warnings,
        contains(
          '1 request had no saved examples; it got a default 200 response — '
          'add examples in Postman or edit the responses here.',
        ),
      );
      expect(
        result.warnings.where((w) => w.contains('query parameter')),
        hasLength(1),
      );
      expect(
        result.warnings.where((w) => w.contains('{{baseUrl}}')).single,
        contains('"/v1"'),
      );
      // {{currency}} resolved, {{$guid}} mapped, empty {{token}} only in auth.
      expect(
        result.warnings.where((w) => w.contains('returned as-is')).single,
        allOf(contains('{{traceId}}'), isNot(contains('currency'))),
      );
    });
  });

  group('paths', () {
    test('strip scheme, host, port, query and fragment', () {
      final cases = {
        '{{baseUrl}}/users/:id?x=1': '/users/:id',
        'https://example.com:8443/a/b/': '/a/b',
        '{{host}}/api/v2/items': '/api/v2/items',
        '{{protocol}}://{{host}}:{{port}}/x#frag': '/x',
        '{{baseUrl}}': '/',
        '': '/',
        '/relative/path': '/relative/path',
        'localhost:3000/api': '/api',
        'http://[::1]:8080/v6': '/v6',
        '{{baseUrl}}/users/{{ userId }}/posts/{{postId}}':
            '/users/:userId/posts/:postId',
      };
      cases.forEach((raw, path) {
        expect(single(raw).path, path, reason: raw);
      });
    });

    test('object URLs use path arrays, including v2.0 {value} segments', () {
      expect(
        single({
          'raw': '{{baseUrl}}/a/:b',
          'host': ['{{baseUrl}}'],
          'path': [
            'a',
            {'type': 'string', 'value': ':b'},
            '',
          ],
        }).path,
        '/a/:b',
      );
      expect(single({'raw': 'https://x.test/raw/only?y=2'}).path, '/raw/only');
      expect(single({'host': 'x.test', 'path': 'str/path'}).path, '/str/path');
    });

    test('variables inside a segment use collection values or become *', () {
      final result = importMap({
        'info': {'name': 'Versions'},
        'variable': [
          {'key': 'ver', 'value': '2'},
        ],
        'item': [
          {
            'name': 'Known',
            'request': {'url': '{{baseUrl}}/v{{ver}}/ping'},
          },
          {
            'name': 'Unknown',
            'request': {'url': '{{baseUrl}}/files/{{name}}.json'},
          },
        ],
      });
      expect(result.endpoints.map((e) => e.path), ['/v2/ping', '/files/*']);
      expect(
        result.warnings.where((w) => w.contains('turned into *')).single,
        contains('{{name}}'),
      );
    });

    test('method defaults to GET and unknown methods become ANY', () {
      final result = importMap([
        {
          'name': 'No method',
          'request': {'url': '/a'},
        },
        {
          'name': 'WebDAV',
          'request': {'method': 'PROPFIND', 'url': '/b'},
        },
        {
          'name': 'Query',
          'request': {'method': 'query', 'url': '/c'},
        },
        {'name': 'String request', 'request': 'https://x.test/d'},
      ]);
      expect(result.endpoints.map((e) => e.method), [
        HttpMethodType.get,
        HttpMethodType.any,
        HttpMethodType.any,
        HttpMethodType.get,
      ]);
      expect(result.endpoints.last.path, '/d');
      expect(
        result.warnings.where((w) => w.contains('ANY')).single,
        startsWith('2 requests used methods'),
      );
    });
  });

  group('responses', () {
    Json ex(String body, {String? lang, String? contentType, Object? code}) => {
      'name': '',
      'code': ?code,
      '_postman_previewlanguage': ?lang,
      'header': [
        if (contentType != null) {'key': 'Content-Type', 'value': contentType},
      ],
      'body': body,
    };

    BodyType typeOf(Json example) =>
        single('/t', response: [example]).responses.single.bodyType;

    test('bodyType comes from preview language, Content-Type or sniffing', () {
      expect(typeOf(ex('{"a": 1}', lang: 'json')), BodyType.json);
      expect(typeOf(ex('{"id": {{id}}}', lang: 'json')), BodyType.json);
      expect(typeOf(ex('not json', lang: 'json')), BodyType.text);
      expect(typeOf(ex('<a/>', lang: 'xml')), BodyType.xml);
      expect(typeOf(ex('<p>hi</p>', lang: 'html')), BodyType.html);
      expect(typeOf(ex('{"a": 1}', lang: 'text')), BodyType.text);
      expect(
        typeOf(ex('[1, 2]', contentType: 'application/vnd.api+json')),
        BodyType.json,
      );
      expect(typeOf(ex('<p/>', contentType: 'text/html')), BodyType.html);
      expect(typeOf(ex('<x/>', contentType: 'text/xml')), BodyType.xml);
      expect(typeOf(ex('42', contentType: 'text/plain')), BodyType.text);
      expect(typeOf(ex('  {"sniffed": true}')), BodyType.json);
      expect(typeOf(ex('<!doctype html><p>x</p>')), BodyType.html);
      expect(typeOf(ex('<?xml version="1.0"?><x/>')), BodyType.xml);
      expect(typeOf(ex('{broken')), BodyType.text);
      expect(typeOf(ex('plain words')), BodyType.text);
      expect(typeOf(ex('   ', lang: 'json')), BodyType.none);
    });

    test('labels fall back to "Example N"; odd codes fall back to 200', () {
      final ep = single(
        '/t',
        response: [
          ex('{}', code: '201'),
          ex('{}', code: 'abc'),
          ex('{}', code: 42),
        ],
      );
      expect(ep.responses.map((r) => '${r.statusCode} ${r.label}'), [
        '201 Example 1',
        '200 Example 2',
        '200 Example 3',
      ]);
    });

    test('without a 2xx example the first one stays the default', () {
      final ep = single(
        '/t',
        response: [ex('{}', code: 401), ex('{}', code: 500)],
      );
      expect(ep.responses.map((r) => r.statusCode), [401, 500]);
      expect(ep.responses.first.conditions, isEmpty);
      expect(
        ep.responses.last.conditions.single.source,
        ConditionSource.header,
      );
    });

    test('raw header strings are parsed and duplicates merged', () {
      final ep = single(
        '/t',
        response: [
          {
            'code': 200,
            'header':
                'Content-Type: text/plain\nDate: today\nVary: Accept\n'
                'vary: Origin',
            'body': 'ok',
          },
        ],
      );
      expect(ep.responses.single.headers, {
        'Content-Type': 'text/plain',
        'Vary': 'Accept, Origin',
      });
    });

    test('rules come from differing originalRequest query params only', () {
      final ep = single(
        '{{baseUrl}}/items?page=1&sort={{sort}}',
        response: [
          {
            'name': 'Page 2',
            'code': 200,
            'originalRequest': {
              'url': '{{baseUrl}}/items?page=2&sort={{sort}}&q=red%20shoes',
            },
            'body': '[]',
          },
          {
            'name': 'Same query',
            'code': 400,
            'originalRequest': {'url': '{{baseUrl}}/items?page=1'},
            'body': '{}',
          },
          {
            'name': 'Page 1',
            'code': 200,
            'originalRequest': {
              'url': {
                'raw': '{{baseUrl}}/items?page=1&debug=1',
                'query': [
                  {'key': 'page', 'value': '1'},
                  {'key': 'debug', 'value': '1', 'disabled': true},
                ],
              },
            },
            'body': '[]',
          },
        ],
      );
      final [page2, same, page1] = ep.responses;
      expect(page2.conditions, isEmpty);
      expect(same.conditions.single.key, postmanResponseNameHeader);
      expect(page1.conditions.single.key, postmanResponseNameHeader);
      expect(page2.label, 'Page 2');

      // Re-run with page 2 not first, to see its conditions.
      final ep2 = single(
        '{{baseUrl}}/items?page=1',
        response: [
          {'name': 'Default', 'code': 200, 'body': '[]'},
          {
            'name': 'Page 2',
            'code': 200,
            'originalRequest': {
              'url': '{{baseUrl}}/items?page=2&sort={{sort}}&q=red%20shoes',
            },
            'body': '[]',
          },
        ],
      );
      expect(ep2.responses.last.conditions.map((c) => c.describe()).toList(), [
        'Query param "page" equals "2"',
        'Query param "q" equals "red shoes"',
      ]);
    });
  });

  group('auth', () {
    test('v2.0 map-style attributes', () {
      final result = importMap({
        'info': {
          'name': 'v2.0',
          'schema':
              'https://schema.getpostman.com/json/collection/v2.0.0/collection.json',
        },
        'auth': {
          'type': 'basic',
          'basic': {'username': 'u', 'password': 'p'},
        },
        'item': [
          {
            'name': 'Inherits basic',
            'request': {'method': 'GET', 'url': 'https://x.test/a'},
          },
          {
            'name': 'Map apikey',
            'request': {
              'method': 'GET',
              'url': 'https://x.test/b',
              'auth': {
                'type': 'apikey',
                'apikey': {'key': 'X-Token', 'value': 's3cret', 'in': 'header'},
              },
            },
          },
          {
            'name': 'Map apikey in query',
            'request': {
              'url': 'https://x.test/c',
              'auth': {
                'type': 'apikey',
                'apikey': {'key': 'token', 'in': 'query'},
              },
            },
          },
          {
            'name': 'OAuth2 in query',
            'request': {
              'url': 'https://x.test/d',
              'auth': {
                'type': 'oauth2',
                'oauth2': [
                  {'key': 'addTokenTo', 'value': 'queryParams'},
                ],
              },
            },
          },
          {
            'name': 'OAuth2 header',
            'request': {
              'url': 'https://x.test/e',
              'auth': {'type': 'oauth2', 'oauth2': []},
            },
          },
        ],
      });
      expect(result.endpoints.map((e) => e.requireAuth ? e.authHeader : '-'), [
        'Authorization',
        'X-Token',
        '-',
        '-',
        'Authorization',
      ]);
      expect(
        result.warnings.where((w) => w.contains('query parameter')).single,
        startsWith('2 requests send credentials'),
      );
    });

    test('noauth on a folder stops inheritance for everything inside', () {
      final result = importMap({
        'info': {'name': 'Auth'},
        'auth': {'type': 'bearer'},
        'item': [
          {
            'name': 'Public',
            'auth': {'type': 'noauth'},
            'item': [
              {
                'name': 'Deep',
                'item': [
                  {
                    'name': 'Open',
                    'request': {'url': '/open', 'auth': null},
                  },
                  {
                    'name': 'Re-secured',
                    'request': {
                      'url': '/locked',
                      'auth': {'type': 'digest'},
                    },
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(byName(result, 'Open').requireAuth, isFalse);
      expect(byName(result, 'Re-secured').requireAuth, isTrue);
      expect(byName(result, 'Open').folder, 'Public/Deep');
    });
  });

  group('loose input', () {
    test('a single request item', () {
      final result = importMap({
        'name': 'Just one',
        'request': {'method': 'POST', 'url': '{{baseUrl}}/login'},
        'response': [
          {'name': 'OK', 'code': 200, 'body': '{"token": "t"}'},
        ],
      });
      expect(result.name, 'Postman collection');
      expect(result.requests, 1);
      expect(result.examples, 1);
      expect(result.endpoints.single.name, 'Just one');
      expect(result.endpoints.single.method, HttpMethodType.post);
      expect(result.endpoints.single.folder, '');
      expect(result.warnings, isEmpty);
    });

    test('a list of items, including folders', () {
      final result = importMap([
        {
          'name': 'A',
          'request': {'url': '/a'},
        },
        {
          'name': 'F',
          'item': [
            {
              'name': 'B',
              'request': {'url': '/b'},
            },
          ],
        },
      ]);
      expect(result.requests, 2);
      expect(result.folders, 1);
      expect(result.endpoints.map((e) => e.folder), ['', 'F']);
      expect(
        result.warnings.single,
        startsWith('2 requests had no saved examples; they got'),
      );
    });

    test('{item: [...]} without info, and the API export wrapper', () {
      final bare = importMap({
        'item': [
          {
            'name': 'A',
            'request': {'url': '/a'},
          },
        ],
      });
      expect(bare.endpoints.single.path, '/a');
      expect(bare.name, 'Postman collection');

      final wrapped = importMap({'collection': shopCollection()});
      expect(wrapped.name, 'Shop API');
      expect(wrapped.requests, 7);
    });

    test('unnamed requests are named after method and path', () {
      final result = importMap([
        {
          'request': {'method': 'PUT', 'url': '/things/:id'},
        },
      ]);
      expect(result.endpoints.single.name, 'PUT /things/:id');
    });
  });

  group('rejects', () {
    Matcher formatError(String fragment) => throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains(fragment),
      ),
    );

    test('invalid JSON', () {
      expect(
        () => importPostmanToMocks('{"info": '),
        formatError('valid JSON'),
      );
      expect(() => importPostmanToMocks('   '), formatError('empty'));
    });

    test('environment and globals files', () {
      final env = {
        'id': 'e1',
        'name': 'Staging',
        'values': [
          {'key': 'baseUrl', 'value': 'https://staging.test', 'enabled': true},
        ],
        '_postman_variable_scope': 'environment',
      };
      expect(() => importMap(env), formatError('environment'));
      final legacy = {...env}..remove('_postman_variable_scope');
      expect(() => importMap(legacy), formatError('environment'));
      expect(
        () => importMap({'values': [], '_postman_variable_scope': 'globals'}),
        formatError('only holds variables'),
      );
    });

    test('OpenAPI documents and other JSON', () {
      expect(
        () => importMap({'openapi': '3.0.0', 'paths': {}}),
        formatError('OpenAPI'),
      );
      expect(
        () => importMap({'hello': 'world'}),
        formatError('Collection v2.1'),
      );
      expect(() => importMap([1, 2]), formatError('isn\'t a Postman'));
      expect(() => importMap('just a string'), formatError('isn\'t a Postman'));
    });

    test('collections without requests', () {
      expect(
        () => importMap({
          'info': {'name': 'Empty'},
          'item': [
            {'name': 'Folder', 'item': []},
          ],
        }),
        formatError('No requests'),
      );
    });
  });

  group('postman v1', () {
    final v1 = {
      'id': 'c1',
      'name': 'Legacy API',
      'description': 'Old format',
      'order': ['r3'],
      'folders_order': ['f1'],
      'folders': [
        {
          'id': 'f1',
          'name': 'Accounts',
          'order': ['r1'],
          'folders_order': ['f2'],
        },
        {
          'id': 'f2',
          'name': 'Admin',
          'order': ['r2'],
        },
      ],
      'requests': [
        {
          'id': 'r1',
          'name': 'Get account',
          'method': 'GET',
          'url': '{{host}}/accounts/{{accountId}}',
          'currentHelper': 'bearerAuth',
          'folder': 'f1',
          'responses': [
            {
              'name': 'Missing',
              'responseCode': {'code': 404, 'name': 'Not Found'},
              'headers': [
                {'key': 'Content-Type', 'value': 'application/json'},
                {'key': 'Content-Length', 'value': '20'},
              ],
              'text': '{"error":"missing"}',
              'language': 'json',
              'request': {'url': '{{host}}/accounts/0?missing=true'},
            },
            {
              'name': 'Found',
              'responseCode': {'code': 200, 'name': 'OK'},
              'headers': [],
              'text': '{"id":"a1"}',
              'language': 'json',
              'request': 'r1',
            },
          ],
        },
        {
          'id': 'r2',
          'name': 'Purge',
          'method': 'DELETE',
          'url': 'https://legacy.test/admin/purge',
          'currentHelper': 'normal',
          'folder': 'f2',
          'responses': [],
        },
        {
          'id': 'r3',
          'name': 'Status',
          'method': 'GET',
          'url': 'https://legacy.test/status',
          'responses': [],
        },
        {
          'id': 'r4',
          'name': 'Orphan',
          'method': 'GET',
          'url': 'https://legacy.test/orphan',
        },
      ],
    };

    test('converts folders, order, responses and helpers', () {
      final result = importMap(v1);
      expect(result.name, 'Legacy API');
      expect(result.description, 'Old format');
      expect(result.folders, 2);
      expect(result.requests, 4);
      expect(result.examples, 2);
      expect(result.endpoints.map((e) => '${e.folder}|${e.name}|${e.path}'), [
        'Accounts/Admin|Purge|/admin/purge', // sub-folders before requests
        'Accounts|Get account|/accounts/:accountId',
        '|Status|/status',
        '|Orphan|/orphan',
      ]);

      final account = byName(result, 'Get account');
      expect(account.requireAuth, isTrue);
      expect(byName(result, 'Purge').requireAuth, isFalse);
      expect(account.strategy, ResponseStrategy.rules);
      final [found, missing] = account.responses;
      expect(found.statusCode, 200);
      expect(found.body, '{"id":"a1"}');
      expect(missing.statusCode, 404);
      expect(missing.headers, {'Content-Type': 'application/json'});
      expect(
        missing.conditions.single.describe(),
        'Query param "missing" equals "true"',
      );
    });
  });

  test('warns once about duplicate method + path pairs', () {
    final result = importMap([
      {
        'name': 'One',
        'request': {'url': '{{baseUrl}}/users/:id'},
      },
      {
        'name': 'Two',
        'request': {'url': '{{baseUrl}}/users/{{userId}}'},
      },
      {
        'name': 'Three',
        'request': {'url': 'https://x.test/users/:uid/'},
      },
      {
        'name': 'Other method',
        'request': {'method': 'POST', 'url': '{{baseUrl}}/users/:id'},
      },
      {
        'name': 'Literal',
        'request': {'url': '{{baseUrl}}/users/me'},
      },
    ]);
    expect(result.endpoints, hasLength(5)); // all kept
    final dupes = result.warnings.where((w) => w.contains('repeat')).single;
    expect(dupes, startsWith('2 endpoints repeat a method and path'));
    expect(dupes, contains('GET /users/:userId'));
    expect(dupes, contains('first matching endpoint'));
  });

  test('collection variables and dynamic variables in bodies', () {
    final result = importMap({
      'info': {'name': 'Vars'},
      'variable': [
        {'key': 'greeting', 'value': 'Hello {{who}}'},
        {'key': 'who', 'value': 'world'},
        {'key': 'count', 'value': 3},
        {'key': 'off', 'value': 'x', 'disabled': true},
      ],
      'item': [
        {
          'name': 'Vars',
          'request': {'url': '/v'},
          'response': [
            {
              'code': 200,
              'body':
                  '{"msg": "{{greeting}}", "n": {{count}}, "id": "{{\$randomUUID}}", '
                  '"at": "{{\$isoTimestamp}}", "t": "{{uuid}}", "off": "{{off}}", '
                  '"bank": "{{\$randomBankAccount}}"}',
            },
          ],
        },
      ],
    });
    final r = result.endpoints.single.responses.single;
    expect(
      r.body,
      '{"msg": "Hello world", "n": 3, "id": "{{uuid}}", "at": "{{now}}", '
      '"t": "{{uuid}}", "off": "{{off}}", "bank": "{{\$randomBankAccount}}"}',
    );
    expect(r.bodyType, BodyType.json);
    final warning = result.warnings.single;
    expect(warning, contains('{{off}}, {{\$randomBankAccount}}'));
    expect(warning, isNot(contains('{{uuid}}'))); // Mock Studio fills it
  });

  group('end to end', () {
    late MockServer server;
    late int port;

    setUp(() async {
      final imported = importMap(shopCollection());
      server = MockServer(
        project: MockProject(port: 0, endpoints: imported.endpoints),
        onLog: (_) {},
      );
      await server.start();
      port = server.boundPort!;
    });

    tearDown(() => server.stop());

    Future<({int status, String body, HttpHeaders headers})> send(
      String method,
      String path, {
      Map<String, String> headers = const {},
    }) async {
      final client = HttpClient();
      try {
        final req = await client.openUrl(
          method,
          Uri.parse('http://127.0.0.1:$port$path'),
        );
        headers.forEach(req.headers.set);
        final res = await req.close();
        final body = await utf8.decodeStream(res);
        return (status: res.statusCode, body: body, headers: res.headers);
      } finally {
        client.close(force: true);
      }
    }

    const bearer = {'Authorization': 'Bearer test'};

    test('path params route to the default 2xx example', () async {
      final res = await send('GET', '/users/42', headers: bearer);
      expect(res.status, 200);
      expect(jsonDecode(res.body), {
        'id': 42,
        'name': 'Ada',
        'currency': 'EUR',
      });
      expect(res.headers.contentType?.mimeType, 'application/json');
    });

    test(
      'query rules and the response-name header pick other examples',
      () async {
        final missing = await send(
          'GET',
          '/users/42?status=404',
          headers: bearer,
        );
        expect(missing.status, 404);
        expect(jsonDecode(missing.body)['error'], 'not_found');

        final error = await send(
          'GET',
          '/users/42',
          headers: {...bearer, postmanResponseNameHeader: 'Server error'},
        );
        expect(error.status, 500);
        expect(jsonDecode(error.body), {'error': 'boom'});

        final other = await send(
          'GET',
          '/users/42?status=500',
          headers: bearer,
        );
        expect(other.status, 200); // unmatched rules fall back to the default
      },
    );

    test('inherited auth is enforced, noauth is open', () async {
      expect((await send('GET', '/users/42')).status, 401);
      expect((await send('GET', '/ping')).status, 401);

      final health = await send('GET', '/admin/health');
      expect(health.status, 200);
      expect(jsonDecode(health.body), {'ok': true});

      expect((await send('GET', '/orders/7')).status, 401);
      final order = await send('GET', '/orders/7', headers: {'X-Api-Key': 'k'});
      expect(order.status, 200);
      expect(order.body, '<order id="7"><total>12.50</total></order>');
      expect(order.headers.contentType?.mimeType, 'application/xml');

      final cancel = await send('DELETE', '/orders/7');
      expect(cancel.status, 204);
      expect(cancel.body, isEmpty);
    });

    test('example headers and Mock Studio tokens are served', () async {
      final list = await send('GET', '/users?page=1', headers: bearer);
      expect(list.status, 200);
      expect(
        list.headers.value('content-type'),
        'application/json; charset=utf-8',
      );
      expect(
        list.headers.value('x-request-id'),
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
      expect(list.headers.value('x-debug'), isNull);
      expect((jsonDecode(list.body) as List).length, 2);

      final ping = await send('GET', '/ping', headers: bearer);
      expect(ping.body, 'pong');
      expect(ping.headers.contentType?.mimeType, 'text/plain');
    });
  });
}

typedef Json = Map<String, Object?>;
