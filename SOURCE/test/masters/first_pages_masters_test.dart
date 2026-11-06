// LOCK 15: four quiet pages through the real parent's existing opening entry.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/dev_onboarding_opening.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shepherd_invite_views.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _capture = MasterCaptureHarness(feature: 'FIRST_PAGES');
const _headings = [
  'A pause before every step.',
  'You won’t walk alone.',
  'Faith first.',
  'Everyone is verified.',
];
Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _waitBrowse(WidgetTester tester) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump();
      if (tester
          .widgetList<SelahOneJourneyBrowseDesigns>(
            find.byType(SelahOneJourneyBrowseDesigns),
          )
          .any(
            (deck) =>
                deck.profiles.isNotEmpty &&
                deck.profiles.every((p) => p.photos.isNotEmpty),
          )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail(
      'The actual retained parent did not return to its local Browse route.',
    );
  });
  await tester.pumpAndSettle();
}

Future<MasterScreen> _opening(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitBrowse(tester);
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Welcome & onboarding'));
  expect(find.byType(DevOnboardingOpening), findsOneWidget);
  return screen;
}

void _expectPage(WidgetTester tester, int page) {
  expect(find.text(_headings[page - 1]), findsOneWidget);
  expect(_key('first_pages_page_$page'), findsOneWidget);
  expect(_key('first_pages_back'), page == 1 ? findsNothing : findsOneWidget);
  expect(_key('first_pages_skip'), page == 4 ? findsNothing : findsOneWidget);
  expect(
    tester.widget<SelahInviteButton>(_key('first_pages_next')).label,
    page == 4 ? 'Continue' : 'Next',
  );
  for (var i = 0; i < 4; i++) {
    final decoration =
        tester.widget<Container>(_key('first_pages_dash_$i')).decoration!
            as BoxDecoration;
    expect(
      decoration.color,
      i == page - 1 ? SelahColors.lake : SelahColors.line,
    );
    expect(tester.getSize(_key('first_pages_dash_$i')), const Size(22, 3));
  }
  expect(find.text('Why photos first?'), findsNothing);
  expect(find.text('The Selah approach'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFetching;
  setUpAll(() async {
    expect(
      Directory('${_capture.featureRoot.path}/MASTERS')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.uri.pathSegments.last)
          .toSet(),
      {for (var i = 1; i <= 4; i++) 'L15_opening_$i.png'},
    );
    oldHttp = HttpOverrides.current;
    oldFetching = GoogleFonts.config.allowRuntimeFetching;
    HttpOverrides.global = SelahOfflineHttpOverrides();
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadSelahMasterFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SelahText.useTestFontStubs = false;
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
    );
    SelahInternalPreviewClient.beginPreview();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    SelahDraftRuntime.stop();
    SelahInternalPreviewClient.finishSignOut();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  tearDownAll(() {
    HttpOverrides.global = oldHttp;
    GoogleFonts.config.allowRuntimeFetching = oldFetching!;
  });

  for (var page = 1; page <= 4; page++) {
    testWidgets(
      'Opening $page is the actual quiet page with readable progress',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final screen = await _opening(tester);
          for (var i = 1; i < page; i++) {
            await _tap(tester, _key('first_pages_next'));
          }
          _expectPage(tester, page);
          expect(find.bySemanticsLabel('Page $page of 4'), findsOneWidget);
          await _capture.capture(tester, screen, 'L15_opening_$page');
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'Opening left/right swipes and Back move one page; Skip keeps parent destination',
    (tester) async {
      await _opening(tester);
      await tester.drag(_key('first_pages_page_1'), const Offset(-160, 0));
      await tester.pumpAndSettle();
      _expectPage(tester, 2);
      await tester.drag(_key('first_pages_page_2'), const Offset(160, 0));
      await tester.pumpAndSettle();
      _expectPage(tester, 1);
      await _tap(tester, _key('first_pages_next'));
      await _tap(tester, _key('first_pages_next'));
      await _tap(tester, _key('first_pages_back'));
      _expectPage(tester, 2);
      await _tap(tester, _key('first_pages_skip'));
      await _waitBrowse(tester);
      expect(find.byType(DevOnboardingOpening), findsNothing);
    },
  );

  testWidgets('Opening Continue preserves the existing parent destination', (
    tester,
  ) async {
    await _opening(tester);
    for (var i = 1; i < 4; i++) {
      await _tap(tester, _key('first_pages_next'));
    }
    final done = tester
        .widget<SelahInviteButton>(_key('first_pages_next'))
        .onPressed!;
    await _tap(tester, _key('first_pages_next'));
    done();
    await _waitBrowse(tester);
    expect(find.byType(DevOnboardingOpening), findsNothing);
  });

  testWidgets('Opening stale page callbacks and runtime ABA cannot advance', (
    tester,
  ) async {
    await _opening(tester);
    final oldNext = tester
        .widget<SelahInviteButton>(_key('first_pages_next'))
        .onPressed!;
    await _tap(tester, _key('first_pages_next'));
    oldNext();
    await tester.pumpAndSettle();
    _expectPage(tester, 2);
    final currentNext = tester
        .widget<SelahInviteButton>(_key('first_pages_next'))
        .onPressed!;
    SelahDraftRuntime.stop();
    currentNext();
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
    );
    currentNext();
    await tester.pumpAndSettle();
    _expectPage(tester, 2);
    expect(find.byType(SelahOneJourneyBrowseDesigns), findsNothing);
  });

  testWidgets(
    'Opening callback cannot advance under an unrelated covering route',
    (tester) async {
      await _opening(tester);
      final next = tester
          .widget<SelahInviteButton>(_key('first_pages_next'))
          .onPressed!;
      final navigator = Navigator.of(
        tester.element(find.byType(DevOnboardingOpening)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Text('Unrelated covering route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      next();
      await tester.pumpAndSettle();
      expect(find.text('Unrelated covering route'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      _expectPage(tester, 1);
      await _tap(tester, _key('first_pages_next'));
      _expectPage(tester, 2);
    },
  );
}
