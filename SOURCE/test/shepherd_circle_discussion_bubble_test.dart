// Session-only Circle discussion markers and caller-owned profile views.
// No marker is a service message, history permission or member access grant.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selah/dev/selah_shepherd_circle_preview.dart';
import 'package:selah/dev/selah_shepherd_circle_topic_options.dart';
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/screens/profile/seeker_profile_screen.dart';
import 'package:selah/screens/mentor/family_messaging_screens.dart';
import 'package:selah/services/selah_account_state.dart';
import 'package:selah/services/selah_developer_access.dart';
import 'package:selah/services/selah_family_messaging_service.dart';
import 'package:selah/state/app_state.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_text.dart';

const _font = 'PoppinsCircleDiscussionBubble';
const _captures = String.fromEnvironment('SELAH_CIRCLE_TOPIC_CAPTURE_DIR');
const _boundary = ValueKey('circle-discussion-bubble-capture');
const _sara = SelahFamilyMessageContext(
  referenceId: 'draft-sara',
  firstName: 'Sara',
  kind: SelahFamilyMessageContextKind.active,
);
const _safeSara = SeekerProfile(
  id: 'draft-sara',
  firstName: 'Sara',
  age: 27,
  city: 'Birmingham',
  photos: [],
  gender: 'female',
  surnameLine: 'Ahmed',
);

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _marker(String id) => _key('circle_discussion_bubble_$id');
Finder get _bubbles => find.byType(SelahCircleDiscussionBubble);
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
    throw StateError(
      'Discussion markers and owned sample profiles stay offline.',
    );
  }
}

class _Fixture {
  _Fixture({
    this.shepherd = false,
    this.funded = true,
    this.withResolver = true,
    bool emptyHistory = false,
    SelahCircleTopicLayout mode = SelahCircleTopicLayout.inChat,
  }) : layout = ValueNotifier(mode) {
    data = SelahShepherdCirclePreviewData(
      seekerId: 'draft-self',
      senderId: shepherd ? 'draft-hassan' : 'draft-self',
      canSend: funded,
      participants: [
        SelahFamilyCircleParticipant(
          userId: 'draft-self',
          firstName: 'Adam',
          memberRole: 'seeker',
          isMainShepherd: false,
          isCurrentUser: !shepherd,
        ),
        SelahFamilyCircleParticipant(
          userId: 'draft-hassan',
          firstName: 'Hassan',
          memberRole: 'shepherd',
          isMainShepherd: true,
          isCurrentUser: shepherd,
        ),
      ],
      messages: emptyHistory
          ? const []
          : [
              SelahFamilyMessage(
                id: 'draft-circle-first',
                senderId: 'draft-hassan',
                senderFirstName: 'Hassan',
                senderRoleLabel: 'Main Shepherd',
                body: 'An existing Circle message.',
                createdAt: DateTime.utc(2026, 10, 13, 9),
              ),
              SelahFamilyMessage(
                id: 'draft-circle-second',
                senderId: 'draft-self',
                senderFirstName: 'Adam',
                senderRoleLabel: 'Seeker',
                body: 'The conversation is already underway.',
                createdAt: DateTime.utc(2026, 10, 13, 9, 1),
              ),
            ],
      contexts: const [_sara],
    );
  }

  final bool shepherd;
  final bool funded;
  final bool withResolver;
  final ValueNotifier<SelahCircleTopicLayout> layout;
  final ValueNotifier<bool> visibility = ValueNotifier(true);
  final past = [
    SelahCircleDiscussionTopic(
      id: 'draft-circle-past-elif',
      firstName: 'Elif',
      kind: SelahCircleTopicKind.past,
      endedOn: DateTime.utc(2026, 10, 10),
    ),
  ];
  late final SelahShepherdCirclePreviewData data;
  bool owner = true;
  bool permitted = true;
  String resolution = 'valid';
  int contextOpens = 0;
  final resolved = <SelahFamilyMessageContext>[];
  bool _current() => owner;
  bool _foreground() => visibility.value;
  late final bool Function() ownerGuard = _current;
  late final bool Function() foregroundGuard = _foreground;
  void _oldContext(SelahFamilyMessageContext _) {
    contextOpens++;
  }

  late final ValueChanged<SelahFamilyMessageContext> oldContext = _oldContext;

  SeekerProfile? _resolve(SelahFamilyMessageContext context) {
    resolved.add(context);
    if (!permitted || resolution == 'null') return null;
    if (resolution == 'throw') throw StateError('Synthetic resolver denial');
    if (resolution == 'wrong id') {
      return const SeekerProfile(
        id: 'draft-other',
        firstName: 'Sara',
        age: 27,
        city: 'Birmingham',
        photos: [],
        gender: 'female',
      );
    }
    if (resolution == 'wrong name') {
      return const SeekerProfile(
        id: 'draft-sara',
        firstName: 'Someone else',
        age: 27,
        city: 'Birmingham',
        photos: [],
        gender: 'female',
      );
    }
    if (resolution == 'different object') {
      return SeekerProfile(
        id: _safeSara.id,
        firstName: _safeSara.firstName,
        age: _safeSara.age,
        city: _safeSara.city,
        photos: const [],
        gender: 'female',
      );
    }
    return identical(context, _sara) ? _safeSara : null;
  }

  late final SeekerProfile? Function(SelahFamilyMessageContext) resolver =
      _resolve;

  SelahShepherdCircleScreen screen({
    SeekerProfile? Function(SelahFamilyMessageContext)? replacementResolver,
    SelahShepherdCirclePreviewData? replacementData,
  }) => SelahShepherdCircleScreen(
    key: const ValueKey('discussion-circle-owner'),
    seekerId: 'draft-self',
    seekerFirstName: 'Adam',
    viewerIsSeeker: !shepherd,
    preview: true,
    previewData: replacementData ?? data,
    previewTopicLayout: layout,
    previewPastTopics: past,
    previewForeground: foregroundGuard,
    previewVisibility: visibility,
    previewDiscussionProfileFor:
        replacementResolver ?? (withResolver ? resolver : null),
    canAct: ownerGuard,
    onOpenContext: oldContext,
  );
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: _font),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 59, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: RepaintBoundary(key: _boundary, child: child!),
  ),
  home: child,
);

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  Size size = const Size(393, 852),
  double scale = 1,
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
  await tester.pumpWidget(_app(fixture.screen(), scale: scale));
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
  await _press(tester, _key('circle_topic_tab_${past ? 1 : 0}'));
  await _press(
    tester,
    _key(id == 'general' ? 'circle_topic_general' : 'circle_topic_$id'),
  );
  expect(find.byType(SelahCircleTopicPicker), findsNothing);
}

Future<void> _send(WidgetTester tester, String body) async {
  await tester.enterText(_composer, body);
  await _press(tester, _circleButton('Send message'));
  expect(find.text(body), findsOneWidget);
}

VoidCallback _profileCallback(WidgetTester tester) => tester
    .widget<TextButton>(_key('circle_discussion_profile_draft-sara'))
    .onPressed!;

int _transcriptIndex(WidgetTester tester, Finder target) {
  final list = tester.widget<ListView>(find.byType(ListView));
  final children = (list.childrenDelegate as SliverChildListDelegate).children;
  final element = tester.element(target);
  var index = children.indexOf(element.widget);
  element.visitAncestorElements((ancestor) {
    final candidate = children.indexOf(ancestor.widget);
    if (candidate < 0) return true;
    index = candidate;
    return false;
  });
  expect(
    index,
    greaterThanOrEqualTo(0),
    reason: 'A rendered transcript child owns this content',
  );
  return index;
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captures.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final file = File('$_captures/$name.png');
    await file.create(exclusive: true);
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpOverrides? oldNetwork;
  late _NoNetwork network;
  late SharedPreferences preferences;
  late Map<String, Object?> beforePreferences;
  late List<Object?> beforeMember;
  Map<String, Object?> preferenceState() => {
    for (final key in preferences.getKeys()) key: preferences.get(key),
  };
  List<Object?> memberState() => [
    List.of(AppState.instance.saved),
    List.of(AppState.instance.activeJourneys),
    List.of(AppState.instance.potentialJourneys),
    List.of(AppState.instance.photos),
    AppState.instance.plan,
  ];

  setUpAll(() async {
    if (_captures.isNotEmpty &&
        (!_captures.startsWith('/') || !Directory(_captures).existsSync())) {
      throw StateError(
        'Discussion captures require an existing absolute directory.',
      );
    }
    final reading = FontLoader(_font);
    for (final weight in ['ExtraLight', 'Light', 'Regular', 'Medium']) {
      reading.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([reading.load(), icons.load()]);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ordinary-member-preference': 'keep',
    });
    preferences = await SharedPreferences.getInstance();
    SelahAccountState.resetForTesting();
    SelahAccountState.clearImagesForTesting = () async {};
    SelahDeveloperAccess.resetAuthorizationForTesting();
    SelahDeveloperAccess.setAuthorizedForTesting(true);
    AppState.instance.resetForAccountChange();
    SelahText.useTestFontStubs = true;
    SelahText.testReadingFontFamily = _font;
    beforePreferences = preferenceState();
    beforeMember = memberState();
    oldNetwork = HttpOverrides.current;
    network = _NoNetwork();
    HttpOverrides.global = network;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    expect(network.attempts, 0);
    expect(preferenceState(), beforePreferences);
    expect(memberState(), beforeMember);
    HttpOverrides.global = oldNetwork;
    SelahDeveloperAccess.setAuthorizedForTesting(false);
    SelahDeveloperAccess.resetAuthorizationForTesting();
    SelahAccountState.clearImagesForTesting = null;
    SelahText.useTestFontStubs = false;
    SelahText.testReadingFontFamily = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'request shell source binds profile projection to its exact permitted Seeker context and stable loaded-photo cache',
    () {
      final source = File(
        'lib/dev/selah_one_journey_concept_shell.dart',
      ).readAsStringSync();
      final circleStart = source.indexOf('Widget _shepherdCircle()');
      expect(circleStart, greaterThanOrEqualTo(0));
      final resolverStart = source.indexOf(
        'previewDiscussionProfileFor: shepherd',
        circleStart,
      );
      final resolverEnd = source.indexOf('canAct: ownerGuard', resolverStart);
      expect(resolverStart, greaterThan(circleStart));
      expect(resolverEnd, greaterThan(resolverStart));
      final binding = source
          .substring(resolverStart, resolverEnd)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(binding, contains('shepherd ? null'));
      expect(binding, contains('!current()'));
      expect(binding, contains("_page != 'shepherd_circle'"));
      expect(binding, contains('allowed.referenceId == context.referenceId'));
      expect(binding, contains('allowed.firstName == context.firstName'));
      expect(binding, contains('allowed.kind == context.kind'));
      expect(
        binding,
        contains('context.kind != SelahFamilyMessageContextKind.active'),
      );
      expect(binding, contains('_model.isBlocked(context.referenceId)'));
      expect(
        binding,
        contains(
          '_model.stateFor(context.referenceId) != DraftJourneyState.active',
        ),
      );
      expect(binding, contains('person.firstName == context.firstName'));
      expect(binding, contains('person == null || _photos == null'));
      expect(binding, contains('discussionProfiles.putIfAbsent('));
      expect(binding, contains('_displayProfile(person)'));
      expect(
        source.substring(circleStart, resolverStart),
        contains('final discussionProfiles = <String, SeekerProfile>{};'),
      );
    },
  );

  testWidgets(
    'selection immediately adds a gold discussion marker to the existing chat without sending a message',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      await tester.enterText(_composer, 'Keep this unfinished Circle draft');
      final controller = tester.widget<TextField>(_composer).controller!;
      await _select(tester, 'draft-sara');
      expect(_bubbles, findsOneWidget);
      expect(_marker('draft-sara'), findsOneWidget);
      expect(find.text('Discussing a Journey with Sara'), findsOneWidget);
      final text = tester.widget<Text>(
        find.text('Discussing a Journey with Sara'),
      );
      expect(text.style!.color, SelahColors.journeyGold);
      final box =
          tester.widget<Container>(_marker('draft-sara')).decoration
              as BoxDecoration;
      expect(box.border, isA<Border>());
      expect(
        (box.border! as Border).top.color.withValues(alpha: 1),
        SelahColors.journeyGold,
      );
      expect(tester.state(find.byType(SelahShepherdCircleScreen)), same(state));
      expect(tester.widget<TextField>(_composer).controller, same(controller));
      expect(controller.text, 'Keep this unfinished Circle draft');
      expect(find.text('An existing Circle message.'), findsOneWidget);
      expect(
        find.text('The conversation is already underway.'),
        findsOneWidget,
      );
      expect(fixture.data.messages.length, 2);
      expect(
        fixture.data.messages.every((message) => !message.lifecycle),
        isTrue,
      );
      expect(fixture.contextOpens, 0);
      await _capture(tester, 'discussion-current-marker');
    },
  );

  testWidgets(
    'initial General, repeated topic and picker cancellation do not append duplicate markers',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'general');
      expect(_bubbles, findsNothing);
      await _select(tester, 'draft-sara');
      await _select(tester, 'draft-sara');
      expect(_bubbles, findsOneWidget);
      await _openPicker(tester);
      Navigator.of(tester.element(find.byType(SelahCircleTopicPicker))).pop();
      await tester.pumpAndSettle();
      expect(_bubbles, findsOneWidget);
      expect(
        tester
            .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
            .topic
            .id,
        'draft-sara',
      );
      await _select(tester, 'general');
      await _select(tester, 'general');
      expect(_bubbles, findsNWidgets(2));
      expect(_marker('preview-circle-general'), findsOneWidget);
      expect(find.text('Back to general conversation'), findsOneWidget);
      expect(fixture.data.messages.length, 2);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'an empty Circle shows its discussion card before any message is sent',
    (tester) async {
      final fixture = _Fixture(emptyHistory: true);
      await _mount(tester, fixture);
      expect(find.text('Start the Shepherd Circle'), findsOneWidget);
      await _select(tester, 'draft-sara');
      expect(_bubbles, findsOneWidget);
      expect(find.text('Start the Shepherd Circle'), findsNothing);
      expect(_composer, findsOneWidget);
      expect(fixture.data.messages, isEmpty);
      await _capture(tester, 'discussion-empty-history-marker');
    },
  );

  testWidgets(
    'returning to an earlier topic keeps distinct chronological cards without duplicate sibling keys',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _select(tester, 'draft-circle-past-elif', past: true);
      await _select(tester, 'draft-sara');
      expect(_bubbles, findsNWidgets(3));
      expect(_marker('draft-sara'), findsNWidgets(2));
      expect(_key('circle_discussion_marker_1'), findsOneWidget);
      expect(_key('circle_discussion_marker_2'), findsOneWidget);
      expect(_key('circle_discussion_marker_3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'markers stay chronological between old messages, later sends, Past and General without replacing history',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _send(tester, 'A later message about Sara.');
      await _select(tester, 'draft-circle-past-elif', past: true);
      await _send(tester, 'A later message about the past Journey.');
      await tester.enterText(_composer, 'The next draft is still here');
      await _select(tester, 'general');
      expect(_bubbles, findsNWidgets(3));
      expect(find.text('Discussing a past Journey with Elif'), findsOneWidget);
      final sequence = [
        _transcriptIndex(
          tester,
          find.text('The conversation is already underway.'),
        ),
        _transcriptIndex(tester, _marker('draft-sara')),
        _transcriptIndex(tester, find.text('A later message about Sara.')),
        _transcriptIndex(tester, _marker('draft-circle-past-elif')),
        _transcriptIndex(
          tester,
          find.text('A later message about the past Journey.'),
        ),
        _transcriptIndex(tester, _marker('preview-circle-general')),
      ];
      for (var index = 1; index < sequence.length; index++) {
        expect(sequence[index], greaterThan(sequence[index - 1]));
      }
      expect(_key('circle_topic_tag_draft-sara'), findsOneWidget);
      expect(_key('circle_topic_tag_draft-circle-past-elif'), findsOneWidget);
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'The next draft is still here',
      );
      expect(fixture.data.messages.length, 2);
      expect(fixture.contextOpens, 0);
      await _capture(tester, 'discussion-chronological-markers');
    },
  );

  testWidgets(
    'placement changes and covered controls retain the same marker, local history and draft',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _send(tester, 'A local message before controls cover this Circle');
      await tester.enterText(
        _composer,
        'A draft held while comparing placements',
      );
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      final controller = tester.widget<TextField>(_composer).controller!;
      for (final mode in [
        SelahCircleTopicLayout.beforeChat,
        SelahCircleTopicLayout.both,
        SelahCircleTopicLayout.inChat,
      ]) {
        fixture.visibility.value = false;
        fixture.layout.value = mode;
        await tester.pumpAndSettle();
        expect(controller.text, 'A draft held while comparing placements');
        fixture.visibility.value = true;
        await tester.pumpAndSettle();
        if (mode.hasEntry) await _select(tester, 'draft-sara');
        expect(
          tester.state(find.byType(SelahShepherdCircleScreen)),
          same(state),
        );
        expect(_bubbles, findsOneWidget);
        expect(_marker('draft-sara'), findsOneWidget);
        expect(
          find.text('A local message before controls cover this Circle'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(_composer).controller,
          same(controller),
        );
        expect(controller.text, 'A draft held while comparing placements');
      }
    },
  );

  for (final shepherd in [false, true]) {
    testWidgets(
      'Basic ${shepherd ? 'Shepherd' : 'Seeker'} cannot add markers or profile access',
      (tester) async {
        final fixture = _Fixture(shepherd: shepherd, funded: false);
        await _mount(tester, fixture);
        expect(_composer, findsNothing);
        expect(find.byType(SelahCircleTopicPicker), findsNothing);
        expect(_bubbles, findsNothing);
        expect(find.byType(SeekerProfileScreen), findsNothing);
        expect(fixture.resolved, isEmpty);
      },
    );
  }

  testWidgets(
    'a covered picker cannot append a marker through its retained selection',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _openPicker(tester);
      final select = tester
          .widget<SelahCircleTopicPicker>(find.byType(SelahCircleTopicPicker))
          .onSelected;
      fixture.visibility.value = false;
      select(
        const SelahCircleDiscussionTopic(
          id: 'draft-sara',
          firstName: 'Sara',
          kind: SelahCircleTopicKind.current,
        ),
      );
      await tester.pumpAndSettle();
      expect(_bubbles, findsNothing);
      fixture.visibility.value = true;
      await tester.pumpAndSettle();
      await _select(tester, 'draft-sara');
      expect(_bubbles, findsOneWidget);
    },
  );

  testWidgets(
    'busy chat denies retained topic and profile callbacks while the original tagged send completes',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      final profile = _profileCallback(tester);
      final choose = tester
          .widget<SelahCircleTopicBar>(find.byType(SelahCircleTopicBar))
          .onChoose!;
      await tester.enterText(_composer, 'This pending send keeps its topic');
      await tester.tap(_circleButton('Send message'));
      await tester.pump(const Duration(milliseconds: 20));
      profile();
      choose();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(SeekerProfileScreen), findsNothing);
      expect(find.byType(SelahCircleTopicPicker), findsNothing);
      expect(_bubbles, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('This pending send keeps its topic'), findsOneWidget);
      expect(_key('circle_topic_tag_draft-sara'), findsOneWidget);
      expect(_bubbles, findsOneWidget);
    },
  );

  testWidgets(
    'permitted current Seeker profile is an owned read-only child and close preserves the exact Circle',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _send(tester, 'Existing local history before the profile child');
      await tester.enterText(
        _composer,
        'The same draft after returning from Sara',
      );
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      final controller = tester.widget<TextField>(_composer).controller!;
      await _press(tester, _key('circle_discussion_profile_draft-sara'));
      final child = tester.widget<SeekerProfileScreen>(
        find.byType(SeekerProfileScreen),
      );
      expect(
        _key('circle_discussion_profile_route_draft-sara'),
        findsOneWidget,
      );
      expect(child.profile, same(_safeSara));
      expect(child.actionBar, isNull);
      expect(child.swipeDownToDismiss, isTrue);
      expect(child.showCloseButtonWhenSwipeDismiss, isTrue);
      expect(child.canAct!(), isTrue);
      expect(child.onDismiss, isNotNull);
      expect(
        fixture.resolved.every((context) => identical(context, _sara)),
        isTrue,
      );
      expect(fixture.contextOpens, 0);
      await _capture(tester, 'discussion-owned-profile-child');
      await _press(tester, _key('seeker-profile-close'));
      expect(find.byType(SeekerProfileScreen), findsNothing);
      expect(tester.state(find.byType(SelahShepherdCircleScreen)), same(state));
      expect(tester.widget<TextField>(_composer).controller, same(controller));
      expect(controller.text, 'The same draft after returning from Sara');
      expect(
        find.text('Existing local history before the profile child'),
        findsOneWidget,
      );
      expect(_bubbles, findsOneWidget);
      await _capture(tester, 'discussion-owned-profile-return');
    },
  );

  testWidgets(
    'owned profile swipe Back returns exactly once to the same ongoing chat',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await tester.enterText(_composer, 'A draft survives profile swipe Back');
      final state = tester.state(find.byType(SelahShepherdCircleScreen));
      await _press(tester, _key('circle_discussion_profile_draft-sara'));
      final scope = _key('concept_pull_down_back_scope');
      expect(scope, findsOneWidget);
      final rect = tester.getRect(scope);
      await tester.timedDragFrom(
        Offset(rect.left + 30, rect.top + 65),
        const Offset(0, 230),
        const Duration(milliseconds: 450),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SeekerProfileScreen), findsNothing);
      expect(tester.state(find.byType(SelahShepherdCircleScreen)), same(state));
      expect(
        tester.widget<TextField>(_composer).controller!.text,
        'A draft survives profile swipe Back',
      );
      expect(_bubbles, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final resolution in [
    'no resolver',
    'null',
    'throw',
    'wrong id',
    'wrong name',
  ]) {
    testWidgets(
      '$resolution never creates a current profile link or navigation grant',
      (tester) async {
        final fixture = _Fixture(withResolver: resolution != 'no resolver')
          ..resolution = resolution;
        await _mount(tester, fixture);
        await _select(tester, 'draft-sara');
        expect(_bubbles, findsOneWidget);
        expect(_key('circle_discussion_profile_draft-sara'), findsNothing);
        expect(
          tester.widget<SelahCircleDiscussionBubble>(_bubbles).onViewProfile,
          isNull,
        );
        expect(find.byType(SeekerProfileScreen), findsNothing);
        expect(fixture.contextOpens, 0);
      },
    );
  }

  for (final shepherd in [false, true]) {
    testWidgets(
      '${shepherd ? 'Shepherd current' : 'Past and General'} markers never consult a profile resolver',
      (tester) async {
        final fixture = _Fixture(shepherd: shepherd);
        await _mount(tester, fixture);
        if (shepherd) await _select(tester, 'draft-sara');
        await _select(tester, 'draft-circle-past-elif', past: true);
        await _select(tester, 'general');
        expect(_bubbles, findsNWidgets(shepherd ? 3 : 2));
        expect(find.text('View profile'), findsNothing);
        expect(fixture.resolved, isEmpty);
        expect(find.byType(SeekerProfileScreen), findsNothing);
        expect(fixture.contextOpens, 0);
      },
    );
  }

  for (final denial in ['permission', 'different object', 'foreground']) {
    testWidgets(
      'retained profile callback rechecks $denial and cannot open a stale child',
      (tester) async {
        final fixture = _Fixture();
        await _mount(tester, fixture);
        await _select(tester, 'draft-sara');
        final open = _profileCallback(tester);
        if (denial == 'permission') fixture.permitted = false;
        if (denial == 'different object') fixture.resolution = denial;
        if (denial == 'foreground') fixture.visibility.value = false;
        open();
        await tester.pumpAndSettle();
        expect(find.byType(SeekerProfileScreen), findsNothing);
        expect(_bubbles, findsOneWidget);
        fixture.permitted = true;
        fixture.resolution = 'valid';
        fixture.visibility.value = true;
        await tester.pumpAndSettle();
        open();
        await tester.pumpAndSettle();
        expect(
          _key('circle_discussion_profile_route_draft-sara'),
          findsOneWidget,
        );
        await _press(tester, _key('seeker-profile-close'));
        expect(_bubbles, findsOneWidget);
      },
    );
  }

  for (final withdrawal in ['caller', 'developer']) {
    testWidgets(
      '$withdrawal withdrawal clears markers and denies retained profile access after restoration',
      (tester) async {
        final fixture = _Fixture();
        await _mount(tester, fixture);
        await _select(tester, 'draft-sara');
        final open = _profileCallback(tester);
        if (withdrawal == 'caller') {
          fixture.owner = false;
          open();
          fixture.owner = true;
        } else {
          SelahDeveloperAccess.setAuthorizedForTesting(false);
          SelahDeveloperAccess.setAuthorizedForTesting(true);
        }
        open();
        await tester.pumpAndSettle();
        expect(_bubbles, findsNothing);
        expect(_composer, findsNothing);
        expect(find.byType(SeekerProfileScreen), findsNothing);
        expect(fixture.contextOpens, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'replacing captured resolver identity withdraws rather than retargeting markers and child access',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      final open = _profileCallback(tester);
      await tester.pumpWidget(
        _app(fixture.screen(replacementResolver: (_) => _safeSara)),
      );
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(fixture.screen()));
      await tester.pumpAndSettle();
      expect(_bubbles, findsNothing);
      expect(_composer, findsNothing);
      expect(find.byType(SeekerProfileScreen), findsNothing);
      expect(fixture.contextOpens, 0);
    },
  );

  testWidgets(
    'replacing active contexts with a stale catalog cannot publish old markers or profile access',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      final open = _profileCallback(tester);
      final replacement = SelahShepherdCirclePreviewData(
        seekerId: fixture.data.seekerId,
        senderId: fixture.data.senderId,
        participants: fixture.data.participants,
        messages: fixture.data.messages,
        canSend: true,
        contexts: const [],
      );
      await tester.pumpWidget(
        _app(fixture.screen(replacementData: replacement)),
      );
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();
      expect(_bubbles, findsNothing);
      expect(_composer, findsNothing);
      expect(find.byType(SeekerProfileScreen), findsNothing);
    },
  );

  testWidgets('retained owned close cannot pop a covering unrelated route', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _mount(tester, fixture);
    await _select(tester, 'draft-sara');
    await _press(tester, _key('circle_discussion_profile_draft-sara'));
    final close = tester
        .widget<IconButton>(_key('seeker-profile-close'))
        .onPressed!;
    final navigator = Navigator.of(
      tester.element(find.byType(SeekerProfileScreen)),
    );
    final cover = MaterialPageRoute<void>(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Unrelated covering route'))),
    );
    navigator.push(cover);
    await tester.pumpAndSettle();
    close();
    await tester.pumpAndSettle();
    expect(cover.isCurrent, isTrue);
    expect(find.text('Unrelated covering route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(_key('seeker-profile-preview-unavailable'), findsNothing);
    expect(_key('seeker-profile-close'), findsOneWidget);
    close();
    await tester.pumpAndSettle();
    expect(find.byType(SeekerProfileScreen), findsNothing);
    expect(_bubbles, findsOneWidget);
  });

  testWidgets(
    'retained owned close after profile permission loss cannot dismiss its protected child',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _press(tester, _key('circle_discussion_profile_draft-sara'));
      final close = tester
          .widget<IconButton>(_key('seeker-profile-close'))
          .onPressed!;
      final route = ModalRoute.of(
        tester.element(find.byType(SeekerProfileScreen)),
      )!;
      fixture.permitted = false;
      close();
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(_key('seeker-profile-preview-unavailable'), findsOneWidget);
      expect(_composer, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'developer withdrawal clears the discussion marker and its owned profile route',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _select(tester, 'draft-sara');
      await _press(tester, _key('circle_discussion_profile_draft-sara'));
      final close = tester
          .widget<IconButton>(_key('seeker-profile-close'))
          .onPressed!;
      SelahDeveloperAccess.setAuthorizedForTesting(false);
      SelahDeveloperAccess.setAuthorizedForTesting(true);
      close();
      await tester.pumpAndSettle();
      expect(find.byType(SeekerProfileScreen), findsNothing);
      expect(_bubbles, findsNothing);
      expect(_composer, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gold marker and profile action remain reachable at 320 wide with 200 percent text',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture, size: const Size(320, 852), scale: 2);
      await _select(tester, 'draft-sara');
      expect(_marker('draft-sara'), findsOneWidget);
      expect(find.text('Discussing a Journey with Sara'), findsOneWidget);
      await _capture(tester, 'discussion-marker-small-large-text');
      await _press(tester, _key('circle_discussion_profile_draft-sara'));
      expect(
        _key('circle_discussion_profile_route_draft-sara'),
        findsOneWidget,
      );
      await _press(tester, _key('seeker-profile-close'));
      expect(_marker('draft-sara'), findsOneWidget);
      expect(_composer, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'discussion-profile-return-small-large-text');
    },
  );
}
