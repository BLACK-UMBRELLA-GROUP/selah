// LOCK17/V3: every capture follows the actual protected sign-up route.
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_your_values_controller.dart';
import 'package:selah/widgets/selah_profile_questions.dart';

import 'master_capture.dart';
import 'your_values_capture_driver.dart';

final _capture = MasterCaptureHarness(feature: 'YOUR_VALUES');
const _masters = [
  'L17_values_overview',
  'L17_values_overview__part_done',
  'L17_values_question',
  'L17_values_question__chosen',
  'L17_values_question__optional',
  'L17_values_question__no_answer',
  'L17_values_part__saving',
  'L17_values_part__didnt_save',
];
void main() {
  configureYourValuesCaptures();
  for (final master in _masters) {
    testWidgets('LOCK17 actual root $master', (tester) async {
      final screen = await mountYourValues(tester, _capture);
      final flow = valuesFlow(tester);
      expect(flow.controller.parts.map((p) => p.name), [
        'Faith at home',
        'Marriage',
        'Family',
        'Money',
        'Home and roles',
        'Talking things through',
        'Everyday life',
      ]);
      expect(flow.controller.questionsRemaining, 27);
      if (master.endsWith('__part_done')) {
        await finishOneValuesPart(tester);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(flow.controller.questionsRemaining, 22);
      } else if (!master.startsWith('L17_values_overview')) {
        await valuesTap(tester, 'values_begin');
        if (master.endsWith('__optional')) {
          await answerValuesQuestion(tester);
          await answerValuesQuestion(tester);
          expect(valuesKey('values_skip'), findsOneWidget);
        } else if (master.endsWith('__chosen')) {
          await valuesTap(tester, 'values_choice_q1_0');
        } else if (master.endsWith('__no_answer')) {
          await valuesTap(tester, 'values_continue');
          expect(find.text('Choose one answer to continue.'), findsOneWidget);
        } else if (master.startsWith('L17_values_part')) {
          for (var i = 0; i < 4; i++) {
            await answerValuesQuestion(tester);
          }
          await valuesTap(tester, 'values_choice_q5_0');
          await valuesPreset(
            tester,
            master.endsWith('__saving') ? 'values_saving' : 'values_failed',
          );
          expect(
            flow.controller.saveState,
            master.endsWith('__saving')
                ? SelahYourValuesSaveState.saving
                : SelahYourValuesSaveState.failed,
          );
        }
      }
      await _capture.capture(tester, screen, master);
    });
  }
  testWidgets(
    'LOCK17 optional questions skip, required last validates, Retry saves one part',
    (tester) async {
      await mountYourValues(tester, _capture);
      final flow = valuesFlow(tester);
      await valuesTap(tester, 'values_begin');
      await answerValuesQuestion(tester);
      await answerValuesQuestion(tester);
      await answerValuesQuestion(tester, skip: true);
      await answerValuesQuestion(tester, skip: true);
      expect(valuesKey('values_skip'), findsNothing);
      await valuesTap(tester, 'values_save');
      expect(find.text('Choose one answer to continue.'), findsOneWidget);
      await valuesTap(tester, 'values_choice_q5_0');
      await valuesPreset(tester, 'values_failed');
      expect(
        flow.controller.isPartDone(flow.controller.parts.first.id),
        isFalse,
      );
      await valuesTap(tester, 'values_retry');
      expect(valuesKey('values_overview'), findsOneWidget);
      expect(
        flow.controller.isPartDone(flow.controller.parts.first.id),
        isTrue,
      );
      expect(find.text('Saved. 22 questions to go.'), findsOneWidget);
      expect(
        flow.controller.answerFor(
          flow.controller.questionsFor(flow.controller.parts.first.id)[2],
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'LOCK17 old question callbacks deny page change and root authority revocation',
    (tester) async {
      await mountYourValues(tester, _capture);
      final controller = valuesFlow(tester).controller;
      await valuesTap(tester, 'values_begin');
      final choice = tester.widget<SelahProfileQuestionChoice>(
        valuesKey('values_choice_q1_0'),
      );
      final question = controller.questionsFor(controller.parts.first.id).first;
      await valuesTap(tester, 'values_back');
      choice.onTap();
      await tester.pumpAndSettle();
      expect(controller.answerFor(question), isNull);
      await valuesTap(tester, 'values_begin');
      final currentChoice = tester.widget<SelahProfileQuestionChoice>(
        valuesKey('values_choice_q1_0'),
      );
      SelahDraftRuntime.stop();
      currentChoice.onTap();
      await tester.pumpAndSettle();
      expect(controller.current, isFalse);
      expect(controller.answerFor(question), isNull);
    },
  );
}
