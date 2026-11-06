// LOCK 4 / Step 4b comparisons through the actual draft sign-up and Profile.
// All answers are fictional, owned by the existing guarded local session.
// Screens are never recreated in the test and draft admission stays required.
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

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
import 'package:selah/models/selah_faith_profile_controller.dart';
import 'package:selah/screens/onboarding/selah_faith_profile_flow.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/services/selah_seeker_details_service.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_faith_profile_card.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

const _shortWords = 'Church is where I grew up.';
const _fullWords =
    'Church is where I grew up. I want a home where we pray '
    'together and serve together.';
const _questions = <int, String>{
  1: 'L04_faith_1_tradition__empty',
  2: 'L04_faith_2_church__empty',
  3: 'L04_faith_3_baptised__empty',
  4: 'L04_faith_4_christian_for__empty',
  5: 'L04_faith_5_serving__empty',
  6: 'L04_faith_6_open__empty',
  7: 'L04_faith_7_own_words__empty',
};
final _masters = <String>{
  ..._questions.values,
  'L04_faith_1_tradition__selected',
  'L04_faith_1_tradition__error',
  'L04_faith_5_serving__selected',
  'L04_faith_7_own_words__filled',
  'L04_faith_7_own_words__too_long',
  'L04_faith_7__saving',
  'L04_faith_7__didnt_save',
  'L04_profile_faith__answered',
  'L04_profile_faith__not_answered',
};
final _capture = MasterCaptureHarness(feature: 'FAITH_PROFILE');
final _profileCapture = MasterCaptureHarness(
  feature: 'FAITH_PROFILE',
  version: 'V1_1',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

class _RootFaith {
  _RootFaith(this.screen, this.session);
  final MasterScreen screen;
  final SelahRequestAccountSession session;
}

SelahFaithProfileController _controller(WidgetTester tester) => tester
    .widget<SelahFaithProfileFlow>(find.byType(SelahFaithProfileFlow))
    .controller;

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
            deck.profiles.every((person) => person.photos.isNotEmpty),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The actual draft Browse deck did not prepare its local portraits.');
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<_RootFaith> _mountRoot(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitForBrowse(tester);
  final session = tester
      .widget<SelahOneJourneyConceptShell>(
        find.byType(SelahOneJourneyConceptShell),
      )
      .accountSession!;
  return _RootFaith(screen, session);
}

Future<_RootFaith> _startFaith(WidgetTester tester) async {
  final root = await _mountRoot(tester);
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Seeker'));
  await _inviteToFaith(tester);
  // The sign-up may legitimately create a new session generation. Capture its
  // actual owner on return to Browse, rather than assume the old one survives.
  return root;
}

Future<void> _inviteToFaith(WidgetTester tester) async {
  await _tap(tester, _key('invite_begin'));
  await _tap(tester, _key('invite_choice_1'));
  await _tap(tester, _key('invite_continue'));
  await tester.enterText(_key('invite_name'), 'David Okafor');
  await _tap(tester, find.text('THEIR NAME'));
  await _tap(tester, _key('invite_send'));
  await _tap(tester, _key('invite_sent_continue'));
  await _tap(tester, _key('consent_agree'));
  expect(_key('faith_question_1'), findsOneWidget);
}

Future<void> _answerQuestion(WidgetTester tester, int question) async {
  switch (question) {
    case 1:
      await _tap(tester, _key('faith_choice_q1_1')); // Baptist
    case 2:
      await _tap(tester, _key('faith_choice_q2_0')); // Every week
    case 3:
      await _tap(tester, _key('faith_choice_q3_0')); // Yes
    case 4:
      await _tap(tester, _key('faith_choice_q4_1')); // More than 10 years
    case 5:
      await _tap(tester, _key('faith_choice_q5_1')); // Youth
      await _tap(tester, _key('faith_choice_q5_5')); // Prayer
    case 6:
      await _tap(tester, _key('faith_choice_q6_0')); // Yes, any tradition
    default:
      fail('No single/multiple-choice fixture for question $question.');
  }
}

Future<void> _advanceTo(WidgetTester tester, int question) async {
  for (var current = 1; current < question; current++) {
    await _answerQuestion(tester, current);
    await _tap(tester, _key('faith_continue'));
  }
  expect(_key('faith_question_$question'), findsOneWidget);
}

Future<void> _words(WidgetTester tester, String words) async {
  await tester.enterText(_key('faith_words'), words);
  await tester.pumpAndSettle();
  // A real outside pointer click invokes the app's keyboard-dismiss Action.
  // Flutter's default mobile touch policy can retain focus after a touch tap.
  await tester.tap(
    find.text('Your faith, in your own words'),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  expect(
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
    isFalse,
  );
}

Future<void> _tab(WidgetTester tester, String label) async {
  final nav = find.byType(SelahShellNavigation);
  expect(nav, findsOneWidget);
  final target = find.descendant(of: nav, matching: find.text(label));
  expect(target, findsOneWidget);
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

SelahRequestAccountSession _browseSession(WidgetTester tester) => tester
    .widget<SelahOneJourneyConceptShell>(
      find.byType(SelahOneJourneyConceptShell),
    )
    .accountSession!;

Future<void> _completeMarriage(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  expect(_key('marriage_question_1'), findsOneWidget);
  for (var q = 1; q <= 7; q++) {
    await _tap(tester, _key('marriage_choice_q${q}_0'));
    await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
  }
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await _tap(tester, _key('language_choice_0'));
  await _tap(tester, _key('languages_save'));
}

Future<void> _showProfile(WidgetTester tester) async {
  // Let the real save SnackBar finish before tapping the dock it can cover.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await _tab(tester, 'Profile');
  final section = _key('faith_profile_section');
  expect(section, findsOneWidget);
  final quote = _key('faith_profile_quote');
  final target = quote.evaluate().isNotEmpty ? quote : section;
  if (target.hitTestable().evaluate().isEmpty ||
      tester.getRect(target).bottom > masterPhoneSize.height - 100) {
    await Scrollable.ensureVisible(tester.element(target), alignment: 1);
    await tester.pumpAndSettle();
  }
}

Future<void> _captureState(
  WidgetTester tester,
  MasterScreen screen,
  String master,
) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  await (master.startsWith('L04_profile_faith__') ? _profileCapture : _capture)
      .capture(tester, screen, master);
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
          'the actual admission policy remains required.',
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
    testWidgets('faith question ${entry.key}: actual empty screen', (
      tester,
    ) async {
      final root = await _startFaith(tester);
      await _advanceTo(tester, entry.key);
      await _captureState(tester, root.screen, entry.value);
    });
  }

  testWidgets('tradition: actual Baptist selection', (tester) async {
    final root = await _startFaith(tester);
    await _answerQuestion(tester, 1);
    expect(_controller(tester).answers.tradition, 'Baptist');
    await _captureState(tester, root.screen, 'L04_faith_1_tradition__selected');
  });

  testWidgets('tradition: required validation from Continue', (tester) async {
    final root = await _startFaith(tester);
    await _tap(tester, _key('faith_continue'));
    expect(find.text('Choose one answer to continue.'), findsOneWidget);
    await _captureState(tester, root.screen, 'L04_faith_1_tradition__error');
  });

  testWidgets('serving: actual Youth and Prayer selections', (tester) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 5);
    await _answerQuestion(tester, 5);
    expect(_controller(tester).answers.serving, ['Youth', 'Prayer']);
    await _captureState(tester, root.screen, 'L04_faith_5_serving__selected');
  });

  testWidgets('own words: actual filled field and counter', (tester) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _fullWords);
    expect(find.text('83 of 150'), findsOneWidget);
    await _captureState(tester, root.screen, 'L04_faith_7_own_words__filled');
  });

  testWidgets('own words: actual overflow remains visible and blocks save', (
    tester,
  ) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, List.filled(160, 'x').join());
    await _tap(tester, _key('faith_save'));
    expect(_key('faith_question_7'), findsOneWidget);
    expect(find.text('160 of 150'), findsOneWidget);
    expect(find.text('Keep it under 150 characters.'), findsOneWidget);
    await _captureState(tester, root.screen, 'L04_faith_7_own_words__too_long');
  });

  testWidgets('saving: real guarded developer preset', (tester) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _shortWords);
    _controller(tester).showSaving();
    await tester.pumpAndSettle();
    expect(find.text('Saving…'), findsOneWidget);
    await _captureState(tester, root.screen, 'L04_faith_7__saving');
  });

  testWidgets('failed: real guarded developer preset', (tester) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _shortWords);
    _controller(tester).showFailure();
    await tester.pumpAndSettle();
    expect(
      find.text('Your faith profile didn’t save. Try again.'),
      findsOneWidget,
    );
    await _captureState(tester, root.screen, 'L04_faith_7__didnt_save');
  });

  testWidgets('Profile answered: actual save is read by the actual Profile', (
    tester,
  ) async {
    final root = await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _shortWords);
    await _tap(tester, _key('faith_save'));
    await _completeMarriage(tester);
    await _waitForBrowse(tester);
    final owner = _browseSession(tester);
    expect(owner.faithAnswers.words, _shortWords);
    await _showProfile(tester);
    final answers = tester
        .widget<SelahFaithProfileCard>(find.byType(SelahFaithProfileCard))
        .answers;
    expect(answers.tradition, 'Baptist');
    expect(answers.church, 'Every week');
    expect(answers.baptised, 'Yes');
    expect(answers.christianFor, 'More than 10 years');
    expect(answers.serving, ['Youth', 'Prayer']);
    expect(answers.openness, 'Yes, any tradition');
    expect(answers.words, owner.faithAnswers.words);
    await _captureState(tester, root.screen, 'L04_profile_faith__answered');
  });

  testWidgets('Profile not answered: actual canonical partial legacy fixture', (
    tester,
  ) async {
    final root = await _mountRoot(tester);
    root.session.seedDetails(
      const SeekerDetails(
        christianFamily: 'Protestant',
        christianDenomination: 'Baptist',
        showChristianTraditionOnProfile: true,
        preferences: {
          'faith_profile': {'tradition': 'Baptist'},
        },
      ),
    );
    await tester.pumpAndSettle();
    await _showProfile(tester);
    expect(
      find.descendant(
        of: _key('faith_profile_card'),
        matching: find.text('Not answered'),
      ),
      findsNWidgets(5),
    );
    expect(_key('faith_profile_quote'), findsNothing);
    await _captureState(tester, root.screen, 'L04_profile_faith__not_answered');
  });

  testWidgets('all five required questions block Continue while unanswered', (
    tester,
  ) async {
    await _startFaith(tester);
    for (final question in [1, 2, 3, 4, 5, 6]) {
      if (question != 5) {
        await _tap(tester, _key('faith_continue'));
        expect(_key('faith_question_$question'), findsOneWidget);
        expect(_key('faith_required_error'), findsOneWidget);
        await _answerQuestion(tester, question);
      }
      await _tap(tester, _key('faith_continue'));
    }
    expect(_key('faith_question_7'), findsOneWidget);
  });

  testWidgets('serving exclusivity and both optional Skip actions stay local', (
    tester,
  ) async {
    await _startFaith(tester);
    await _advanceTo(tester, 5);
    final controller = _controller(tester);
    await _answerQuestion(tester, 5);
    await _tap(tester, _key('faith_choice_q5_7'));
    expect(controller.answers.serving, ['Not right now']);
    await _tap(tester, _key('faith_choice_q5_0'));
    expect(controller.answers.serving, ['Worship']);
    await _tap(tester, _key('faith_skip'));
    expect(controller.answers.serving, isEmpty);
    await _answerQuestion(tester, 6);
    await _tap(tester, _key('faith_continue'));
    await _tap(tester, _key('faith_skip'));
    await _completeMarriage(tester);
    await _waitForBrowse(tester);
    expect(_browseSession(tester).faithAnswers.serving, isEmpty);
    expect(_browseSession(tester).faithAnswers.words, isEmpty);
  });

  testWidgets('Back retains chosen answers and the unsubmitted own words', (
    tester,
  ) async {
    await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _fullWords);
    final controller = _controller(tester);
    await _tap(tester, _key('faith_back'));
    expect(_key('faith_question_6'), findsOneWidget);
    expect(controller.answers.openness, 'Yes, any tradition');
    await _tap(tester, _key('faith_back'));
    expect(_key('faith_question_5'), findsOneWidget);
    expect(controller.answers.serving, ['Youth', 'Prayer']);
    await _tap(tester, _key('faith_continue'));
    await _tap(tester, _key('faith_continue'));
    expect(_key('faith_question_7'), findsOneWidget);
    expect(controller.answers.words, _fullWords);
    expect(
      tester.widget<TextField>(_key('faith_words')).controller!.text,
      _fullWords,
    );
  });

  testWidgets('new Seeker sign-up revokes the previous saved profile owner', (
    tester,
  ) async {
    await _startFaith(tester);
    await _advanceTo(tester, 7);
    await _words(tester, _shortWords);
    await _tap(tester, _key('faith_save'));
    await _completeMarriage(tester);
    await _waitForBrowse(tester);
    final previous = _browseSession(tester);
    final savedAnswers = previous.faithAnswers;
    expect(previous.current, isTrue);
    expect(savedAnswers.tradition, 'Baptist');
    expect(savedAnswers.words, _shortWords);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, _key('draft_close'));
    await _tap(tester, find.text('Explore as a Seeker'));
    expect(previous.current, isFalse);
    expect(previous.saveFaithProfile(savedAnswers), isFalse);
    await _inviteToFaith(tester);
    expect(_controller(tester).answers.tradition, isNull);
    expect(_controller(tester).answers.words, isEmpty);
    expect(_controller(tester).answers.serving, isEmpty);
  });
}
