// LOCK18/V3: all seven parts are genuinely saved before Deal-breakers opens.
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/models/selah_your_values_controller.dart';
import 'package:selah/screens/onboarding/selah_your_values_flow.dart';
import 'package:selah/widgets/selah_profile_questions.dart';
import 'package:selah/widgets/selah_shepherd_invite_views.dart';

import 'master_capture.dart';
import 'your_values_capture_driver.dart';

final _capture = MasterCaptureHarness(
  feature: 'YOUR_VALUES',
  version: 'LOCK18_V1',
);
const _masters = [
  'L18_dealbreakers',
  'L18_dealbreakers__chosen',
  'L18_dealbreakers__none',
  'L18_dealbreakers__saving',
  'L18_dealbreakers__didnt_save',
  'L18_values_overview__all_done',
  'L17_values_overview',
  'L17_values_overview__part_done',
];
void main() {
  configureYourValuesCaptures();
  for (final master in _masters) {
    testWidgets('LOCK18 actual root $master', (tester) async {
      final screen = await mountYourValues(tester, _capture);
      final flow = valuesFlow(tester);
      if (master == 'L17_values_overview__part_done') {
        await finishOneValuesPart(tester);
        expect(find.text('Done'), findsOneWidget);
      } else if (master != 'L17_values_overview') {
        await finishSevenValuesParts(tester);
        expect(flow.controller.allPartsDone, isTrue);
        expect(find.text('Done'), findsNWidgets(7));
        await valuesTap(tester, 'values_begin');
        expect(valuesKey('values_dealbreakers'), findsOneWidget);
        if (master.endsWith('__none') || master.endsWith('__all_done')) {
          await valuesTap(tester, 'values_dealbreaker_5');
        } else if (master != 'L18_dealbreakers') {
          await valuesTap(tester, 'values_dealbreaker_0');
        }
        if (master.endsWith('__saving') || master.endsWith('__didnt_save')) {
          await valuesPreset(
            tester,
            master.endsWith('__saving') ? 'values_saving' : 'values_failed',
          );
          expect(flow.controller.savingPartId, 'dealbreakers');
        } else if (master.endsWith('__all_done')) {
          await valuesTap(tester, 'values_dealbreakers_save');
          expect(flow.controller.dealbreakersDone, isTrue);
          expect(find.text('Done'), findsNWidgets(8));
        }
      }
      await _capture.capture(tester, screen, master);
    });
  }
  testWidgets(
    'LOCK18 None excludes choices, Retry saves real hard requirements and completes actual root',
    (tester) async {
      await mountYourValues(tester, _capture);
      final controller = valuesFlow(tester).controller;
      await finishSevenValuesParts(tester);
      await valuesTap(tester, 'values_begin');
      await valuesTap(tester, 'values_dealbreaker_0');
      await valuesTap(tester, 'values_dealbreaker_1');
      expect(controller.selectedDealbreakers, {0, 1});
      await valuesTap(tester, 'values_dealbreaker_5');
      expect(controller.selectedDealbreakers, {5});
      await valuesTap(tester, 'values_dealbreaker_0');
      expect(controller.selectedDealbreakers, {0});
      await valuesPreset(tester, 'values_failed');
      expect(controller.dealbreakersDone, isFalse);
      await valuesTap(tester, 'values_dealbreakers_retry');
      expect(valuesKey('values_overview'), findsOneWidget);
      expect(find.text('Done'), findsNWidgets(8));
      await valuesTap(tester, 'values_begin');
      expect(find.byType(SelahYourValuesFlow), findsNothing);
      final owner = tester
          .widget<SelahOneJourneyConceptShell>(
            find.byType(SelahOneJourneyConceptShell),
          )
          .accountSession!;
      expect(owner.compatibility.rawHardRequirements['ch3_q52'], {
        'I vape only',
        'I smoke only',
        'I both smoke and vape',
      });
      expect(
        owner.compatibility.rawHardRequirements.containsKey('ch3_q53'),
        isFalse,
      );
      expect(controller.current, isFalse);
      expect(await controller.saveDealbreakers(), isFalse);
    },
  );
  testWidgets(
    'LOCK18 stale choice after Back and saving preset cannot change addressed selection',
    (tester) async {
      await mountYourValues(tester, _capture);
      final controller = valuesFlow(tester).controller;
      await finishSevenValuesParts(tester);
      await valuesTap(tester, 'values_begin');
      final old = tester.widget<SelahProfileQuestionChoice>(
        valuesKey('values_dealbreaker_0'),
      );
      await valuesTap(tester, 'values_back');
      old.onTap();
      await tester.pumpAndSettle();
      expect(controller.selectedDealbreakers, isEmpty);
      await valuesTap(tester, 'values_begin');
      await valuesTap(tester, 'values_dealbreaker_5');
      final saveBefore = tester.getRect(valuesKey('values_dealbreakers_save'));
      await valuesPreset(tester, 'values_saving');
      expect(controller.saveState, SelahYourValuesSaveState.saving);
      final busy = tester.widget<SelahProfileQuestionChoice>(
        valuesKey('values_dealbreaker_0'),
      );
      busy.onTap();
      await tester.pumpAndSettle();
      expect(controller.selectedDealbreakers, {5});
      final save = tester.widget<SelahInviteButton>(
        valuesKey('values_dealbreakers_save'),
      );
      expect(save.onPressed, isNull);
      expect(
        tester.getRect(valuesKey('values_dealbreakers_save')).bottom,
        closeTo(saveBefore.bottom, .1),
      );
    },
  );
  testWidgets(
    'LOCK18 optional unselected Save writes no five deal-breaker keys',
    (tester) async {
      await mountYourValues(tester, _capture);
      await finishSevenValuesParts(tester);
      await valuesTap(tester, 'values_begin');
      expect(valuesFlow(tester).controller.selectedDealbreakers, isEmpty);
      await valuesTap(tester, 'values_dealbreakers_save');
      expect(find.text('Done'), findsNWidgets(8));
      await valuesTap(tester, 'values_begin');
      final owner = tester
          .widget<SelahOneJourneyConceptShell>(
            find.byType(SelahOneJourneyConceptShell),
          )
          .accountSession!;
      for (final id in ['ch3_q52', 'ch3_q53', 'ch3_q3', 'ch3_q2', 'ch3_q28']) {
        expect(
          owner.compatibility.rawHardRequirements.containsKey(id),
          isFalse,
        );
      }
    },
  );
}
