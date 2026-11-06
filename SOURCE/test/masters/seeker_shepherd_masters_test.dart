// LOCK 12. Actual root, canonical prayer/Circle owners and guarded loaders.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/screens/mentor/seeker_shepherd_designs.dart';
import 'package:selah/screens/mentor/family_messaging_screens.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _capture = MasterCaptureHarness(feature: 'SEEKER_SHEPHERD');
const _masters = {
  'L12_seeker_shepherd_tab__top',
  'L12_seeker_shepherd_tab__bottom',
  'L12_seeker_shepherd_tab__nothing_yet',
  'L12_seeker_shepherd_tab__access_loading',
  'L12_seeker_shepherd_tab__access_didnt_load',
  'L12_seeker_shepherd_tab__no_active_journeys',
};
Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tab(WidgetTester tester, String label) async {
  final target = find.descendant(
    of: find.byType(SelahShellNavigation),
    matching: find.text(label),
  );
  expect(target, findsOneWidget);
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _expireNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<MasterScreen> _mount(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump();
      final decks = tester.widgetList<SelahOneJourneyBrowseDesigns>(
        find.byType(SelahOneJourneyBrowseDesigns),
      );
      if (decks.any(
        (deck) =>
            deck.profiles.isNotEmpty &&
            deck.profiles.every((p) => p.photos.isNotEmpty),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The real root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  return screen;
}

Future<void> _role(WidgetTester tester, bool shepherd) async {
  await _tap(tester, _key('draft_back'));
  await _tap(
    tester,
    _key(shepherd ? 'draft_role_shepherd' : 'draft_role_seeker'),
  );
  await _tab(tester, shepherd ? 'Dashboard' : 'Shepherd');
}

Future<void> _preset(WidgetTester tester, String key) async {
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key(key));
}

Future<void> _recent(WidgetTester tester, {bool journey = true}) async {
  if (journey) {
    await _tab(tester, 'Journey');
    await _preset(tester, 'concept_journey_preview_1');
  }
  await _role(tester, true);
  await _tap(tester, _key('prayer_pray_prayer-seed-1'));
  await _tap(tester, _key('prayer_pray_prayer-seed-3'));
  await _role(tester, false);
  await _tab(tester, 'Shepherd');
  await _expireNotice(tester);
}

Future<void> _bottom(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: _key('seeker_shepherd_scroll'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scroll.position.jumpTo(scroll.position.maxScrollExtent);
  await tester.pumpAndSettle();
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
          .where((file) => file.path.endsWith('.png'))
          .map((file) => file.uri.pathSegments.last.replaceFirst('.png', ''))
          .toSet(),
      _masters,
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

  for (final state in [
    'top',
    'bottom',
    'nothing_yet',
    'access_loading',
    'access_didnt_load',
    'no_active_journeys',
  ]) {
    testWidgets('LOCK12 actual root $state', (tester) async {
      final screen = await _mount(tester);
      await _recent(tester, journey: state != 'no_active_journeys');
      expect(find.text('My Shepherd'), findsOneWidget);
      expect(find.text('Pastor David Okafor'), findsOneWidget);
      expect(find.text('Mark Carter'), findsOneWidget);
      expect(
        find.text('Brother · Supports you with your Journey.'),
        findsOneWidget,
      );
      final page = tester.widget<SeekerShepherdPage>(
        find.byType(SeekerShepherdPage),
      );
      expect(page.recent, hasLength(3));
      expect(
        page.recent.where((row) => row.text.startsWith('“Hello.')),
        hasLength(1),
      );
      expect(
        page.recent.any(
          (row) => row.text == 'Prayed for your Journey with Esther',
        ),
        isTrue,
      );
      if (state == 'nothing_yet') {
        await _preset(tester, 'shepherd_recent_empty');
        expect(
          find.text(
            'Nothing yet. When Pastor David prays for you or sends a message, it shows here.',
          ),
          findsOneWidget,
        );
      } else if (state == 'access_loading' || state == 'access_didnt_load') {
        await _preset(
          tester,
          state == 'access_loading'
              ? 'shepherd_access_loading'
              : 'shepherd_access_failed',
        );
        expect(
          find.text(
            state == 'access_loading'
                ? 'Loading Journey access…'
                : 'Journey access didn’t load.',
          ),
          findsOneWidget,
        );
      }
      if (state == 'bottom' ||
          state == 'no_active_journeys' ||
          state == 'access_loading' ||
          state == 'access_didnt_load') {
        await _bottom(tester);
      }
      if (state == 'no_active_journeys') {
        expect(
          find.text('No active Journeys. Access is set when one begins.'),
          findsOneWidget,
        );
      }
      expect(_key('shepherd-family-messages-top'), findsNothing);
      await _capture.capture(tester, screen, 'L12_seeker_shepherd_tab__$state');
    });
  }

  testWidgets(
    'LOCK12 empty projection preserves real events and Circle owner',
    (tester) async {
      await _mount(tester);
      await _recent(tester);
      final before = tester
          .widget<SeekerShepherdPage>(find.byType(SeekerShepherdPage))
          .recent;
      await _preset(tester, 'shepherd_recent_empty');
      expect(
        tester
            .widget<SeekerShepherdPage>(find.byType(SeekerShepherdPage))
            .recent,
        isEmpty,
      );
      await _preset(tester, 'shepherd_access_available');
      expect(
        tester
            .widget<SeekerShepherdPage>(find.byType(SeekerShepherdPage))
            .recent
            .map((row) => row.key),
        before.map((row) => row.key),
      );
      await _tap(tester, _key('seeker_shepherd_message'));
      final circle = tester.widget<SelahShepherdCircleScreen>(
        find.byType(SelahShepherdCircleScreen),
      );
      expect(
        circle.previewData!.messages.where(
          (m) => m.id == 'draft-circle-response',
        ),
        hasLength(1),
      );
    },
  );
  testWidgets('LOCK12 stale management and loader callbacks deny role ABA', (
    tester,
  ) async {
    await _mount(tester);
    await _tab(tester, 'Shepherd');
    final page = tester.widget<SeekerShepherdPage>(
      find.byType(SeekerShepherdPage),
    );
    final person = page.people.firstWhere((person) => person.isMain);
    await _role(tester, true);
    expect(await page.clearMainShepherd!(person.id), isFalse);
    await _role(tester, false);
    expect(await page.clearMainShepherd!(person.id), isFalse);
    final result = await page.journeyAccessLoader!(shepherdId: person.id);
    expect(result.isAvailable, isFalse);
    await _tab(tester, 'Shepherd');
    expect(
      tester
          .widget<SeekerShepherdPage>(find.byType(SeekerShepherdPage))
          .people
          .where((p) => p.isMain),
      hasLength(1),
    );
  });
  testWidgets(
    'LOCK12 addressed Additional management keeps Main and role guards',
    (tester) async {
      await _mount(tester);
      await _tab(tester, 'Shepherd');
      final page = tester.widget<SeekerShepherdPage>(
        find.byType(SeekerShepherdPage),
      );
      final oldMain = page.people.firstWhere((p) => p.isMain);
      final additional = page.people.firstWhere((p) => !p.isMain);
      await _tap(tester, _key('seeker_shepherd_manage_${additional.id}'));
      await _tap(tester, _key('shepherd-make-main'));
      await _tap(
        tester,
        find.descendant(
          of: _key('shepherd-make-main-confirmation'),
          matching: find.text('Confirm'),
        ),
      );
      final changed = tester.widget<SeekerShepherdPage>(
        find.byType(SeekerShepherdPage),
      );
      expect(changed.people.firstWhere((p) => p.isMain).id, additional.id);
      expect(await page.clearMainShepherd!(oldMain.id), isFalse);
      expect(changed.displayNames[additional.id], 'Mark Carter');
    },
  );
  testWidgets(
    'LOCK12 real Circle sends remain in its single owner after reopening',
    (tester) async {
      await _mount(tester);
      await _tab(tester, 'Shepherd');
      await _tap(tester, _key('seeker_shepherd_message'));
      final composer = find.descendant(
        of: _key('shepherd-circle-composer'),
        matching: find.byType(TextField),
      );
      await tester.enterText(composer, 'A real local message from this test');
      final send = find.descendant(
        of: find.byType(SelahShepherdCircleScreen),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Send message',
        ),
      );
      await _tap(tester, send);
      expect(find.text('A real local message from this test'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SeekerShepherdPage), findsOneWidget);
      await _tap(tester, _key('seeker_shepherd_message'));
      final reopened = tester.widget<SelahShepherdCircleScreen>(
        find.byType(SelahShepherdCircleScreen),
      );
      expect(
        reopened.previewData!.messages.where(
          (m) => m.body == 'A real local message from this test',
        ),
        hasLength(1),
      );
      expect(reopened.previewData!.messageCount, 3);
    },
  );
}
