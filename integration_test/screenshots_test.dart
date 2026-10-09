// Renders the real app on the Linux embedder and saves PNGs of the main
// screens in each theme. Storage and preferences point at a temporary
// directory, so your own projects are never touched.
//
//   flutter test integration_test/screenshots_test.dart -d linux
//
// PNGs land in screenshots/ at the repository root.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mock_studio/app.dart';
import 'package:mock_studio/state/app_state.dart';
import 'package:mock_studio/theme/app_theme.dart';
import 'package:mock_studio/ui/dialogs/postman_import_dialog.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _shop = {
  'info': {
    'name': 'Shop API',
    'schema':
        'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  },
  'auth': {
    'type': 'bearer',
    'bearer': [
      {'key': 'token', 'value': '{{token}}'},
    ],
  },
  'item': [
    {
      'name': 'Orders',
      'item': [
        {
          'name': 'Get order',
          'request': {'method': 'GET', 'url': '{{baseUrl}}/orders/{{orderId}}'},
          'response': [
            {
              'name': 'Found',
              'code': 200,
              '_postman_previewlanguage': 'json',
              'header': [
                {'key': 'Content-Type', 'value': 'application/json'},
              ],
              'body': '{"id": 42, "status": "shipped"}',
            },
            {
              'name': 'Not found',
              'code': 404,
              'originalRequest': {
                'url': {
                  'raw': '{{baseUrl}}/orders/0?debug=missing',
                  'query': [
                    {'key': 'debug', 'value': 'missing'},
                  ],
                },
              },
              'body': '{"error": "not found"}',
            },
          ],
        },
        {
          'name': 'List orders',
          'request': {'method': 'GET', 'url': '{{baseUrl}}/orders'},
          'response': [
            {'name': 'All', 'code': 200, 'body': '[{"id": 42}]'},
          ],
        },
        {
          'name': 'Cancel order',
          'request': {
            'method': 'DELETE',
            'url': '{{baseUrl}}/orders/{{orderId}}',
          },
        },
      ],
    },
    {
      'name': 'Login',
      'request': {
        'method': 'POST',
        'url': '{{baseUrl}}/auth/login',
        'auth': {'type': 'noauth'},
      },
      'response': [
        {'name': 'OK', 'code': 200, 'body': '{"token": "abc"}'},
      ],
    },
  ],
};

const _boundaryKey = ValueKey('screenshot-boundary');

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Directory('${Directory.current.path}/screenshots');

  testWidgets('screenshots', (tester) async {
    late Directory tmp;
    late int port;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('ms_shots_');
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();
      await outDir.create(recursive: true);
    });
    PathProviderPlatform.instance = _TempPaths(tmp.path);
    SharedPreferences.setMockInitialValues({'themeMode': 1});

    final app = AppState();
    await tester.runAsync(() => app.init());
    // The view's size is what MediaQuery (and so the layout) sees;
    // setSurfaceSize alone only scales the drawing.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ChangeNotifierProvider.value(
          value: app,
          child: const MockStudioApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundaryKey),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('${outDir.path}/$name.png').writeAsBytesSync(bytes!);
    }

    // Serve the sample project on a free port and send some traffic.
    final project = app.selectedProject!;
    project.port = port;
    await tester.runAsync(() async {
      await app.startServer(project);
      final client = HttpClient();
      for (final path in ['/api/users', '/api/users/7', '/api/nope', '/']) {
        final req = await client.get('127.0.0.1', port, path);
        await (await req.close()).drain<void>();
      }
      client.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await shot('01-teal-light');

    // A hover card: point the mouse at the path field's help.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.help_outline).at(3)));
    await tester.pump(const Duration(milliseconds: 600));
    await shot('01b-hover-card');
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.removePointer();

    await tester.runAsync(() => app.setThemeMode(ThemeMode.dark));
    await tester.pumpAndSettle();
    await shot('02-teal-dark');

    await tester.runAsync(() => app.setThemeId(AppThemeId.graphite));
    await tester.pumpAndSettle();
    await shot('03-graphite');

    await tester.runAsync(() async {
      await app.setThemeId(AppThemeId.teal);
      await app.setThemeMode(ThemeMode.light);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live').first);
    await tester.pumpAndSettle();
    await shot('04-live-requests');

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await shot('05-settings');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import').first);
    await tester.pumpAndSettle();
    await shot('06-import-menu');

    await tester.tapAt(const Offset(700, 450));
    await tester.pumpAndSettle();

    importPostmanDialog(tester.element(find.byType(Scaffold).first), app);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Or paste Postman JSON here'),
      jsonEncode(_shop),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await shot('07-postman-import');
    await tester.tap(find.text('Import').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endpoints').first);
    await tester.pumpAndSettle();
    await shot('08-imported-tree');

    // Phone layout (an Android-sized window) with the live sample project.
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    app.selectProject(project.id);
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();
    await shot('09-phone-endpoints');

    await tester.tap(find.text('Get user by id'));
    await tester.pumpAndSettle();
    await shot('10-phone-editor');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Live'),
      ),
    );
    await tester.pumpAndSettle();
    await shot('11-phone-live');

    await tester.runAsync(() async {
      await app.stopServer(project);
      await tmp.delete(recursive: true);
    });
  });
}
