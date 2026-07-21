import 'package:flutter_test/flutter_test.dart';

import 'package:mock_studio/models/endpoint.dart';
import 'package:mock_studio/models/enums.dart';
import 'package:mock_studio/models/mock_response.dart';
import 'package:mock_studio/services/response_resolver.dart';
import 'package:mock_studio/services/route_matcher.dart';
import 'package:mock_studio/services/template_engine.dart';

void main() {
  group('RouteMatcher', () {
    test('matches literal paths', () {
      expect(RouteMatcher.match('/users', '/users'), isNotNull);
      expect(RouteMatcher.match('/users', '/orders'), isNull);
    });

    test('captures named params', () {
      final m = RouteMatcher.match('/users/:id', '/users/42');
      expect(m, isNotNull);
      expect(m!.params['id'], '42');
    });

    test('tail wildcard captures the rest', () {
      final m = RouteMatcher.match('/assets/**', '/assets/img/logo.png');
      expect(m!.params['rest'], 'img/logo.png');
    });

    test('specificity ranks literals above params', () {
      expect(
        RouteMatcher.specificity('/users/list') >
            RouteMatcher.specificity('/users/:id'),
        isTrue,
      );
    });
  });

  group('TemplateEngine', () {
    test('substitutes path params and query', () {
      final ctx = TemplateContext(
        pathParams: {'id': '7'},
        query: {'page': '3'},
        headers: {},
        rawBody: '',
      );
      expect(
        TemplateEngine.render('id={{params.id}} page={{query.page}}', ctx),
        'id=7 page=3',
      );
    });

    test('reads JSON body fields', () {
      final ctx = TemplateContext(
        pathParams: {},
        query: {},
        headers: {},
        rawBody: '{"user":{"email":"a@b.com"}}',
      );
      expect(TemplateEngine.render('{{body.user.email}}', ctx), 'a@b.com');
    });
  });

  group('ResponseResolver', () {
    test('rules pick the matching response', () {
      final ep = Endpoint(
        strategy: ResponseStrategy.rules,
        responses: [
          MockResponse(
            label: 'ok',
            statusCode: 200,
            conditions: [
              RuleCondition(
                source: ConditionSource.bodyJson,
                key: 'password',
                operator: ConditionOperator.equals,
                value: 'secret',
              ),
            ],
          ),
          MockResponse(label: 'fail', statusCode: 401),
        ],
      );
      final good = TemplateContext(
        pathParams: {},
        query: {},
        headers: {},
        rawBody: '{"password":"secret"}',
      );
      final bad = TemplateContext(
        pathParams: {},
        query: {},
        headers: {},
        rawBody: '{"password":"nope"}',
      );
      expect(ResponseResolver.select(ep, good, 'POST').statusCode, 200);
      expect(ResponseResolver.select(ep, bad, 'POST').statusCode, 401);
    });

    test('sequence advances each call', () {
      final ep = Endpoint(
        strategy: ResponseStrategy.sequence,
        responses: [
          MockResponse(statusCode: 503),
          MockResponse(statusCode: 200),
        ],
      );
      final ctx = TemplateContext(
        pathParams: {},
        query: {},
        headers: {},
        rawBody: '',
      );
      expect(ResponseResolver.select(ep, ctx, 'GET').statusCode, 503);
      expect(ResponseResolver.select(ep, ctx, 'GET').statusCode, 200);
      expect(ResponseResolver.select(ep, ctx, 'GET').statusCode, 503);
    });
  });
}
