// LOCK 9: four comparisons from the real concept Journey, scrolled to its
// preparation card. Stage changes use the existing local walkthrough actions;
// this does not claim server Family Review or phone-delivery verification.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/dev/selah_concept_preview_boundary.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_marriage_prep_card.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

const _person = 'draft-sara';
const _masters = {
  'L09_marriage_prep__not_started',
  'L09_marriage_prep__one_done',
  'L09_marriage_prep__all_done',
  'L09_marriage_prep__didnt_save',
};
final _capture = MasterCaptureHarness(feature: 'MARRIAGE_PREP');

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

Future<void> _local(WidgetTester tester, String key) async {
  // The actual Journey uses lazy vertical arrival/action pages. Follow its
  // existing scroll path if an action page has not yet been built.
  for (
    var attempt = 0;
    _key(key).evaluate().isEmpty && attempt < 3;
    attempt++
  ) {
    final pages = find.descendant(
      of: find.byType(SelahConceptJourneyPresentation),
      matching: find.byType(PageView),
    );
    expect(pages, findsWidgets);
    await tester.drag(pages.first, const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  await _tap(tester, _key(key));
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
            deck.profiles.every((profile) => profile.photos.isNotEmpty),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The actual local Browse deck did not prepare its bundled photos.');
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _journeyTab(WidgetTester tester) async {
  final nav = find.byType(SelahShellNavigation);
  expect(nav, findsOneWidget);
  final label = find.descendant(of: nav, matching: find.text('Journey'));
  expect(label, findsOneWidget);
  await tester.tapAt(tester.getCenter(label));
  await tester.pumpAndSettle();
}

Future<void> _scrollToCard(WidgetTester tester) async {
  final card = _key('marriage_prep_card');
  if (card.evaluate().isEmpty) {
    await _local(tester, 'concept_journey_arrival_continue');
  }
  expect(card, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(card), alignment: 1);
  await tester.pumpAndSettle();
  // Scroll the real content to its end, retaining the actual stage content
  // above the card and its current navigation/spacing. Nothing is redrawn.
  final scrollable = Scrollable.of(tester.element(card));
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pumpAndSettle();
  final viewport = Offset.zero & masterPhoneSize;
  expect(viewport.contains(tester.getRect(card).topLeft), isTrue);
  expect(
    viewport.contains(tester.getRect(card).bottomRight - const Offset(1, 1)),
    isTrue,
  );
  expect(tester.takeException(), isNull);
}

SelahMarriagePrepCard _card(WidgetTester tester) =>
    tester.widget<SelahMarriagePrepCard>(find.byType(SelahMarriagePrepCard));

Future<MasterScreen> _conversation(WidgetTester tester) async {
  final screen = await _capture.mount(
    tester,
    home: SelahConceptPreviewBoundary(
      child: SelahOneJourneyConceptShell(
        canAct: () => SelahDraftRuntime.active,
        onExit: () {},
      ),
    ),
  );
  await _waitForBrowse(tester);
  await _journeyTab(tester);
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('concept_journey_preview_1'));
  await _tap(tester, _key('draft_journey_$_person'));

  for (final stage in SelahJourneyStages.all) {
    final journey = tester.widget<SelahConceptJourneyPresentation>(
      find.byType(SelahConceptJourneyPresentation),
    );
    expect(journey.stage.value, stage.value);
    if (stage.value == 'conversation') break;
    expect(find.byType(SelahMarriagePrepCard), findsNothing);
    await _local(tester, 'concept_journey_arrival_continue');
    if (stage.value == 'greeting_exchange') {
      await _local(tester, 'draft_greeting_$_person');
      await _local(tester, 'draft_peer_greeting_$_person');
    } else if (stage.value == 'compatibility_reveal') {
      await _local(tester, 'draft_reveal_$_person');
      await _local(tester, 'draft_peer_reveal_$_person');
    }
    await _local(tester, 'draft_stage_ready_$_person');
    await _local(tester, 'draft_stage_peer_ready_$_person');
    await _local(tester, 'draft_stage_next_$_person');
  }
  await _scrollToCard(tester);
  expect(_card(tester).completedSteps, isEmpty);
  expect(_card(tester).saveFailed, isFalse);
  return screen;
}

Future<void> _toggle(WidgetTester tester, int step) async {
  await _tap(tester, _key('marriage_prep_step_$step'));
  await tester.pump(const Duration(seconds: 4));
  await _scrollToCard(tester);
}

Future<void> _failedPreset(WidgetTester tester) async {
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('marriage_prep_didnt_save'));
  await _scrollToCard(tester);
  expect(_card(tester).saveFailed, isTrue);
  expect(find.text('That didn’t save. Try again.'), findsOneWidget);
}

Future<void> _captureState(
  WidgetTester tester,
  MasterScreen screen,
  String master,
) async {
  // Let the app's real three-second result toast expire. Do not strip it or
  // mutate private notice state just to expose the bottom preparation row.
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  await _scrollToCard(tester);
  await _capture.capture(tester, screen, master);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? originalHttpOverrides;
  bool? originalFontFetching;

  setUpAll(() async {
    final present = Directory('${_capture.featureRoot.path}/MASTERS')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .map((file) => file.uri.pathSegments.last.replaceFirst('.png', ''))
        .toSet();
    expect(present, _masters);
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
          'Use --dart-define=SELAH_DRAFT_LOCAL_ONLY=true; '
          'the real draft-admission policy is required.',
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

  testWidgets('conversation preparation: not started', (tester) async {
    final screen = await _conversation(tester);
    await _captureState(tester, screen, 'L09_marriage_prep__not_started');
  });

  testWidgets('conversation preparation: one real row toggled', (tester) async {
    final screen = await _conversation(tester);
    await _toggle(tester, 0);
    expect(_card(tester).completedSteps, {0});
    await _captureState(tester, screen, 'L09_marriage_prep__one_done');
  });

  testWidgets('conversation preparation: all three done in any order', (
    tester,
  ) async {
    final screen = await _conversation(tester);
    for (final step in [2, 0, 1]) {
      await _toggle(tester, step);
    }
    expect(_card(tester).completedSteps, {0, 1, 2});
    expect(
      find.text(
        'You’ve finished your marriage preparation together. Well done.',
      ),
      findsOneWidget,
    );
    await _captureState(tester, screen, 'L09_marriage_prep__all_done');
  });

  testWidgets('conversation preparation: real private save-failure preset', (
    tester,
  ) async {
    final screen = await _conversation(tester);
    await _toggle(tester, 0);
    await _failedPreset(tester);
    expect(_card(tester).completedSteps, {0});
    await _captureState(tester, screen, 'L09_marriage_prep__didnt_save');
  });

  testWidgets('preparation ticks survive real Journey exit and re-entry', (
    tester,
  ) async {
    await _conversation(tester);
    await _toggle(tester, 2);
    await _toggle(tester, 0);
    await _tap(tester, _key('marriage_prep_step_2'));
    expect(find.text('Unmarked.'), findsOneWidget);
    expect(_card(tester).completedSteps, {0});
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tap(tester, _key('draft_journey_$_person'));
    await _scrollToCard(tester);
    expect(_card(tester).completedSteps, {0});
    expect(
      tester
          .widget<SelahConceptJourneyPresentation>(
            find.byType(SelahConceptJourneyPresentation),
          )
          .stage
          .value,
      'conversation',
    );
  });

  testWidgets(
    'failure retry clears only the error, retaining the checked step',
    (tester) async {
      await _conversation(tester);
      await _toggle(tester, 0);
      await _failedPreset(tester);
      await _tap(tester, _key('marriage_prep_retry'));
      expect(_card(tester).saveFailed, isFalse);
      expect(_card(tester).completedSteps, {0});
      expect(find.text('That didn’t save. Try again.'), findsNothing);
    },
  );
}
