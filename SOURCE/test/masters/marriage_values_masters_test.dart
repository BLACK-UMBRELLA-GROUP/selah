// LOCK 5 / DOC-SELAH-0020. Real admitted draft sign-up and Profile only.
// The empty Profile capture retains the reachable fixture; no partial answers
// are injected merely to match the prototype's unsaved example.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/selah_marriage_values_controller.dart';
import 'package:selah/screens/onboarding/selah_marriage_values_flow.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_marriage_values_views.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';
import 'your_values_driver.dart';

const _questions = <int, String>{
  1: 'L05_marriage_1_married_before__empty',
  2: 'L05_marriage_2_children__empty',
  3: 'L05_marriage_3_want_children__empty',
  4: 'L05_marriage_4_roles__empty',
  5: 'L05_marriage_5_divorced_partner__empty',
  6: 'L05_marriage_6_where_to_live__empty',
  7: 'L05_marriage_7_when_to_marry__empty',
};
const _answers = <int, int>{1: 0, 2: 0, 3: 0, 4: 1, 5: 1, 6: 1, 7: 1};
const _words =
    'Church is where I grew up. I want a home where we pray together and serve together.';
final _masters = <String>{
  ..._questions.values,
  'L05_marriage_1_married_before__error',
  'L05_marriage_4_roles__selected',
  'L05_marriage_7__saving',
  'L05_marriage_7__didnt_save',
  'L05_faith_7__continues_to_marriage',
  'L05_profile_marriage__answered',
  'L05_profile_marriage__not_answered',
};
final _capture = MasterCaptureHarness(feature: 'MARRIAGE_VALUES');
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
    fail('The actual root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<MasterScreen> _mountRoot(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitForBrowse(tester);
  return screen;
}

Future<MasterScreen> _startFaith(WidgetTester tester) async {
  final screen = await _mountRoot(tester);
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
  expect(_key('faith_question_7'), findsOneWidget);
  return screen;
}

Future<MasterScreen> _startMarriage(
  WidgetTester tester, {
  bool words = false,
}) async {
  final screen = await _startFaith(tester);
  if (words) await tester.enterText(_key('faith_words'), _words);
  await _tap(tester, _key(words ? 'faith_save' : 'faith_skip'));
  expect(_key('marriage_question_1'), findsOneWidget);
  // Let the actual Faith-save result expire before using the next primary.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  return screen;
}

SelahMarriageValuesController _controller(WidgetTester tester) => tester
    .widget<SelahMarriageValuesFlow>(find.byType(SelahMarriageValuesFlow))
    .controller;
SelahRequestAccountSession _owner(WidgetTester tester) => tester
    .widget<SelahOneJourneyConceptShell>(
      find.byType(SelahOneJourneyConceptShell),
    )
    .accountSession!;

Future<void> _advanceTo(WidgetTester tester, int question) async {
  for (var q = 1; q < question; q++) {
    await _tap(tester, _key('marriage_choice_q${q}_${_answers[q]}'));
    await _tap(tester, _key('marriage_continue'));
  }
  expect(_key('marriage_question_$question'), findsOneWidget);
}

Future<void> _finishLanguages(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await _tap(tester, _key('language_choice_0'));
  await _tap(tester, _key('languages_save'));
  if (_key('values_overview').evaluate().isNotEmpty) {
    await finishYourValuesFromOverview(tester);
  }
}

Future<void> _showProfile(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final nav = find.byType(SelahShellNavigation);
  final profile = find.descendant(of: nav, matching: find.text('Profile'));
  await tester.tapAt(tester.getCenter(profile));
  await tester.pumpAndSettle();
  final card = _key('marriage_values_card');
  expect(card, findsOneWidget);
  // The member dock overlays the page viewport. Scroll the real final row
  // above it, so every marriage value is visible in the evidence.
  final lastRow = _key('marriage_values_row_6');
  await Scrollable.ensureVisible(tester.element(lastRow), alignment: .75);
  await tester.pumpAndSettle();
  expect(
    tester.getRect(lastRow).bottom,
    lessThan(masterPhoneSize.height - 100),
  );
  expect(tester.takeException(), isNull);
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
  HttpOverrides? originalHttpOverrides;
  bool? originalFontFetching;
  setUpAll(() async {
    final present = Directory('${_capture.featureRoot.path}/MASTERS')
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.png') &&
              f.uri.pathSegments.last.startsWith('L05_'),
        )
        .map((f) => f.uri.pathSegments.last.replaceFirst('.png', ''))
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
          'The actual draft runtime requires --dart-define=SELAH_DRAFT_LOCAL_ONLY=true.',
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

  for (final entry in _questions.entries) {
    testWidgets('marriage question ${entry.key}: actual empty screen', (
      tester,
    ) async {
      final screen = await _startMarriage(tester);
      await _advanceTo(tester, entry.key);
      expect(_key('marriage_skip'), findsNothing);
      await _captureState(tester, screen, entry.value);
    });
  }
  testWidgets('faith 7: actual screen that continues to marriage', (
    tester,
  ) async {
    final screen = await _startFaith(tester);
    await _captureState(tester, screen, 'L05_faith_7__continues_to_marriage');
  });
  testWidgets('marriage: required validation from Continue', (tester) async {
    final screen = await _startMarriage(tester);
    await _tap(tester, _key('marriage_continue'));
    expect(find.text('Choose one answer to continue.'), findsOneWidget);
    await _captureState(tester, screen, 'L05_marriage_1_married_before__error');
  });
  testWidgets('marriage roles: real selected answer', (tester) async {
    final screen = await _startMarriage(tester);
    await _advanceTo(tester, 4);
    await _tap(tester, _key('marriage_choice_q4_1'));
    expect(
      _controller(tester).answers.rolesInMarriage,
      'Equal partners who decide together',
    );
    await _captureState(tester, screen, 'L05_marriage_4_roles__selected');
  });
  for (final (state, master) in [
    ('saving', 'L05_marriage_7__saving'),
    ('failed', 'L05_marriage_7__didnt_save'),
  ]) {
    testWidgets('marriage $state: actual guarded private preset', (
      tester,
    ) async {
      final screen = await _startMarriage(tester);
      await _advanceTo(tester, 7);
      await _tap(tester, _key('marriage_choice_q7_1'));
      final controller = _controller(tester);
      if (state == 'saving') {
        controller.showSaving();
      } else {
        controller.showFailure();
      }
      await tester.pumpAndSettle();
      expect(controller.answers.hopingToMarry, 'In 1–2 years');
      await _captureState(tester, screen, master);
    });
  }
  testWidgets('marriage Profile: actual save is read by the existing owner', (
    tester,
  ) async {
    final screen = await _startMarriage(tester, words: true);
    await _advanceTo(tester, 7);
    await _tap(tester, _key('marriage_choice_q7_1'));
    final expected = _controller(tester).answers.toMap();
    await _tap(tester, _key('marriage_save'));
    await _finishLanguages(tester);
    await _waitForBrowse(tester);
    expect(_owner(tester).marriageAnswers.toMap(), expected);
    await _showProfile(tester);
    expect(
      tester
          .widget<SelahMarriageValuesCard>(find.byType(SelahMarriageValuesCard))
          .answers
          .toMap(),
      expected,
    );
    await _captureState(tester, screen, 'L05_profile_marriage__answered');
  });
  testWidgets('marriage Profile: actual initial unanswered profile', (
    tester,
  ) async {
    final screen = await _mountRoot(tester);
    expect(_owner(tester).marriageAnswers.toMap().values, everyElement(isNull));
    await _showProfile(tester);
    final card = _key('marriage_values_card');
    expect(
      find.descendant(of: card, matching: find.text('Not answered')),
      findsNWidgets(7),
    );
    await _captureState(tester, screen, 'L05_profile_marriage__not_answered');
  });
  testWidgets('marriage: all seven answers are required and single choice', (
    tester,
  ) async {
    await _startMarriage(tester);
    for (var q = 1; q <= 7; q++) {
      await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
      expect(_key('marriage_question_$q'), findsOneWidget);
      expect(_key('marriage_required_error'), findsOneWidget);
      await _tap(tester, _key('marriage_choice_q${q}_1'));
      await _tap(tester, _key('marriage_choice_q${q}_0'));
      expect(_controller(tester).showRequiredErrorFor(q), isFalse);
      if (q < 7) await _tap(tester, _key('marriage_continue'));
    }
  });
  testWidgets('marriage: Back retains answers across the faith boundary', (
    tester,
  ) async {
    await _startMarriage(tester);
    await _tap(tester, _key('marriage_choice_q1_2'));
    final controller = _controller(tester);
    await _tap(tester, _key('marriage_continue'));
    await _tap(tester, _key('marriage_choice_q2_1'));
    await _tap(tester, _key('marriage_back'));
    expect(controller.answers.marriedBefore, 'Yes, widowed');
    await _tap(tester, _key('marriage_back'));
    expect(_key('faith_question_7'), findsOneWidget);
    await _tap(tester, _key('faith_skip'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_key('marriage_question_1'), findsOneWidget);
    expect(_controller(tester).answers.marriedBefore, 'Yes, widowed');
    expect(_controller(tester).answers.children, 'Yes, they live with me');
  });
  testWidgets('marriage: failed retry preserves answers and saves once', (
    tester,
  ) async {
    await _startMarriage(tester);
    await _advanceTo(tester, 7);
    await _tap(tester, _key('marriage_choice_q7_1'));
    final controller = _controller(tester);
    final answers = controller.answers.toMap();
    controller.showFailure();
    await tester.pumpAndSettle();
    await _tap(tester, _key('marriage_retry'));
    expect(find.text('Marriage values saved.'), findsOneWidget);
    await _finishLanguages(tester);
    await _waitForBrowse(tester);
    expect(_owner(tester).marriageAnswers.toMap(), answers);
  });
}
