// LOCKs 1/2 visual evidence through DOC-SELAH-0020's widget compare route.
// These are real draft screens with their existing fictional people/flows.
// They do not establish phone delivery, native launch or device acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_concept_preview_boundary.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'master_capture.dart';

final _look = Directory('../APP/APPROVED/LOOK').absolute;
final _captureHarness = MasterCaptureHarness(feature: 'LOOK');
final _profileCapture = MasterCaptureHarness(feature: 'LOOK', version: 'V1_1');
// Exact current fixture images already reviewed under the later LOCKs. Keep
// earlier LOOK evidence intact instead of updating its historical snapshots.
final _stagesCapture = MasterCaptureHarness(
  feature: 'JOURNEY_STAGES',
  wordingRevision: false,
);
final _introduceCapture = MasterCaptureHarness(
  feature: 'SHEPHERD_INTRODUCE',
  wordingRevision: false,
);
// These distinct initial/preparing fixtures are not the phase-1 fixtures in
// JOURNEY_STAGES/V1. Record them separately under LOCK21; never substitute data.
final _initialJourneyCapture = MasterCaptureHarness(
  feature: 'LOOK',
  version: 'LOCK21_V1',
  wordingRevision: false,
);

// Features absent from the current app are deliberately not reconstructed in
// tests. The two absent async states are also not invented for screenshots.
const _skippedMasters = <String, String>{
  'L01_seeker_shepherd__permissions':
      'The master permissions screen/content is not LOCKed.',
  'L01_seeker_ask_for_prayer': 'Prayer is a later feature LOCK.',
  'L01_seeker_pause__before_asking': 'Selah pause is a later feature LOCK.',
  'L01_shepherd_prayer': 'The current Shepherd shell has no Prayer tab.',
  'L01_seeker_journeys__loading':
      'Draft Journey reads synchronous in-memory state; it has no load gate.',
  'L01_seeker_my_selah__action_failed':
      'Draft My SELAH has no asynchronous answer-send failure point.',
};

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// Delays/fails an actual input to the existing portrait-loading state machine.
/// Every other asset is handled by Flutter's real asset messenger.
class _PortraitGate {
  _PortraitGate({required this.fail}) {
    _messenger.setMockMessageHandler('flutter/assets', (message) {
      final asset = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (asset == _firstPortrait && !_released) {
        requested = true;
        return fail ? Future<ByteData?>.value() : _pending.future;
      }
      return _messenger.delegate.send('flutter/assets', message);
    });
  }

  static const _firstPortrait = 'assets/dev/one_journey_photos/selah1a.jpg';
  final bool fail;
  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final _pending = Completer<ByteData?>();
  bool requested = false;
  bool _released = false;

  void release() {
    _released = true;
    _messenger.setMockMessageHandler('flutter/assets', null);
    if (!_pending.isCompleted) {
      _pending.complete(
        ByteData.sublistView(File(_firstPortrait).readAsBytesSync()),
      );
    }
  }
}

Future<MasterScreen> _mount(WidgetTester tester, {bool shepherd = false}) =>
    _captureHarness.mount(
      tester,
      home: SelahConceptPreviewBoundary(
        child: SelahOneJourneyConceptShell(
          canAct: () => true,
          onExit: () {},
          initialShepherdRole: shepherd,
        ),
      ),
    );

Future<void> _waitForPhotos(WidgetTester tester) async {
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
    fail('The real offline Browse deck did not publish its bundled portraits.');
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _back(WidgetTester tester) async {
  // Dispatch the existing platform-back route; PopScope owns shell history.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tab(WidgetTester tester, String label) async {
  for (
    var i = 0;
    find.byType(SelahShellNavigation).evaluate().isEmpty && i < 8;
    i++
  ) {
    await _back(tester);
  }
  final nav = find.byType(SelahShellNavigation);
  expect(nav, findsOneWidget);
  final target = find.descendant(of: nav, matching: find.text(label));
  expect(target, findsOneWidget);
  // The bar's parent recognizer owns taps and scrubs; label children ignore
  // pointers intentionally. Tap the actual label's coordinates on that bar.
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _activeJourney(WidgetTester tester) async {
  await _tab(tester, 'Journey');
  await _tap(tester, _key('draft_back'));
  await _tap(tester, _key('concept_journey_preview_1'));
  expect(_key('draft_journey_draft-sara'), findsOneWidget);
}

Future<void> _preparingJourney(WidgetTester tester) async {
  await _tab(tester, 'My Selah');
  await _tap(tester, find.text('View requests').first);
  await _tap(tester, _key('concept_request_draft-amira_header'));
  await _tap(tester, _key('draft_accept_draft-amira'));
  await _tap(tester, _key('pause_confirm'));
  expect(find.text('Choose to begin, together.'), findsOneWidget);
  await _tab(tester, 'Journey');
}

Future<void> _capture(WidgetTester tester, MasterScreen screen, String master) {
  final harness = switch (master) {
    'L01_seeker_profile__faith' ||
    'L01_seeker_my_selah__request' => _stagesCapture,
    'L01_shepherd_seekers' => _introduceCapture,
    'L01_seeker_journeys__pending_and_free_place' ||
    'L01_seeker_journey__stages' => _initialJourneyCapture,
    'L01_seeker_browse__profile' => _profileCapture,
    _ => _captureHarness,
  };
  return harness.capture(
    tester,
    screen,
    master,
    masterFile: File('${_look.path}/MASTERS/$master.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? originalHttpOverrides;
  bool? originalFontFetching;

  setUpAll(() async {
    originalHttpOverrides = HttpOverrides.current;
    originalFontFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = SelahOfflineHttpOverrides();
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
          'Run with --dart-define=SELAH_DRAFT_LOCAL_ONLY=true. '
          'The real draft admission policy remains required.',
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

  test(
    'all LOCK masters have a real capture or an explicit scope exclusion',
    () {
      const captures = {
        'L01_seeker_browse__profile',
        'L01_seeker_journeys__pending_and_free_place',
        'L01_seeker_journeys__empty',
        'L01_seeker_journey__stages',
        'L01_seeker_my_selah__request',
        'L01_seeker_profile__faith',
        'L01_shepherd_seekers',
        'L01_seeker_browse__loading',
        'L01_seeker_browse__error',
      };
      final present = Directory('${_look.path}/MASTERS')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .map((file) => file.uri.pathSegments.last.replaceFirst('.png', ''))
          .toSet();
      expect(present, {...captures, ..._skippedMasters.keys});
      expect(captures.intersection(_skippedMasters.keys.toSet()), isEmpty);
    },
  );

  testWidgets('Browse: actual bundled profile', (tester) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _capture(tester, screen, 'L01_seeker_browse__profile');
  });

  testWidgets('Journey: existing accepted request awaiting both readiness', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _preparingJourney(tester);
    await tester.pump(const Duration(seconds: 4));
    await _capture(
      tester,
      screen,
      'L01_seeker_journeys__pending_and_free_place',
    );
  });

  testWidgets('Journey: fresh empty current-Journey list', (tester) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _tab(tester, 'Journey');
    expect(_key('concept_journey_empty'), findsOneWidget);
    await _capture(tester, screen, 'L01_seeker_journeys__empty');
  });

  testWidgets('Journey: real stage presentation via sample Journey control', (
    tester,
  ) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _activeJourney(tester);
    await _tap(tester, _key('draft_journey_draft-sara'));
    expect(_key('concept_journey_draft-sara'), findsOneWidget);
    await _capture(tester, screen, 'L01_seeker_journey__stages');
  });

  testWidgets('My SELAH: fresh received request', (tester) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _tab(tester, 'My Selah');
    expect(find.text('Journey request from Grace'), findsWidgets);
    await _capture(tester, screen, 'L01_seeker_my_selah__request');
  });

  testWidgets('Profile: existing own-profile screen and words', (tester) async {
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _tab(tester, 'Profile');
    expect(_key('concept_profile_title'), findsOneWidget);
    await _capture(tester, screen, 'L01_seeker_profile__faith');
  });

  testWidgets('Shepherd: existing Seekers tab, original tabs preserved', (
    tester,
  ) async {
    // Load the real portrait deck while on Seeker Browse, then select the
    // existing Shepherd role through its page controls.
    final screen = await _mount(tester);
    await _waitForPhotos(tester);
    await _tab(tester, 'Journey');
    await _tap(tester, _key('draft_back'));
    await _tap(tester, _key('draft_role_shepherd'));
    await _tab(tester, 'Seekers');
    await _capture(tester, screen, 'L01_shepherd_seekers');
  });

  testWidgets('Browse: actual portrait request remains loading', (
    tester,
  ) async {
    final gate = _PortraitGate(fail: false);
    try {
      final screen = await _mount(tester);
      await tester.pumpAndSettle();
      expect(gate.requested, isTrue);
      expect(_key('selah_loading_browse'), findsOneWidget);
      await _capture(tester, screen, 'L01_seeker_browse__loading');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      gate.release();
      await tester.pump();
    }
  });

  testWidgets('Browse: actual portrait request fails closed', (tester) async {
    final gate = _PortraitGate(fail: true);
    try {
      final screen = await _mount(tester);
      await tester.pumpAndSettle();
      expect(gate.requested, isTrue);
      expect(_key('selah_load_failure'), findsOneWidget);
      expect(find.text('Profiles didn’t load'), findsOneWidget);
      await _capture(tester, screen, 'L01_seeker_browse__error');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      gate.release();
      await tester.pump();
    }
  });
}
