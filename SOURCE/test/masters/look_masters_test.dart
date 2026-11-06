// LOCKs 1/2 visual evidence through DOC-SELAH-0020's widget compare route.
// These are real draft screens with their existing fictional people/flows.
// They do not establish phone delivery, native launch or device acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_concept_preview_boundary.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/dev/selah_one_journey_concept_shell.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/main.dart' show SelahApp;
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phoneSize = Size(430, 932);
const _pixelRatio = 3.0;
const _safeArea = EdgeInsets.only(top: 59, bottom: 34);
final _look = Directory('../APP/APPROVED/LOOK').absolute;
final _output = Directory('${_look.path}/BUILT/V1');

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

class _Screen {
  _Screen(this.pane, this.boundary);
  final Widget pane;
  final GlobalKey boundary;
}

Future<_Screen> _mount(WidgetTester tester, {bool shepherd = false}) async {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = _phoneSize * _pixelRatio;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  // Obtain the production theme and outer presentation builder from SelahApp.
  // The unavailable home is then replaced by the actual admitted local concept
  // shell. Runtime admission below still uses the real exact-bundle policy and
  // SELAH_DRAFT_LOCAL_ONLY compile-time flag; no admission check is bypassed.
  await tester.pumpWidget(const SelahApp());
  await tester.pump();
  final production = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(production.theme!.brightness, Brightness.light);
  final boundary = GlobalKey(debugLabel: 'look-built-screen');
  final pane = RepaintBoundary(
    key: boundary,
    child: SizedBox.fromSize(
      size: _phoneSize,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: production.theme,
        scrollBehavior: production.scrollBehavior,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: _phoneSize,
            devicePixelRatio: _pixelRatio,
            padding: _safeArea,
            viewPadding: _safeArea,
            viewInsets: EdgeInsets.zero,
            textScaler: TextScaler.noScaling,
            platformBrightness: Brightness.light,
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: production.builder?.call(context, child) ?? child!,
        ),
        home: SelahConceptPreviewBoundary(
          child: SelahOneJourneyConceptShell(
            canAct: () => true,
            onExit: () {},
            initialShepherdRole: shepherd,
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(pane);
  await tester.pump();
  return _Screen(pane, boundary);
}

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
  await _tab(tester, 'My SELAH');
  await _tap(tester, find.text('View requests').first);
  await _tap(tester, _key('concept_request_draft-amira_header'));
  await _tap(tester, _key('draft_accept_draft-amira'));
  expect(find.text('Choose to begin, together.'), findsOneWidget);
  await _tab(tester, 'Journey');
}

Future<void> _prepareImages(WidgetTester tester) async {
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    for (final widget in images) {
      var ready = false;
      Object? error;
      unawaited(
        precacheImage(
          widget.image,
          tester.element(find.byWidget(widget)),
          onError: (exception, _) => error = exception,
        ).then((_) => ready = true),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      // A FileImage started by a pumped widget may complete in the test's
      // FakeAsync zone. Keep pumping while the real codec/I/O event completes.
      while (!ready && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      expect(ready, isTrue, reason: 'First frame for ${widget.image}');
      expect(error, isNull, reason: 'Decode ${widget.image}');
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _golden(
  WidgetTester tester,
  GlobalKey boundary,
  String filename,
) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: _pixelRatio);
    try {
      expect(image.width, (render.size.width * _pixelRatio).round());
      expect(image.height, (render.size.height * _pixelRatio).round());
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await expectLater(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        matchesGoldenFile(File('${_output.path}/$filename').uri),
      );
    } finally {
      image.dispose();
    }
  });
}

Future<void> _capture(
  WidgetTester tester,
  _Screen screen,
  String master,
) async {
  await _prepareImages(tester);
  expect(tester.getSize(find.byKey(screen.boundary)), _phoneSize);
  await _golden(tester, screen.boundary, '${master}__build.png');
  final comparison = GlobalKey(debugLabel: 'look-master-beside-build');
  tester.view.physicalSize = const Size(860, 932) * _pixelRatio;
  // Reparent the same real app subtree at its original 430-pixel width. Its
  // GlobalKey preserves current navigation/state; no screen is redrawn here.
  await tester.pumpWidget(
    RepaintBoundary(
      key: comparison,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            SizedBox.fromSize(
              size: _phoneSize,
              child: Image.file(
                File('${_look.path}/MASTERS/$master.png'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            screen.pane,
          ],
        ),
      ),
    ),
  );
  await _prepareImages(tester);
  expect(tester.getSize(find.byKey(comparison)), const Size(860, 932));
  await _golden(tester, comparison, '${master}__master_beside_build.png');
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
    final figtree = FontLoader('Figtree')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Figtree[wght].ttf').readAsBytesSync(),
          ),
        ),
      );
    final cormorant = FontLoader('Cormorant Garamond');
    for (final file in [
      'CormorantGaramond[wght].ttf',
      'CormorantGaramond-Italic[wght].ttf',
    ]) {
      cormorant.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([figtree.load(), cormorant.load(), icons.load()]);
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
    await _tab(tester, 'My SELAH');
    expect(find.text('Journey request from Amira'), findsWidgets);
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
