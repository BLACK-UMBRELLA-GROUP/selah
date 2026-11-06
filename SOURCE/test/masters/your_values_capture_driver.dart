// Real sign-up traversal for LOCK17/18 captures. No answers, completion or
// admission are injected into the flow being captured.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/screens/onboarding/selah_your_values_flow.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_profile_questions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

Finder valuesKey(String value) => find.byKey(ValueKey<String>(value));
Future<void> valuesTap(WidgetTester tester, String key) async {
  final target = valuesKey(key);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> valuesExpireToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void configureYourValuesCaptures() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFetching;
  setUpAll(() async {
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
}

Future<MasterScreen> mountYourValues(
  WidgetTester tester,
  MasterCaptureHarness capture,
) async {
  final screen = await capture.mount(tester, home: const SelahDraftRoot());
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
    fail('The actual root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  await valuesTap(tester, 'draft_close');
  await tester.tap(find.text('Explore as a Seeker'));
  await tester.pumpAndSettle();
  await valuesTap(tester, 'invite_begin');
  await valuesTap(tester, 'invite_choice_1');
  await valuesTap(tester, 'invite_continue');
  await tester.enterText(valuesKey('invite_name'), 'David Okafor');
  await tester.tap(find.text('THEIR NAME'));
  await tester.pumpAndSettle();
  await valuesTap(tester, 'invite_send');
  await valuesTap(tester, 'invite_sent_continue');
  await valuesTap(tester, 'consent_agree');
  for (final (q, choice) in [(1, 1), (2, 0), (3, 0), (4, 1), (5, 1), (6, 0)]) {
    await valuesTap(tester, 'faith_choice_q${q}_$choice');
    await valuesTap(tester, 'faith_continue');
  }
  await valuesTap(tester, 'faith_skip');
  await valuesExpireToast(tester);
  for (var q = 1; q <= 7; q++) {
    await valuesTap(tester, 'marriage_choice_q${q}_0');
    await valuesTap(tester, q == 7 ? 'marriage_save' : 'marriage_continue');
  }
  await valuesExpireToast(tester);
  await valuesTap(tester, 'language_choice_0');
  await valuesTap(tester, 'languages_save');
  await valuesExpireToast(tester);
  expect(valuesKey('values_overview'), findsOneWidget);
  return screen;
}

SelahYourValuesFlow valuesFlow(WidgetTester tester) =>
    tester.widget<SelahYourValuesFlow>(find.byType(SelahYourValuesFlow));
Future<void> answerValuesQuestion(
  WidgetTester tester, {
  bool skip = false,
}) async {
  final page = tester.widget<SelahProfileQuestionPage>(
    find.byType(SelahProfileQuestionPage),
  );
  if (skip) {
    await valuesTap(tester, 'values_skip');
  } else {
    await valuesTap(tester, 'values_choice_q${page.questionNumber}_0');
    await valuesTap(
      tester,
      page.questionNumber == page.questions.length
          ? 'values_save'
          : 'values_continue',
    );
  }
}

Future<void> finishOneValuesPart(WidgetTester tester) async {
  final flow = valuesFlow(tester);
  final part = flow.controller.parts.firstWhere(
    (part) => !flow.controller.isPartDone(part.id),
  );
  final count = flow.controller.questionsFor(part.id).length;
  await valuesExpireToast(tester);
  await valuesTap(tester, 'values_begin');
  for (var i = 0; i < count; i++) {
    await answerValuesQuestion(tester);
  }
  expect(valuesKey('values_overview'), findsOneWidget);
  expect(flow.controller.isPartDone(part.id), isTrue);
  await valuesExpireToast(tester);
}

Future<void> finishSevenValuesParts(WidgetTester tester) async {
  while (!valuesFlow(tester).controller.allPartsDone) {
    await finishOneValuesPart(tester);
  }
}

Future<void> valuesPreset(WidgetTester tester, String key) async {
  await valuesTap(tester, 'dev_rail_actions');
  await valuesTap(tester, key);
}
