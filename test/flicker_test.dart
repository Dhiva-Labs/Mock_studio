// Guards against the flicker and jank sources found in the layout review:
// whole-view rebuilds on every logged request, one-frame colour lag on
// theme switches, a "Checking…" flash on the Share tab, rows jumping in the
// Live list, and the editor rebuilding while the side panel is resized.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_studio/models/enums.dart';
import 'package:mock_studio/theme/app_theme.dart';
import 'package:mock_studio/ui/editor/endpoint_editor.dart';
import 'package:mock_studio/ui/editor/response_card.dart';
import 'package:mock_studio/ui/editor/test_bar.dart';
import 'package:mock_studio/ui/home_shell.dart';
import 'package:mock_studio/ui/logs/logs_view.dart';
import 'package:mock_studio/ui/sidebar/project_switcher.dart';
import 'package:mock_studio/ui/widgets/badges.dart';

import 'support/app_harness.dart';

const _desktop = Size(1280, 800);

/// Counts rebuilds of widgets of the given types while [body] runs.
Future<Map<Type, int>> _countRebuilds(
  Set<Type> types,
  Future<void> Function() body,
) async {
  final counts = {for (final t in types) t: 0};
  debugOnRebuildDirtyWidget = (element, _) {
    final t = element.widget.runtimeType;
    if (counts.containsKey(t)) counts[t] = counts[t]! + 1;
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

void main() {
  for (final (name, size) in [
    ('desktop', _desktop),
    ('phone', const Size(390, 844)),
  ]) {
    testWidgets('logged requests do not rebuild the editor ($name)', (
      tester,
    ) async {
      final app = await pumpApp(tester, size: size);
      await sendRequests(tester, app, ['/health']); // starts the server
      await tester.tap(find.text('Get user by id'));
      await tester.pumpAndSettle();
      expect(find.byType(EndpointEditor), findsOneWidget);

      final counts = await _countRebuilds(
        {EndpointEditor, ResponseCard, TestBar, LiveRequestsBadge},
        () => sendRequests(tester, app, [
          for (var i = 0; i < 12; i++) '/users/$i',
        ]),
      );
      expect(app.logsFor(app.selectedProject!.id), hasLength(13));
      expect(counts[EndpointEditor], 0);
      expect(counts[ResponseCard], 0);
      expect(counts[TestBar], 0);
      // Only the request counter follows the traffic.
      if (name == 'desktop') expect(counts[LiveRequestsBadge], greaterThan(0));
      await stopServers(tester, app);
    });
  }

  testWidgets('a theme switch recolours everything in one frame, keeping '
      'state', (tester) async {
    final app = await pumpApp(tester, size: _desktop);
    await tester.scrollUntilVisible(
      find.text('Advanced settings'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(EndpointEditor),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    await tester.tap(find.text('Advanced settings'));
    await tester.pumpAndSettle();
    expect(find.text('LATENCY SIMULATION'), findsOneWidget);

    await tester.runAsync(() => app.setThemeMode(ThemeMode.dark));
    await tester.pump(); // a single frame

    expect(AppTheme.isDark, isTrue);
    final ctx = tester.element(find.byType(EndpointEditor));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    // Method colours (which follow AppTheme.isDark, not the inherited theme)
    // already use the dark tones in that same frame, everywhere.
    final badges = tester.widgetList<MethodBadge>(find.byType(MethodBadge));
    expect(badges, isNotEmpty);
    for (final badge in badges) {
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byWidget(badge),
              matching: find.text(badge.method.label),
            )
            .first,
      );
      expect(text.style!.color, AppTheme.methodColor(badge.method));
    }
    expect(
      AppTheme.methodColor(HttpMethodType.get),
      const Color(0xFF4CC38A),
      reason: 'the dark tone of GET',
    );
    // Nothing was rebuilt from scratch: the open section is still open.
    expect(find.text('LATENCY SIMULATION'), findsOneWidget);
  });

  testWidgets('the Share tab does not flash "Checking…" on rebuilds', (
    tester,
  ) async {
    final app = await pumpApp(tester, size: _desktop);
    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    // Let the one `which cloudflared` lookup finish: real process I/O,
    // alternating with frames so its callbacks get to run.
    for (
      var i = 0;
      i < 20 && find.text('Checking…').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('Checking…'), findsNothing);

    // A theme switch rebuilds every widget; the answer must be reused.
    await tester.runAsync(() => app.setThemeMode(ThemeMode.dark));
    await tester.pump();
    expect(find.text('Checking…'), findsNothing);
    // Starting the server (the stopped-server hint disappears) neither.
    await sendRequests(tester, app, ['/health']);
    expect(find.text('Checking…'), findsNothing);
    await stopServers(tester, app);
  });

  testWidgets('new requests do not move the rows you are reading', (
    tester,
  ) async {
    final app = await pumpApp(tester, size: _desktop);
    await sendRequests(tester, app, [for (var i = 1; i <= 30; i++) '/r/$i']);
    await tester.tap(find.text('Live').first);
    await tester.pumpAndSettle();

    // The request list (the filter field has a Scrollable of its own).
    final list = find
        .descendant(
          of: find.descendant(
            of: find.byType(LogsView),
            matching: find.byType(ListView),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(200);
    await tester.pump();
    final reading = find.text('/r/22');
    final before = tester.getTopLeft(reading).dy;
    Element row() => tester.element(
      find.ancestor(of: reading, matching: find.byType(InkWell)).first,
    );
    final rowBefore = row();

    await sendRequests(tester, app, ['/r/31', '/r/32', '/r/33']);
    expect(tester.getTopLeft(reading).dy, moreOrLessEquals(before));
    // The row is the same widget instance, so a hover card or ink on it
    // stays with its request instead of jumping to another one.
    expect(identical(row(), rowBefore), isTrue);
    expect(position.pixels, greaterThan(200));

    // At the top the list stays live: the newest request shows first.
    position.jumpTo(0);
    await tester.pump();
    await sendRequests(tester, app, ['/r/34']);
    expect(position.pixels, 0);
    expect(find.text('/r/34'), findsOneWidget);
    await stopServers(tester, app);
  });

  testWidgets('resizing the side panel does not rebuild the editor', (
    tester,
  ) async {
    await pumpApp(tester, size: _desktop);
    expect(find.byType(EndpointEditor), findsOneWidget);
    final handle = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    final widthBefore = tester.getSize(find.byType(ProjectSwitcher)).width;
    final counts = await _countRebuilds({EndpointEditor, HomeShell}, () async {
      await tester.drag(handle, const Offset(80, 0));
      await tester.pump();
    });
    expect(
      tester.getSize(find.byType(ProjectSwitcher)).width,
      greaterThan(widthBefore + 40),
    );
    expect(counts[EndpointEditor], 0);
    expect(counts[HomeShell], 0);
  });
}
