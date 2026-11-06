// LOCK 3 / DOC-SELAH-0020 screenshots. Every pane is a real invite screen or
// the actual draft root driven through its sign-up flow. No phone-delivery or
// real invite-sending claim is made by these widget images.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_shepherd_invite.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/screens/mentor/accept_shepherd_invite_screen.dart';
import 'package:selah/screens/onboarding/selah_shepherd_invite_flow.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/floating_nav_bar.dart';
import 'package:selah/widgets/selah_shepherd_invite_scope.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

const _name = 'David Okafor';
const _masters = <String>{
  'L03_signup_welcome',
  'L03_signup_choose__empty',
  'L03_signup_choose__selected',
  'L03_signup_choose__error',
  'L03_signup_invite',
  'L03_signup_invite__name_error',
  'L03_signup_invite__sending',
  'L03_signup_invite__failed',
  'L03_signup_sent',
  'L03_seeker_browse__waiting_for_shepherd',
  'L03_seeker_shepherd__invite_pending',
  'L03_shepherd_invitation',
};
final _capture = MasterCaptureHarness(feature: 'SHEPHERD_INVITE');
final _correctionCapture = MasterCaptureHarness(
  feature: 'SHEPHERD_INVITE',
  version: 'V1_1',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

class _Flow {
  _Flow(this.screen, this.controller);
  final MasterScreen screen;
  final SelahShepherdInviteController controller;
}

Future<_Flow> _mountFlow(WidgetTester tester) async {
  final controller = SelahShepherdInviteController(
    canAct: () => SelahDraftRuntime.active,
  );
  addTearDown(controller.dispose);
  final screen = await _capture.mount(
    tester,
    home: SelahShepherdInviteFlow(controller: controller, onContinue: () {}),
  );
  await tester.pumpAndSettle();
  return _Flow(screen, controller);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _choosePastor(WidgetTester tester) async {
  await _tap(tester, _key('invite_begin'));
  await _tap(tester, _key('invite_choice_1'));
}

Future<void> _openInvite(WidgetTester tester, {bool name = true}) async {
  await _choosePastor(tester);
  await _tap(tester, _key('invite_continue'));
  expect(find.text('Invite your Shepherd'), findsOneWidget);
  if (name) {
    await tester.enterText(_key('invite_name'), _name);
    await _tap(tester, find.text('THEIR NAME'));
  }
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
            deck.profiles.every((profile) => profile.photos.isNotEmpty),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The real draft root did not publish its offline Browse portraits.');
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<MasterScreen> _pendingRoot(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Seeker'));
  await _openInvite(tester);
  await _tap(tester, _key('invite_send'));
  await _tap(tester, _key('invite_sent_continue'));
  await _tap(tester, _key('consent_agree'));
  // LOCK 4 is now the real next sign-up step. Complete required answers and
  // use both genuine optional Skip actions before continuing to Browse.
  for (final (question, answer) in [(1, 1), (2, 0), (3, 0), (4, 1)]) {
    await _tap(tester, _key('faith_choice_q${question}_$answer'));
    await _tap(tester, _key('faith_continue'));
  }
  await _tap(tester, _key('faith_skip'));
  await _tap(tester, _key('faith_choice_q6_0'));
  await _tap(tester, _key('faith_continue'));
  await _tap(tester, _key('faith_skip'));
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
  await _waitForBrowse(tester);
  // The newly completed faith step shows its real save result before Browse.
  // Let it expire naturally so it neither covers the dock nor enters a master
  // whose pending state does not include that transient result.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  expect(find.text('Request later'), findsOneWidget);
  return screen;
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

SelahShepherdInviteController _rootInvite(WidgetTester tester) => tester
    .widget<SelahShepherdInviteScope>(find.byType(SelahShepherdInviteScope))
    .notifier!;

Future<void> _openActualShepherdReview(WidgetTester tester) async {
  await _tap(tester, _key('draft_close'));
  await _tap(tester, find.text('Explore as a Shepherd'));
  await tester.pumpAndSettle();
  expect(_key('local_shepherd_invite_review'), findsOneWidget);
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
    expect(present, _masters, reason: 'Every LOCK 3 master must be captured.');
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
          'The real draft gate requires '
          '--dart-define=SELAH_DRAFT_LOCAL_ONLY=true.',
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

  testWidgets('welcome: actual Seeker invite-flow entry', (tester) async {
    final flow = await _mountFlow(tester);
    expect(
      find.text('No one should walk toward marriage alone.'),
      findsOneWidget,
    );
    await _capture.capture(tester, flow.screen, 'L03_signup_welcome');
  });

  testWidgets('choose: empty closed list', (tester) async {
    final flow = await _mountFlow(tester);
    await _tap(tester, _key('invite_begin'));
    expect(flow.controller.relation, isNull);
    await _capture.capture(tester, flow.screen, 'L03_signup_choose__empty');
  });

  testWidgets('choose: Pastor selected through real choice', (tester) async {
    final flow = await _mountFlow(tester);
    await _choosePastor(tester);
    expect(flow.controller.relation, SelahShepherdRelation.pastor);
    await _capture.capture(tester, flow.screen, 'L03_signup_choose__selected');
  });

  testWidgets('choose: existing validation from Continue without choice', (
    tester,
  ) async {
    final flow = await _mountFlow(tester);
    await _tap(tester, _key('invite_begin'));
    await _tap(tester, _key('invite_continue'));
    expect(find.text('Choose who your Shepherd is.'), findsOneWidget);
    await _capture.capture(tester, flow.screen, 'L03_signup_choose__error');
  });

  testWidgets('invite: real form with fictional name', (tester) async {
    final flow = await _mountFlow(tester);
    await _openInvite(tester);
    expect(flow.controller.fullName, _name);
    await _capture.capture(tester, flow.screen, 'L03_signup_invite');
  });

  testWidgets('invite: missing name from real Send action', (tester) async {
    final flow = await _mountFlow(tester);
    await _openInvite(tester, name: false);
    await _tap(tester, _key('invite_send'));
    expect(find.text('Enter your Shepherd’s name.'), findsOneWidget);
    // DOC-SELAH-0047: the error belongs only to a trim-empty name. Exercise
    // editing through valid and whitespace values, then return to the exact
    // empty field in the corrected master using the real form actions.
    await tester.enterText(_key('invite_name'), _name);
    await tester.pumpAndSettle();
    expect(find.text('Enter your Shepherd’s name.'), findsNothing);
    await tester.enterText(_key('invite_name'), '   ');
    await tester.pumpAndSettle();
    expect(find.text('Enter your Shepherd’s name.'), findsOneWidget);
    await tester.enterText(_key('invite_name'), '');
    await _tap(tester, _key('invite_send'));
    await _tap(tester, find.text('THEIR NAME'));
    expect(flow.controller.fullName, isEmpty);
    expect(find.text('Enter your Shepherd’s name.'), findsOneWidget);
    await _correctionCapture.capture(
      tester,
      flow.screen,
      'L03_signup_invite__name_error',
    );
  });

  testWidgets('invite: approved local sending preset', (tester) async {
    final flow = await _mountFlow(tester);
    await _openInvite(tester);
    // The same public controller action used by the approved private preset.
    flow.controller.showSending();
    await tester.pumpAndSettle();
    expect(find.text('Sending…'), findsOneWidget);
    expect(_key('invite_copy'), findsNothing);
    await _capture.capture(tester, flow.screen, 'L03_signup_invite__sending');
  });

  testWidgets('invite: approved local failure preset', (tester) async {
    final flow = await _mountFlow(tester);
    await _openInvite(tester);
    flow.controller.showFailure();
    await tester.pumpAndSettle();
    expect(find.text('Your invite didn’t send. Try again.'), findsOneWidget);
    await _capture.capture(tester, flow.screen, 'L03_signup_invite__failed');
  });

  testWidgets('sent: reached through local Send', (tester) async {
    final flow = await _mountFlow(tester);
    await _openInvite(tester);
    await _tap(tester, _key('invite_send'));
    expect(flow.controller.pending, isTrue);
    expect(find.text('David has your invite.'), findsOneWidget);
    await _capture.capture(tester, flow.screen, 'L03_signup_sent');
  });

  testWidgets('pending Browse: actual root sign-up and Continue', (
    tester,
  ) async {
    final screen = await _pendingRoot(tester);
    expect(
      find.text(
        'Waiting for David to accept. You can request a Journey once they say yes.',
      ),
      findsOneWidget,
    );
    await _correctionCapture.capture(
      tester,
      screen,
      'L03_seeker_browse__waiting_for_shepherd',
    );
  });

  testWidgets('pending Shepherd: actual root pending invitation', (
    tester,
  ) async {
    final screen = await _pendingRoot(tester);
    await _tab(tester, 'Shepherd');
    expect(find.text(_name), findsOneWidget);
    expect(find.text('Invite sent · waiting for a yes'), findsOneWidget);
    await _capture.capture(
      tester,
      screen,
      'L03_seeker_shepherd__invite_pending',
    );
  });

  testWidgets('Shepherd invitation: real review screen', (tester) async {
    final screen = await _capture.mount(
      tester,
      home: AcceptShepherdInviteScreen.seekerRequest(
        seekerName: 'James',
        seekerAge: 31,
        seekerGender: 'Male',
        relationship: 'Pastor',
        seekerPhoto: Image.asset(
          'assets/dev/one_journey_photos/seeker_self.jpg',
          fit: BoxFit.cover,
        ),
        onAccept: () {},
        onDecline: () {},
        bottomNavigation: SelahShellNavigation(
          items: const [
            FloatingNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
            FloatingNavItem(icon: Icons.diversity_3_outlined, label: 'Network'),
            FloatingNavItem(icon: Icons.people_outline, label: 'Seekers'),
            FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
          ],
          currentIndex: 2,
          onTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Be James’s Shepherd?'), findsOneWidget);
    await _correctionCapture.capture(tester, screen, 'L03_shepherd_invitation');
  });

  testWidgets(
    'pending invitation blocks Request and incoming Accept without mutation',
    (tester) async {
      await _pendingRoot(tester);
      final invite = _rootInvite(tester);
      var deck = tester.widget<SelahOneJourneyBrowseDesigns>(
        find.byType(SelahOneJourneyBrowseDesigns),
      );
      final person = deck.profiles[deck.selectedIndex];
      expect(deck.invitationSent!(person), isFalse);
      await _tap(tester, find.text('Request later'));
      expect(
        find.text('You can request a Journey once David accepts your invite.'),
        findsOneWidget,
      );
      deck = tester.widget<SelahOneJourneyBrowseDesigns>(
        find.byType(SelahOneJourneyBrowseDesigns),
      );
      expect(deck.invitationSent!(person), isFalse);
      expect(invite.pending, isTrue);

      await _tab(tester, 'My SELAH');
      await _tap(tester, find.text('View requests').first);
      await _tap(tester, _key('concept_request_draft-amira_header'));
      await _tap(tester, _key('draft_accept_draft-amira'));
      expect(
        find.text('You can accept once David accepts your invite.'),
        findsOneWidget,
      );
      expect(_key('draft_accept_draft-amira'), findsOneWidget);
      expect(find.text('Choose to begin, together.'), findsNothing);
      expect(invite.pending, isTrue);
      expect(invite.fullName, _name);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'real Shepherd-accepts control restores Request, full name and update',
    (tester) async {
      await _pendingRoot(tester);
      final invite = _rootInvite(tester);
      await _tap(tester, _key('draft_back'));
      await _tap(tester, _key('invite_shepherd_accepts'));
      expect(invite.accepted, isTrue);
      expect(invite.pending, isFalse);
      expect(invite.fullName, _name);
      expect(_key('invite_waiting_banner'), findsNothing);
      expect(find.text('Request a Journey'), findsOneWidget);
      expect(
        find.text('David said yes. You can ask and accept now.'),
        findsOneWidget,
      );
      await _tab(tester, 'Shepherd');
      expect(_key('invite_pending_card'), findsNothing);
      expect(find.textContaining('David', findRichText: true), findsWidgets);
      await _tab(tester, 'My SELAH');
      expect(
        find.text('David Okafor accepted. Your Shepherd walks with you now.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'actual Shepherd review Accept changes the local owner and home',
    (tester) async {
      await _pendingRoot(tester);
      final invite = _rootInvite(tester);
      await _openActualShepherdReview(tester);
      await _tap(tester, _key('invite_review_accept'));
      expect(invite.accepted, isTrue);
      expect(invite.fullName, _name);
      expect(_key('local_shepherd_invite_review'), findsNothing);
      expect(find.text('You are now James’s Shepherd.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'actual Shepherd review Not now preserves the pending invitation',
    (tester) async {
      await _pendingRoot(tester);
      final invite = _rootInvite(tester);
      await _openActualShepherdReview(tester);
      await _tap(tester, _key('invite_review_decline'));
      expect(invite.pending, isTrue);
      expect(invite.accepted, isFalse);
      expect(_key('local_shepherd_invite_review'), findsNothing);
      expect(
        find.text(
          'James will be told kindly. You can accept later from the message.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
