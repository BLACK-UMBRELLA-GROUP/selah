// LOCK 20: three actual-root Prayer comparisons and two controlled-window
// real-component comparisons. Events come only from successful model advances.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/selah_shepherd_dashboard.dart';
import 'package:selah/screens/mentor/family_messaging_screens.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shepherd_dashboard_views.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _capture = MasterCaptureHarness(
  feature: 'SHEPHERD_DASHBOARD',
  wordingRevision: false,
);
const _masters = {
  'L20_dashboard__check_in',
  'L20_dashboard__nothing_needs_you',
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
}

Future<void> _expireNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<MasterScreen> _mount(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
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

Future<void> _declineGrace(WidgetTester tester) async {
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
}

SelahShepherdDashboardView _view(WidgetTester tester) =>
    tester.widget<SelahShepherdDashboardView>(
      find.byType(SelahShepherdDashboardView),
    );

Finder _dashboardScroll() => find
    .descendant(
      of: _key('shepherd_dashboard_scroll'),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _bottom(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(_dashboardScroll());
  for (var attempt = 0; attempt < 3; attempt++) {
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
  expect(_key('shepherd_dashboard_prayer_note'), findsOneWidget);
}

Future<void> _dashboardTap(WidgetTester tester, String key) async {
  final target = _key(key);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: _dashboardScroll(),
    );
  }
  await _tap(tester, target);
}

List<SelahShepherdCheckIn> _recordedWindow({
  required String seekerId,
  required String seekerFirstName,
}) {
  final now = DateTime.utc(2026, 11, 6, 12);
  var time = now.subtract(const Duration(days: 8));
  final model = ViewRequestDraftModel(capacity: 3, clock: () => time);
  model.seedJourneys(1);
  final person = draftProfiles[1];
  expect(model.stageChangesFor(person.id), isEmpty);
  while (model.stageFor(person.id)!.value != 'phase_1') {
    final stage = model.stageFor(person.id)!;
    if (stage.value == 'greeting_exchange') {
      expect(model.sendGreeting(person.id), isTrue);
      expect(model.simulatePeerGreeting(person.id), isTrue);
    } else if (stage.value == 'compatibility_reveal') {
      expect(model.chooseCompatibilityReveal(person.id), isTrue);
      expect(model.simulatePeerCompatibilityReveal(person.id), isTrue);
    }
    expect(model.chooseStageContinue(person.id), isTrue);
    expect(model.simulatePeerStageContinue(person.id), isTrue);
    final next = SelahJourneyStages.all[stage.order];
    if (next.value == 'phase_1') {
      time = now;
    }
    expect(model.advanceStage(person.id), isTrue);
  }
  final rows = selahShepherdCheckIns(
    events: model.stageChangesFor(person.id),
    admittedJourneys: {
      person.id: SelahShepherdCheckInIdentity(
        seekerId: seekerId,
        seekerFirstName: seekerFirstName,
        counterpartFirstName: person.firstName,
      ),
    },
    now: now,
  );
  expect(rows, hasLength(1));
  expect(rows.single.stage.value, 'phase_1');
  return rows;
}

Future<MasterScreen> _controlledComponent(
  WidgetTester tester, {
  required bool empty,
}) async {
  await _mount(tester);
  if (empty) {
    await _declineGrace(tester);
  }
  await _tab(tester, 'Journey');
  await _role(tester, true);
  final actual = _view(tester);
  final dock = tester.widget<SelahShellNavigation>(
    find.byType(SelahShellNavigation),
  );
  final shell = tester.widget<SelahOneJourneyConceptShell>(
    find.byType(SelahOneJourneyConceptShell),
  );
  final own = shell.accountSession!.ownProfile(false);
  final checkIns = empty
      ? const <SelahShepherdCheckIn>[]
      : _recordedWindow(seekerId: own.id, seekerFirstName: own.firstName);
  expect(actual.needs.isEmpty, empty);
  // Reuse actual-root read-only Prayer/Needs/Updates projections. No master
  // update rows, incoming Naomi request, dates or account state are injected.
  final screen = await _capture.mount(
    tester,
    home: Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SelahShepherdDashboardView(
            prayerRequests: actual.prayerRequests,
            needs: actual.needs,
            checkIns: checkIns,
            updates: actual.updates,
            needsStatus: actual.needsStatus,
            onNeed: (_) {},
            onMessage: (_) {},
          ),
          SelahShellNavigation(
            items: dock.items,
            currentIndex: 0,
            onTap: (_) {},
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _bottom(tester);
  return screen;
}

Future<void> _journeyAction(WidgetTester tester, String key) async {
  if (['draft_peer_greeting_', 'draft_stage_peer_ready_'].any(key.startsWith)) {
    await _preset(tester, key);
    return;
  }
  for (
    var attempt = 0;
    _key(key).evaluate().isEmpty && attempt < 3;
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
  await _tap(tester, _key(key));
}

Future<void> _recordRootTransition(WidgetTester tester) async {
  await _tab(tester, 'Journey');
  await _preset(tester, 'concept_journey_preview_1');
  await _tap(tester, _key('draft_journey_draft-sara'));
  await _journeyAction(tester, 'concept_journey_arrival_continue');
  await _journeyAction(tester, 'draft_greeting_draft-sara');
  await _journeyAction(tester, 'draft_peer_greeting_draft-sara');
  await _journeyAction(tester, 'draft_stage_ready_draft-sara');
  await _journeyAction(tester, 'draft_stage_peer_ready_draft-sara');
  await _journeyAction(tester, 'draft_stage_next_draft-sara');
  await _expireNotice(tester);
  await _role(tester, true);
  expect(_view(tester).checkIns, hasLength(1));
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

  for (final state in ['check_in', 'nothing_needs_you']) {
    testWidgets('LOCK20 controlled recorded-window component $state', (
      tester,
    ) async {
      final screen = await _controlledComponent(
        tester,
        empty: state == 'nothing_needs_you',
      );
      await _capture.capture(tester, screen, 'L20_dashboard__$state');
    });
  }

  for (final state in ['requests', 'prayed', 'no_requests']) {
    testWidgets('LOCK20 actual-root Prayer Dashboard $state', (tester) async {
      final screen = await _mount(tester);
      await _tab(tester, 'Journey');
      await _role(tester, true);
      if (state == 'prayed') {
        await _tap(tester, _key('prayer_pray_prayer-seed-1'));
      } else if (state == 'no_requests') {
        await _preset(tester, 'prayer_empty');
      }
      await _expireNotice(tester);
      await _capture.capture(
        tester,
        screen,
        'L10_shepherd_dashboard__$state',
        masterFile: File(
          '../APP/APPROVED/PRAYER/MASTERS/L10_shepherd_dashboard__$state.png',
        ),
      );
    });
  }

  testWidgets('actual Encourage opens the existing linked James Circle', (
    tester,
  ) async {
    await _mount(tester);
    await _tab(tester, 'Journey');
    await _role(tester, true);
    final need = _view(tester).needs.single;
    expect(need.seekerId, 'draft-self');
    await _dashboardTap(tester, 'shepherd_dashboard_need_${need.id}');
    final circle = tester.widget<SelahShepherdCircleScreen>(
      find.byType(SelahShepherdCircleScreen),
    );
    expect(circle.seekerId, need.seekerId);
    expect(circle.previewData?.seekerId, need.seekerId);
  });

  testWidgets('old Dashboard need callbacks reject tab and role changes', (
    tester,
  ) async {
    await _mount(tester);
    await _tab(tester, 'Journey');
    await _role(tester, true);
    final actual = _view(tester);
    final need = actual.needs.single;
    await _tab(tester, 'Introduce');
    actual.onNeed(need);
    await tester.pumpAndSettle();
    expect(find.byType(SelahShepherdCircleScreen), findsNothing);
    await _tab(tester, 'Dashboard');
    final beforeRole = _view(tester);
    await _role(tester, false);
    beforeRole.onNeed(need);
    await tester.pumpAndSettle();
    expect(find.byType(SelahShepherdCircleScreen), findsNothing);
  });

  testWidgets(
    'recorded check-in Message is addressed and rejects stale scopes',
    (tester) async {
      await _mount(tester);
      await _recordRootTransition(tester);
      final actual = _view(tester);
      final row = actual.checkIns.single;
      expect(row.identity.seekerId, 'draft-self');
      expect(row.identity.counterpartFirstName, 'Esther');
      await _tab(tester, 'Introduce');
      actual.onMessage(row);
      await tester.pumpAndSettle();
      expect(find.byType(SelahShepherdCircleScreen), findsNothing);
      await _tab(tester, 'Dashboard');
      final beforeRole = _view(tester);
      await _role(tester, false);
      beforeRole.onMessage(row);
      await tester.pumpAndSettle();
      expect(find.byType(SelahShepherdCircleScreen), findsNothing);
      await _role(tester, true);
      final current = _view(tester).checkIns.single;
      await _dashboardTap(tester, 'shepherd_dashboard_message_${current.key}');
      final circle = tester.widget<SelahShepherdCircleScreen>(
        find.byType(SelahShepherdCircleScreen),
      );
      expect(circle.seekerId, current.identity.seekerId);
      expect(circle.previewData?.seekerId, current.identity.seekerId);
    },
  );
}
