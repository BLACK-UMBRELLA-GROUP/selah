import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/dev_menu_directions.dart';
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
const _font = 'PoppinsJourneyNavigation';
const _candidates = 'visual/candidates/browse_gallery_filters_2026_10_09';

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
    final font = FontLoader(_font);
    for (final weight in [
      'ExtraLight',
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
    ]) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([font.load(), icons.load()]);
  });

  setUp(() {
    SelahText.useTestFontStubs = true;
    SelahText.testReadingFontFamily = _capture ? _font : null;
    SelahAccountState.resetForTesting();
    SelahDeveloperAccess.resetAuthorizationForTesting();
    SelahDeveloperAccess.setAuthorizedForTesting(true);
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
      'shared bar retains Journey size and tint at selected $selected',
      (tester) async {
        await _mount(tester, _app(selected: selected));
        final finder = find.byType(SelahJourneyIcon);
        expect(finder, findsOneWidget);
        final glyph = tester.widget<SelahJourneyIcon>(finder);
        expect(glyph.size, SelahNavBarMetrics.iconSize);
        expect(tester.getSize(finder), const Size.square(22));
        expect(
          glyph.color,
          selected == 1 ? SelahColors.foreground : SelahColors.ink(.45),
        );
        final scale = tester.widget<AnimatedScale>(
          find.ancestor(of: finder, matching: find.byType(AnimatedScale)),
        );
        expect(scale.scale, 1);
        final position = tester
            .widgetList<Positioned>(
              find.descendant(
                of: find.byType(FloatingNavBar),
                matching: find.byType(Positioned),
              ),
            )
            .first;
        expect(position.left, SelahNavBarMetrics.sideInset);
        expect(position.right, SelahNavBarMetrics.sideInset);
        expect(position.bottom, 0);
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.route_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in [('Seeker', _items), ('Shepherd', _shepherdItems)]) {
    for (var selected = 0; selected < role.$2.length; selected++) {
      testWidgets(
        '${role.$1} navigation gives every selected/inactive glyph the same 22 px size at tab $selected',
        (tester) async {
          await _mount(tester, _app(selected: selected, items: role.$2));
          for (var index = 0; index < role.$2.length; index++) {
            final item = role.$2[index];
            final cell = find.byKey(ValueKey('floating-nav-item-$index'));
            final glyph = find.descendant(
              of: cell,
              matching: item.useJourneyGlyph
                  ? find.byType(SelahJourneyIcon)
                  : find.byIcon(item.icon),
            );
            expect(glyph, findsOneWidget);
            expect(
              tester.getSize(glyph),
              const Size.square(SelahNavBarMetrics.iconSize),
            );
            final scale = tester.widget<AnimatedScale>(
              find.ancestor(of: glyph, matching: find.byType(AnimatedScale)),
            );
            expect(scale.scale, 1);
            if (item.useJourneyGlyph) {
              final painter = tester
                  .widgetList<CustomPaint>(
                    find.descendant(
                      of: glyph,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .map((paint) => paint.painter)
                  .whereType<SelahJourneyIconPainter>()
                  .single;
              expect(painter.design, SelahJourneyIconDesign.couple);
            } else {
              expect(
                tester.widget<Icon>(glyph).size,
                SelahNavBarMetrics.iconSize,
              );
            }
          }
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

  testWidgets('Journey glyph retains dimming and the existing badge shoulder', (
    tester,
  ) async {
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
    final glyph = tester.widget<SelahJourneyIcon>(find.byType(SelahJourneyIcon));
    expect(glyph.color, SelahColors.foreground.withValues(alpha: .58));
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final design in SelahMenuDesign.values.skip(1)) {
    testWidgets('${design.name} uses the same Journey glyph and destination', (
      tester,
    ) async {
      expect(_chooseMenu(design), isTrue);
      final calls = <int>[];
      await _mount(tester, _app(onTap: calls.add));
      if (design.opensMenu) {
        await tester.tap(find.byKey(const ValueKey('menu-open')));
        await tester.pumpAndSettle();
      }
      final finder = find.byType(SelahJourneyIcon);
      expect(finder, findsOneWidget);
      final glyph = tester.widget<SelahJourneyIcon>(finder);
      expect(
        (glyph.size, glyph.color),
        (
          24,
          design == SelahMenuDesign.fab
              ? SelahColors.onAction
              : SelahColors.foreground,
        ),
      );
      final destination = find.byKey(const ValueKey('menu-destination-1'));
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(calls, [1]);
      expect(selectionTicks(), 1);
      expect(tester.takeException(), isNull);
    });
  }

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
