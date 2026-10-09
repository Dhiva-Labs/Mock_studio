import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_studio/ui/editor/endpoint_editor.dart';
import 'package:mock_studio/ui/flows/flows_view.dart';
import 'package:mock_studio/ui/home_shell.dart';
import 'package:mock_studio/ui/logs/logs_view.dart';
import 'package:mock_studio/ui/phone_shell.dart';
import 'package:mock_studio/ui/settings/project_settings_view.dart';
import 'package:mock_studio/ui/share/share_view.dart';
import 'package:mock_studio/ui/sidebar/endpoints_list.dart';
import 'package:mock_studio/ui/sidebar/project_switcher.dart';
import 'package:mock_studio/ui/sidebar/server_control_card.dart';

import 'support/app_harness.dart';

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('phones get the bottom navigation, not the rail', (tester) async {
    await pumpApp(tester);
    expect(find.byType(PhoneShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byType(EndpointsList), findsOneWidget);
    expect(find.text('My First Mock API'), findsOneWidget);

    for (final (label, view) in [
      ('Live', LogsView),
      ('Flows', FlowsView),
      ('Share', ShareView),
      ('Project', ProjectSettingsView),
      ('Endpoints', EndpointsList),
    ]) {
      await tester.tap(_navLabel(label));
      await tester.pumpAndSettle();
      expect(find.byType(view), findsOneWidget, reason: label);
    }
  });

  testWidgets('tapping an endpoint opens the editor; back returns', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get user by id'));
    await tester.pumpAndSettle();
    expect(find.byType(EndpointEditor), findsOneWidget);
    // Full screen: the list and the bottom bar are behind the page.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(EndpointsList), findsNothing);
    expect(find.widgetWithText(AppBar, 'Get user by id'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(EndpointEditor), findsNothing);
    expect(find.byType(EndpointsList), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the Android back button leaves the editor, not the app', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Create user'));
    await tester.pumpAndSettle();
    expect(find.byType(EndpointEditor), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.byType(EndpointEditor), findsNothing);
    expect(find.byType(EndpointsList), findsOneWidget);

    // The editor opens again afterwards (its page was really removed).
    await tester.tap(find.text('Create user'));
    await tester.pumpAndSettle();
    expect(find.byType(EndpointEditor), findsOneWidget);
  });

  testWidgets('creating an endpoint opens it in the editor', (tester) async {
    final app = await pumpApp(tester);
    final before = app.selectedProject!.endpoints.length;
    await tester.tap(find.byTooltip('New endpoint'));
    await tester.pumpAndSettle();
    // Saving the project is real file I/O, so tap outside fake time.
    await tester.runAsync(() async {
      await tester.tap(find.text('Blank endpoint'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(app.selectedProject!.endpoints.length, before + 1);
    expect(find.byType(EndpointEditor), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'New endpoint'), findsOneWidget);
  });

  testWidgets('the title opens the drawer with project and server', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Switch project and control the server'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(ProjectSwitcher),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(ServerControlCard),
      ),
      findsOneWidget,
    );
    expect(find.text('Start server'), findsOneWidget);
  });

  testWidgets('the overflow menu has import, guide, theme and settings', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tester.tap(find.byTooltip('Import, guide, theme and settings'));
    await tester.pumpAndSettle();
    for (final item in [
      'From Postman collection',
      'From OpenAPI / Swagger',
      'Mock Studio project file',
      'Guide mode',
      'Dark mode',
      'Settings',
    ]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.byTooltip('Import, guide, theme and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('request details open as a page and back returns to the list', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await sendRequests(tester, app, ['/health', '/users/7', '/nope']);
    await tester.tap(_navLabel('Live'));
    await tester.pumpAndSettle();
    // The bottom bar badge counts the requests.
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(find.text('/users/7'));
    await tester.pumpAndSettle();
    expect(find.text('REQUEST HEADERS'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('REQUEST HEADERS'), findsNothing);
    expect(find.byType(LogsView), findsOneWidget);
    await stopServers(tester, app);
  });

  testWidgets('the section survives resizing between phone and desktop', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(_navLabel('Flows'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneShell), findsNothing);
    expect(find.byType(FlowsView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneShell), findsOneWidget);
    expect(find.byType(FlowsView), findsOneWidget);
  });

  testWidgets('no projects: a start screen instead of the navigation', (
    tester,
  ) async {
    // Already seeded once and nothing on disk: no sample project.
    await pumpApp(tester, prefs: {'seeded': true});
    expect(find.byType(NoProjectsView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Create a project'), findsOneWidget);
  });
}
