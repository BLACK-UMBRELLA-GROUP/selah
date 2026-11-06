// LOCK 19: real root, same-account Introductions and the existing request flow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shepherd_introduce_views.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';
import 'your_values_driver.dart';

final _capture = MasterCaptureHarness(
  feature: 'SHEPHERD_INTRODUCE',
  wordingRevision: false,
);
// LOCK20 supersedes only the older Dashboard snapshots. These same real-root
// Prayer cases now assert its reviewed evidence, preserving LOCK19 history.
final _dashboardCapture = MasterCaptureHarness(
  feature: 'SHEPHERD_DASHBOARD',
  wordingRevision: false,
);
const _masters = {
  'L19_introduce',
  'L19_introduce__for_joel',
  'L19_introduce__suggesting',
  'L19_introduce__didnt_send',
  'L19_introduce__no_one_new',
  'L19_my_selah__suggestion',
};
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

Future<void> _waitBrowse(WidgetTester tester) async {
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
    fail('The real root did not prepare its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
}

Future<MasterScreen> _mount(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _waitBrowse(tester);
  return screen;
}

Future<void> _role(WidgetTester tester, bool shepherd) async {
  await _tap(tester, _key('draft_back'));
  await _tap(
    tester,
    _key(shepherd ? 'draft_role_shepherd' : 'draft_role_seeker'),
  );
  await _tab(tester, shepherd ? 'Dashboard' : 'My Selah');
}

Future<void> _preset(WidgetTester tester, String key) async {
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key(key));
}

Future<void> _declineInitialGraceRequest(WidgetTester tester) async {
  await _tab(tester, 'My Selah');
  await _tap(tester, find.text('View requests').first);
  await _tap(tester, _key('concept_request_draft-amira_header'));
  await _tap(tester, _key('draft_decline_draft-amira'));
  final temporaryPage = _key('concept_pull_down_back_scope');
  await tester.dragFrom(
    tester.getTopLeft(temporaryPage) + const Offset(180, 90),
    const Offset(0, 270),
  );
  await tester.pumpAndSettle();
  await _tab(tester, 'Journey');
}

Future<MasterScreen> _introduce(WidgetTester tester) async {
  final screen = await _mount(tester);
  await _declineInitialGraceRequest(tester);
  await _role(tester, true);
  await _tab(tester, 'Introduce');
  await _expireNotice(tester);
  expect(_view(tester).candidate?.firstName, 'Grace');
  return screen;
}

SelahShepherdIntroduceView _view(WidgetTester tester) =>
    tester.widget<SelahShepherdIntroduceView>(
      find.byType(SelahShepherdIntroduceView),
    );

SelahRequestAccountSession _owner(WidgetTester tester) => tester
    .widget<SelahOneJourneyConceptShell>(
      find.byType(SelahOneJourneyConceptShell),
    )
    .accountSession!;

Future<void> _suggestNaomi(WidgetTester tester) async {
  // Read the actual candidate and advance through the actual neutral action.
  // No request, filter, Introduction or completion data is injected.
  for (var step = 0; step < draftProfiles.length; step++) {
    if (_view(tester).candidate?.firstName == 'Naomi') {
      break;
    }
    await _tap(tester, _key('introduce_next'));
  }
  expect(_view(tester).candidate?.firstName, 'Naomi');
  await _tap(tester, _key('introduce_suggest'));
  await _expireNotice(tester);
}

Future<MasterScreen> _invitation(WidgetTester tester) async {
  final screen = await _mount(tester);
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Seeker'));
  await _tap(tester, _key('invite_begin'));
  await _tap(tester, _key('invite_choice_1'));
  await _tap(tester, _key('invite_continue'));
  await tester.enterText(_key('invite_name'), 'Pastor David');
  await _tap(tester, find.text('THEIR NAME'));
  await _tap(tester, _key('invite_send'));
  await _tap(tester, _key('invite_sent_continue'));
  await _tap(tester, _key('consent_skip'));
  await _expireNotice(tester);
  for (var question = 1; question <= 7; question++) {
    await _tap(tester, _key('marriage_choice_q${question}_0'));
    await _tap(
      tester,
      _key(question == 7 ? 'marriage_save' : 'marriage_continue'),
    );
  }
  await _expireNotice(tester);
  await _tap(tester, _key('language_choice_0'));
  await _tap(tester, _key('languages_save'));
  await finishYourValuesFromOverview(tester);
  await _waitBrowse(tester);
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Shepherd'));
  expect(_key('local_shepherd_invite_review'), findsOneWidget);
  await _expireNotice(tester);
  return screen;
}

SeekerProfile _graceFixture() {
  final fixture = draftProfiles.first;
  return SeekerProfile(
    id: fixture.id,
    firstName: fixture.firstName,
    age: fixture.age,
    city: fixture.city,
    gender: 'female',
    photos: const [],
    faithProfile: SelahFaithProfileAnswers(
      tradition: fixture.faithTradition,
      church: fixture.churchAttendance,
      baptised: fixture.baptised,
      words: fixture.faithWords,
    ),
    marriageValues: fixture.marriageAnswers,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFetching;
  setUpAll(() async {
    expect(
      Directory('${_capture.featureRoot.path}/MASTERS')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .map((file) => file.uri.pathSegments.last.replaceFirst('.png', ''))
          .toSet(),
      _masters,
    );
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

  for (final state in [
    '',
    '__for_joel',
    '__suggesting',
    '__didnt_send',
    '__no_one_new',
  ]) {
    testWidgets('LOCK19 Introduce$state through actual root', (tester) async {
      final screen = await _introduce(tester);
      if (state == '__for_joel') {
        final joel = _view(tester).seekers.singleWhere((p) => p.name == 'Joel');
        await _tap(tester, _key('introduce_for_${joel.id}'));
        expect(_view(tester).selectedSeekerId, joel.id);
        expect(_view(tester).candidate?.firstName, 'Grace');
      } else if (state.isNotEmpty) {
        await _preset(tester, switch (state) {
          '__suggesting' => 'introduce_suggesting',
          '__didnt_send' => 'introduce_failed',
          _ => 'introduce_empty',
        });
        expect(_view(tester).suggesting, state == '__suggesting');
        expect(_view(tester).failed, state == '__didnt_send');
        if (state == '__no_one_new') {
          expect(_view(tester).candidate, isNull);
        }
      }
      await _capture.capture(tester, screen, 'L19_introduce$state');
    });
  }

  testWidgets('LOCK19 My Selah reads the actual Grace Introduction', (
    tester,
  ) async {
    final screen = await _introduce(tester);
    await _tap(tester, _key('introduce_suggest'));
    await _expireNotice(tester);
    await _role(tester, false);
    await _tab(tester, 'My Selah');
    final card = tester.widget<SelahShepherdSuggestionCard>(
      find.byType(SelahShepherdSuggestionCard),
    );
    expect(card.profile.firstName, 'Grace');
    expect(find.text('FROM YOUR SHEPHERD'), findsOneWidget);
    await _capture.capture(tester, screen, 'L19_my_selah__suggestion');
  });

  testWidgets('See opens Naomi in Browse and Not now dismisses locally', (
    tester,
  ) async {
    await _introduce(tester);
    final owner = _owner(tester);
    await _suggestNaomi(tester);
    await _role(tester, false);
    await _tap(tester, _key('suggestion_see_draft-aisha'));
    final browse = tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );
    expect(browse.profiles[browse.selectedIndex].firstName, 'Naomi');
    expect(owner.introductionsFor('draft-self'), hasLength(1));
    await _tab(tester, 'My Selah');
    await _tap(tester, _key('suggestion_dismiss_draft-aisha'));
    expect(owner.introductionsFor('draft-self'), isEmpty);
    expect(find.byType(SelahShepherdSuggestionCard), findsNothing);
    expect(find.text('Noted. Pastor David won’t be told why.'), findsOneWidget);
  });

  testWidgets('old Suggest callbacks cannot write after tab or role changes', (
    tester,
  ) async {
    await _introduce(tester);
    final owner = _owner(tester);
    final beforeTab = _view(tester).onSuggest!;
    await _tab(tester, 'Seekers');
    beforeTab();
    await tester.pumpAndSettle();
    expect(owner.introductionsFor('draft-self'), isEmpty);
    await _tab(tester, 'Introduce');
    final beforeRole = _view(tester).onSuggest!;
    await _role(tester, false);
    beforeRole();
    await tester.pumpAndSettle();
    expect(owner.introductionsFor('draft-self'), isEmpty);
    expect(find.byType(SelahShepherdSuggestionCard), findsNothing);
  });

  testWidgets('duplicate Suggest creates one card in both Seeker surfaces', (
    tester,
  ) async {
    await _introduce(tester);
    final owner = _owner(tester);
    final suggest = _view(tester).onSuggest!;
    suggest();
    suggest();
    await tester.pumpAndSettle();
    expect(owner.introductionsFor('draft-self'), hasLength(1));
    expect(
      owner.introductionsFor('draft-self').single.profile.firstName,
      'Grace',
    );
    await _expireNotice(tester);
    await _role(tester, false);
    expect(find.byType(SelahShepherdSuggestionCard), findsOneWidget);
    await _tap(tester, find.text('View introductions').first);
    expect(_key('draft_requests_2'), findsOneWidget);
    expect(find.byType(SelahShepherdSuggestionCard), findsOneWidget);
    expect(owner.introductionsFor('draft-self'), hasLength(1));
  });

  testWidgets('LOCK19 updated dock on actual Shepherd Seekers', (tester) async {
    final screen = await _mount(tester);
    await _tab(tester, 'Journey');
    await _role(tester, true);
    await _tab(tester, 'Seekers');
    await _capture.capture(
      tester,
      screen,
      'L01_shepherd_seekers',
      masterFile: File('../APP/APPROVED/LOOK/MASTERS/L01_shepherd_seekers.png'),
    );
  });

  testWidgets('LOCK19 updated dock on actual pending invitation review', (
    tester,
  ) async {
    final screen = await _invitation(tester);
    final dock = tester.widget<SelahShellNavigation>(
      find.byType(SelahShellNavigation),
    );
    expect(dock.items.map((item) => item.label), [
      'Dashboard',
      'Introduce',
      'Seekers',
      'Profile',
    ]);
    expect(dock.currentIndex, 2);
    await _capture.capture(
      tester,
      screen,
      'L03_shepherd_invitation',
      masterFile: File(
        '../APP/APPROVED/SHEPHERD_INVITE/MASTERS/L03_shepherd_invitation.png',
      ),
    );
  });

  for (final state in ['requests', 'prayed', 'no_requests']) {
    testWidgets('LOCK19 updated dock on actual Prayer Dashboard $state', (
      tester,
    ) async {
      final screen = await _mount(tester);
      await _tab(tester, 'Journey');
      await _role(tester, true);
      if (state == 'prayed') {
        await _tap(tester, _key('prayer_pray_prayer-seed-1'));
      } else if (state == 'no_requests') {
        await _preset(tester, 'prayer_empty');
      }
      await _expireNotice(tester);
      await _dashboardCapture.capture(
        tester,
        screen,
        'L10_shepherd_dashboard__$state',
        masterFile: File(
          '../APP/APPROVED/PRAYER/MASTERS/L10_shepherd_dashboard__$state.png',
        ),
      );
    });
  }

  testWidgets('Introduce footer reproduces CSS button content split', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelahShepherdIntroduceView(
            seekers: const [(id: 'draft-self', name: 'James')],
            selectedSeekerId: 'draft-self',
            candidate: _graceFixture(),
            failed: true,
            onSeekerChanged: (_) {},
            onNext: () {},
            onSuggest: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_key('introduce_next')).width, closeTo(158, .01));
    expect(tester.getSize(_key('introduce_suggest')).width, closeTo(218, .01));
    expect(
      tester.getRect(_key('introduce_next')).bottom,
      tester.getRect(_key('introduce_suggest')).bottom,
    );
    expect(_key('introduce_suggest').hitTestable(), findsOneWidget);
    final before = tester.getRect(_key('introduce_actions'));
    await tester.drag(_key('introduce_scroll'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(tester.getRect(_key('introduce_actions')), before);
  });

  testWidgets('short viewport with larger text keeps real footer reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var suggested = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.5),
            padding: masterSafeArea,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SelahShepherdIntroduceView(
            seekers: const [(id: 'draft-self', name: 'James')],
            selectedSeekerId: 'draft-self',
            candidate: _graceFixture(),
            failed: true,
            onSeekerChanged: (_) {},
            onNext: () {},
            onSuggest: () => suggested++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_key('introduce_suggest').hitTestable(), findsOneWidget);
    final footer = tester.getRect(_key('introduce_actions'));
    await tester.drag(_key('introduce_scroll'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_key('introduce_actions')), footer);
    await _tap(tester, _key('introduce_suggest'));
    expect(suggested, 1);
  });
}
