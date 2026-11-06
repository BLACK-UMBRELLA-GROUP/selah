// LOCK 7/13, Q7/Q10: real root Journey actions, with the existing private
// scenario controls. No isolated mock pause or admission bypass is captured.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahDraftRoot;
import 'package:selah/models/selah_action_pause.dart';
import 'package:selah/models/selah_action_pause_controller.dart';
import 'package:selah/screens/journey/selah_pause_screen.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _capture = MasterCaptureHarness(feature: 'SELAH_PAUSE');
final _replaceCapture = MasterCaptureHarness(
  feature: 'SELAH_PAUSE',
  version: 'V1_1',
);
MasterCaptureHarness _captureFor(String master) =>
    master.startsWith('L07_pause_replace') ? _replaceCapture : _capture;
const _masters = {
  'L07_pause_ask',
  'L07_pause_ask__sending',
  'L07_pause_ask__didnt_send',
  'L07_pause_accept',
  'L07_pause_end',
  'L07_pause_end__ending',
  'L07_pause_end__no_shepherd',
  'L07_pause_replace',
  'L07_pause_replace__ending',
  'L07_pause_replace__didnt_go_through',
};
Finder _key(String value) => find.byKey(ValueKey<String>(value));

SelahActionPauseController _controller(WidgetTester tester) =>
    tester.widget<SelahPauseScreen>(find.byType(SelahPauseScreen)).controller;

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
  final nav = find.byType(SelahShellNavigation);
  final target = find.descendant(of: nav, matching: find.text(label));
  expect(target, findsOneWidget);
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
}

Future<MasterScreen> _root(WidgetTester tester) async {
  final screen = await _capture.mount(tester, home: const SelahDraftRoot());
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
    fail('The actual root Browse deck did not prepare its local portraits.');
  });
  await tester.pumpAndSettle();
  return screen;
}

Future<void> _seedJourneys(WidgetTester tester, int count) async {
  await _tab(tester, 'Journey');
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('concept_journey_preview_$count'));
}

Future<void> _openReceived(WidgetTester tester) async {
  await _tab(tester, 'My SELAH');
  await _tap(tester, find.text('View requests').first);
  await _tap(tester, _key('concept_request_draft-amira_header'));
  await _tap(tester, _key('draft_accept_draft-amira'));
}

Future<void> _removeShepherds(WidgetTester tester) async {
  await _tab(tester, 'Shepherd');
  for (final id in ['draft-shepherd-hassan', 'draft-shepherd-yusuf']) {
    await _tap(tester, _key('seeker_shepherd_manage_$id'));
    await _tap(tester, _key('shepherd-remove').hitTestable());
    final confirmation = _key('shepherd-remove-confirmation');
    await _tap(
      tester,
      find
          .descendant(of: confirmation, matching: find.text('Confirm'))
          .hitTestable(),
    );
  }
  expect(_key('shepherdship-manager-empty'), findsOneWidget);
}

Future<MasterScreen> _openPause(
  WidgetTester tester,
  SelahActionPauseKind kind, {
  bool noShepherd = false,
}) async {
  final screen = await _root(tester);
  switch (kind) {
    case SelahActionPauseKind.ask:
      await _tap(tester, _key('draft_profile_draft-sara'));
    case SelahActionPauseKind.accept:
      await _openReceived(tester);
    case SelahActionPauseKind.end:
      await _seedJourneys(tester, 1);
      if (noShepherd) await _removeShepherds(tester);
      await _tab(tester, 'Journey');
      await _tap(tester, _key('draft_journey_options_draft-sara'));
      await _tap(tester, _key('draft_options_end_draft-sara'));
    case SelahActionPauseKind.replace:
      await _seedJourneys(tester, 3);
      await _openReceived(tester);
      expect(_key('request_capacity_choice'), findsOneWidget);
      await _tap(tester, _key('request_capacity_journey_draft-sara'));
      await _tap(tester, _key('request_capacity_continue'));
  }
  expect(_key('pause_${kind.name}'), findsOneWidget);
  expect(find.byType(SelahShellNavigation), findsNothing);
  return screen;
}

Future<void> _preset(WidgetTester tester, String state) async {
  await _tap(tester, _key('pause_developer_actions'));
  await _tap(tester, _key('pause_state_$state'));
  expect(
    _controller(tester).state,
    state == 'working'
        ? SelahActionPauseState.working
        : SelahActionPauseState.failed,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? originalHttp;
  bool? originalFonts;
  setUpAll(() async {
    final present = Directory('${_capture.featureRoot.path}/MASTERS')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .map((file) => file.uri.pathSegments.last.replaceFirst('.png', ''))
        .toSet();
    expect(present, _masters, reason: 'Q7 adds the tenth locked master.');
    originalHttp = HttpOverrides.current;
    originalFonts = GoogleFonts.config.allowRuntimeFetching;
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
      reason: 'Use --dart-define=SELAH_DRAFT_LOCAL_ONLY=true.',
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
    GoogleFonts.config.allowRuntimeFetching = originalFonts!;
    HttpOverrides.global = originalHttp;
  });

  for (final entry in {
    'L07_pause_ask': SelahActionPauseKind.ask,
    'L07_pause_accept': SelahActionPauseKind.accept,
    'L07_pause_end': SelahActionPauseKind.end,
    'L07_pause_replace': SelahActionPauseKind.replace,
    'L07_pause_end__no_shepherd': SelahActionPauseKind.end,
  }.entries) {
    testWidgets('actual root ${entry.key}', (tester) async {
      final screen = await _openPause(
        tester,
        entry.value,
        noShepherd: entry.key.endsWith('no_shepherd'),
      );
      await _captureFor(entry.key).capture(tester, screen, entry.key);
    });
  }

  for (final entry in {
    'L07_pause_ask__sending': SelahActionPauseKind.ask,
    'L07_pause_ask__didnt_send': SelahActionPauseKind.ask,
    'L07_pause_end__ending': SelahActionPauseKind.end,
    'L07_pause_replace__ending': SelahActionPauseKind.replace,
    'L07_pause_replace__didnt_go_through': SelahActionPauseKind.replace,
  }.entries) {
    testWidgets('actual root private state ${entry.key}', (tester) async {
      final screen = await _openPause(tester, entry.value);
      final failed = entry.key.contains('didnt');
      await _preset(tester, failed ? 'failed' : 'working');
      await _captureFor(entry.key).capture(tester, screen, entry.key);
    });
  }

  testWidgets('Not yet keeps request unsent; confirmation sends once', (
    tester,
  ) async {
    await _openPause(tester, SelahActionPauseKind.ask);
    final first = _controller(tester);
    await _tap(tester, _key('pause_not_yet'));
    expect(find.byType(SelahPauseScreen), findsNothing);
    expect(await first.confirm(), isFalse);
    final deck = tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );
    final person = deck.profiles.firstWhere(
      (person) => person.id == 'draft-sara',
    );
    expect(deck.invitationSent!(person), isFalse);
    await _tap(tester, _key('draft_profile_draft-sara'));
    await _tap(tester, _key('pause_confirm'));
    expect(find.byType(SelahPauseScreen), findsNothing);
    final updated = tester.widget<SelahOneJourneyBrowseDesigns>(
      find.byType(SelahOneJourneyBrowseDesigns),
    );
    expect(updated.invitationSent!(person), isTrue);
  });

  testWidgets('no Shepherd blocks ask and accept without opening a pause', (
    tester,
  ) async {
    await _root(tester);
    await _removeShepherds(tester);
    await _tab(tester, 'Browse');
    await _tap(tester, _key('draft_profile_draft-sara'));
    expect(find.byType(SelahPauseScreen), findsNothing);
    expect(find.text(SelahActionPause.noShepherdMessage), findsOneWidget);
    await _openReceived(tester);
    expect(find.byType(SelahPauseScreen), findsNothing);
    expect(find.text(SelahActionPause.noShepherdMessage), findsOneWidget);
    expect(_key('draft_accept_draft-amira'), findsOneWidget);
  });

  testWidgets('Replace stays atomic and publishes its exact local update', (
    tester,
  ) async {
    await _openPause(tester, SelahActionPauseKind.replace);
    final pause = _controller(tester).pause;
    expect(
      find.textContaining('Your Journeys are full. Accepting ${pause.name}'),
      findsOneWidget,
    );
    await _tap(tester, _key('pause_not_yet'));
    expect(_key('request_capacity_choice'), findsOneWidget);
    await _tap(tester, _key('request_capacity_continue'));
    await _tap(tester, _key('pause_confirm'));
    expect(_key('request_capacity_choice'), findsNothing);
    expect(find.text('Journey with ${pause.name} has begun.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tab(tester, 'My SELAH');
    expect(
      find.text(
        'You ended your Journey with ${pause.endingName} and '
        'accepted ${pause.name}. Both Shepherds were told.',
      ),
      findsOneWidget,
    );
  });
}
