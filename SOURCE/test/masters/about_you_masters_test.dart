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
import 'package:selah/widgets/selah_profile_questions.dart';
import 'package:selah/screens/onboarding/selah_languages_flow.dart';
import 'package:selah/data/selah_reference_data.dart';

final _capture = MasterCaptureHarness(feature: 'ABOUT_YOU');
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

Future<MasterScreen> _languages(WidgetTester tester) async {
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
  await _tap(tester, _key('consent_skip'));
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  for (var q = 1; q <= 7; q++) {
    await _tap(tester, _key('marriage_choice_q${q}_0'));
    await _tap(tester, _key(q == 7 ? 'marriage_save' : 'marriage_continue'));
  }
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  expect(_key('languages_screen'), findsOneWidget);
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
  testWidgets('languages empty preserves existing ordered list', (
    tester,
  ) async {
    final screen = await _languages(tester);
    await _captureState(tester, screen, 'L14_languages__empty');
  });
  testWidgets('languages multi-select and Back retain answers', (tester) async {
    final screen = await _languages(tester);
    await _tap(tester, _key('language_choice_0'));
    await _tap(tester, _key('language_choice_1'));
    await _captureState(tester, screen, 'L14_languages__chosen');
    await _tap(tester, _key('languages_back'));
    expect(_key('marriage_question_7'), findsOneWidget);
    await _tap(tester, _key('marriage_save'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_key('languages_screen'), findsOneWidget);
    expect(
      tester
          .widget<SelahProfileQuestionChoice>(_key('language_choice_0'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<SelahProfileQuestionChoice>(_key('language_choice_1'))
          .selected,
      isTrue,
    );
  });
  testWidgets('languages requires at least one', (tester) async {
    final screen = await _languages(tester);
    await _tap(tester, _key('languages_save'));
    expect(_key('languages_required_error'), findsOneWidget);
    await _captureState(tester, screen, 'L14_languages__no_answer');
  });
  for (final state in ['saving', 'failed']) {
    testWidgets('languages private $state state', (tester) async {
      final screen = await _languages(tester);
      await _tap(tester, _key('language_choice_0'));
      await _tap(tester, _key('dev_rail_actions'));
      await _tap(tester, _key('languages_$state'));
      await _captureState(
        tester,
        screen,
        'L14_languages__${state == 'failed' ? 'didnt_save' : state}',
      );
    });
  }
  testWidgets('languages save and actual Profile use same field', (
    tester,
  ) async {
    final screen = await _languages(tester);
    await _tap(tester, _key('language_choice_0'));
    await _tap(tester, _key('language_choice_1'));
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
    expect(
      tester
          .widget<SelahShellNavigation>(find.byType(SelahShellNavigation))
          .currentIndex,
      4,
    );
    final card = _key('about_you_card');
    await tester.scrollUntilVisible(
      card,
      250,
      scrollable: find
          .descendant(
            of: _key('concept-current-profile-scroll'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(card, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(card), alignment: .5);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelahAboutYouCard>(find.byType(SelahAboutYouCard))
          .languages,
      selahLanguageNames.take(2).toList(),
    );
    await _captureState(tester, screen, 'L14_profile_about_you');
  });
}
