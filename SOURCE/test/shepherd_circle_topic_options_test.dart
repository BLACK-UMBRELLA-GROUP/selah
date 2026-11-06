// Detached, caller-owned Circle discussion examples. These tests do not
// establish a member link, history consent, messaging or payment authority.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/services/selah_internal_preview_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selah/dev/dev_discovery_directions.dart';
import 'package:selah/dev/selah_shepherd_circle_preview.dart';
import 'package:selah/dev/selah_shepherd_circle_topic_options.dart';
import 'package:selah/dev/selah_one_journey_browse_designs.dart';
import 'package:selah/screens/mentor/family_messaging_screens.dart';
import 'package:selah/services/selah_account_state.dart';
import 'package:selah/services/selah_developer_access.dart';
import 'package:selah/services/selah_family_messaging_service.dart';
import 'package:selah/state/app_state.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/floating_nav_bar.dart';
import 'masters/master_capture.dart' show loadSelahMasterFonts;

void _setDraftAdmission(bool admitted) {
  if (admitted) {
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
      reason: 'Run with --dart-define=SELAH_DRAFT_LOCAL_ONLY=true.',
    );
    SelahInternalPreviewClient.beginPreview();
  } else {
    SelahDraftRuntime.stop();
    SelahInternalPreviewClient.finishSignOut();
  }
  // Publish the existing authority revision for listener/ABA simulation.
  // Admission comes only from the exact runtime policy above; the test
  // operator override is immediately cleared and never remains authority.
  SelahDeveloperAccess.setAuthorizedForTesting(true);
  SelahDeveloperAccess.setAuthorizedForTesting(false);
}

const _font = 'Figtree';
const _captureDirectory = String.fromEnvironment(
  'SELAH_CIRCLE_TOPIC_CAPTURE_DIR',
);
const _captureKey = ValueKey('circle-topic-options-capture');
const _newLayouts = [
  SelahCircleTopicLayout.inChat,
  SelahCircleTopicLayout.beforeChat,
  SelahCircleTopicLayout.both,
];
const _currentContexts = [
  SelahFamilyMessageContext(
    referenceId: 'draft-sara',
    firstName: 'Sara',
    kind: SelahFamilyMessageContextKind.active,
  ),
  SelahFamilyMessageContext(
    referenceId: 'draft-aisha',
    firstName: 'Aisha',
    kind: SelahFamilyMessageContextKind.active,
  ),
  SelahFamilyMessageContext(
    referenceId: 'draft-maryam',
    firstName: 'Maryam',
    kind: SelahFamilyMessageContextKind.active,
  ),
];

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _messageTags => find.descendant(
  of: find.byType(ListView),
  matching: find.byType(SelahCircleTopicTag),
);
Finder _messageTag(String id) => find.descendant(
  of: find.byType(ListView),
  matching: _key('circle_topic_tag_$id'),
);
Finder get _composer => find.descendant(
  of: _key('shepherd-circle-composer'),
  matching: find.byType(TextField),
);
Finder _circleButton(String tooltip) => find.descendant(
  of: find.byType(SelahShepherdCircleScreen),
  matching: find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  ),
);

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Circle topic comparisons must remain offline.');
  }
}

class _Fixture {
  _Fixture({
    SelahCircleTopicLayout mode = SelahCircleTopicLayout.inChat,
    bool canSend = true,
    this.shepherd = false,
    List<SelahCircleDiscussionTopic>? pastTopics,
  }) : layout = ValueNotifier(mode),
       past =
           pastTopics ??
           [
             for (var index = 0; index < 12; index++)
               SelahCircleDiscussionTopic(
                 id: 'draft-circle-past-$index',
                 firstName: index == 11
                     ? 'Yasmin A Long But Clearly Labelled Past Journey'
                     : const [
                         'Elif',
                         'Noor',
                         'Hafsa',
                         'Zainab',
                         'Huda',
                         'Safiya',
                         'Mariam',
                         'Amina',
                         'Khadija',
                         'Sumayya',
                         'Layla',
                       ][index],
                 kind: SelahCircleTopicKind.past,
                 endedOn: DateTime.utc(
                   2026,
                   10,
                   10,
                 ).subtract(Duration(days: index * 15)),
               ),
           ] {
    data = SelahShepherdCirclePreviewData(
      seekerId: 'draft-self',
      senderId: shepherd ? 'draft-shepherd-hassan' : 'draft-self',
      canSend: canSend,
      participants: [
        SelahFamilyCircleParticipant(
          userId: 'draft-self',
          firstName: 'Adam',
          memberRole: 'seeker',
          isMainShepherd: false,
          isCurrentUser: !shepherd,
        ),
        SelahFamilyCircleParticipant(
          userId: 'draft-shepherd-hassan',
          firstName: 'Hassan',
          memberRole: 'shepherd',
          isMainShepherd: true,
          isCurrentUser: shepherd,
        ),
        const SelahFamilyCircleParticipant(
          userId: 'draft-shepherd-yusuf',
          firstName: 'Yusuf',
          memberRole: 'shepherd',
          isMainShepherd: false,
          isCurrentUser: false,
        ),
      ],
      messages: [
        SelahFamilyMessage(
          id: 'draft-circle-welcome',
          senderId: 'draft-shepherd-hassan',
          senderFirstName: 'Hassan',
          senderRoleLabel: 'Main Shepherd',
          body: 'We are here to support your Journey.',
          createdAt: DateTime.utc(2026, 10, 12, 9),
        ),
      ],
      contexts: _currentContexts,
    );
  }

  final bool shepherd;
  final ValueNotifier<SelahCircleTopicLayout> layout;
  final ValueNotifier<bool> visibility = ValueNotifier(true);
  final List<SelahCircleDiscussionTopic> past;
  late final SelahShepherdCirclePreviewData data;
  bool owner = true;
  int contextOpens = 0;
  bool _ownerCurrent() => owner;
  bool _foregroundCurrent() => visibility.value;
  late final bool Function() ownerGuard = _ownerCurrent;
  late final bool Function() foregroundGuard = _foregroundCurrent;
  void setForeground(bool visible) => visibility.value = visible;
  void _contextOpened(SelahFamilyMessageContext _) {
    contextOpens++;
  }

  late final ValueChanged<SelahFamilyMessageContext> openContext =
      _contextOpened;

  SelahShepherdCircleScreen screen({
    bool preview = true,
    SelahShepherdCirclePreviewData? replacementData,
    bool Function()? replacementGuard,
    bool Function()? replacementForeground,
    ValueListenable<bool>? replacementVisibility,
    ValueListenable<SelahCircleTopicLayout>? replacementLayout,
    List<SelahCircleDiscussionTopic>? replacementPast,
    bool? viewerIsSeeker,
    String seekerId = 'draft-self',
  }) => SelahShepherdCircleScreen(
    key: const ValueKey('controlled-circle-owner'),
    seekerId: seekerId,
    seekerFirstName: 'Adam',
    viewerIsSeeker: viewerIsSeeker ?? !shepherd,
    preview: preview,
    previewData: replacementData ?? data,
    previewTopicLayout: replacementLayout ?? layout,
    previewPastTopics: replacementPast ?? past,
    previewForeground: replacementForeground ?? foregroundGuard,
    previewVisibility: replacementVisibility ?? visibility,
    canAct: replacementGuard ?? ownerGuard,
    onOpenContext: openContext,
  );
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 59, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: RepaintBoundary(key: _captureKey, child: child!),
  ),
  home: child,
);

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  double scale = 1,
  Size size = const Size(393, 852),
  Widget? screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(fixture.layout.dispose);
  addTearDown(fixture.visibility.dispose);
  expect(
    fixture.data.validFor('draft-self', viewerIsSeeker: !fixture.shepherd),
    isTrue,
  );
  await tester.pumpWidget(_app(screen ?? fixture.screen(), scale: scale));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _press(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  if (find
      .ancestor(of: target, matching: find.byType(Scrollable))
      .evaluate()
      .isNotEmpty) {
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _openPicker(WidgetTester tester) async {
  expect(_key('circle_topic_entry'), findsNothing);
  await _press(
    tester,
    find.descendant(
      of: _key('circle_topic_bar'),
      matching: find.byType(InkWell),
    ),
  );
  expect(find.byType(SelahCircleTopicPicker), findsOneWidget);
}

Future<void> _select(
  WidgetTester tester,
  String id, {
  bool past = false,
}) async {
  if (find.byType(SelahCircleTopicPicker).evaluate().isEmpty) {
    await _openPicker(tester);
  }
  if (past) await _press(tester, _key('circle_topic_tab_1'));
  await _press(
    tester,
    _key(id == 'general' ? 'circle_topic_general' : 'circle_topic_$id'),
  );
  expect(find.byType(SelahCircleTopicPicker), findsNothing);
}

Future<void> _send(WidgetTester tester, String body) async {
  expect(_composer, findsOneWidget);
  await tester.enterText(_composer, body);
  await _press(tester, _circleButton('Send message'));
  expect(find.text(body), findsOneWidget);
  expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
}

VoidCallback _rowCallback(WidgetTester tester, String key) => tester
    .widget<InkWell>(
      find.descendant(of: _key(key), matching: find.byType(InkWell)),
    )
    .onTap!;

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDirectory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final file = File('$_captureDirectory/$name.png');
    await file.create(exclusive: true);
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}

Future<void> _mountShell(WidgetTester tester, {bool shepherd = false}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _app(
      ViewRequestDraftScreen(
        ownerGeneration: SelahAccountState.generation,
        ownerId: SelahAccountState.userId,
        initialShepherdRole: shepherd,
        onExit: () => fail('Circle Page options must not exit its owner.'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!shepherd) {
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        final target = find.byType(SelahOneJourneyBrowseDesigns);
        if (target.evaluate().isNotEmpty) {
          final deck = tester.widget<SelahOneJourneyBrowseDesigns>(target);
          if (deck.profiles.isNotEmpty &&
              deck.profiles.every((person) => person.photos.isNotEmpty)) {
            return;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await tester.pump();
      }
      fail('The bundled offline Browse deck did not prepare.');
    });
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}

Future<void> _nav(WidgetTester tester, int index) async {
  final nav = find.byType(FloatingNavBar);
  final cell = _key('floating-nav-item-$index');
  expect(nav, findsOneWidget);
  expect(cell, findsOneWidget);
  final box = tester.renderObject<RenderBox>(nav);
  final local = box.globalToLocal(tester.getCenter(cell));
  expect(
    nav.hitTestable(
      at: Alignment(
        local.dx * 2 / box.size.width - 1,
        local.dy * 2 / box.size.height - 1,
      ),
    ),
    findsOneWidget,
  );
  await tester.tapAt(tester.getCenter(cell));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _chooseShellMode(
  WidgetTester tester,
  SelahCircleTopicLayout mode, {
  String pageTitle = 'Shepherd Circle',
  bool returnsToCircle = true,
  String? menuCapture,
}) async {
  await _press(tester, _key('draft_back'));
  expect(find.text('Page options'), findsOneWidget);
  expect(_key('concept_page_options_context'), findsOneWidget);
  final contextTitle = tester.widget<Text>(
    _key('concept_page_options_context'),
  );
  expect(contextTitle.data, contains(pageTitle));
  final dropdown = find.byType(DropdownButtonFormField<SelahCircleTopicLayout>);
  expect(dropdown, findsOneWidget);
  if (menuCapture != null) await _capture(tester, menuCapture);
  await _press(tester, dropdown);
  final popup = find.byElementPredicate(
    (element) =>
        element.widget is Scrollable &&
        (ModalRoute.of(element)?.isCurrent ?? false),
  );
  expect(popup, findsOneWidget);
  final target = find.descendant(
    of: popup,
    matching: _key('concept_circle_topic_layout_${mode.name}'),
  );
  expect(target, findsOneWidget);
  await _press(
    tester,
    find.ancestor(of: target, matching: find.byType(InkWell)).first,
  );
  expect(find.text('Page options'), findsOneWidget);
  await _press(tester, _key('draft_back'));
  expect(find.text('Page options'), findsNothing);
  expect(
    find.byType(SelahShepherdCircleScreen),
    returnsToCircle ? findsOneWidget : findsNothing,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpOverrides? previousNetwork;
  late _NoNetwork network;
  late SharedPreferences preferences;
  late Map<String, Object?> beforePreferences;
  late List<Object?> beforeMemberState;

  Map<String, Object?> preferenceState() => {
    for (final key in preferences.getKeys()) key: preferences.get(key),
  };
  List<Object?> memberState() => [
    List.of(AppState.instance.saved),
    List.of(AppState.instance.potentialJourneys),
    List.of(AppState.instance.activeJourneys),
    List.of(AppState.instance.photos),
    AppState.instance.plan,
  ];

  setUpAll(() async {
    if (_captureDirectory.isNotEmpty &&
        (!_captureDirectory.startsWith('/') ||
            !Directory(_captureDirectory).existsSync())) {
      throw StateError(
        'Circle captures require an existing absolute directory.',
      );
    }
    await loadSelahMasterFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ordinary-member-preference': 'keep',
    });
    preferences = await SharedPreferences.getInstance();
    SelahAccountState.resetForTesting();
    SelahAccountState.clearImagesForTesting = () async {};
    SelahDeveloperAccess.resetAuthorizationForTesting();
    _setDraftAdmission(true);
    AppState.instance.resetForAccountChange();
    SelahText.useTestFontStubs = true;
    SelahText.testReadingFontFamily = _font;
    beforePreferences = preferenceState();
    beforeMemberState = memberState();
    previousNetwork = HttpOverrides.current;
    network = _NoNetwork();
    HttpOverrides.global = network;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    expect(network.attempts, 0);
    expect(preferenceState(), beforePreferences);
    expect(memberState(), beforeMemberState);
    HttpOverrides.global = previousNetwork;
    _setDraftAdmission(false);
    SelahDeveloperAccess.resetAuthorizationForTesting();
    SelahAccountState.clearImagesForTesting = null;
    SelahText.useTestFontStubs = false;
    SelahText.testReadingFontFamily = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final mode in _newLayouts) {
    testWidgets(
      '${mode.name} selects a Current topic and uses the one shared local chat',
      (tester) async {
        final fixture = _Fixture(mode: mode);
        await _mount(tester, fixture);
        expect(
          _key('circle_topic_entry'),
          mode.hasEntry ? findsOneWidget : findsNothing,
        );
        await _capture(tester, '${mode.name}-initial');
        await _select(tester, 'draft-sara');
        expect(_key('circle_topic_entry'), findsNothing);
        expect(
          _key('circle_topic_bar'),
          mode.hasInChat ? findsOneWidget : findsNothing,
        );
        expect(_composer, findsOneWidget);
        expect(
          find.text('We are here to support your Journey.'),
          findsOneWidget,
        );
        await _send(tester, 'A local message about Sara in ${mode.name}');
        expect(_messageTag('draft-sara'), findsOneWidget);
        expect(_messageTags, findsOneWidget);
        expect(_key('open-message-context-draft-sara'), findsNothing);
        final tag = tester.widget<SelahCircleTopicTag>(_messageTags);
        expect(tag.topic.kind, SelahCircleTopicKind.current);
        expect(
          find.descendant(of: _messageTags, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(fixture.contextOpens, 0);
        expect(fixture.data.messages.length, 1);
        await _capture(tester, '${mode.name}-current-message');
      },
    );

    testWidgets(
      '${mode.name} Basic remains read-only despite topics and paid-looking participants',
      (tester) async {
        final fixture = _Fixture(mode: mode, canSend: false);
        await _mount(tester, fixture);
        expect(_composer, findsNothing);
        expect(_circleButton('Send message'), findsNothing);
        expect(_key('circle_topic_entry'), findsNothing);
        expect(find.byType(SelahCircleTopicPicker), findsNothing);
        for (final bar in tester.widgetList<SelahCircleTopicBar>(
          find.byType(SelahCircleTopicBar),
        )) {
          expect(bar.onChoose, isNull);
        }
        expect(
          find.text('We are here to support your Journey.'),
          findsOneWidget,
        );
        expect(fixture.contextOpens, 0);
      },
    );
  }

  testWidgets(
    'Current keeps the original Circle presentation and context contract',
    (tester) async {
      final fixture = _Fixture(mode: SelahCircleTopicLayout.current);
      await _mount(tester, fixture);
      expect(find.byType(SelahCircleTopicBar), findsNothing);
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(_circleButton('Discuss someone'), findsOneWidget);
      await _send(tester, 'An untagged original Circle message');
      expect(find.byType(SelahCircleTopicTag), findsNothing);
      expect(
        fixture.data.contexts.every(
          (topic) => topic.kind == SelahFamilyMessageContextKind.active,
        ),
        isTrue,
      );
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'Past picker searches names and dates without opening old Journey routes',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _openPicker(tester);
      expect(_key('circle_topic_draft-sara'), findsOneWidget);
      expect(find.text('Potential'), findsNothing);
      expect(find.text('Paused'), findsNothing);
      await _press(tester, _key('circle_topic_tab_1'));
      expect(_key('circle_topic_draft-sara'), findsNothing);
      expect(find.text('10 Oct 2026'), findsOneWidget);
      expect(_key('circle_topic_general'), findsOneWidget);
      expect(_key('circle_topic_search'), findsOneWidget);
      await _capture(tester, 'past-picker');
      await tester.enterText(_key('circle_topic_search'), '2026-10-10');
      await tester.pumpAndSettle();
      expect(_key('circle_topic_draft-circle-past-0'), findsOneWidget);
      expect(_key('circle_topic_draft-circle-past-1'), findsNothing);
      await tester.enterText(_key('circle_topic_search'), '10/10/2026');
      await tester.pumpAndSettle();
      expect(_key('circle_topic_draft-circle-past-0'), findsOneWidget);
      await tester.enterText(_key('circle_topic_search'), 'yasmin a long');
      await tester.pumpAndSettle();
      expect(_key('circle_topic_draft-circle-past-11'), findsOneWidget);
      expect(_key('circle_topic_draft-circle-past-0'), findsNothing);
      await _press(tester, _key('circle_topic_draft-circle-past-11'));
      await _send(tester, 'A detached discussion of a past Journey');
      expect(_messageTag('draft-circle-past-11'), findsOneWidget);
      expect(_key('open-message-context-draft-circle-past-11'), findsNothing);
      expect(fixture.contextOpens, 0);
      expect(fixture.data.contexts, _currentContexts);
      await _capture(tester, 'past-message');
    },
  );

  testWidgets(
    'General is a selected topic rather than cancellation and does not tag the message',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-circle-past-0', past: true);
      await _send(tester, 'Tagged past topic');
      await _openPicker(tester);
      await _press(tester, _key('circle_topic_general'));
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .topic
            .isGeneral,
        isTrue,
      );
      await _send(tester, 'A general Circle conversation');
      expect(_messageTags, findsOneWidget);
      expect(_messageTag('draft-circle-past-0'), findsOneWidget);
      expect(_key('circle_topic_tag_preview-circle-general'), findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'changing placement preserves draft, local history and selected topic in the same Circle',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      await _select(tester, 'draft-circle-past-0', past: true);
      await _send(tester, 'First local past discussion');
      await tester.enterText(_composer, 'An unfinished shared draft');
      final controller = tester.widget<TextField>(_composer).controller!;
      for (final mode in [
        SelahCircleTopicLayout.beforeChat,
        SelahCircleTopicLayout.both,
        SelahCircleTopicLayout.inChat,
      ]) {
        fixture.layout.value = mode;
        await tester.pumpAndSettle();
        expect(
          tester.state(find.byType(SelahShepherdCircleScreen)),
          same(state),
        );
        expect(controller.text, 'An unfinished shared draft');
        if (mode.hasEntry) {
          await _select(tester, 'draft-circle-past-0', past: true);
        }
        expect(
          tester.widget<TextField>(_composer).controller,
          same(controller),
        );
        expect(find.text('First local past discussion'), findsOneWidget);
        expect(_messageTag('draft-circle-past-0'), findsOneWidget);
        if (mode.hasInChat) {
          expect(
            tester
                .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
                .topic
                .id,
            'draft-circle-past-0',
          );
        }
      }
      await _press(tester, _circleButton('Send message'));
      expect(find.text('An unfinished shared draft'), findsOneWidget);
      expect(_messageTag('draft-circle-past-0'), findsNWidgets(2));
      expect(fixture.data.messages.length, 1);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'Shepherd sender uses the same locally selected topic without acquiring Seeker authority',
    (tester) async {
      final fixture = _Fixture(shepherd: true);
      await _mount(tester, fixture);
      expect(find.text('Adam’s Shepherd Circle'), findsOneWidget);
      await _select(tester, 'draft-aisha');
      await _send(tester, 'A local Shepherd topic message');
      expect(_key('circle_topic_tag_draft-aisha'), findsOneWidget);
      expect(fixture.data.senderId, 'draft-shepherd-hassan');
      expect(
        fixture.data.participants
            .singleWhere((person) => person.isCurrentUser)
            .memberRole,
        'shepherd',
      );
      expect(fixture.contextOpens, 0);
    },
  );

  final invalidPast = <String, List<SelahCircleDiscussionTopic>>{
    'live-looking namespace': [
      SelahCircleDiscussionTopic(
        id: 'member-123',
        firstName: 'Elif',
        kind: SelahCircleTopicKind.past,
        endedOn: DateTime.utc(2026, 10, 10),
      ),
    ],
    'missing end date': const [
      SelahCircleDiscussionTopic(
        id: 'draft-circle-past-0',
        firstName: 'Elif',
        kind: SelahCircleTopicKind.past,
      ),
    ],
    'current kind': [
      SelahCircleDiscussionTopic(
        id: 'draft-circle-past-0',
        firstName: 'Elif',
        kind: SelahCircleTopicKind.current,
        endedOn: DateTime.utc(2026, 10, 10),
      ),
    ],
    'duplicate detached ID': [
      for (var i = 0; i < 2; i++)
        SelahCircleDiscussionTopic(
          id: 'draft-circle-past-0',
          firstName: 'Elif',
          kind: SelahCircleTopicKind.past,
          endedOn: DateTime.utc(2026, 10, 10),
        ),
    ],
  };
  for (final invalid in invalidPast.entries) {
    testWidgets(
      '${invalid.key} disables comparison without granting history or revoking valid chat',
      (tester) async {
        final fixture = _Fixture(pastTopics: invalid.value);
        await _mount(tester, fixture);
        expect(find.byType(SelahCircleTopicBar), findsNothing);
        expect(find.byType(SelahCircleTopicPicker), findsNothing);
        await _send(tester, 'Still an admitted ordinary local Circle');
        expect(find.byType(SelahCircleTopicTag), findsNothing);
        expect(fixture.contextOpens, 0);
      },
    );
  }

  testWidgets(
    'foreground cover temporarily denies retained callbacks without destroying owned draft or history',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _send(tester, 'A message before covering the Circle');
      await tester.enterText(
        _composer,
        'A draft retained while controls cover chat',
      );
      final controller = tester.widget<TextField>(_composer).controller!;
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      final send = tester
          .widget<IconButton>(_circleButton('Send message'))
          .onPressed!;
      fixture.setForeground(false);
      choose();
      send();
      await tester.pumpAndSettle();
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(
        find.text('A draft retained while controls cover chat'),
        findsOneWidget,
      );
      expect(controller.text, 'A draft retained while controls cover chat');
      expect(find.text('A message before covering the Circle'), findsOneWidget);
      fixture.layout.value = SelahCircleTopicLayout.both;
      await tester.pumpAndSettle();
      expect(controller.text, 'A draft retained while controls cover chat');
      fixture.setForeground(true);
      await tester.pumpAndSettle();
      await _select(tester, 'general');
      await _press(tester, _circleButton('Send message'));
      expect(
        find.text('A draft retained while controls cover chat'),
        findsOneWidget,
      );
      expect(controller.text, isEmpty);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'a covered open picker cannot select through a retained row callback',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _openPicker(tester);
      await _press(tester, _key('circle_topic_tab_1'));
      final choosePast = _rowCallback(
        tester,
        'circle_topic_draft-circle-past-0',
      );
      fixture.setForeground(false);
      choosePast();
      await tester.pumpAndSettle();
      expect(find.byType(SelahCircleTopicPicker), findsOneWidget);
      fixture.setForeground(true);
      await tester.pumpAndSettle();
      await _press(tester, _key('circle_topic_draft-circle-past-0'));
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      await _send(tester, 'Selection after the same owner returns');
      expect(_messageTag('draft-circle-past-0'), findsOneWidget);
      expect(fixture.contextOpens, 0);
    },
  );

  for (final boundary in ['caller', 'developer', 'account']) {
    testWidgets(
      '$boundary withdrawal is terminal across ABA for retained topic and send callbacks',
      (tester) async {
        final fixture = _Fixture();
        await _mount(tester, fixture);
        await tester.enterText(_composer, 'A revoked draft must never publish');
        final send = tester
            .widget<IconButton>(_circleButton('Send message'))
            .onPressed!;
        await _openPicker(tester);
        final choose = _rowCallback(tester, 'circle_topic_draft-sara');
        if (boundary == 'caller') {
          fixture.owner = false;
          choose();
          fixture.owner = true;
        } else if (boundary == 'developer') {
          _setDraftAdmission(false);
          _setDraftAdmission(true);
        } else {
          final ownerGeneration = SelahAccountState.generation;
          await tester.runAsync(() => SelahAccountState.beginSignOut());
          expect(SelahAccountState.isSigningOut, isTrue);
          expect(SelahAccountState.generation, greaterThan(ownerGeneration));
          choose();
          send();
          await tester.pumpAndSettle();
          SelahAccountState.endSignOutAttempt();
          _setDraftAdmission(true);
          expect(SelahAccountState.isSigningOut, isFalse);
          expect(SelahAccountState.generation, greaterThan(ownerGeneration));
        }
        choose();
        send();
        await tester.pumpAndSettle();
        fixture.layout.value = SelahCircleTopicLayout.both;
        await tester.pumpAndSettle();
        expect(find.byType(SelahCircleTopicPicker), findsNothing);
        expect(_composer, findsNothing);
        expect(find.text('A revoked draft must never publish'), findsNothing);
        expect(find.byType(SelahCircleTopicTag), findsNothing);
        expect(fixture.contextOpens, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending tagged send is denied after owner withdrawal even if restored before publication',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-circle-past-0', past: true);
      await tester.enterText(_composer, 'Never publish after revocation');
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      await tester.tap(_circleButton('Send message'));
      await tester.pump(const Duration(milliseconds: 20));
      fixture.owner = false;
      choose();
      await tester.pump();
      fixture.owner = true;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Never publish after revocation'), findsNothing);
      expect(find.byType(SelahCircleTopicTag), findsNothing);
      expect(_composer, findsNothing);
      expect(fixture.contextOpens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final replacement in [
    'data',
    'guard',
    'layout',
    'past',
    'foreground',
    'visibility',
    'role',
    'seeker',
  ]) {
    testWidgets(
      'replacing captured $replacement withdraws the Circle rather than retargeting its authority',
      (tester) async {
        final fixture = _Fixture();
        await _mount(tester, fixture);
        await tester.enterText(
          _composer,
          'A draft owned by the original inputs',
        );
        final send = tester
            .widget<IconButton>(_circleButton('Send message'))
            .onPressed!;
        final replacementLayout = ValueNotifier(SelahCircleTopicLayout.both);
        addTearDown(replacementLayout.dispose);
        final replacementVisibility = ValueNotifier(true);
        addTearDown(replacementVisibility.dispose);
        final replacementData = SelahShepherdCirclePreviewData(
          seekerId: fixture.data.seekerId,
          senderId: fixture.data.senderId,
          participants: fixture.data.participants,
          messages: fixture.data.messages,
          contexts: fixture.data.contexts,
          canSend: fixture.data.canSend,
        );
        await tester.pumpWidget(
          _app(
            fixture.screen(
              replacementData: replacement == 'data' ? replacementData : null,
              replacementGuard: replacement == 'guard' ? () => true : null,
              replacementLayout: replacement == 'layout'
                  ? replacementLayout
                  : null,
              replacementPast: replacement == 'past'
                  ? List.of(fixture.past)
                  : null,
              replacementForeground: replacement == 'foreground'
                  ? () => true
                  : null,
              replacementVisibility: replacement == 'visibility'
                  ? replacementVisibility
                  : null,
              viewerIsSeeker: replacement == 'role' ? false : null,
              seekerId: replacement == 'seeker' ? 'draft-other' : 'draft-self',
            ),
          ),
        );
        await tester.pumpAndSettle();
        send();
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(fixture.screen()));
        await tester.pumpAndSettle();
        expect(_composer, findsNothing);
        expect(find.text('A draft owned by the original inputs'), findsNothing);
        expect(fixture.contextOpens, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disposed owner callbacks and layout changes cannot resurrect the removed Circle',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await tester.enterText(_composer, 'A disposed draft');
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      final send = tester
          .widget<IconButton>(_circleButton('Send message'))
          .onPressed!;
      await tester.pumpWidget(
        _app(const Scaffold(body: Text('Replacement owner'))),
      );
      await tester.pumpAndSettle();
      fixture.layout.value = SelahCircleTopicLayout.both;
      choose();
      send();
      await tester.pumpAndSettle();
      expect(find.text('Replacement owner'), findsOneWidget);
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(find.text('A disposed draft'), findsNothing);
      expect(fixture.contextOpens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'raw preview props cannot create developer admission or a topic-enabled composer',
    (tester) async {
      _setDraftAdmission(false);
      final fixture = _Fixture(mode: SelahCircleTopicLayout.both);
      await _mount(tester, fixture);
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(find.byType(SelahCircleTopicBar), findsNothing);
      expect(_composer, findsNothing);
      _setDraftAdmission(true);
      fixture.layout.value = SelahCircleTopicLayout.inChat;
      await tester.pumpAndSettle();
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(_composer, findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  for (final admitted in [false, true]) {
    testWidgets(
      'topic options without supplied data preserve the ${admitted ? 'admitted legacy' : 'unadmitted'} Circle boundary',
      (tester) async {
        _setDraftAdmission(admitted);
        final fixture = _Fixture(mode: SelahCircleTopicLayout.both);
        await _mount(
          tester,
          fixture,
          screen: SelahShepherdCircleScreen(
            key: const ValueKey('legacy-with-raw-topic-options'),
            seekerId: 'draft-self',
            seekerFirstName: 'Adam',
            viewerIsSeeker: true,
            preview: true,
            previewTopicLayout: fixture.layout,
            previewPastTopics: fixture.past,
            previewForeground: fixture.foregroundGuard,
            previewVisibility: fixture.visibility,
            canAct: fixture.ownerGuard,
          ),
        );
        expect(find.byType(SelahCircleTopicPicker), findsNothing);
        expect(find.byType(SelahCircleTopicBar), findsNothing);
        expect(_key('circle_topic_entry'), findsNothing);
        expect(_composer, admitted ? findsOneWidget : findsNothing);
        if (admitted) {
          await _send(
            tester,
            'Only the retained admitted legacy local conversation',
          );
          expect(find.byType(SelahCircleTopicTag), findsNothing);
        }
        expect(SelahDeveloperAccess.canUseDeveloperTools, admitted);
        expect(SelahDeveloperAccess.isAuthorizedOperator, isFalse);
      },
    );
  }

  testWidgets(
    'a live-mode flag with supplied synthetic data and topics denies rather than starting member messaging',
    (tester) async {
      final fixture = _Fixture(mode: SelahCircleTopicLayout.both);
      await _mount(tester, fixture, screen: fixture.screen(preview: false));
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(find.byType(SelahCircleTopicBar), findsNothing);
      expect(_composer, findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'legacy Current person chip is hidden in new layouts and cannot mislabel a new-mode send',
    (tester) async {
      final fixture = _Fixture(mode: SelahCircleTopicLayout.current);
      await _mount(tester, fixture);
      final discuss = tester
          .widget<IconButton>(_circleButton('Discuss someone'))
          .onPressed!;
      await _press(tester, _circleButton('Discuss someone'));
      await _press(tester, find.text('Sara'));
      expect(_circleButton('Remove person'), findsOneWidget);
      await tester.enterText(_composer, 'One draft, not a second chat');
      fixture.layout.value = SelahCircleTopicLayout.inChat;
      await tester.pumpAndSettle();
      expect(_circleButton('Discuss someone'), findsNothing);
      expect(_circleButton('Remove person'), findsNothing);
      expect(
        find.descendant(
          of: _key('shepherd-circle-composer'),
          matching: find.text('Sara'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .topic
            .isGeneral,
        isTrue,
      );
      discuss();
      await tester.pumpAndSettle();
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(find.text('Discuss someone'), findsNothing);
      fixture.layout.value = SelahCircleTopicLayout.current;
      await tester.pumpAndSettle();
      expect(_circleButton('Remove person'), findsOneWidget);
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'One draft, not a second chat',
      );
      fixture.layout.value = SelahCircleTopicLayout.inChat;
      await tester.pumpAndSettle();
      await _select(tester, 'draft-aisha');
      await _press(tester, _circleButton('Send message'));
      expect(find.text('One draft, not a second chat'), findsOneWidget);
      expect(_messageTag('draft-aisha'), findsOneWidget);
      expect(_key('open-message-context-draft-sara'), findsNothing);
      expect(_key('open-message-context-draft-aisha'), findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'busy Topic bar and retained choose callback cannot interrupt or drop the tagged message',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await tester.enterText(
        _composer,
        'A pending message keeps its selected topic',
      );
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      await tester.tap(_circleButton('Send message'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .onChoose,
        isNull,
      );
      choose();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.text('A pending message keeps its selected topic'),
        findsOneWidget,
      );
      expect(_messageTag('draft-sara'), findsOneWidget);
      expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .onChoose,
        isNotNull,
      );
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'an entry picker cannot invoke hidden chat callbacks and a changed layout invalidates its old selector',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await tester.enterText(_composer, 'Retained while choosing a discussion');
      final send = tester
          .widget<IconButton>(_circleButton('Send message'))
          .onPressed!;
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      fixture.layout.value = SelahCircleTopicLayout.beforeChat;
      await tester.pumpAndSettle();
      expect(_key('circle_topic_entry'), findsOneWidget);
      final pick = _rowCallback(tester, 'circle_topic_draft-sara');
      choose();
      send();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SelahCircleTopicPicker), findsOneWidget);
      expect(_composer, findsNothing);
      fixture.layout.value = SelahCircleTopicLayout.inChat;
      await tester.pumpAndSettle();
      pick();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .topic
            .isGeneral,
        isTrue,
      );
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'Retained while choosing a discussion',
      );
      await _press(tester, _circleButton('Send message'));
      expect(find.text('Retained while choosing a discussion'), findsOneWidget);
      expect(_messageTags, findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'changing mode while a modal picker is open denies its retained selection and leaves the caller in control',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _openPicker(tester);
      final picker = find.byWidgetPredicate(
        (widget) => widget is SelahCircleTopicPicker && !widget.embedded,
      );
      final pick = _rowCallback(tester, 'circle_topic_draft-sara');
      final navigator = Navigator.of(tester.element(picker));
      fixture.layout.value = SelahCircleTopicLayout.beforeChat;
      await tester.pumpAndSettle();
      pick();
      await tester.pumpAndSettle();
      expect(picker, findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(_key('circle_topic_entry'), findsOneWidget);
      await _select(tester, 'general');
      await _send(tester, 'General after dismissing the old selector');
      expect(_messageTags, findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  for (final mode in _newLayouts) {
    testWidgets(
      '${mode.name} remains reachable at 320 wide and 200 percent text',
      (tester) async {
        final fixture = _Fixture(mode: mode);
        await _mount(tester, fixture, scale: 2, size: const Size(320, 852));
        if (!mode.hasEntry) await _openPicker(tester);
        await _press(tester, _key('circle_topic_tab_1'));
        await tester.enterText(_key('circle_topic_search'), 'yasmin');
        await tester.pumpAndSettle();
        expect(_key('circle_topic_draft-circle-past-11'), findsOneWidget);
        await _capture(tester, '${mode.name}-small-large-text-past');
        await _press(tester, _key('circle_topic_draft-circle-past-11'));
        await _send(tester, 'Small screen local message');
        expect(_messageTag('draft-circle-past-11'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, '${mode.name}-small-large-text-message');
      },
    );
  }

  testWidgets(
    'actual protected shell offers compact Circle-only modes and preserves the mounted shared chat',
    (tester) async {
      await _mountShell(tester);
      await _nav(tester, 1);
      await _press(tester, _key('draft_back'));
      await _press(tester, _key('concept_journey_preview_3'));
      await _nav(tester, 3);
      await _press(tester, _key('shepherd-family-messages-top'));
      final owner = tester.widget<SelahShepherdCircleScreen>(
        find.byType(SelahShepherdCircleScreen),
      );
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      expect(owner.preview, isTrue);
      expect(
        owner.previewData!.validFor('draft-self', viewerIsSeeker: true),
        isTrue,
      );
      expect(owner.previewPastTopics.length, 12);
      expect(
        owner.previewData!.contexts.every(
          (topic) => topic.kind == SelahFamilyMessageContextKind.active,
        ),
        isTrue,
      );
      await _send(tester, 'Shell Circle history must survive Page options');
      await tester.enterText(
        _composer,
        'Shell Circle draft must survive Page options',
      );
      final controller = tester.widget<TextField>(_composer).controller!;
      for (final mode in _newLayouts) {
        await _chooseShellMode(tester, mode);
        expect(
          tester.state(find.byType(SelahShepherdCircleScreen)),
          same(state),
        );
        expect(
          tester
              .widget<SelahShepherdCircleScreen>(
                find.byType(SelahShepherdCircleScreen),
              )
              .previewData,
          same(owner.previewData),
        );
        expect(controller.text, 'Shell Circle draft must survive Page options');
        if (mode.hasEntry) await _select(tester, 'general');
        expect(
          find.text('Shell Circle history must survive Page options'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(_composer).controller,
          same(controller),
        );
      }
      await _select(tester, 'draft-circle-past-0', past: true);
      await _press(tester, _circleButton('Send message'));
      expect(_key('circle_topic_tag_draft-circle-past-0'), findsOneWidget);
      expect(
        find.text('Shell Circle draft must survive Page options'),
        findsOneWidget,
      );
      await _capture(tester, 'protected-shell-in-chat');
      await _press(tester, _circleButton('Back'));
      expect(find.byType(SelahShepherdCircleScreen), findsNothing);
      expect(_key('shepherd-family-messages-top'), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsOneWidget);
    },
  );

  testWidgets(
    'actual Shepherd shell shares the compact topic dropdown and the one admitted Circle',
    (tester) async {
      await _mountShell(tester, shepherd: true);
      await _nav(tester, 2);
      await _press(tester, _key('seeker-family-chat-draft-self'));
      final owner = tester.widget<SelahShepherdCircleScreen>(
        find.byType(SelahShepherdCircleScreen),
      );
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      expect(owner.viewerIsSeeker, isFalse);
      expect(
        owner.previewData!.validFor('draft-self', viewerIsSeeker: false),
        isTrue,
      );
      expect(owner.previewData!.senderId, 'draft-shepherd-hassan');
      await _chooseShellMode(tester, SelahCircleTopicLayout.both);
      expect(tester.state(find.byType(SelahShepherdCircleScreen)), same(state));
      await _select(tester, 'draft-circle-past-0', past: true);
      await _send(tester, 'Shepherd shell local topic conversation');
      expect(_messageTag('draft-circle-past-0'), findsOneWidget);
      expect(_key('open-message-context-draft-circle-past-0'), findsNothing);
      await _capture(tester, 'protected-shepherd-shell-both');
      await _press(tester, _circleButton('Back'));
      expect(find.byType(SelahShepherdCircleScreen), findsNothing);
      expect(_key('seeker-family-chat-draft-self'), findsOneWidget);
    },
  );

  for (final shepherd in [false, true]) {
    final role = shepherd ? 'Shepherd' : 'Seeker';
    final parentTab = shepherd ? 2 : 3;
    final parentTitle = shepherd ? 'Seekers' : 'Shepherd';
    final circleEntry = shepherd
        ? 'seeker-family-chat-draft-self'
        : 'shepherd-family-messages-top';
    final dropdown = find.byType(
      DropdownButtonFormField<SelahCircleTopicLayout>,
    );

    testWidgets(
      '$role parent toggle selects every new placement for the same Circle topic notifier',
      (tester) async {
        await _mountShell(tester, shepherd: shepherd);
        await _nav(tester, parentTab);
        ValueListenable<SelahCircleTopicLayout>? sharedLayout;
        for (final mode in _newLayouts) {
          await _chooseShellMode(
            tester,
            mode,
            pageTitle: parentTitle,
            returnsToCircle: false,
            menuCapture: mode == SelahCircleTopicLayout.inChat
                ? '${role.toLowerCase()}-parent-discussion-options'
                : null,
          );
          await _press(tester, _key(circleEntry));
          final circle = tester.widget<SelahShepherdCircleScreen>(
            find.byType(SelahShepherdCircleScreen),
          );
          expect(circle.preview, isTrue);
          expect(circle.viewerIsSeeker, !shepherd);
          expect(
            circle.previewData!.validFor(
              'draft-self',
              viewerIsSeeker: !shepherd,
            ),
            isTrue,
          );
          expect(
            circle.previewData!.senderId,
            shepherd ? 'draft-shepherd-hassan' : 'draft-self',
          );
          expect(circle.previewTopicLayout, isNotNull);
          expect(circle.previewTopicLayout!.value, mode);
          if (sharedLayout == null) {
            sharedLayout = circle.previewTopicLayout;
          } else {
            expect(circle.previewTopicLayout, same(sharedLayout));
          }
          expect(
            _key('circle_topic_entry'),
            mode.hasEntry ? findsOneWidget : findsNothing,
          );
          if (mode == SelahCircleTopicLayout.both) {
            await _capture(
              tester,
              '${role.toLowerCase()}-parent-discussion-entry',
            );
          }
          if (!mode.hasEntry) await _openPicker(tester);
          expect(_key('circle_topic_general'), findsOneWidget);
          expect(_key('circle_topic_tab_0'), findsOneWidget);
          expect(_key('circle_topic_tab_1'), findsOneWidget);
          await _press(tester, _key('circle_topic_tab_1'));
          expect(_key('circle_topic_search'), findsOneWidget);
          expect(_key('circle_topic_draft-circle-past-0'), findsOneWidget);
          expect(find.text('10 Oct 2026'), findsOneWidget);
          expect(find.text('Potential'), findsNothing);
          expect(find.text('Paused'), findsNothing);
          await _select(tester, 'general');
          expect(_composer, findsOneWidget);
          expect(
            _key('circle_topic_bar'),
            mode.hasInChat ? findsOneWidget : findsNothing,
          );
          await _press(tester, _circleButton('Back'));
          expect(find.byType(SelahShepherdCircleScreen), findsNothing);
          expect(_key(circleEntry), findsOneWidget);
        }
      },
    );

    testWidgets(
      '$role unrelated parent tabs do not expose Journey discussion options',
      (tester) async {
        await _mountShell(tester, shepherd: shepherd);
        for (var tab = 0; tab < (shepherd ? 4 : 5); tab++) {
          if (tab == parentTab) continue;
          await _nav(tester, tab);
          await _press(tester, _key('draft_back'));
          expect(find.text('Page options'), findsOneWidget);
          expect(dropdown, findsNothing);
          expect(find.text('Journey discussion'), findsNothing);
          await _press(tester, _key('draft_back'));
          expect(find.text('Page options'), findsNothing);
        }
      },
    );

    for (final withdrawal in ['tab ABA', 'role ABA', 'authorization ABA']) {
      testWidgets(
        '$role parent $withdrawal refuses the retained topic-layout callback',
        (tester) async {
          await _mountShell(tester, shepherd: shepherd);
          await _nav(tester, parentTab);
          await _chooseShellMode(
            tester,
            SelahCircleTopicLayout.beforeChat,
            pageTitle: parentTitle,
            returnsToCircle: false,
          );
          await _press(tester, _key('draft_back'));
          final stale = tester
              .widget<DropdownButtonFormField<SelahCircleTopicLayout>>(dropdown)
              .onChanged!;
          if (withdrawal == 'tab ABA') {
            await _press(tester, _key('draft_back'));
            await _nav(tester, 0);
            await _nav(tester, parentTab);
            await _press(tester, _key('draft_back'));
          } else if (withdrawal == 'role ABA') {
            await _press(
              tester,
              _key(shepherd ? 'draft_role_seeker' : 'draft_role_shepherd'),
            );
            await _press(tester, _key('draft_back'));
            await _press(
              tester,
              _key(shepherd ? 'draft_role_shepherd' : 'draft_role_seeker'),
            );
            await _nav(tester, parentTab);
            await _press(tester, _key('draft_back'));
          } else {
            _setDraftAdmission(false);
            _setDraftAdmission(true);
            await tester.pumpAndSettle();
          }
          stale(SelahCircleTopicLayout.both);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (withdrawal == 'authorization ABA') {
            expect(dropdown, findsNothing);
            expect(find.byType(SelahShepherdCircleScreen), findsNothing);
          } else {
            expect(dropdown, findsOneWidget);
            expect(
              tester
                  .widget<DropdownButtonFormField<SelahCircleTopicLayout>>(
                    dropdown,
                  )
                  .initialValue,
              SelahCircleTopicLayout.beforeChat,
            );
            await _press(tester, _key('draft_back'));
            await _press(tester, _key(circleEntry));
            final circle = tester.widget<SelahShepherdCircleScreen>(
              find.byType(SelahShepherdCircleScreen),
            );
            expect(circle.viewerIsSeeker, !shepherd);
            expect(
              circle.previewTopicLayout!.value,
              SelahCircleTopicLayout.beforeChat,
            );
            expect(_key('circle_topic_entry'), findsOneWidget);
          }
        },
      );
    }
  }
}
