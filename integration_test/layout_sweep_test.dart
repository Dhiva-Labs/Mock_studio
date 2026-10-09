// Visits every screen of the real app at phone, tablet and desktop sizes in
// each theme, on the Linux embedder with real fonts, and fails with a
// readable list of every layout problem it finds:
//
//  * any FlutterError (RenderFlex overflows, layout or build exceptions),
//  * controls that are pushed off screen or covered by another widget,
//  * touch targets smaller than 44 px on phone sizes.
//
//   flutter test integration_test/layout_sweep_test.dart -d linux
//
// Storage and preferences point at a temporary directory, so your own
// projects are never touched.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mock_studio/app.dart';
import 'package:mock_studio/models/endpoint.dart';
import 'package:mock_studio/models/enums.dart';
import 'package:mock_studio/models/load_flow.dart';
import 'package:mock_studio/models/mock_project.dart';
import 'package:mock_studio/models/mock_response.dart';
import 'package:mock_studio/services/flow_runner.dart';
import 'package:mock_studio/services/mock_server.dart';
import 'package:mock_studio/state/app_state.dart';
import 'package:mock_studio/theme/app_theme.dart';
import 'package:mock_studio/ui/editor/endpoint_editor.dart';
import 'package:mock_studio/ui/editor/response_card.dart';
import 'package:mock_studio/ui/home_shell.dart';
import 'package:mock_studio/ui/logs/logs_view.dart';
import 'package:mock_studio/ui/sidebar/project_switcher.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [
  Size(320, 640),
  Size(360, 780),
  Size(412, 915),
  Size(768, 1024),
  Size(900, 700),
  Size(1280, 800),
  Size(1440, 900),
];

enum _Look { tealLight, tealDark, graphite }

/// Teal light and dark everywhere; Graphite on one phone and one desktop.
List<_Look> _looksFor(Size s) => [
  _Look.tealLight,
  _Look.tealDark,
  if (s == const Size(360, 780) || s == const Size(1440, 900)) _Look.graphite,
];

const _bigName =
    'Payments & Subscriptions Platform API — staging mirror (EU region)';
const _refundName =
    'Create a refund for a partially captured payment intent (idempotent)';
const _flowName =
    'Checkout journey with refunds for many concurrent European merchants';

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

MockProject _bigProject(int port) => MockProject(
  name: _bigName,
  description: 'Long names, deep folders and every kind of response.',
  port: port,
  proxyBaseUrl:
      'https://api.payments-staging.example-company-internal.com/v2/eu-west',
  recordProxy: true,
  globalDelayMs: 120,
  globalHeaders: {
    'X-Environment-Name-For-Debugging': 'staging-eu-west-1-mirror-cluster',
    'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
  },
  endpoints: [
    Endpoint(
      name: _refundName,
      method: HttpMethodType.post,
      path:
          '/api/v2/payment-intents/:paymentIntentId/refunds/:refundId/line-items',
      folder: 'Billing/Payments/Refunds and disputes for European merchants',
      strategy: ResponseStrategy.rules,
      defaultDelayMs: 250,
      jitterMs: 100,
      requireAuth: true,
      authHeader: 'X-Merchant-Authorization-Token',
      description:
          'Refunds part of a captured payment. Several responses depending on '
          'the amount, currency, idempotency key and simulated failures.',
      responses: [
        MockResponse(
          label: 'Refund accepted for processing by the settlement provider',
          statusCode: 201,
          headers: {
            'X-Request-Id': '{{uuid}}',
            'Location': '/api/v2/refunds/{{uuid}}/status-and-settlement',
            'X-RateLimit-Remaining-For-This-Merchant-Account': '99',
          },
          conditions: [
            RuleCondition(
              source: ConditionSource.bodyJson,
              key: 'refund.amount.currency.isoCode',
              value: 'EUR',
            ),
            RuleCondition(
              source: ConditionSource.header,
              key: 'X-Idempotency-Key',
              operator: ConditionOperator.exists,
            ),
            RuleCondition(
              key: 'dryRun',
              operator: ConditionOperator.notEquals,
              value: 'true',
            ),
            RuleCondition(
              source: ConditionSource.pathParam,
              key: 'paymentIntentId',
              operator: ConditionOperator.regex,
              value: r'^pi_[A-Za-z0-9]{24}$',
            ),
            RuleCondition(source: ConditionSource.method, value: 'POST'),
          ],
          body:
              '{\n  "id": "{{uuid}}",\n  "paymentIntent": "{{params.paymentIntentId}}",\n'
              '  "status": "pending_settlement_with_acquiring_bank_partner",\n'
              '  "amount": {"value": 1999, "currency": "EUR"},\n'
              '  "createdAt": "{{now}}"\n}',
        ),
        MockResponse(
          label: 'Validation failed: amount exceeds captured total',
          statusCode: 422,
          delayMs: 1500,
          fault: FaultType.malformedBody,
          conditions: [
            RuleCondition(
              source: ConditionSource.bodyJson,
              key: 'refund.amount.value',
              operator: ConditionOperator.greaterThan,
              value: '1000000',
            ),
          ],
          headers: {'Retry-After': '120'},
          body: '{"error": "amount_too_large"}',
        ),
        MockResponse(
          label: 'Upstream settlement provider timed out',
          statusCode: 504,
          fault: FaultType.hang,
          conditions: [
            RuleCondition(
              source: ConditionSource.header,
              key: 'X-Simulate-Failure-Mode',
              operator: ConditionOperator.contains,
              value: 'timeout',
            ),
          ],
        ),
        MockResponse(
          label: 'Fallback',
          statusCode: 400,
          bodyType: BodyType.text,
          body: 'Bad request',
        ),
      ],
    ),
    Endpoint(
      name: 'List archived invoices for an organisation',
      method: HttpMethodType.get,
      path: '/api/v2/organisations/:orgId/billing/invoices',
      folder: 'Billing/Invoices/Archived 2024 statements and credit notes',
      strategy: ResponseStrategy.sequence,
      responses: [
        MockResponse(label: 'First page', body: '{"page": 1}'),
        MockResponse(label: 'Rate limited', statusCode: 429),
        MockResponse(label: 'Server error', statusCode: 503),
      ],
    ),
    Endpoint(
      name: 'Flaky webhook receiver',
      method: HttpMethodType.patch,
      path: '/webhooks/:provider/events',
      folder: 'Webhooks',
      strategy: ResponseStrategy.random,
      responses: [
        MockResponse(label: 'Delivered', weight: 9),
        MockResponse(
          label: 'Dropped',
          statusCode: 500,
          weight: 1,
          fault: FaultType.connectionReset,
        ),
      ],
    ),
    Endpoint(
      name: 'Delete customer',
      method: HttpMethodType.delete,
      path: '/api/v2/customers/:customerId',
      folder: 'Customers',
      responses: [MockResponse(statusCode: 204, bodyType: BodyType.none)],
    ),
    Endpoint(
      name: 'CORS preflight for every path',
      method: HttpMethodType.options,
      path: '/**',
    ),
    Endpoint(
      name: 'Any method on files',
      method: HttpMethodType.any,
      path: '/files/*',
      enabled: false,
    ),
    for (var i = 1; i <= 8; i++)
      Endpoint(
        name: 'Product variant $i with a fairly long descriptive name',
        path: '/api/v2/catalogue/products/:productId/variants/$i',
        folder: 'Catalogue/Products/Variants',
      ),
  ],
  flows: [
    LoadFlow(
      name: _flowName,
      virtualUsers: 250,
      iterations: 40,
      rampUpSec: 10,
      thinkTimeMs: 500,
      steps: [
        FlowStep(
          name: 'Log in as a merchant with a long descriptive step name',
          method: 'POST',
          path: '/login',
          body: '{"email": "{{faker.email}}", "password": "secret"}',
          extract: {'token': 'body.token'},
          expectStatus: '200,201',
        ),
        FlowStep(
          method: 'OPTIONS',
          path:
              '/api/v2/payment-intents/{{vars.intent}}/refunds/{{vu}}/line-items',
          headers: {'Authorization': 'Bearer {{vars.token}}'},
        ),
        FlowStep(
          method: 'DELETE',
          path: '/api/v2/customers/{{vu}}',
          expectStatus: '204',
        ),
        FlowStep(path: '/health', enabled: false),
      ],
    ),
    LoadFlow(
      name: 'Parallel burst',
      mode: StepMode.parallel,
      steps: [FlowStep(path: '/health')],
    ),
  ],
);

RunSnapshot _snapshot() => RunSnapshot(
  elapsedMs: 125000,
  totalRequests: 1482100,
  ok: 1480000,
  failed: 2100,
  iterationsDone: 370525,
  activeUsers: 250,
  plannedRequests: 0,
  durationMs: 0,
  done: true,
  stopped: true,
  fatalError: null,
  p50Ms: 3,
  p95Ms: 1880,
  p99Ms: 12041,
  meanMs: 45.2,
  steps: const [
    StepSummary(
      name: 'Log in as a merchant with a long descriptive step name',
      method: 'POST',
      path: '/login',
      count: 370525,
      ok: 368425,
      failed: 2100,
      meanMs: 6.1,
      minMs: 1,
      p50Ms: 4,
      p95Ms: 20,
      p99Ms: 44,
      maxMs: 120000,
      statusCounts: {200: 368425, 401: 2100},
      topErrors: {
        'Unexpected status 401 from https://api.example.com/login': 2100,
      },
    ),
    StepSummary(
      name: 'OPTIONS /api/v2/payment-intents/{{vars.intent}}/refunds',
      method: 'OPTIONS',
      path: '/api/v2/payment-intents',
      count: 370525,
      ok: 370525,
      failed: 0,
      meanMs: 2.5,
      minMs: 1,
      p50Ms: 2,
      p95Ms: 5,
      p99Ms: 9,
      maxMs: 31,
      statusCounts: {204: 370525},
      topErrors: {},
    ),
    StepSummary(
      name: 'DELETE /api/v2/customers/{{vu}}',
      method: 'DELETE',
      path: '/api/v2/customers',
      count: 370525,
      ok: 370525,
      failed: 0,
      meanMs: 3.5,
      minMs: 1,
      p50Ms: 3,
      p95Ms: 8,
      p99Ms: 15,
      maxMs: 60,
      statusCounts: {204: 370525},
      topErrors: {},
    ),
  ],
  perSecond: List.generate(120, (i) => 9000 + (i * 37) % 4000),
  errorsPerSecond: List.generate(120, (i) => i % 7 == 0 ? 120 : 0),
);

final _postman = {
  'info': {
    'name': 'Shop API with a long collection name for small screens',
    'schema':
        'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  },
  'item': [
    {
      'name': 'Orders',
      'item': [
        {
          'name': 'Get order',
          'request': {'method': 'GET', 'url': '{{baseUrl}}/orders/{{orderId}}'},
          'response': [
            {'name': 'Found', 'code': 200, 'body': '{"id": 42}'},
            {'name': 'Not found', 'code': 404, 'body': '{}'},
          ],
        },
      ],
    },
    {
      'name': 'Login',
      'request': {'method': 'POST', 'url': '{{baseUrl}}/auth/login'},
    },
  ],
};

/// Widget names reported as the place where a problem sits.
const _appWidgets = {
  'EndpointEditor',
  'ResponseCard',
  'ConditionsEditor',
  '_ConditionRow',
  'HeadersEditor',
  'BodyEditor',
  '_PreviewRow',
  'TestBar',
  '_ResultPanel',
  'LogsView',
  '_LogRow',
  '_LogDetail',
  'FlowsView',
  '_FlowList',
  '_FlowEditor',
  '_LoadProfile',
  '_StepCard',
  'FlowResults',
  '_StepTable',
  '_ThroughputChart',
  'ShareView',
  '_LanSection',
  '_TunnelSection',
  'ProjectSettingsView',
  '_RecordingsPanel',
  '_GlobalHeadersEditor',
  'EndpointsList',
  '_FolderRow',
  '_EndpointTile',
  'ServerControlCard',
  'ProjectSwitcher',
  'PhoneShell',
  'HomeShell',
  '_Header',
  'ServerPill',
  '_NavRail',
  'AlertDialog',
  'Dialog',
  'Drawer',
  'AppBar',
  'NavigationBar',
  'NoProjectsView',
  '_PostmanDialog',
  '_StrategySelector',
  '_MethodDropdown',
};

class _Sweep {
  _Sweep(this.tester, this.app);

  final WidgetTester tester;
  final AppState app;

  /// Problem → where it was seen.
  final problems = <String, List<String>>{};
  final screens = <String>{};
  String where = 'startup';
  Size size = Size.zero;
  String look = '';
  int checks = 0;

  bool get phone => size.width < 600;

  /// Light theme: every interaction (strategies, body types, keyboard,
  /// menus, dialogs). Dark and Graphite: every screen once, which is what
  /// can differ between themes, to keep the sweep to a few minutes.
  bool deep = true;

  void report(String problem) =>
      problems.putIfAbsent(problem, () => []).add(where);

  void onError(FlutterErrorDetails d) {
    var text = d.exceptionAsString().trim().split('\n').first;
    final full = d.toString();
    final loc = RegExp(
      r'(lib/[\w/]+\.dart):(\d+)',
    ).allMatches(full).map((m) => '${m.group(1)}:${m.group(2)}').toSet();
    if (loc.isNotEmpty) text = '$text  [${loc.take(3).join(', ')}]';
    report(text);
  }

  // ---- pumping ------------------------------------------------------------

  final settleTime = Stopwatch();
  final geometryTime = Stopwatch();
  int settleTimeouts = 0;

  Future<void> settle() async {
    settleTime.start();
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 8),
      );
    } on FlutterError {
      // Something keeps animating (a spinner); a few frames are enough.
      settleTimeouts++;
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      settleTime.stop();
    }
  }

  Future<void> wait(int ms) =>
      tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

  /// Labels everything reported from now on, then runs [action].
  Future<void> step(String screen, [Future<void> Function()? action]) async {
    where = '${size.width.toInt()}x${size.height.toInt()} $look › $screen';
    if (action != null) await action();
    await settle();
  }

  /// Scrolls the lists of the current screen until [f] is built (lists
  /// only build what's near the viewport).
  Future<void> reveal(Finder f) async {
    if (f.evaluate().isNotEmpty) return;
    for (final st in _scrollables()) {
      if (!st.mounted) continue;
      final pos = st.position;
      pos.jumpTo(pos.minScrollExtent);
      await tester.pump();
      while (st.mounted &&
          f.evaluate().isEmpty &&
          pos.pixels < pos.maxScrollExtent) {
        pos.jumpTo(
          (pos.pixels + pos.viewportDimension * 0.7).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      if (f.evaluate().isNotEmpty) return;
    }
  }

  Future<void> tap(Finder f) async {
    await reveal(f);
    if (f.evaluate().isEmpty) {
      final texts = [
        for (final e in find.byType(Text).evaluate())
          if (_current(e, _focus())) (e.widget as Text).data,
      ].whereType<String>().take(60);
      final all = [
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
      ].whereType<String>().take(40);
      fail(
        'Not found at $where: $f\nOn screen: ${texts.join(' | ')}'
        '\nIn tree: ${all.join(' | ')}'
        '\nDrawers: ${find.byType(Drawer).evaluate().length}',
      );
    }
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first, warnIfMissed: false);
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text));

  Future<void> tapTooltip(String tooltip) => tap(find.byTooltip(tooltip));

  /// Pops the top route of the navigator that shows [inside].
  Future<void> dismiss(Finder inside) async {
    final ctx = tester.element(inside.last);
    Navigator.of(ctx).pop();
    await settle();
  }

  /// Snack bars float over the content for a few seconds; they would
  /// count as covering it.
  Future<void> clearSnackBars() async {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    for (final e in find.byType(ScaffoldMessenger).evaluate()) {
      final state = (e as StatefulElement).state;
      if (state is ScaffoldMessengerState) state.clearSnackBars();
    }
    await settle();
  }

  // ---- checks -------------------------------------------------------------

  /// Checks the current screen, then scrolls each vertical list through so
  /// lazily built parts get laid out and checked too.
  Future<void> check(String screen, {bool scroll = true}) async {
    await step(screen);
    screens.add(screen);
    await clearSnackBars();
    _geometry();
    if (!scroll) return;
    for (final state in _scrollables()) {
      // Scrolling an outer list can unbuild a list nested in it.
      if (!state.mounted) continue;
      final pos = state.position;
      if (pos.maxScrollExtent <= 0) continue;
      final start = pos.pixels;
      var p = 0.0;
      while (state.mounted && p < pos.maxScrollExtent) {
        p = (p + pos.viewportDimension * 0.8).clamp(0, pos.maxScrollExtent);
        pos.jumpTo(p);
        await tester.pump();
        _geometry();
      }
      if (!state.mounted) continue;
      pos.jumpTo(start);
      await tester.pump();
    }
  }

  /// Vertical scrollables of the current route, outermost first.
  List<ScrollableState> _scrollables() {
    final focus = _focus();
    return [
      for (final e in find.byType(Scrollable).evaluate())
        if (_current(e, focus) &&
            (e as StatefulElement).state is ScrollableState &&
            (e.state as ScrollableState).position.axis == Axis.vertical &&
            (e.state as ScrollableState).position.hasContentDimensions)
          e.state as ScrollableState,
    ];
  }

  /// An open drawer or floating side panel, when it is on the top route:
  /// everything else is behind it on purpose. Looked up once per pass.
  Element? _focus() {
    for (final f in [
      find.byType(Drawer),
      find.byKey(const ValueKey('floating-panel')),
    ]) {
      final found = f.evaluate();
      if (found.isNotEmpty && _onTopRoute(found.first)) return found.first;
    }
    return null;
  }

  static bool _onTopRoute(Element e) {
    // The element's route and every route around its navigator (dialogs go
    // to the root navigator, above the phone shell's nested one).
    for (var route = ModalRoute.of(e); route != null;) {
      if (!route.isCurrent) return false;
      final nav = route.navigator;
      route = nav == null ? null : ModalRoute.of(nav.context);
    }
    return true;
  }

  static bool _current(Element e, Element? focus) {
    if (!_onTopRoute(e)) return false;
    if (focus == null || identical(e, focus)) return true;
    var inside = false;
    e.visitAncestorElements((a) {
      inside = identical(a, focus);
      return !inside;
    });
    return inside;
  }

  static bool _control(Widget w) =>
      w is ButtonStyleButton ||
      w is Checkbox ||
      w is Switch ||
      w is DropdownButton ||
      w is PopupMenuButton ||
      w is TextField ||
      (w is RawChip && (w.onPressed != null || w.onSelected != null)) ||
      (w is InkResponse && (w.onTap != null || w.onLongPress != null));

  static bool _touchSized(Element e) {
    final w = e.widget;
    if (w is TextField) return false;
    if (w is Switch || w is Checkbox) {
      // In a SwitchListTile / CheckboxListTile the whole tile is the target.
      var inTile = false;
      e.visitAncestorElements((a) {
        inTile = a.widget is ListTile;
        return !inTile;
      });
      if (inTile) return false;
    }
    if (w is InkResponse) {
      // A button's own ink area sits inside its padded tap target.
      var inControl = false;
      e.visitAncestorElements((a) {
        final aw = a.widget;
        if (aw is ButtonStyleButton ||
            aw is Checkbox ||
            aw is Switch ||
            aw is RawChip ||
            aw is DropdownButton ||
            aw is PopupMenuButton ||
            aw is NavigationBar) {
          inControl = true;
          return false;
        }
        return true;
      });
      if (inControl) return false;
    }
    return true;
  }

  Rect _rect(RenderBox b) =>
      MatrixUtils.transformRect(b.getTransformTo(null), Offset.zero & b.size);

  void _geometry() {
    geometryTime.start();
    try {
      _geometryPass();
    } finally {
      geometryTime.stop();
    }
  }

  void _geometryPass() {
    checks++;
    final screen = Offset.zero & size;
    final scrim = find.byKey(const ValueKey('panel-scrim')).evaluate();
    final scrimBox = scrim.isEmpty ? null : scrim.first.renderObject;
    final viewId = tester.view.viewId;
    final focus = _focus();
    for (final e in find.byWidgetPredicate(_control).evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty || !_current(e, focus)) continue;
      final rect = _rect(box);
      var visible = screen;
      var scrolled = false;
      for (RenderObject? p = box.parent; p != null; p = p.parent) {
        if (p is RenderAbstractViewport && p is RenderBox) {
          visible = visible.intersect(_rect(p as RenderBox));
          scrolled = true;
        }
      }
      const eps = 0.5;
      final inside =
          rect.left >= visible.left - eps &&
          rect.top >= visible.top - eps &&
          rect.right <= visible.right + eps &&
          rect.bottom <= visible.bottom + eps;
      if (!inside) {
        // Partly scrolled out of a list is fine; cut off by the window isn't.
        if (!scrolled) report('off screen: ${_describe(e, rect)}');
        continue;
      }
      for (final p in [
        rect.center,
        Offset(rect.left + rect.width * 0.2, rect.center.dy),
        Offset(rect.left + rect.width * 0.8, rect.center.dy),
      ]) {
        final result = HitTestResult();
        tester.binding.hitTestInView(result, p, viewId);
        bool within(Object t) {
          for (
            RenderObject? r = t is RenderObject ? t : null;
            r != null;
            r = r.parent
          ) {
            if (identical(r, box)) return true;
          }
          return false;
        }

        if (result.path.any((h) => within(h.target))) continue;
        if (scrimBox != null &&
            result.path.any((h) => identical(h.target, scrimBox))) {
          break; // the floating side panel's scrim covers it on purpose
        }
        final top = result.path.isEmpty ? null : result.path.first.target;
        report(
          'covered: ${_describe(e, rect)} by '
          '${top is RenderObject ? _creator(top) : top}',
        );
        break;
      }
      if (phone &&
          _touchSized(e) &&
          (rect.width < 44 - eps || rect.height < 44 - eps)) {
        report(
          'touch target ${rect.width.toStringAsFixed(0)}x'
          '${rect.height.toStringAsFixed(0)} < 44: ${_describe(e, rect, withRect: false)}',
        );
      }
    }
  }

  String _creator(RenderObject r) {
    final c = r.debugCreator;
    if (c is DebugCreator) return _describe(c.element, null, withRect: false);
    return r.runtimeType.toString();
  }

  String _describe(Element e, Rect? rect, {bool withRect = true}) {
    String? label;
    void visit(Element c) {
      if (label != null) return;
      final w = c.widget;
      if (w is Text && (w.data ?? '').trim().isNotEmpty) {
        label = '"${w.data}"';
      } else if (w is Tooltip && (w.message ?? '').isNotEmpty) {
        label = 'tooltip "${w.message}"';
      } else if (w is Icon && w.icon != null) {
        label = 'icon 0x${w.icon!.codePoint.toRadixString(16)}';
      }
      if (label == null) c.visitChildren(visit);
    }

    final w = e.widget;
    if (w is IconButton && w.tooltip != null) label = 'tooltip "${w.tooltip}"';
    if (w is PopupMenuButton && (w.tooltip ?? '').isNotEmpty) {
      label = 'tooltip "${w.tooltip}"';
    }
    if (label == null) visit(e);
    var owner = '';
    e.visitAncestorElements((a) {
      final name = a.widget.runtimeType.toString().split('<').first;
      if (_appWidgets.contains(name)) {
        owner = ' in $name';
        return false;
      }
      return true;
    });
    final l = label == null
        ? ''
        : ' ${label!.length > 60 ? '${label!.substring(0, 60)}…' : label}';
    final r = withRect && rect != null
        ? ' @(${rect.left.toInt()},${rect.top.toInt()} '
              '${rect.width.toInt()}x${rect.height.toInt()})'
        : '';
    return '${w.runtimeType.toString().split('<').first}$l$owner$r';
  }

  // ---- navigation ---------------------------------------------------------

  /// Goes to [tab] without toggling the desktop side panel.
  Future<void> goTab(MainTab tab) async {
    if (phone) {
      await tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab.railLabel),
        ),
      );
      return;
    }
    if (_desktopTab == tab) return;
    await tap(find.text(tab.railLabel).first);
    _desktopTab = tab;
  }

  MainTab _desktopTab = MainTab.editor;

  /// The side panel holds the project switcher.
  bool get panelShown => find.byType(ProjectSwitcher).evaluate().isNotEmpty;

  /// Desktop: shows or hides the side panel by re-clicking the active item.
  Future<void> setPanel(bool open) async {
    if (panelShown == open) return;
    await tap(find.text(_desktopTab.railLabel).first);
  }

  Future<void> back() async {
    await tap(find.byTooltip('Back'));
  }

  Future<void> keyboard(bool on) async {
    if (on) {
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.42);
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
    }
    await settle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'layout sweep: no overflow, overlap or tiny targets',
    timeout: const Timeout(Duration(minutes: 15)),
    (tester) async {
      late Directory tmp;
      late int port;
      await tester.runAsync(() async {
        tmp = await Directory.systemTemp.createTemp('ms_sweep_');
        final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        port = probe.port;
        await probe.close();
      });
      PathProviderPlatform.instance = _TempPaths(tmp.path);
      SharedPreferences.setMockInitialValues({'themeMode': 1});

      final app = AppState();
      final sweep = _Sweep(tester, app);
      final previousOnError = FlutterError.onError;
      FlutterError.onError = sweep.onError;
      // Frames run in real time: play animations (ink, page and dialog
      // transitions) twenty times faster so the sweep takes minutes.
      timeDilation = 0.05;
      try {
        await tester.runAsync(() => app.init());
        final sample = app.projects.single;
        final big = _bigProject(port);
        await tester.runAsync(() => app.addProject(big));
        app.flowSession(big.flows.first.id).snapshot = _snapshot();
        for (var i = 0; i < 4; i++) {
          app.pendingRecordings.add(
            RecordedCall(
              i.isEven ? 'GET' : 'DELETE',
              '/api/v2/organisations/acme-corporation-international/members/$i',
              i.isEven ? 200 : 404,
              '{"id": $i}',
              const {'content-type': 'application/json'},
            ),
          );
        }

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = _sizes.first;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: app,
            child: const MockStudioApp(),
          ),
        );
        await sweep.settle();

        // Live traffic for the big project.
        await tester.runAsync(() async {
          final err = await app.startServer(big);
          expect(err, isNull);
          final client = HttpClient();
          final paths = [
            ('GET', '/health'),
            (
              'GET',
              '/api/v2/organisations/acme-corporation-international/billing/invoices?expand=customer,subscription&limit=100',
            ),
            ('POST', '/api/v2/payment-intents/pi_123/refunds/re_1/line-items'),
            ('PATCH', '/webhooks/stripe/events'),
            ('DELETE', '/api/v2/customers/cus_9'),
            ('OPTIONS', '/anything/at/all'),
            ('GET', '/definitely/not/a/mocked/path/that/is/quite/long/indeed'),
            ('GET', '/api/v2/catalogue/products/7/variants/3'),
          ];
          for (var round = 0; round < 3; round++) {
            for (final (method, path) in paths) {
              final req = await client.openUrl(
                method,
                Uri.parse('http://127.0.0.1:$port$path'),
              );
              if (method == 'POST') {
                req.headers.contentType = ContentType.json;
                req.write('{"refund": {"amount": {"value": 5}}}');
              }
              try {
                await (await req.close()).drain<void>();
              } catch (_) {} // dropped connections are part of the mix
            }
          }
          client.close(force: true);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await sweep.settle();

        for (final size in _sizes) {
          for (final look in _looksFor(size)) {
            final clock = Stopwatch()..start();
            await _configure(sweep, size, look);
            sweep.deep = look == _Look.tealLight;
            app.selectProject(big.id);
            await sweep.settle();
            await _sweepProject(sweep, full: true);
            if (sweep.deep) {
              // The sample project: stopped server, no flows, no requests.
              app.selectProject(sample.id);
              await sweep.settle();
              await _sweepProject(sweep, full: false);
            }
            // ignore: avoid_print
            print(
              '  ${sweep.where.split(' › ').first}: ${clock.elapsed} '
              '(settle ${sweep.settleTime.elapsed}, '
              '${sweep.settleTimeouts} timeouts, '
              'geometry ${sweep.geometryTime.elapsed})',
            );
          }
        }

        await tester.runAsync(() async {
          await app.stopServer(big);
          await tmp.delete(recursive: true);
        });
      } finally {
        FlutterError.onError = previousOnError;
        timeDilation = 1;
        tester.view.reset();
        // Printed even when a step failed, so a partial sweep still helps.
        final looks = {for (final s in _sizes) ..._looksFor(s)}.length;
        final lines = [
          'Layout sweep: ${_sizes.length} sizes, $looks themes, '
              '${sweep.screens.length} distinct screens, '
              '${sweep.checks} checks, ${sweep.problems.length} problems.',
          for (final MapEntry(key: problem, value: where)
              in sweep.problems.entries)
            '• $problem\n    seen ${where.length}x, e.g. '
                '${where.toSet().take(4).join(' | ')}',
        ];
        // ignore: avoid_print
        print(lines.join('\n'));
      }
      expect(
        sweep.problems.keys.toList(),
        isEmpty,
        reason: 'layout problems are listed above',
      );
    },
  );
}

Future<void> _configure(_Sweep s, Size size, _Look look) async {
  final t = s.tester;
  s.size = size;
  s.look = switch (look) {
    _Look.tealLight => 'teal-light',
    _Look.tealDark => 'teal-dark',
    _Look.graphite => 'graphite',
  };
  await s.step('resize');
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.runAsync(() async {
    await s.app.setThemeId(
      look == _Look.graphite ? AppThemeId.graphite : AppThemeId.teal,
    );
    await s.app.setThemeMode(
      look == _Look.tealDark ? ThemeMode.dark : ThemeMode.light,
    );
  });
  await s.settle();
  final mq = MediaQuery.sizeOf(t.element(find.byType(HomeShell)));
  expect(mq, size, reason: 'the app must really be laid out at $size');
  expect(
    Theme.of(t.element(find.byType(HomeShell))).brightness,
    look == _Look.tealLight ? Brightness.light : Brightness.dark,
  );
}

Future<void> _sweepProject(_Sweep s, {required bool full}) async {
  await (s.phone ? _phone(s, full: full) : _desktop(s, full: full));
}

// ---------------------------------------------------------------------------
// Phone

Future<void> _phone(_Sweep s, {required bool full}) async {
  await s.goTab(MainTab.editor);
  await s.check('endpoints list');
  if (!full) {
    await s.tapText('Login (conditional)');
    await s.check('editor (server stopped)');
    await s.back();
    for (final tab in [MainTab.logs, MainTab.flows, MainTab.share]) {
      await s.goTab(tab);
      await s.check('${tab.railLabel} (sample project)');
    }
    await s.goTab(MainTab.editor);
    return;
  }

  await s.step(
    'drawer',
    () => s.tap(find.byTooltip('Switch project and control the server')),
  );
  await s.check('drawer');
  if (s.deep) await _projectDialogs(s);
  final scaffold = s.tester.state<ScaffoldState>(find.byType(Scaffold).first);
  scaffold.closeDrawer();
  await s.settle();

  await s.step(
    'overflow menu',
    () => s.tapTooltip('Import, guide, theme and settings'),
  );
  await s.check('overflow menu');
  await s.tapText('Settings');
  await _settingsDialog(s);

  await s.tapTooltip('Import, guide, theme and settings');
  await s.tapText('From Postman collection');
  await _postmanDialog(s);

  if (s.deep) await _listDialogs(s);

  for (final name in [_refundName, if (s.deep) 'Delete customer']) {
    await s.step('open $name', () => s.tapText(name));
    expect(find.byType(EndpointEditor), findsOneWidget);
    await _editor(s, name, deep: name == _refundName);
    await s.back();
    expect(find.byType(EndpointEditor), findsNothing);
  }

  if (s.deep) {
    await s.step('new endpoint', () => s.tapTooltip('New endpoint'));
    await s.check('new endpoint dialog');
    await s.tapTooltip('Close');
  }

  await _logs(s);
  await _flows(s);
  await s.goTab(MainTab.share);
  await _share(s);
  await s.goTab(MainTab.settings);
  await s.check('project settings');
  await s.goTab(MainTab.editor);
}

// ---------------------------------------------------------------------------
// Tablet and desktop

Future<void> _desktop(_Sweep s, {required bool full}) async {
  final floating = s.size.width < 900;
  await s.goTab(MainTab.editor);
  await s.setPanel(true);
  await s.check(floating ? 'floating panel' : 'panel + editor');
  if (!full) {
    await s.tapText('Login (conditional)');
    if (floating) await s.setPanel(false);
    await s.check('editor (server stopped)');
    for (final tab in [MainTab.logs, MainTab.flows, MainTab.share]) {
      await s.goTab(tab);
      await s.check('${tab.railLabel} (sample project)');
    }
    await s.goTab(MainTab.editor);
    return;
  }

  if (s.deep) {
    await _projectDialogs(s);
    await _listDialogs(s);
    await s.step('new endpoint', () => s.tapTooltip('New endpoint'));
    await s.check('new endpoint dialog');
    await s.tapTooltip('Close');
  }

  for (final name in [_refundName, if (s.deep) 'Delete customer']) {
    await s.setPanel(true);
    await s.step('select $name', () => s.tapText(name));
    if (floating) await s.setPanel(false);
    await _editor(s, name, deep: name == _refundName);
  }

  await s.tapText('Settings');
  await _settingsDialog(s);
  await s.tapText('Import');
  if (s.deep) await s.check('import menu');
  await s.tapText('From Postman collection');
  await _postmanDialog(s);

  await _logs(s);
  await _flows(s);
  await s.goTab(MainTab.share);
  await _share(s);
  await s.goTab(MainTab.settings);
  await s.check('project settings');

  // The same views with the side panel collapsed.
  if (s.deep) {
    await s.setPanel(false);
    await s.check('project settings, panel hidden');
  }
  await s.goTab(MainTab.editor);
  await s.setPanel(false);
  await s.check('editor, panel hidden');
  await s.goTab(MainTab.flows);
  await s.setPanel(false);
  await s.check('flows, panel hidden');
  if (s.deep) {
    await s.goTab(MainTab.logs);
    await s.setPanel(false);
    await s.check('live, panel hidden');
  }
  await s.goTab(MainTab.editor);
  await s.setPanel(true);
}

// ---------------------------------------------------------------------------
// Shared screens

Future<void> _editor(_Sweep s, String name, {required bool deep}) async {
  await s.check('editor: $name');
  if (!deep) return;
  final collapsed = find.descendant(
    of: find.byType(ResponseCard),
    matching: find.byIcon(Icons.expand_more),
  );
  if (!s.deep) {
    // Every response and the advanced settings open, once.
    while (collapsed.evaluate().isNotEmpty) {
      await s.tap(collapsed);
    }
    await s.tapText('Advanced settings');
    await s.check('editor: all expanded');
    await s.tapText('Advanced settings');
    return;
  }

  // Every strategy, with every response expanded.
  for (final strategy in [
    ResponseStrategy.single,
    ResponseStrategy.sequence,
    ResponseStrategy.random,
    ResponseStrategy.rules,
  ]) {
    await s.step('strategy ${strategy.label}', () => s.tapText(strategy.label));
    while (collapsed.evaluate().isNotEmpty) {
      await s.tap(collapsed);
    }
    await s.check('editor: ${strategy.label}, all expanded');
  }

  // Body types of the first response.
  for (final t in [BodyType.text, BodyType.none, BodyType.json]) {
    await s.step('body ${t.label}', () => s.tapText(t.label));
  }
  await s.check('editor: body types');

  await s.step('advanced', () => s.tapText('Advanced settings'));
  await s.check('editor: advanced settings');

  // Test bar: request body and a live test request.
  await s.step('test body', () => s.tapText('Request body'));
  await s.step('send', () async {
    await s.tap(find.text('Send'));
    await s.wait(500);
    await s.tester.pump();
  });
  await s.check('editor: test result');

  await s.step(
    'path help',
    () => s.tap(
      find.descendant(
        of: find.byType(EndpointEditor),
        matching: find.widgetWithIcon(IconButton, Icons.help_outline),
      ),
    ),
  );
  await s.check('path patterns dialog');
  await s.tapText('Got it');

  if (s.phone) {
    await s.step('keyboard', () async {
      await s.keyboard(true);
      await s.tap(
        find.ancestor(
          of: find.text('Endpoint name'),
          matching: find.byType(TextField),
        ),
      );
    });
    await s.check('editor with keyboard');
    await s.keyboard(false);
  }

  // Collapse again so later visits start from the default view.
  await s.tapText('Advanced settings');
}

Future<void> _logs(_Sweep s) async {
  await s.goTab(MainTab.logs);
  await s.check('live requests');
  if (!s.deep) {
    await s.step('details', () => s.tap(_logRow('/billing/invoices')));
    await s.check('request details');
    await _closeDetails(s);
    return;
  }
  await s.step('errors only', () => s.tapText('Errors only'));
  await s.check('live requests, errors only');
  await s.tapText('Errors only');
  await s.step('filter', () async {
    if (s.phone) await s.keyboard(true);
    await s.tester.enterText(
      find.widgetWithText(TextField, 'Filter by path, method, status…'),
      'api',
    );
  });
  await s.check(s.phone ? 'live filter with keyboard' : 'live filter');
  await s.tester.enterText(find.widgetWithText(TextField, 'api'), '');
  if (s.phone) await s.keyboard(false);
  await s.step('details', () => s.tap(_logRow('/billing/invoices')));
  await s.check('request details');
  await _closeDetails(s);
}

/// A request in the Live list (the side panel lists similar paths).
Finder _logRow(String path) => find.descendant(
  of: find.byType(LogsView),
  matching: find.textContaining(path),
);

Future<void> _closeDetails(_Sweep s) async {
  if (find.byTooltip('Back').evaluate().isNotEmpty) {
    await s.back();
  } else {
    await s.tapTooltip('Close details');
  }
}

Future<void> _flows(_Sweep s) async {
  await s.goTab(MainTab.flows);
  await s.check('flows');
  final expand = find.byTooltip('Show name, headers, body and extract');
  while (expand.evaluate().isNotEmpty) {
    await s.tap(expand);
  }
  await s.check('flows: steps expanded');
  if (!s.deep) return;
  await s.step('parallel', () => s.tapText('All at once'));
  await s.check('flows: all at once');
  await s.tapText('One by one');
  await s.step('add step menu', () => s.tapText('Add step'));
  await s.check('add step menu');
  await s.dismiss(find.text('Custom request'));
  await s.step('new flow menu', () => s.tapTooltip('New flow'));
  await s.check('new flow menu');
  await s.dismiss(find.text('Blank flow'));
}

Future<void> _share(_Sweep s) async {
  await s.check('share');
  if (!s.deep) return;
  await s.step('ngrok', () => s.tapText('ngrok'));
  await s.check('share: ngrok');
  await s.tapText('cloudflared');
}

Future<void> _settingsDialog(_Sweep s) async {
  await s.check('settings dialog');
  await s.step('about', () => s.tapText('About Mock Studio'));
  await s.check('about dialog');
  await s.dismiss(find.text('Close'));
  await s.tapText('Done');
}

Future<void> _postmanDialog(_Sweep s) async {
  await s.check('postman import dialog');
  await s.step('paste', () async {
    if (s.phone && s.deep) await s.keyboard(true);
    await s.tester.enterText(
      find.widgetWithText(TextField, 'Or paste Postman JSON here'),
      jsonEncode(_postman),
    );
  });
  if (s.deep) {
    await s.check(s.phone ? 'postman paste with keyboard' : 'postman paste');
    if (s.phone) await s.keyboard(false);
  }
  await s.step('add', () => s.tapText('Add'));
  await s.check('postman summary');
  if (!s.deep) {
    await s.tapText('Cancel');
    return;
  }
  await s.step('into existing', () async {
    await s.tap(find.text('A new project'));
    await s.tap(find.textContaining('Existing: $_bigName').last);
  });
  await s.check('postman into existing project');
  await s.tapText('Cancel');
}

/// New project and rename dialogs, from the project switcher.
Future<void> _projectDialogs(_Sweep s) async {
  await s.step(
    'project menu',
    () => s.tap(
      find.descendant(
        of: find.byType(PopupMenuButton<String>),
        matching: find.byIcon(Icons.unfold_more),
      ),
    ),
  );
  await s.check('project switcher menu');
  await s.tapText('New project');
  await s.check('new project dialog');
  if (s.phone) {
    await s.keyboard(true);
    await s.check('new project dialog with keyboard');
    await s.keyboard(false);
  }
  await s.tapText('Cancel');
  await s.tapTooltip('Rename, duplicate, export or delete this project');
  await s.check('project actions menu');
  await s.tapText('Rename');
  await s.check('rename project dialog');
  await s.tapText('Cancel');
}

/// Folder and endpoint menus and their dialogs.
Future<void> _listDialogs(_Sweep s) async {
  await s.step('folder menu', () => s.tapTooltip('Folder actions'));
  await s.check('folder menu');
  await s.tapText('Rename folder');
  await s.check('rename folder dialog');
  await s.tapText('Cancel');
  await s.step('endpoint menu', () => s.tapTooltip('Endpoint actions'));
  await s.check('endpoint menu');
  await s.tapText('Move to folder…');
  await s.check('move to folder dialog');
  await s.tapText('Cancel');
}
