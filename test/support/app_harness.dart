import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mock_studio/app.dart';
import 'package:mock_studio/state/app_state.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points storage at a temporary directory so tests never touch the user's
/// real projects.
class TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  TempPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

bool _fontsLoaded = false;

/// Loads Roboto, the Material icons and a monospace font from the Flutter
/// SDK and the system, so widget tests measure text like the real app
/// instead of with the square test font. Missing files are skipped.
Future<void> loadRealFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  await tester.runAsync(() async {
    // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<os>/.
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final fonts = '${artifacts.path}/material_fonts';
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      var any = false;
      for (final f in files) {
        final file = File(f);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        any = true;
      }
      if (any) await loader.load();
    }

    await load('Roboto', [
      for (final w in ['Regular', 'Medium', 'Bold', 'Black'])
        '$fonts/Roboto-$w.ttf',
    ]);
    await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    await load('monospace', [
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
    ]);
  });
}

/// Pumps the whole app at [size] with the sample project in a temp folder.
Future<AppState> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Map<String, Object> prefs = const {},
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tmp = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('ms_test_'),
  ))!;
  addTearDown(() => tmp.delete(recursive: true));
  PathProviderPlatform.instance = TempPaths(tmp.path);
  SharedPreferences.setMockInitialValues({'themeMode': 1, ...prefs});
  final app = AppState();
  await tester.runAsync(() => app.init());
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: app, child: const MockStudioApp()),
  );
  await tester.pumpAndSettle();
  return app;
}

/// A free local port.
Future<int> freePort(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = s.port;
      await s.close();
      return port;
    }))!;

/// Starts the selected project's server on a free port and sends [paths]
/// to it, so the Live list has entries.
Future<void> sendRequests(
  WidgetTester tester,
  AppState app,
  List<String> paths,
) async {
  final project = app.selectedProject!;
  if (!app.isRunning(project.id)) {
    project.port = await freePort(tester);
    await tester.runAsync(() async {
      expect(await app.startServer(project), isNull);
    });
  }
  await tester.runAsync(
    // Widget tests replace HttpClient with a fake that answers 400 without
    // connecting; these requests must reach the real mock server.
    () => HttpOverrides.runWithHttpOverrides(() async {
      for (final p in paths) {
        await http.get(Uri.parse('http://127.0.0.1:${project.port}$p'));
      }
      // Log updates are batched every 120 ms.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }, _RealHttp()),
  );
  await tester.pump();
}

class _RealHttp extends HttpOverrides {}

Future<void> stopServers(WidgetTester tester, AppState app) => tester
    .runAsync(() async {
      for (final p in app.projects) {
        await app.stopServer(p);
      }
    })
    .then((_) {});
