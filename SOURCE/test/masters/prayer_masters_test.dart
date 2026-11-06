// LOCK 10 / DOC-SELAH-0020. Real root routes, actors, store and private presets.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/selah_prayer_controller.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_prayer_views.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';
import 'your_values_driver.dart';

final _capture = MasterCaptureHarness(
  feature: 'PRAYER',
  version: 'V1_FIX_LABELS',
  wordingRevision: false,
);
const _masters = {
  'L10_seeker_ask_for_prayer',
  'L10_seeker_ask_for_prayer__sending',
  'L10_seeker_ask_for_prayer__didnt_send',
  'L10_shepherd_dashboard__requests',
  'L10_shepherd_dashboard__prayed',
  'L10_shepherd_dashboard__no_requests',
  'L10_seeker_my_selah__prayed_update',
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

Future<void> _composer(WidgetTester tester, {bool journey = true}) async {
  if (journey) {
    await _tab(tester, 'Journey');
    await _tap(tester, _key('draft_back'));
    await _tap(tester, _key('concept_journey_preview_1'));
  }
  await _tab(tester, 'Shepherd');
  await _tap(tester, _key('ask_for_prayer'));
  expect(_key('prayer_page'), findsOneWidget);
  await _expireNotice(tester);
}

Future<void> _preset(WidgetTester tester, String key) async {
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key(key));
}

SelahPrayerRequestsBlock _requests(WidgetTester tester) => tester
    .widget<SelahPrayerRequestsBlock>(find.byType(SelahPrayerRequestsBlock));

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

  for (final state in ['', '__sending', '__didnt_send']) {
    testWidgets('Prayer composer$state through actual Shepherd entry', (
      tester,
    ) async {
      final screen = await _mount(tester);
      await _composer(tester);
      final controller = tester
          .widget<SelahPrayerComposer>(find.byType(SelahPrayerComposer))
          .controller;
      expect(
        controller.suggestions.first,
        'For wisdom in my Journey with Esther',
      );
      if (state.isNotEmpty) {
        await _preset(
          tester,
          state == '__sending' ? 'prayer_sending' : 'prayer_failed',
        );
      }
      if (state == '__sending') {
        expect(controller.sendState, SelahPrayerSendState.sending);
        expect(controller.send(), isFalse);
      } else if (state == '__didnt_send') {
        expect(_key('prayer_failure'), findsOneWidget);
      }
      await _capture.capture(tester, screen, 'L10_seeker_ask_for_prayer$state');
    });
  }

  for (final state in ['requests', 'prayed', 'no_requests']) {
    testWidgets('Prayer Dashboard $state through actual role switch', (
      tester,
    ) async {
      final screen = await _mount(tester);
      await _tab(tester, 'Journey');
      await _role(tester, true);
      expect(_requests(tester).requests.map((r) => r.id), [
        for (var i = 1; i <= 4; i++) 'prayer-seed-$i',
      ]);
      expect(_requests(tester).requests.map((r) => r.prayedCount), [
        2,
        5,
        1,
        3,
      ]);
      if (state == 'prayed') {
        await _tap(tester, _key('prayer_pray_prayer-seed-1'));
        expect(_requests(tester).requests.first.prayedCount, 3);
        await _expireNotice(tester);
      } else if (state == 'no_requests') {
        await _preset(tester, 'prayer_empty');
        expect(_key('prayer_requests_empty'), findsOneWidget);
      }
      await _capture.capture(tester, screen, 'L10_shepherd_dashboard__$state');
    });
  }

  testWidgets('Prayer My SELAH update follows actual Shepherd prayer', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _tab(tester, 'Journey');
    await _role(tester, true);
    await _tap(tester, _key('prayer_pray_prayer-seed-1'));
    await _role(tester, false);
    await _tab(tester, 'My Selah');
    expect(
      find.text('Pastor David prayed for your Journey with Esther.'),
      findsOneWidget,
    );
    await _expireNotice(tester);
    await tester.ensureVisible(
      find.text('Pastor David prayed for your Journey with Esther.'),
    );
    await tester.pumpAndSettle();
    await _capture.capture(
      tester,
      screen,
      'L10_seeker_my_selah__prayed_update',
    );
  });

  testWidgets('Prayer own words send once and survive the actual role swap', (
    tester,
  ) async {
    await _mount(tester);
    await _composer(tester, journey: false);
    final composer = tester.widget<SelahPrayerComposer>(
      find.byType(SelahPrayerComposer),
    );
    expect(composer.controller.suggestions.first, 'For wisdom in my Journey');
    await _tap(tester, _key('prayer_choice_1'));
    await tester.enterText(_key('prayer_words'), 'Please pray for my family.');
    await _tap(tester, _key('prayer_send'));
    expect(_key('prayer_page'), findsNothing);
    expect(find.text('Sent. Pastor David will pray for you.'), findsOneWidget);
    expect(composer.controller.send(), isFalse);
    await _tab(tester, 'My Selah');
    expect(find.text('You asked Pastor David for prayer.'), findsOneWidget);
    await _role(tester, true);
    final rows = _requests(tester).requests;
    expect(rows, hasLength(5));
    expect(rows.first.text, 'Please pray for my family.');
    expect(rows.first.prayedCount, 0);
    final id = rows.first.id;
    await _tap(tester, _key('prayer_pray_$id'));
    final already = _requests(tester);
    expect(already.requests.first.prayedCount, 1);
    already.onPray(id);
    await tester.pumpAndSettle();
    expect(_requests(tester).requests.first.prayedCount, 1);
    await _role(tester, false);
    await _tab(tester, 'My Selah');
    expect(find.text('Pastor David prayed for you.'), findsOneWidget);
  });

  testWidgets('Prayer empty preset preserves requests and prayed-once state', (
    tester,
  ) async {
    await _mount(tester);
    await _tab(tester, 'Journey');
    await _role(tester, true);
    await _tap(tester, _key('prayer_pray_prayer-seed-1'));
    final oldCallback = _requests(tester).onPray;
    await _preset(tester, 'prayer_empty');
    expect(_requests(tester).requests, isEmpty);
    oldCallback('prayer-seed-2');
    await tester.pumpAndSettle();
    await _preset(tester, 'prayer_requests');
    expect(_requests(tester).requests.map((r) => r.prayedCount), [3, 5, 1, 3]);
    await _role(tester, false);
    oldCallback('prayer-seed-2');
    await tester.pumpAndSettle();
    await _role(tester, true);
    oldCallback('prayer-seed-2');
    await tester.pumpAndSettle();
    expect(_requests(tester).requests.map((r) => r.prayedCount), [3, 5, 1, 3]);
  });

  testWidgets('Prayer failed request retries the existing words once', (
    tester,
  ) async {
    await _mount(tester);
    await _composer(tester);
    await tester.enterText(_key('prayer_words'), 'For patience today.');
    await _tap(tester, find.text('Ask for prayer'));
    await _preset(tester, 'prayer_failed');
    expect(
      tester.widget<TextField>(_key('prayer_words')).controller!.text,
      'For patience today.',
    );
    await _tap(tester, _key('prayer_retry'));
    await _role(tester, true);
    expect(_requests(tester).requests, hasLength(5));
    expect(_requests(tester).requests.first.text, 'For patience today.');
  });

  testWidgets('Prayer old composer cannot send after runtime revocation', (
    tester,
  ) async {
    await _mount(tester);
    await _composer(tester);
    final old = tester
        .widget<SelahPrayerComposer>(find.byType(SelahPrayerComposer))
        .controller;
    SelahDraftRuntime.stop();
    expect(old.send(), isFalse);
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
    );
    expect(old.send(), isFalse);
  });

  testWidgets(
    'Prayer entry remains unavailable while the Shepherd invite is pending',
    (tester) async {
      await _mount(tester);
      await _tap(tester, _key('draft_close'));
      await _tap(tester, find.text('Explore as a Seeker'));
      await _tap(tester, _key('invite_begin'));
      await _tap(tester, _key('invite_choice_1'));
      await _tap(tester, _key('invite_continue'));
      await tester.enterText(_key('invite_name'), 'David Okafor');
      await _tap(tester, find.text('THEIR NAME'));
      await _tap(tester, _key('invite_send'));
      await _tap(tester, _key('invite_sent_continue'));
      await _tap(tester, _key('consent_skip'));
      await _expireNotice(tester);
      for (var q = 1; q <= 7; q++) {
        await _tap(tester, _key('marriage_choice_q${q}_0'));
        await _tap(
          tester,
          _key(q == 7 ? 'marriage_save' : 'marriage_continue'),
        );
      }
      await _expireNotice(tester);
      await _tap(tester, _key('language_choice_0'));
      await _tap(tester, _key('languages_save'));
      if (_key('values_overview').evaluate().isNotEmpty) {
        await finishYourValuesFromOverview(tester);
      }
      await _expireNotice(tester);
      await _tab(tester, 'Shepherd');
      expect(_key('invite_pending_card'), findsOneWidget);
      expect(_key('ask_for_prayer'), findsNothing);
      expect(_key('prayer_page'), findsNothing);
    },
  );
}
