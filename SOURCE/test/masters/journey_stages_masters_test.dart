// LOCK 21 / Q15: nine new comparisons through the actual root and its current
// guarded local Journey walkthrough. Earlier feature evidence is untouched.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/data/selah_journey_header.dart';
import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_marriage_prep_card.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

const _person = 'draft-sara';
final _capture = MasterCaptureHarness(
  feature: 'JOURNEY_STAGES',
  wordingRevision: false,
);
const _lookMasters = [
  'L01_seeker_journey__stages',
  'L01_seeker_journeys__pending_and_free_place',
  'L01_seeker_my_selah__request',
  'L01_seeker_profile__faith',
  'L01_shepherd_seekers',
];
const _prepStates = ['not_started', 'one_done', 'all_done', 'didnt_save'];
Finder _key(String key) => find.byKey(ValueKey<String>(key));

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
      if (tester
          .widgetList<SelahOneJourneyBrowseDesigns>(
            find.byType(SelahOneJourneyBrowseDesigns),
          )
          .any(
            (deck) =>
                deck.profiles.isNotEmpty &&
                deck.profiles.every((profile) => profile.photos.isNotEmpty),
          )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The actual root did not publish its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  return screen;
}

Future<void> _preset(WidgetTester tester, String key) async {
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key(key));
}

Future<void> _back(WidgetTester tester) async {
  final scope = _key('concept_pull_down_back_scope');
  await tester.dragFrom(
    tester.getTopLeft(scope) + const Offset(180, 90),
    const Offset(0, 270),
  );
  await tester.pumpAndSettle();
}

Future<void> _journeyAction(WidgetTester tester, String key) async {
  if ([
    'draft_peer_greeting_',
    'draft_peer_reveal_',
    'draft_stage_peer_ready_',
  ].any(key.startsWith)) {
    await _preset(tester, key);
    return;
  }
  for (
    var attempt = 0;
    _key(key).evaluate().isEmpty && attempt < 4;
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

SelahConceptJourneyPresentation _journey(WidgetTester tester) =>
    tester.widget<SelahConceptJourneyPresentation>(
      find.byType(SelahConceptJourneyPresentation),
    );

Future<MasterScreen> _reachStage(WidgetTester tester, String target) async {
  final screen = await _mount(tester);
  await _tab(tester, 'Journey');
  await _preset(tester, 'concept_journey_preview_1');
  await _tap(tester, _key('draft_journey_$_person'));
  final visited = <String>[];
  for (final expected in SelahJourneyStages.all) {
    final journey = _journey(tester);
    expect(journey.stage.value, expected.value);
    visited.add(journey.stage.value);
    expect(journey.stage.value, isNot('mentor_gate'));
    if (journey.stage.value == target) {
      break;
    }
    await _journeyAction(tester, 'concept_journey_arrival_continue');
    if (journey.stage.value == 'greeting_exchange') {
      await _journeyAction(tester, 'draft_greeting_$_person');
      await _journeyAction(tester, 'draft_peer_greeting_$_person');
    } else if (journey.stage.value == 'compatibility_reveal') {
      await _journeyAction(tester, 'draft_reveal_$_person');
      await _journeyAction(tester, 'draft_peer_reveal_$_person');
    }
    await _journeyAction(tester, 'draft_stage_ready_$_person');
    await _journeyAction(tester, 'draft_stage_peer_ready_$_person');
    await _journeyAction(tester, 'draft_stage_next_$_person');
  }
  expect(_journey(tester).stage.value, target);
  expect(visited, isNot(contains('mentor_gate')));
  expect(SelahJourneyStages.count, 7);
  await _expireNotice(tester);
  return screen;
}

SelahMarriagePrepCard _card(WidgetTester tester) =>
    tester.widget<SelahMarriagePrepCard>(find.byType(SelahMarriagePrepCard));

Future<void> _scrollToPrep(WidgetTester tester) async {
  final card = _key('marriage_prep_card');
  if (card.evaluate().isEmpty) {
    await _journeyAction(tester, 'concept_journey_arrival_continue');
  }
  expect(card, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(card), alignment: 1);
  await tester.pumpAndSettle();
  final scroll = Scrollable.of(tester.element(card));
  scroll.position.jumpTo(scroll.position.maxScrollExtent);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _togglePrep(WidgetTester tester, int step) async {
  await _tap(tester, _key('marriage_prep_step_$step'));
  await _expireNotice(tester);
  await _scrollToPrep(tester);
}

Future<void> _requestGrace(WidgetTester tester) async {
  await _tab(tester, 'My Selah');
  await _tap(tester, find.text('View requests').first);
  await _tap(tester, _key('concept_request_draft-amira_header'));
  await _tap(tester, _key('draft_decline_draft-amira'));
  await _back(tester);
  await _expireNotice(tester);
  await _tab(tester, 'Browse');
  final seen = <String>{};
  while (true) {
    final browse = tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );
    final id = browse.profiles[browse.selectedIndex].id;
    if (id == 'draft-amira') {
      break;
    }
    expect(
      seen.add(id),
      isTrue,
      reason: 'Advance the actual eligible frontier',
    );
    await _tap(tester, _key('concept_next_profile'));
  }
  await _tap(tester, _key('draft_profile_draft-amira'));
  await _tap(tester, _key('pause_confirm'));
  await _expireNotice(tester);
  await _tab(tester, 'Journey');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFetching;
  setUpAll(() async {
    for (final name in _lookMasters) {
      expect(
        File('../APP/APPROVED/LOOK/MASTERS/$name.png').existsSync(),
        isTrue,
      );
    }
    for (final state in _prepStates) {
      expect(
        File(
          '../APP/APPROVED/MARRIAGE_PREP/MASTERS/L09_marriage_prep__$state.png',
        ).existsSync(),
        isTrue,
      );
    }
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

  for (final master in _lookMasters) {
    testWidgets('LOCK21 actual-root comparison $master', (tester) async {
      final screen = await _reachStage(tester, 'phase_1');
      if (master == 'L01_seeker_journey__stages') {
        expect(_journey(tester).stage.order, 3);
        expect(
          find.text(
            'Stage 3 of 7 · Shepherds: Pastor David and Pastor Ama Mensah',
          ),
          findsOneWidget,
        );
      } else {
        await _back(tester);
        if (master == 'L01_seeker_journeys__pending_and_free_place') {
          await _requestGrace(tester);
          expect(
            tester.widget<Text>(_key('journey_stage_caption_$_person')).data,
            'Stage 3 of 7 · Faith & Values',
          );
        } else if (master == 'L01_seeker_my_selah__request') {
          await _tab(tester, 'My Selah');
        } else if (master == 'L01_seeker_profile__faith') {
          await _tab(tester, 'Profile');
        } else {
          await _tab(tester, 'Journey');
          await _preset(tester, 'draft_role_shepherd');
          await _tab(tester, 'Seekers');
          expect(
            find.textContaining('Stage 3 · Faith & Values'),
            findsOneWidget,
          );
        }
      }
      await _expireNotice(tester);
      await _capture.capture(
        tester,
        screen,
        master,
        masterFile: File('../APP/APPROVED/LOOK/MASTERS/$master.png'),
      );
    });
  }

  for (final state in _prepStates) {
    testWidgets('LOCK21 actual-root Marriage preparation $state', (
      tester,
    ) async {
      final screen = await _reachStage(tester, 'conversation');
      expect(_journey(tester).stage.order, 7);
      await _scrollToPrep(tester);
      expect(_card(tester).completedSteps, isEmpty);
      if (state != 'not_started') {
        await _togglePrep(tester, 0);
      }
      if (state == 'all_done') {
        await _togglePrep(tester, 1);
        await _togglePrep(tester, 2);
        expect(_card(tester).completedSteps, {0, 1, 2});
      } else if (state == 'didnt_save') {
        await _preset(tester, 'marriage_prep_didnt_save');
        await _scrollToPrep(tester);
        expect(_card(tester).completedSteps, {0});
        expect(_card(tester).saveFailed, isTrue);
      }
      await _expireNotice(tester);
      await _capture.capture(
        tester,
        screen,
        'L09_marriage_prep__$state',
        masterFile: File(
          '../APP/APPROVED/MARRIAGE_PREP/MASTERS/L09_marriage_prep__$state.png',
        ),
      );
    });
  }

  test(
    'Q15 header uses only supplied own Main and the permitted peer label',
    () {
      expect(
        selahJourneyStageHeader(
          stageOrder: 3,
          counterpartFirstName: 'Esther',
          ownMainShepherdName: 'Pastor David',
          otherMainShepherdName: 'Pastor Ama Mensah',
        ),
        'Stage 3 of 7 · Shepherds: Pastor David and Pastor Ama Mensah',
      );
      expect(
        selahJourneyStageHeader(
          stageOrder: 3,
          counterpartFirstName: 'Esther',
          ownMainShepherdName: 'Pastor David',
        ),
        'Stage 3 of 7 · Shepherds: Pastor David and Esther’s Shepherd',
      );
      for (final own in [null, '', '   ']) {
        expect(
          selahJourneyStageHeader(
            stageOrder: 3,
            counterpartFirstName: 'Esther',
            ownMainShepherdName: own,
            otherMainShepherdName: 'Pastor Ama Mensah',
          ),
          'Stage 3 of 7',
        );
      }
    },
  );
}
