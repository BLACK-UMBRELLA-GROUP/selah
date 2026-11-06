// LOCK 16 / Q13. Actual root disclosure routes; existing photo inspection stays.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/dev/selah_one_journey_discovery_presentation.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_marriage_values_views.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';
import 'your_values_driver.dart';

final _capture = MasterCaptureHarness(
  feature: 'MARRIAGE_VALUES',
  version: 'LOCK16_V1',
);
Finder _key(String key) => find.byKey(ValueKey<String>(key));
const _note = SelahMarriageValuesCard.ownVisibilityNote;
const _fixtureCards = [
  ('draft-amira', 'grace', 'Never married · No children · Would like children'),
  ('draft-sara', 'esther', 'Never married · No children · Would like children'),
  ('draft-aisha', 'naomi', 'Widowed · Has children · Open to children'),
  ('draft-maryam', 'abigail', 'Divorced · No children · Would like children'),
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tab(WidgetTester tester, String label) async {
  final finder = find.descendant(
    of: find.byType(SelahShellNavigation),
    matching: find.text(label),
  );
  expect(finder, findsOneWidget);
  await tester.tapAt(tester.getCenter(finder));
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
            (d) =>
                d.profiles.isNotEmpty &&
                d.profiles.every((p) => p.photos.isNotEmpty),
          )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The actual root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
}

Future<MasterScreen> _mount(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitBrowse(tester);
  return screen;
}

Future<void> _expire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _showPerson(WidgetTester tester, String id) async {
  for (var i = 0; i < 12; i++) {
    final deck = tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );
    expect(deck.profiles, isNotEmpty);
    if (deck.profiles[deck.selectedIndex].id == id) return;
    await _tap(tester, _key('concept_next_profile'));
  }
  fail('Actual eligible deck did not reach $id.');
}

Future<void> _captureMaster(
  WidgetTester tester,
  MasterScreen screen,
  String feature,
  String master, {
  String? name,
}) async {
  await _expire(tester);
  await _capture.capture(
    tester,
    screen,
    name ?? master,
    masterFile: File('../APP/APPROVED/$feature/MASTERS/$master.png').absolute,
  );
}

Future<void> _signup(WidgetTester tester) async {
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Seeker'));
  await _tap(tester, _key('invite_begin'));
  await _tap(tester, _key('invite_choice_1'));
  await _tap(tester, _key('invite_continue'));
  await tester.enterText(_key('invite_name'), 'David Okafor');
  await _tap(tester, find.text('THEIR NAME'));
  await _tap(tester, _key('invite_send'));
  await _tap(tester, _key('invite_sent_continue'));
  await _tap(tester, _key('consent_agree'));
  for (final (q, index) in [(1, 1), (2, 0), (3, 0), (4, 1), (5, 1), (6, 0)]) {
    await _tap(tester, _key('faith_choice_q${q}_$index'));
    await _tap(tester, _key('faith_continue'));
  }
  await tester.enterText(
    _key('faith_words'),
    'Church is where I grew up. I want a home where we pray together and serve together.',
  );
  await _tap(tester, _key('faith_save'));
  await _expire(tester);
  for (final (q, index) in [
    (1, 0),
    (2, 0),
    (3, 0),
    (4, 1),
    (5, 1),
    (6, 1),
    (7, 1),
  ]) {
    await _tap(tester, _key('marriage_choice_q${q}_$index'));
    await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
  }
  await _expire(tester);
  await _tap(tester, _key('language_choice_0'));
  await _tap(tester, _key('language_choice_5'));
  await _tap(tester, _key('languages_save'));
  await finishYourValuesFromOverview(tester);
  await _waitBrowse(tester);
  await _expire(tester);
}

Future<void> _ownCard(WidgetTester tester) async {
  await _tab(tester, 'Profile');
  await tester.ensureVisible(_key('marriage_values_section'));
  await Scrollable.ensureVisible(
    tester.element(find.text(_note)),
    alignment: .8,
  );
  await tester.pumpAndSettle();
}

Future<void> _journey(WidgetTester tester) async {
  await _tab(tester, 'Journey');
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('concept_journey_preview_1'));
  await _tap(tester, _key('draft_journey_draft-sara'));
  await _expire(tester);
}

Future<void> _shepherd(WidgetTester tester) async {
  await _tab(tester, 'Journey');
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('draft_role_shepherd'));
  await _tab(tester, 'Dashboard');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFonts;
  setUpAll(() async {
    oldHttp = HttpOverrides.current;
    oldFonts = GoogleFonts.config.allowRuntimeFetching;
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
    GoogleFonts.config.allowRuntimeFetching = oldFonts!;
  });

  for (final (id, name, line) in _fixtureCards) {
    testWidgets('LOCK16 Browse $name exposes only three saved fields', (
      tester,
    ) async {
      final screen = await _mount(tester);
      await _showPerson(tester, id);
      expect(find.text(line), findsOneWidget);
      expect(find.byType(SelahMarriageValuesCard), findsNothing);
      await _captureMaster(
        tester,
        screen,
        'BROWSE_CARD',
        'L08_browse_card__$name',
      );
    });
  }
  testWidgets('LOCK16 LOOK Browse receives the same public line', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _showPerson(tester, 'draft-amira');
    await _captureMaster(tester, screen, 'LOOK', 'L01_seeker_browse__profile');
  });
  testWidgets('LOCK16 share later omits only the marriage-history part', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _showPerson(tester, 'draft-amira');
    await _tap(tester, _key('draft_back'));
    await _tap(tester, _key('marriage_share_later'));
    expect(find.text('No children · Would like children'), findsOneWidget);
    expect(find.textContaining('Never married'), findsNothing);
    await _captureMaster(
      tester,
      screen,
      'MARRIAGE_VALUES',
      'L16_browse_card__share_later',
    );
  });
  testWidgets('LOCK16 pending Browse still shows the public line', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _signup(tester);
    // Grace already owns the existing received-request fixture. Retain that
    // behavior; Esther is the real pending Browse card with no request yet.
    await _showPerson(tester, 'draft-sara');
    expect(find.text('Request later'), findsOneWidget);
    await _captureMaster(
      tester,
      screen,
      'SHEPHERD_INVITE',
      'L03_seeker_browse__waiting_for_shepherd',
    );
  });
  for (final (feature, master) in [
    ('MARRIAGE_VALUES', 'L05_profile_marriage__answered'),
    ('ABOUT_YOU', 'L14_profile_about_you'),
  ]) {
    testWidgets('LOCK16 own saved card and note: $feature', (tester) async {
      final screen = await _mount(tester);
      await _signup(tester);
      final owner = tester
          .widget<SelahOneJourneyConceptShell>(
            find.byType(SelahOneJourneyConceptShell),
          )
          .accountSession!;
      await _ownCard(tester);
      final card = tester.widget<SelahMarriageValuesCard>(
        find.byType(SelahMarriageValuesCard),
      );
      expect(card.answers.requiredComplete, isTrue);
      expect(card.answers.toMap(), owner.marriageAnswers.toMap());
      expect(find.text(_note), findsOneWidget);
      await _captureMaster(tester, screen, feature, master);
    });
  }
  testWidgets('LOCK16 actual active Journey name opens seven answers', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _journey(tester);
    await _tap(tester, _key('concept_journey_profile_name'));
    expect(_key('journey_marriage_profile_draft-sara'), findsOneWidget);
    expect(
      find.text('You can see these because you’re on a Journey together.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SelahMarriageValuesCard>(find.byType(SelahMarriageValuesCard))
          .answers
          .requiredComplete,
      isTrue,
    );
    await _captureMaster(
      tester,
      screen,
      'MARRIAGE_VALUES',
      'L16_journey_their_profile',
    );
  });
  testWidgets(
    'LOCK16 Shepherd retains photo inspection above canonical saved card',
    (tester) async {
      final screen = await _mount(tester);
      await _signup(tester);
      await _tap(tester, _key('draft_back'));
      await _tap(tester, _key('invite_shepherd_accepts'));
      await _journey(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _shepherd(tester);
      await _tab(tester, 'Seekers');
      await _tap(tester, find.text('Open current Journey'));
      await _tap(tester, find.text('View profile'));
      expect(find.byType(SelahOneJourneyBrowsePresentation), findsOneWidget);
      final gallery = _key('concept_browse_photo_gallery');
      expect(tester.getSize(gallery).height, masterPhoneSize.height);
      await tester.tapAt(tester.getTopLeft(gallery) + const Offset(320, 300));
      await tester.pumpAndSettle();
      expect(find.byType(SelahOneJourneyBrowsePresentation), findsOneWidget);
      await tester.ensureVisible(_key('marriage_values_section'));
      await tester.pumpAndSettle();
      final card = tester.widget<SelahMarriageValuesCard>(
        find.byType(SelahMarriageValuesCard),
      );
      expect(card.answers.requiredComplete, isTrue);
      expect(card.visibilityNote, isNull);
      await _captureMaster(
        tester,
        screen,
        'MARRIAGE_VALUES',
        'L05_profile_marriage__answered',
        name: 'L16_shepherd_linked_seeker__marriage_values',
      );
    },
  );
  testWidgets('LOCK16 captured Journey name cannot open after a role change', (
    tester,
  ) async {
    await _mount(tester);
    await _journey(tester);
    final old = tester
        .widget<SelahConceptJourneyPresentation>(
          find.byType(SelahConceptJourneyPresentation),
        )
        .onProfile!;
    for (
      var step = 0;
      step < 3 && _key('draft_role_shepherd').evaluate().isEmpty;
      step++
    ) {
      await _tap(tester, _key('draft_back'));
    }
    await _tap(tester, _key('draft_role_shepherd'));
    old();
    await tester.pumpAndSettle();
    expect(_key('journey_marriage_profile_draft-sara'), findsNothing);
  });
}
