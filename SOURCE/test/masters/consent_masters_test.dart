// LOCK 6 comparisons through the actual admitted draft sign-up route.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'master_capture.dart';
import 'package:selah/screens/onboarding/selah_faith_profile_flow.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/models/selah_sign_up_compatibility.dart';

final _capture = MasterCaptureHarness(feature: 'CONSENT');
Finder _key(String value) => find.byKey(ValueKey<String>(value));
Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _browse(WidgetTester tester) async {
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
    fail('Actual draft Browse did not prepare.');
  });
  await tester.pumpAndSettle();
}

Future<MasterScreen> _consent(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _browse(tester);
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Seeker'));
  await _tap(tester, _key('invite_begin'));
  await _tap(tester, _key('invite_choice_1'));
  await _tap(tester, _key('invite_continue'));
  await tester.enterText(_key('invite_name'), 'David Okafor');
  await _tap(tester, find.text('THEIR NAME'));
  await _tap(tester, _key('invite_send'));
  await _tap(tester, _key('invite_sent_continue'));
  expect(_key('consent_screen'), findsOneWidget);
  return screen;
}

Future<void> _captureState(
  WidgetTester tester,
  MasterScreen screen,
  String master,
) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await _capture.capture(tester, screen, master);
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
    GoogleFonts.config.allowRuntimeFetching = oldFonts!;
    HttpOverrides.global = oldHttp;
  });
  testWidgets('consent default through actual invite', (tester) async {
    final screen = await _consent(tester);
    await _captureState(tester, screen, 'L06_consent');
  });
  testWidgets('consent saving private preset', (tester) async {
    final screen = await _consent(tester);
    await _tap(tester, _key('dev_rail_actions'));
    await _tap(tester, _key('consent_saving'));
    expect(_key('consent_skip'), findsNothing);
    expect(find.text('Saving…'), findsOneWidget);
    await _captureState(tester, screen, 'L06_consent__saving');
  });
  testWidgets('consent failure private preset and retry', (tester) async {
    final screen = await _consent(tester);
    await _tap(tester, _key('dev_rail_actions'));
    await _tap(tester, _key('consent_failed'));
    await _captureState(tester, screen, 'L06_consent__didnt_save');
    await _tap(tester, _key('consent_retry'));
    expect(_key('consent_failure'), findsNothing);
    expect(_key('faith_question_1'), findsOneWidget);
  });
  testWidgets('skip preserves sign-up and exposes skipped faith note', (
    tester,
  ) async {
    final screen = await _consent(tester);
    await _tap(tester, _key('consent_skip'));
    expect(_key('marriage_question_1'), findsOneWidget);
    expect(_key('faith_question_1'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('marriage_back'));
    expect(_key('consent_screen'), findsOneWidget);
    await _tap(tester, _key('consent_skip'));
    await tester.pump(const Duration(seconds: 5));
    for (var q = 1; q <= 7; q++) {
      await _tap(tester, _key('marriage_choice_q${q}_0'));
      await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
    }
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('language_choice_0'));
    await _tap(tester, _key('languages_save'));
    await _browse(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(
      tester,
      find.descendant(
        of: find.byType(SelahShellNavigation),
        matching: find.text('Profile'),
      ),
    );
    final section = _key('faith_profile_section');
    await Scrollable.ensureVisible(tester.element(section), alignment: .3);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You chose not to share these. You can change this in Settings.',
      ),
      findsOneWidget,
    );
    await _captureState(tester, screen, 'L06_profile_faith__skipped');
  });
  testWidgets('consent Back returns sent and agree precedes faith', (
    tester,
  ) async {
    await _consent(tester);
    await _tap(tester, _key('consent_back'));
    expect(_key('invite_sent_continue'), findsOneWidget);
    await _tap(tester, _key('invite_sent_continue'));
    await _tap(tester, _key('consent_agree'));
    expect(_key('faith_question_1'), findsOneWidget);
    await _tap(tester, _key('faith_back'));
    expect(_key('consent_screen'), findsOneWidget);
  });
  testWidgets('saved faith is cleared by Back and Skip in the same owner', (
    tester,
  ) async {
    await _consent(tester);
    await _tap(tester, _key('consent_agree'));
    final oldEditor = tester
        .widget<SelahFaithProfileFlow>(find.byType(SelahFaithProfileFlow))
        .controller;
    for (var q = 1; q <= 6; q++) {
      if (q == 5) {
        await _tap(tester, _key('faith_skip'));
      } else {
        await _tap(tester, _key('faith_choice_q${q}_0'));
        await _tap(tester, _key('faith_continue'));
      }
    }
    await _tap(tester, _key('faith_skip'));
    expect(_key('marriage_question_1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('marriage_back'));
    for (var q = 7; q >= 1; q--) {
      await _tap(tester, _key('faith_back'));
    }
    expect(_key('consent_screen'), findsOneWidget);
    await _tap(tester, _key('consent_skip'));
    expect(await oldEditor.save(), isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('marriage_back'));
    await _tap(tester, _key('consent_agree'));
    expect(
      tester
          .widget<SelahFaithProfileFlow>(find.byType(SelahFaithProfileFlow))
          .controller
          .answers
          .tradition,
      isNull,
    );
    await _tap(tester, _key('faith_back'));
    await _tap(tester, _key('consent_skip'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    for (var q = 1; q <= 7; q++) {
      await _tap(tester, _key('marriage_choice_q${q}_0'));
      await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
    }
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('language_choice_0'));
    await _tap(tester, _key('languages_save'));
    await _browse(tester);
    final owner = tester
        .widget<SelahOneJourneyConceptShell>(
          find.byType(SelahOneJourneyConceptShell),
        )
        .accountSession!;
    expect(owner.faithAnswers.tradition, isNull);
    expect(owner.faithAnswers.words, isEmpty);
    expect(owner.marriageAnswers.requiredComplete, isTrue);
    expect(owner.details.languages.length, 1);
    final projection = SelahSignUpCompatibility.fromPreferences(
      owner.details.preferences,
    );
    for (final id in ['ch3_q46', 'ch3_q39', 'ch3_q40']) {
      expect(projection.bankAnswers.containsKey(id), isFalse);
    }
  });
}
