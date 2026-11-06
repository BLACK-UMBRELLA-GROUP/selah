import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/screens/onboarding/selah_your_values_flow.dart';
import 'package:selah/widgets/selah_profile_questions.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _tap(WidgetTester tester, String key) async {
  final target = _key(key);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _expireSaveToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Complete the real LOCK17/18 flow through its visible answers and saves.
/// Controller data is read only; no answers/completion/authority are injected.
Future<void> finishYourValuesFromOverview(WidgetTester tester) async {
  expect(_key('values_overview'), findsOneWidget);
  final flow = tester.widget<SelahYourValuesFlow>(
    find.byType(SelahYourValuesFlow),
  );
  final parts = flow.controller.parts;
  for (final part in parts) {
    if (flow.controller.isPartDone(part.id)) continue;
    await _expireSaveToast(tester);
    await _tap(tester, 'values_begin');
    final count = flow.controller.questionsFor(part.id).length;
    for (var number = 1; number <= count; number++) {
      final page = tester.widget<SelahProfileQuestionPage>(
        find.byType(SelahProfileQuestionPage),
      );
      expect(page.keyPrefix, 'values');
      expect(page.questionNumber, number);
      expect(page.questions.length, count);
      await _tap(tester, 'values_choice_q${number}_0');
      await _tap(tester, number == count ? 'values_save' : 'values_continue');
    }
    expect(_key('values_overview'), findsOneWidget);
    expect(flow.controller.isPartDone(part.id), isTrue);
  }
  expect(flow.controller.allPartsDone, isTrue);
  await _expireSaveToast(tester);
  await _tap(tester, 'values_begin');
  expect(_key('values_dealbreakers'), findsOneWidget);
  await _tap(tester, 'values_dealbreaker_5');
  await _tap(tester, 'values_dealbreakers_save');
  expect(_key('values_overview'), findsOneWidget);
  expect(flow.controller.dealbreakersDone, isTrue);
  await _tap(tester, 'values_begin');
  expect(find.byType(SelahYourValuesFlow), findsNothing);
}
