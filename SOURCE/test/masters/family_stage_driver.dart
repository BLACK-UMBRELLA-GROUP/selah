// Actual Family form interactions shared by later-stage capture drivers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/widgets/selah_shell_navigation.dart';

import 'master_capture.dart';

// Exact LOCK 22 prototype inputs. They enter through the real editable fields;
// no test writes a saved answer map or marks a participant sent directly.
const familyMasterAnswers = [
  'Through Pastor David’s suggestion and three months of honest answers. I have prayed about every stage.',
  'St Mark’s, where we both have friends. I would keep serving with the youth team.',
  'By being at Sunday lunch with them often, and asking her pastor to stay close to us.',
  'Pastor David and Pastor Ama, and the couples in our house group.',
];

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> tapFamilyControl(WidgetTester tester, String key) async {
  final target = _key(key);
  expect(target, findsOneWidget);
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> fillFamilyAnswers(
  WidgetTester tester, {
  bool firstOnly = false,
}) async {
  for (var index = 0; index < (firstOnly ? 1 : 4); index++) {
    final target = _key('family_answer_fam_q${index + 1}');
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.enterText(target, familyMasterAnswers[index]);
    await tester.pumpAndSettle();
    expect(
      find.text('${familyMasterAnswers[index].runes.length} of 400'),
      findsWidgets,
    );
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> finishFamilyAnswers(
  WidgetTester tester, {
  required String journeyId,
}) async {
  await fillFamilyAnswers(tester);
  await tapFamilyControl(tester, 'family_send');
  expect(_key('family_sent'), findsOneWidget);
  await tapFamilyControl(tester, 'draft_back');
  await tapFamilyControl(tester, 'draft_family_peer_send_$journeyId');
  expect(find.text('Both families have spoken.'), findsOneWidget);
  expect(find.textContaining('Waiting for '), findsNothing);
  await tapFamilyControl(tester, 'family_back');
}

Future<void> familyPageOption(WidgetTester tester, String key) async {
  await tapFamilyControl(tester, 'draft_back');
  await tapFamilyControl(tester, key);
}

Future<void> familyJourneyAction(WidgetTester tester, String key) async {
  if ([
    'draft_peer_greeting_',
    'draft_peer_reveal_',
    'draft_stage_peer_ready_',
  ].any(key.startsWith)) {
    await familyPageOption(tester, key);
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
  await tapFamilyControl(tester, key);
}

/// Stops at the real sixth stage, using the canonical list and current guarded
/// peer actions. It does not write any local model or add a historical event.
Future<MasterScreen> reachFamilyStage(
  WidgetTester tester, {
  required MasterCaptureHarness capture,
  String journeyId = 'draft-sara',
}) async {
  final screen = await capture.mount(tester, home: const SelahDraftRoot());
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
    fail('The actual root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  final nav = find.descendant(
    of: find.byType(SelahShellNavigation),
    matching: find.text('Journey'),
  );
  await tester.tapAt(tester.getCenter(nav));
  await tester.pumpAndSettle();
  await familyPageOption(tester, 'concept_journey_preview_1');
  await tapFamilyControl(tester, 'draft_journey_$journeyId');
  for (final stage in SelahJourneyStages.all) {
    final journey = tester.widget<SelahConceptJourneyPresentation>(
      find.byType(SelahConceptJourneyPresentation),
    );
    expect(journey.stage.value, stage.value);
    if (stage.value == 'family_stage') {
      expect(stage.order, 6);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      return screen;
    }
    await familyJourneyAction(tester, 'concept_journey_arrival_continue');
    if (stage.value == 'greeting_exchange') {
      await familyJourneyAction(tester, 'draft_greeting_$journeyId');
      await familyJourneyAction(tester, 'draft_peer_greeting_$journeyId');
    } else if (stage.value == 'compatibility_reveal') {
      await familyJourneyAction(tester, 'draft_reveal_$journeyId');
      await familyJourneyAction(tester, 'draft_peer_reveal_$journeyId');
    }
    await familyJourneyAction(tester, 'draft_stage_ready_$journeyId');
    await familyJourneyAction(tester, 'draft_stage_peer_ready_$journeyId');
    await familyJourneyAction(tester, 'draft_stage_next_$journeyId');
  }
  fail('The canonical stage list did not contain Family Compatibility.');
}

Future<void> openFamilyStage(
  WidgetTester tester, {
  String journeyId = 'draft-sara',
}) async {
  await familyJourneyAction(tester, 'concept_journey_arrival_continue');
  await familyJourneyAction(tester, 'draft_family_open_$journeyId');
  expect(_key('family_page'), findsOneWidget);
}
