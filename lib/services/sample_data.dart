import '../models/endpoint.dart';
import '../models/enums.dart';
import '../models/mock_project.dart';
import '../models/mock_response.dart';

/// Ready-made projects and endpoints used for first-run onboarding and the
/// "add from template" flow.
class SampleData {
  /// A friendly starter project shown the first time the app launches.
  static MockProject welcomeProject() {
    return MockProject(
      name: 'My First Mock API',
      description:
          'A sample project to explore Mock Studio. Edit or delete freely.',
      port: 8080,
      corsEnabled: true,
      endpoints: [
        Endpoint(
          name: 'Health check',
          method: HttpMethodType.get,
          path: '/health',
          description: 'A simple endpoint that always says the service is up.',
          responses: [
            MockResponse(
              label: 'Healthy',
              statusCode: 200,
              body: '{\n  "status": "ok",\n  "time": "{{now}}"\n}',
            ),
          ],
        ),
        Endpoint(
          name: 'Get user by id',
          method: HttpMethodType.get,
          path: '/users/:id',
          description: 'Returns a fake user. The id in the URL is echoed back.',
          responses: [
            MockResponse(
              label: 'User found',
              statusCode: 200,
              body:
                  '{\n'
                  '  "id": "{{params.id}}",\n'
                  '  "name": "{{faker.name}}",\n'
                  '  "email": "{{faker.email}}",\n'
                  '  "city": "{{faker.city}}",\n'
                  '  "createdAt": "{{now}}"\n'
                  '}',
            ),
          ],
        ),
        Endpoint(
          name: 'Create user',
          method: HttpMethodType.post,
          path: '/users',
          description: 'Echoes back the posted body with a generated id.',
          responses: [
            MockResponse(
              label: 'Created',
              statusCode: 201,
              body:
                  '{\n'
                  '  "id": "{{uuid}}",\n'
                  '  "name": "{{body.name}}",\n'
                  '  "email": "{{body.email}}",\n'
                  '  "createdAt": "{{now}}"\n'
                  '}',
            ),
          ],
        ),
        Endpoint(
          name: 'Login (conditional)',
          method: HttpMethodType.post,
          path: '/login',
          description:
              'Returns 200 with a token when password is "secret", '
              'otherwise 401. Demonstrates conditional rules.',
          strategy: ResponseStrategy.rules,
          responses: [
            MockResponse(
              label: 'Success',
              statusCode: 200,
              conditions: [
                RuleCondition(
                  source: ConditionSource.bodyJson,
                  key: 'password',
                  operator: ConditionOperator.equals,
                  value: 'secret',
                ),
              ],
              body: '{\n  "token": "{{uuid}}",\n  "expiresIn": 3600\n}',
            ),
            MockResponse(
              label: 'Invalid credentials',
              statusCode: 401,
              body: '{\n  "error": "invalid_credentials"\n}',
            ),
          ],
        ),
      ],
    );
  }

  /// Named templates for the "New endpoint from template" picker.
  static List<({String title, String subtitle, Endpoint Function() build})>
  endpointTemplates() {
    return [
      (
        title: 'Simple JSON response',
        subtitle: 'A GET that returns a fixed JSON object',
        build: () => Endpoint(
          name: 'Get something',
          method: HttpMethodType.get,
          path: '/something',
          responses: [
            MockResponse(
              label: 'OK',
              statusCode: 200,
              body: '{\n  "message": "Hello"\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Resource by id',
        subtitle: 'GET /items/:id echoing the id back',
        build: () => Endpoint(
          name: 'Get item',
          method: HttpMethodType.get,
          path: '/items/:id',
          responses: [
            MockResponse(
              label: 'Found',
              statusCode: 200,
              body:
                  '{\n  "id": "{{params.id}}",\n  "name": "{{faker.word}}"\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Create (POST) endpoint',
        subtitle: 'Echoes the request body with a new id',
        build: () => Endpoint(
          name: 'Create item',
          method: HttpMethodType.post,
          path: '/items',
          responses: [
            MockResponse(
              label: 'Created',
              statusCode: 201,
              body: '{\n  "id": "{{uuid}}",\n  "received": {{body.}}\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Protected endpoint',
        subtitle: 'Requires an Authorization header (401 otherwise)',
        build: () => Endpoint(
          name: 'Get profile',
          method: HttpMethodType.get,
          path: '/me',
          requireAuth: true,
          responses: [
            MockResponse(
              label: 'Profile',
              statusCode: 200,
              body: '{\n  "name": "{{faker.name}}"\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Flaky service (random errors)',
        subtitle: 'Returns 500 ~20% of the time',
        build: () => Endpoint(
          name: 'Flaky endpoint',
          method: HttpMethodType.get,
          path: '/flaky',
          strategy: ResponseStrategy.random,
          responses: [
            MockResponse(
              label: 'Success',
              statusCode: 200,
              weight: 8,
              body: '{\n  "ok": true\n}',
            ),
            MockResponse(
              label: 'Server error',
              statusCode: 500,
              weight: 2,
              body: '{\n  "error": "boom"\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Slow endpoint',
        subtitle: '2s delay — test spinners and timeouts',
        build: () => Endpoint(
          name: 'Slow endpoint',
          method: HttpMethodType.get,
          path: '/slow',
          defaultDelayMs: 2000,
          responses: [
            MockResponse(
              label: 'OK',
              statusCode: 200,
              body: '{\n  "done": true\n}',
            ),
          ],
        ),
      ),
      (
        title: 'Retry sequence',
        subtitle: 'Fails twice, then succeeds — test retry logic',
        build: () => Endpoint(
          name: 'Retry test',
          method: HttpMethodType.get,
          path: '/retry',
          strategy: ResponseStrategy.sequence,
          responses: [
            MockResponse(
              label: 'Attempt 1 — fail',
              statusCode: 503,
              body: '{\n  "error": "unavailable"\n}',
            ),
            MockResponse(
              label: 'Attempt 2 — fail',
              statusCode: 503,
              body: '{\n  "error": "unavailable"\n}',
            ),
            MockResponse(
              label: 'Attempt 3 — success',
              statusCode: 200,
              body: '{\n  "ok": true\n}',
            ),
          ],
        ),
      ),
      (
        title: 'List with pagination',
        subtitle: 'GET returning an array of fake items',
        build: () => Endpoint(
          name: 'List items',
          method: HttpMethodType.get,
          path: '/items',
          responses: [
            MockResponse(
              label: 'OK',
              statusCode: 200,
              body:
                  '{\n'
                  '  "page": {{query.page}},\n'
                  '  "items": [\n'
                  '    { "id": "{{uuid}}", "name": "{{faker.word}}" },\n'
                  '    { "id": "{{uuid}}", "name": "{{faker.word}}" }\n'
                  '  ]\n'
                  '}',
            ),
          ],
        ),
      ),
    ];
  }
}
