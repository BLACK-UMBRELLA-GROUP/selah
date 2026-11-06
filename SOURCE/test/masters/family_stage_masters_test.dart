// LOCK22: five comparisons and action proofs through the actual root/owner.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_journey_presentation.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_family_stage_controller.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_family_stage_views.dart';
import 'package:selah/widgets/selah_shepherd_invite_views.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'family_stage_driver.dart';
import 'master_capture.dart';

final _capture = MasterCaptureHarness(
  feature: 'FAMILY_STAGE',
  wordingRevision: false,
);
const _person = 'draft-sara';
const _masters = [
  'L22_journey__family_stage',
  'L22_family__questions',
  'L22_family__sending',
  'L22_family__didnt_send',
  'L22_family__sent',
];
Finder _key(String key) => find.byKey(ValueKey<String>(key));
SelahFamilyCompatibilityView _view(WidgetTester tester) =>
    tester.widget<SelahFamilyCompatibilityView>(
      find.byType(SelahFamilyCompatibilityView),
    );
SelahFamilyStageController _controller(WidgetTester tester) =>
    _view(tester).controller;

Future<void> _scroll(WidgetTester tester, {required bool bottom}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: _key('family_scroll'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scrollable.position.jumpTo(bottom ? scrollable.position.maxScrollExtent : 0);
  await tester.pumpAndSettle();
}

Future<void> _expireNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<({ValueChanged<String> change, VoidCallback send, VoidCallback back})>
_formActions(WidgetTester tester) async {
  await _scroll(tester, bottom: false);
  final change = tester
      .widget<TextField>(_key('family_answer_fam_q1'))
      .onChanged!;
  final back = tester.widget<TextButton>(_key('family_back')).onPressed!;
  await _scroll(tester, bottom: true);
  final send = tester.widget<SelahInviteButton>(_key('family_send')).onPressed!;
  return (change: change, send: send, back: back);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? oldHttp;
  bool? oldFetching;
  setUpAll(() async {
    for (final master in _masters) {
      expect(
        File('../APP/APPROVED/FAMILY_STAGE/MASTERS/$master.png').existsSync(),
        isTrue,
      );
    }
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

  for (final master in _masters) {
    testWidgets('LOCK22 actual-root comparison $master', (tester) async {
      final screen = await reachFamilyStage(tester, capture: _capture);
      await familyJourneyAction(tester, 'concept_journey_arrival_continue');
      expect(_key('draft_family_open_$_person'), findsOneWidget);
      if (master != 'L22_journey__family_stage') {
        await familyJourneyAction(tester, 'draft_family_open_$_person');
        expect(
          find.text('PASTOR AMA MENSAH, ESTHER’S SHEPHERD, ASKS YOU'),
          findsOneWidget,
        );
        if (master == 'L22_family__questions') {
          await fillFamilyAnswers(tester, firstOnly: true);
          expect(_controller(tester).answeredCount, 1);
          expect(
            tester.widget<SelahInviteButton>(_key('family_send')).onPressed,
            isNull,
          );
          await _scroll(tester, bottom: false);
        } else {
          await fillFamilyAnswers(tester);
          if (master == 'L22_family__sending') {
            await familyPageOption(tester, 'family_sending');
            expect(_controller(tester).sendState, SelahFamilySendState.sending);
            expect(_controller(tester).sent, isFalse);
            expect(
              tester.widget<TextField>(_key('family_answer_fam_q1')).enabled,
              isFalse,
            );
            await _scroll(tester, bottom: true);
          } else if (master == 'L22_family__didnt_send') {
            await familyPageOption(tester, 'family_failed');
            expect(
              _controller(tester).answers.values.values.toList(),
              familyMasterAnswers,
            );
            await _scroll(tester, bottom: true);
            expect(_key('family_failure'), findsOneWidget);
          } else {
            await tapFamilyControl(tester, 'family_send');
            expect(_controller(tester).sent, isTrue);
            expect(find.byType(TextField), findsNothing);
            expect(
              find.text('Sent to Pastor Ama Mensah and Esther.'),
              findsOneWidget,
            );
            await _scroll(tester, bottom: false);
          }
        }
      }
      await _expireNotice(tester);
      await _capture.capture(tester, screen, master);
    });
  }

  testWidgets(
    'Family limit and original form callbacks reject Page options ABA',
    (tester) async {
      await reachFamilyStage(tester, capture: _capture);
      await openFamilyStage(tester);
      final first = _key('family_answer_fam_q1');
      await tester.ensureVisible(first);
      await tester.enterText(first, List.filled(401, '🙂').join());
      await tester.pumpAndSettle();
      expect(_controller(tester).characterCount('fam_q1'), 400);
      expect(find.text('400 of 400'), findsOneWidget);
      await fillFamilyAnswers(tester);
      final owner = _controller(tester);
      final before = owner.answers.values;
      final old = await _formActions(tester);
      await tapFamilyControl(tester, 'draft_back');
      old.change('Unrelated covering-page write');
      old.send();
      old.back();
      await tester.pumpAndSettle();
      expect(owner.answers.values, before);
      expect(owner.sent, isFalse);
      await tapFamilyControl(tester, 'family_ready');
      old.change('Stale form after Page options closes');
      old.send();
      old.back();
      await tester.pumpAndSettle();
      expect(owner.answers.values, before);
      expect(owner.sent, isFalse);
      expect(_key('family_page'), findsOneWidget);
      final covered = await _formActions(tester);
      final navigator = Navigator.of(
        tester.element(find.byType(SelahFamilyCompatibilityView)),
      );
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('Unrelated covering route')),
        ),
      );
      await tester.pumpAndSettle();
      covered.change('Foreign route write');
      covered.send();
      covered.back();
      await tester.pumpAndSettle();
      expect(owner.answers.values, before);
      expect(owner.sent, isFalse);
      expect(find.text('Unrelated covering route'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      covered.change('Stale form after foreign route pops');
      covered.send();
      covered.back();
      await tester.pumpAndSettle();
      expect(owner.answers.values, before);
      expect(owner.sent, isFalse);
      await tapFamilyControl(tester, 'family_send');
      expect(owner.sent, isTrue);
    },
  );

  testWidgets('Own Family send alone keeps existing next-step barrier closed', (
    tester,
  ) async {
    await reachFamilyStage(tester, capture: _capture);
    await openFamilyStage(tester);
    await fillFamilyAnswers(tester);
    final owner = _controller(tester);
    await tapFamilyControl(tester, 'family_send');
    expect(owner.sent, isTrue);
    expect(owner.peerSent, isFalse);
    expect(owner.bothSent, isFalse);
    await tapFamilyControl(tester, 'family_back');
    await familyJourneyAction(tester, 'concept_journey_arrival_continue');
    expect(
      tester
          .widget<OutlinedButton>(_key('draft_stage_ready_$_person'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<SelahConceptJourneyPresentation>(
            find.byType(SelahConceptJourneyPresentation),
          )
          .stage
          .value,
      'family_stage',
    );
  });

  testWidgets(
    'Both real Family sends replace Waiting and allow existing stage progression',
    (tester) async {
      await reachFamilyStage(tester, capture: _capture);
      await openFamilyStage(tester);
      await finishFamilyAnswers(tester, journeyId: _person);
      await familyJourneyAction(tester, 'draft_stage_ready_$_person');
      await familyJourneyAction(tester, 'draft_stage_peer_ready_$_person');
      await familyJourneyAction(tester, 'draft_stage_next_$_person');
      expect(
        tester
            .widget<SelahConceptJourneyPresentation>(
              find.byType(SelahConceptJourneyPresentation),
            )
            .stage
            .value,
        'conversation',
      );
    },
  );
}
