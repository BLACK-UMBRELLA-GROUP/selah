// LOCK 8 / DOC-SELAH-0020. Real draft Browse and existing private Journey
// controls supply every capture; no test screen or admission bypass exists.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _capture = MasterCaptureHarness(feature: 'BROWSE_CARD');
const _cards = <(String, String, String, List<String>)>[
  ('draft-amira', 'grace', 'Grace', ['Anglican', 'Church weekly', 'Baptised']),
  (
    'draft-sara',
    'esther',
    'Esther',
    ['Pentecostal', 'Church weekly', 'Baptised'],
  ),
  (
    'draft-aisha',
    'naomi',
    'Naomi',
    ['Non-denominational', 'Church most weeks', 'Baptised'],
  ),
  (
    'draft-maryam',
    'abigail',
    'Abigail',
    ['Catholic', 'Church weekly', 'Baptised'],
  ),
];
Finder _key(String key) => find.byKey(ValueKey<String>(key));
SelahOneJourneyBrowseDesigns _deck(WidgetTester tester) =>
    tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );

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

Future<void> _waitForBrowse(WidgetTester tester) async {
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
    fail('The actual draft Browse did not prepare its offline portraits.');
  });
  await tester.pumpAndSettle();
}

Future<MasterScreen> _mount(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitForBrowse(tester);
  return screen;
}

Future<void> _showPerson(WidgetTester tester, String id) async {
  for (var step = 0; step < 12; step++) {
    final deck = _deck(tester);
    expect(
      deck.profiles,
      isNotEmpty,
      reason: 'The real eligible deck must contain the requested person.',
    );
    if (deck.profiles[deck.selectedIndex].id == id) {
      await tester.ensureVisible(_key('concept_browse_header'));
      await tester.pumpAndSettle();
      return;
    }
    await _tap(tester, _key('concept_next_profile'));
  }
  fail('The actual eligible Browse deck did not reach $id.');
}

Future<void> _tab(WidgetTester tester, String label) async {
  final target = find.descendant(
    of: find.byType(SelahShellNavigation),
    matching: find.text(label),
  );
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? originalHttpOverrides;
  bool? originalFontFetching;
  setUpAll(() async {
    final present = Directory('${_capture.featureRoot.path}/MASTERS')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .map((f) => f.uri.pathSegments.last.replaceFirst('.png', ''))
        .toSet();
    expect(present, {
      ..._cards.map((c) => 'L08_browse_card__${c.$2}'),
      'L08_browse_card__in_a_journey',
      'L08_browse__no_one_new',
    });
    originalHttpOverrides = HttpOverrides.current;
    originalFontFetching = GoogleFonts.config.allowRuntimeFetching;
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
      reason:
          'Use the actual draft admission flag --dart-define=SELAH_DRAFT_LOCAL_ONLY=true.',
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
    GoogleFonts.config.allowRuntimeFetching = originalFontFetching!;
    HttpOverrides.global = originalHttpOverrides;
  });

  for (final (id, master, name, chips) in _cards) {
    testWidgets('Browse faith card: $name through actual neutral navigation', (
      tester,
    ) async {
      final screen = await _mount(tester);
      await _showPerson(tester, id);
      final deck = _deck(tester);
      final person = deck.profiles[deck.selectedIndex];
      expect(person.firstName, name);
      expect(person.browseFaithChips, chips);
      for (final chip in chips) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(_key('concept_browse_faith_quote_$id'), findsOneWidget);
      expect(find.textContaining('Nationality:'), findsNothing);
      expect(find.textContaining('Ethnicity:'), findsNothing);
      await _capture.capture(tester, screen, 'L08_browse_card__$master');
    });
  }
  testWidgets(
    'Browse faith card: actual existing Journey disables request',
    (tester) async {
      final screen = await _mount(tester);
      await _tab(tester, 'Journey');
      await _tap(tester, _key('draft_back'));
      await _tap(tester, _key('concept_journey_preview_1'));
      await _tab(tester, 'Browse');
      await _waitForBrowse(tester);
      await _showPerson(tester, 'draft-sara');
      final deck = _deck(tester);
      final person = deck.profiles[deck.selectedIndex];
      expect(deck.canRequest!(person), isFalse);
      expect(find.text('In a Journey'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _capture.capture(tester, screen, 'L08_browse_card__in_a_journey');
    },
    // Q9: the actual discovery contract excludes this state. No invented image.
    skip: true,
  );
  testWidgets('Browse keeps an own active Journey outside discovery', (
    tester,
  ) async {
    await _mount(tester);
    await _tab(tester, 'Journey');
    await _tap(tester, _key('draft_back'));
    await _tap(tester, _key('concept_journey_preview_1'));
    await _tab(tester, 'Browse');
    await _waitForBrowse(tester);
    expect(
      _deck(tester).profiles.map((person) => person.id),
      isNot(contains('draft-sara')),
    );
    expect(find.text('In a Journey'), findsNothing);
    expect(_key('concept_browse_no_one_new'), findsNothing);
  });
  testWidgets(
    'Browse no one new: actual frontier exhaustion opens existing filters',
    (tester) async {
      final screen = await _mount(tester);
      final count = _deck(tester).profiles.length;
      for (var i = 0; i < count; i++) {
        await _tap(tester, _key('concept_next_profile'));
      }
      expect(_key('concept_browse_no_one_new'), findsOneWidget);
      expect(find.text('You’ve seen everyone for now'), findsOneWidget);
      await _capture.capture(tester, screen, 'L08_browse__no_one_new');
      await _tap(tester, find.text('Change who you’d like to meet'));
      expect(find.text('Age'), findsOneWidget);
    },
  );
  test('faith chip projection respects withheld answers and exact order', () {
    SeekerProfile person(Map<String, dynamic> faith, {String? own}) =>
        SeekerProfile(
          id: 'projection-only',
          firstName: 'Grace',
          age: 29,
          city: 'Leeds',
          photos: const [],
          gender: 'female',
          publicNationality: 'British',
          publicEthnicity: 'Mixed',
          faithProfile: SelahFaithProfileAnswers.fromMap(faith),
          faithDenominationText: own,
        );
    expect(person({}).browseFaithChips, isEmpty);
    expect(
      person({'tradition': 'Another tradition'}).browseFaithChips,
      isEmpty,
    );
    expect(
      person({
        'tradition': 'Another tradition',
      }, own: '  My local church  ').browseFaithChips,
      ['My local church'],
    );
    expect(
      person({
        'church': 'Rarely right now',
        'baptised': 'I’d rather not say',
      }).browseFaithChips,
      isEmpty,
    );
    expect(
      person({
        'tradition': 'Baptist',
        'church': 'Sometimes',
        'baptised': 'Not yet',
      }).browseFaithChips,
      ['Baptist', 'Church sometimes', 'Not yet baptised'],
    );
    expect(
      person({
        'tradition': 'Catholic',
        'church': 'Every week',
        'baptised': 'Yes',
      }).browseFaithChips,
      ['Catholic', 'Church weekly', 'Baptised'],
    );
  });
}
