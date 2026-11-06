import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/dev_menu_directions.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/services/selah_account_state.dart';
import 'package:selah/services/selah_developer_access.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/floating_nav_bar.dart';
import 'package:selah/widgets/selah_journey_icon.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';

const _capture = bool.fromEnvironment('SELAH_JOURNEY_NAV_ICON_CAPTURE');
const _boundary = ValueKey('journey-navigation-candidate');
const _font = 'Figtree';
const _candidates = 'visual/candidates/still_water_navigation_2026_11_06';

const _items = [
  FloatingNavItem(icon: Icons.search, label: 'Browse'),
  FloatingNavItem(
    icon: Icons.route_outlined,
    label: 'Journey',
    useJourneyGlyph: true,
  ),
  FloatingNavItem(icon: Icons.dashboard_outlined, label: 'My SELAH'),
  FloatingNavItem(icon: Icons.gpp_good_outlined, label: 'Shepherd'),
  FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
];

const _shepherdItems = [
  FloatingNavItem(icon: Icons.dashboard_outlined, label: 'My SELAH'),
  FloatingNavItem(icon: Icons.diversity_3_outlined, label: 'Network'),
  FloatingNavItem(icon: Icons.people_outline, label: 'Seekers'),
  FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
];

Widget _app({
  int selected = 0,
  ValueChanged<int>? onTap,
  List<FloatingNavItem> items = _items,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(bottom: 34),
      viewPadding: const EdgeInsets.only(bottom: 34),
    ),
    child: child!,
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: _boundary,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SelahShellNavigation(
              items: items,
              currentIndex: selected,
              onTap: onTap ?? (_) {},
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

bool _chooseMenu(SelahMenuDesign design) => SelahDevMenuDesign.instance.select(
  design,
  expectedGeneration: SelahAccountState.generation,
  expectedRevision: SelahDevMenuDesign.instance.revision,
);

Finder _barGesture() => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.byType(GestureDetector),
);

Finder _dockGlyph(Finder cell, FloatingNavItem item) => find.descendant(
  of: cell,
  matching: item.label == 'Network'
      ? find.byIcon(item.icon)
      : find.byType(CustomPaint),
);

// Canvas Paint serializes logical widths to float32, including LOCK's 1.7/2.2.
double _paintStroke(double width) => (Paint()..strokeWidth = width).strokeWidth;

void _expectDockGeometry(WidgetTester tester) {
  final dock = find.byType(FloatingNavBar);
  final position = tester.widget<Positioned>(
    find.descendant(of: dock, matching: find.byType(Positioned)).first,
  );
  expect((position.left, position.right, position.bottom), (0, 0, 0));
  final rect = tester.getRect(dock);
  expect(rect.left, 0);
  expect(rect.right, 393);
  expect(rect.bottom, 852);
  expect(rect.height, 81);
  final surface = tester.widget<Container>(
    find.descendant(of: dock, matching: find.byType(Container)).first,
  );
  expect(surface.padding, const EdgeInsets.fromLTRB(6, 8, 6, 26));
  final decoration = surface.decoration! as BoxDecoration;
  expect(decoration.color, SelahColors.surface);
  expect(
    decoration.border,
    const Border(top: BorderSide(color: SelahColors.line)),
  );
  expect(decoration.borderRadius, isNull);
  expect(decoration.boxShadow, isNull);
  expect(decoration.gradient, isNull);
  expect(
    find.descendant(of: dock, matching: find.byType(BackdropFilter)),
    findsNothing,
  );
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await expectLater(
        bytes!.buffer.asUint8List(),
        matchesGoldenFile('$_candidates/$name.png'),
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final haptics = <MethodCall>[];

  setUpAll(() async {
    if (!_capture) {
      return;
    }
    final font = FontLoader(_font)
      ..addFont(rootBundle.load('assets/fonts/Figtree[wght].ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([font.load(), icons.load()]);
  });

  setUp(() {
    SelahText.useTestFontStubs = true;
    SelahText.testReadingFontFamily = _capture ? _font : null;
    SelahAccountState.resetForTesting();
    SelahDeveloperAccess.resetAuthorizationForTesting();
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
      reason: 'Use the real private-draft admission define for these tests.',
    );
    SelahDevMenuDesign.instance.resetForTesting();
    SelahInteractionStyle.restoreDefaults();
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          haptics.add(call);
          return null;
        });
  });

  tearDown(() {
    SelahDevMenuDesign.instance.resetForTesting();
    SelahDeveloperAccess.resetAuthorizationForTesting();
    SelahDraftRuntime.stop();
    SelahInteractionStyle.restoreDefaults();
    SelahText.useTestFontStubs = false;
    SelahText.testReadingFontFamily = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  int selectionTicks() => haptics
      .where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      )
      .length;

  test(
    'existing nav items retain material glyphs unless explicitly opted in',
    () {
      const oldConnection = FloatingNavItem(
        icon: Icons.bookmark_border,
        label: 'Connections',
      );
      const oldRoute = FloatingNavItem(
        icon: Icons.route_outlined,
        label: 'Journey',
      );
      for (final item in [oldConnection, oldRoute]) {
        expect(item.useJourneyGlyph, isFalse);
        final icon = item.buildIcon(color: Colors.amber, size: 22) as Icon;
        expect(icon.icon, item.icon);
        expect(icon.color, Colors.amber);
        expect(icon.size, 22);
      }
    },
  );

  test(
    'Journey glyph preserves metadata and takes the caller size and tint',
    () {
      const item = FloatingNavItem(
        icon: Icons.route_outlined,
        label: 'Journey',
        useJourneyGlyph: true,
        dot: true,
        badge: 3,
        dimmed: true,
      );
      final glyph =
          item.buildIcon(color: Colors.white54, size: 24) as SelahJourneyIcon;
      expect((glyph.size, glyph.color), (24, Colors.white54));
      expect((item.icon, item.label), (Icons.route_outlined, 'Journey'));
      expect((item.dot, item.badge, item.dimmed), (true, 3, true));
    },
  );

  test(
    'canonical Couple painter retains a quiet 24-unit outline and tint-only repaint',
    () {
      const original = SelahJourneyIconPainter(color: Colors.amber);
      expect(original.design, SelahJourneyIconDesign.couple);
      expect(SelahJourneyIconPainter.viewBoxSize, 24);
      expect(SelahJourneyIconPainter.strokeWidth, 1.8);
      expect(original.shouldRepaint(original), isFalse);
      expect(
        original.shouldRepaint(
          const SelahJourneyIconPainter(color: Colors.white),
        ),
        isTrue,
      );
    },
  );

  for (final selected in [0, 1]) {
    testWidgets(
      'Still Water dock paints the locked Journey outline at selected $selected',
      (tester) async {
        await _mount(tester, _app(selected: selected));
        final cell = find.byKey(const ValueKey('floating-nav-item-1'));
        final finder = _dockGlyph(cell, _items[1]);
        expect(finder, findsOneWidget);
        expect(tester.getSize(finder), const Size.square(23));
        final color = selected == 1 ? SelahColors.lake : SelahColors.muted;
        final stroke = _paintStroke(selected == 1 ? 2.2 : 1.7);
        expect(
          tester.renderObject<RenderCustomPaint>(finder),
          paints
            ..circle(
              x: 4,
              y: 19,
              radius: 1.6,
              color: color,
              strokeWidth: stroke,
            )
            ..circle(
              x: 20,
              y: 7,
              radius: 1.6,
              color: color,
              strokeWidth: stroke,
            )
            ..path(
              color: color,
              strokeWidth: stroke,
              style: PaintingStyle.stroke,
            ),
        );
        _expectDockGeometry(tester);
        expect(find.byType(SelahJourneyIcon), findsNothing);
        expect(find.byIcon(Icons.route_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in [('Seeker', _items), ('Shepherd', _shepherdItems)]) {
    for (var selected = 0; selected < role.$2.length; selected++) {
      testWidgets(
        '${role.$1} dock keeps 23 px icons and lake/muted labels at tab $selected',
        (tester) async {
          await _mount(tester, _app(selected: selected, items: role.$2));
          for (var index = 0; index < role.$2.length; index++) {
            final item = role.$2[index];
            final cell = find.byKey(ValueKey('floating-nav-item-$index'));
            final glyph = _dockGlyph(cell, item);
            expect(glyph, findsOneWidget);
            expect(tester.getSize(glyph), const Size.square(23));
            final active = index == selected;
            final color = active ? SelahColors.lake : SelahColors.muted;
            if (item.label == 'Network') {
              final icon = tester.widget<Icon>(glyph);
              expect((icon.size, icon.color), (23, color));
            } else {
              expect(
                tester.renderObject<RenderCustomPaint>(glyph),
                paints..path(
                  color: color,
                  strokeWidth: _paintStroke(active ? 2.2 : 1.7),
                  style: PaintingStyle.stroke,
                ),
              );
            }
            final label = find.descendant(
              of: cell,
              matching: find.text(item.label),
            );
            final style = tester.widget<Text>(label).style!;
            expect(
              (style.fontSize, style.fontWeight, style.color),
              (11, FontWeight.w500, color),
            );
            expect(
              tester.getTopLeft(label).dy - tester.getBottomLeft(glyph).dy,
              4,
            );
          }
          _expectDockGeometry(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Journey tap keeps the existing target and one selection haptic',
    (tester) async {
      final calls = <int>[];
      await _mount(tester, _app(onTap: calls.add));
      final rect = tester.getRect(_barGesture());
      await tester.tapAt(Offset(rect.left + rect.width * .3, rect.center.dy));
      await tester.pumpAndSettle();
      expect(calls, [1]);
      expect(selectionTicks(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Journey remains reachable through the existing drag scrub', (
    tester,
  ) async {
    final calls = <int>[];
    await _mount(tester, _app(onTap: calls.add));
    final rect = tester.getRect(_barGesture());
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * .1, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.left + rect.width * .3, rect.center.dy));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, [1]);
    expect(selectionTicks(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Journey badge retains unread semantics and locked lake styling',
    (tester) async {
      await _mount(
        tester,
        _app(
          selected: 1,
          items: [
            _items.first,
            const FloatingNavItem(
              icon: Icons.route_outlined,
              label: 'Journey',
              useJourneyGlyph: true,
              dimmed: true,
              dot: true,
              badge: 3,
            ),
            ..._items.skip(2),
          ],
        ),
      );
      final cell = find.byKey(const ValueKey('floating-nav-item-1'));
      final glyph = _dockGlyph(cell, _items[1]);
      expect(tester.getSize(glyph), const Size.square(23));
      expect(
        tester.renderObject<RenderCustomPaint>(glyph),
        paints..path(
          color: SelahColors.lake,
          strokeWidth: _paintStroke(2.2),
          style: PaintingStyle.stroke,
        ),
      );
      final semantics = tester.ensureSemantics();
      try {
        final data = tester.getSemantics(cell).getSemanticsData();
        expect((data.label, data.value), ('Journey', '3 unread'));
      } finally {
        semantics.dispose();
      }
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final design in SelahMenuDesign.values.skip(1)) {
    testWidgets(
      '${design.name} selection retains the locked dock and destination',
      (tester) async {
        expect(_chooseMenu(design), isTrue);
        final calls = <int>[];
        await _mount(tester, _app(onTap: calls.add));
        expect(SelahDevMenuDesign.instance.effectiveDesign, design);
        final destination = find.byKey(const ValueKey('floating-nav-item-1'));
        final finder = _dockGlyph(destination, _items[1]);
        expect(finder, findsOneWidget);
        expect(tester.getSize(finder), const Size.square(23));
        _expectDockGeometry(tester);
        expect(find.byKey(const ValueKey('menu-open')), findsNothing);
        expect(find.byKey(const ValueKey('menu-destination-1')), findsNothing);
        await tester.tapAt(tester.getCenter(destination));
        await tester.pumpAndSettle();
        expect(calls, [1]);
        expect(selectionTicks(), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'legacy menu selection retains revision and developer authority guards',
    () {
      final generation = SelahAccountState.generation;
      final revision = SelahDevMenuDesign.instance.revision;
      expect(_chooseMenu(SelahMenuDesign.grid), isTrue);
      expect(
        SelahDevMenuDesign.instance.select(
          SelahMenuDesign.fab,
          expectedGeneration: generation,
          expectedRevision: revision,
        ),
        isFalse,
      );
      expect(SelahDevMenuDesign.instance.effectiveDesign, SelahMenuDesign.grid);
      SelahDraftRuntime.stop();
      expect(_chooseMenu(SelahMenuDesign.sideMenu), isFalse);
      expect(
        SelahDevMenuDesign.instance.effectiveDesign,
        SelahMenuDesign.current,
      );
    },
  );

  if (_capture) {
    for (final selected in [0, 1]) {
      testWidgets('capture Journey ${selected == 1 ? 'active' : 'inactive'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(393, 120);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(selected: selected));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _snapshot(
          tester,
          selected == 1 ? 'journey_nav_active' : 'journey_nav_inactive',
        );
      });
    }
  }
}
