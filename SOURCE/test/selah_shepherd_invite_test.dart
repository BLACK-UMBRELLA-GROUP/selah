import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_shepherd_invite.dart';
import 'package:selah/services/selah_developer_access.dart';
import 'package:selah/widgets/selah_shepherd_invite_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool ownerCurrent;
  late SelahShepherdInviteController controller;

  setUp(() {
    SelahDraftRuntime.stop();
    ownerCurrent = true;
    controller = SelahShepherdInviteController(canAct: () => ownerCurrent);
  });

  tearDown(() {
    controller.dispose();
    SelahDraftRuntime.stop();
  });

  void validName() => controller.setName('  David Okafor  ');

  void activatePrivateDraft() {
    expect(
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      ),
      isTrue,
      reason:
          'Run with --dart-define=SELAH_DRAFT_LOCAL_ONLY=true; no guard bypass.',
    );
    expect(SelahDeveloperAccess.canUseDeveloperTools, isTrue);
  }

  test('relationship choices are the closed six locked labels', () {
    expect(SelahShepherdRelation.values.map((item) => item.label), [
      'Parent',
      'Pastor',
      'Mentor',
      'Church elder',
      'Family member',
      'A mature Christian friend',
    ]);
    expect(controller.relation, isNull);
    expect(controller.continueChoice(), isFalse);
    expect(controller.showChoiceError, isTrue);
    controller.chooseRelation(SelahShepherdRelation.pastor);
    expect(controller.relation, SelahShepherdRelation.pastor);
    expect(controller.showChoiceError, isFalse);
    expect(controller.continueChoice(), isTrue);
    expect(controller.hasInvite, isFalse);
  });

  test('blank name fails; typing keeps its error until next send attempt', () {
    controller.chooseRelation(SelahShepherdRelation.parent);
    controller.setName('   ');
    expect(controller.send(), isFalse);
    expect(controller.showNameError, isTrue);
    expect(controller.hasInvite, isFalse);
    validName();
    expect(controller.showNameError, isTrue);
    expect(controller.send(), isTrue);
    expect(controller.showNameError, isFalse);
    expect(controller.fullName, 'David Okafor');
    expect(controller.firstName, 'David');
  });

  test('normal Send is local, synchronous and pending until accepted', () {
    controller.chooseRelation(SelahShepherdRelation.pastor);
    validName();
    expect(controller.send(), isTrue);
    expect(controller.sendState, SelahShepherdInviteSendState.sent);
    expect(controller.hasInvite, isTrue);
    expect(controller.pending, isTrue);
    expect(controller.accepted, isFalse);
    expect(SelahDraftRuntime.active, isFalse);
    expect(SelahDeveloperAccess.canUseDeveloperTools, isFalse);
    expect(controller.accept(), isTrue);
    expect(controller.accepted, isTrue);
    expect(controller.pending, isFalse);
    expect(controller.accept(), isFalse);
  });

  test('legacy direct Invite permits a name without inventing a relation', () {
    validName();
    expect(controller.relation, isNull);
    expect(controller.send(copied: true), isTrue);
    expect(controller.relation, isNull);
    expect(controller.pending, isTrue);
    expect(controller.sendState, SelahShepherdInviteSendState.sent);
  });

  test('accept cannot grant a link before an invite; reset clears session', () {
    expect(controller.accept(), isFalse);
    validName();
    expect(controller.send(), isTrue);
    expect(controller.accept(), isTrue);
    controller.reset();
    expect(controller.relation, isNull);
    expect(controller.fullName, isEmpty);
    expect(controller.firstName, isEmpty);
    expect(controller.hasInvite, isFalse);
    expect(controller.pending, isFalse);
    expect(controller.accepted, isFalse);
    expect(controller.sendState, SelahShepherdInviteSendState.idle);
    expect(controller.showChoiceError, isFalse);
    expect(controller.showNameError, isFalse);
  });

  test('a further successful local send requires acceptance again', () {
    validName();
    expect(controller.send(), isTrue);
    expect(controller.accept(), isTrue);
    controller.setName('Ruth Okafor');
    expect(controller.send(), isTrue);
    expect(controller.firstName, 'Ruth');
    expect(controller.pending, isTrue);
    expect(controller.accepted, isFalse);
  });

  test('private sending/failure presets require actual draft authority', () {
    validName();
    controller.showSending();
    controller.showFailure();
    expect(controller.sendState, SelahShepherdInviteSendState.idle);
    expect(
      SelahDraftRuntime.activate(bundleId: 'an.unapproved.bundle'),
      isFalse,
    );
    controller.showSending();
    expect(controller.sendState, SelahShepherdInviteSendState.idle);

    activatePrivateDraft();
    controller.showSending();
    expect(controller.sendState, SelahShepherdInviteSendState.sending);
    expect(controller.send(), isFalse);
    expect(controller.send(copied: true), isFalse);
    expect(controller.hasInvite, isFalse);
    expect(controller.accept(), isFalse);
    controller.showFailure();
    expect(controller.sendState, SelahShepherdInviteSendState.failed);
    expect(controller.hasInvite, isFalse);
    expect(controller.send(), isTrue);
    expect(controller.pending, isTrue);
  });

  test('private presets neither invent a name nor survive draft stop', () {
    activatePrivateDraft();
    controller.showSending();
    controller.showFailure();
    expect(controller.sendState, SelahShepherdInviteSendState.idle);
    validName();
    SelahDraftRuntime.stop();
    controller.showSending();
    controller.showFailure();
    expect(controller.sendState, SelahShepherdInviteSendState.idle);
  });

  test('revoked owner denies actions, hides state and cannot revive', () {
    validName();
    expect(controller.send(), isTrue);
    var notifications = 0;
    controller.addListener(() => notifications++);
    ownerCurrent = false;
    controller.chooseRelation(SelahShepherdRelation.mentor);
    controller.setName('Another person');
    expect(controller.continueChoice(), isFalse);
    expect(controller.send(), isFalse);
    controller.showSending();
    controller.showFailure();
    expect(controller.accept(), isFalse);
    controller.reset();
    expect(notifications, 0);
    expect(controller.fullName, isEmpty);
    expect(controller.relation, isNull);
    expect(controller.hasInvite, isFalse);
    expect(controller.accepted, isFalse);
    expect(controller.pending, isFalse);
    ownerCurrent = true;
    controller.setName('Cannot revive');
    expect(controller.send(), isFalse);
    expect(controller.fullName, isEmpty);
    expect(notifications, 0);
  });

  test('throwing or disposed owners fail closed without notifying', () {
    controller.dispose();
    controller = SelahShepherdInviteController(
      canAct: () => throw StateError('owner unavailable'),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.setName('Denied');
    controller.chooseRelation(SelahShepherdRelation.familyMember);
    expect(controller.send(), isFalse);
    expect(controller.accept(), isFalse);
    expect(controller.fullName, isEmpty);
    expect(notifications, 0);
    controller.dispose();
    expect(() => controller.reset(), returnsNormally);
    expect(() => controller.showSending(), returnsNormally);
    expect(() => controller.showFailure(), returnsNormally);
    expect(controller.send(), isFalse);
    expect(controller.continueChoice(), isFalse);
    expect(controller.relation, isNull);
  });

  testWidgets(
    'optional scope is absent for retained fixtures and reactive when present',
    (tester) async {
      SelahShepherdInviteController? found;
      Widget reader() => Builder(
        builder: (context) {
          found = SelahShepherdInviteScope.maybeOf(context);
          return Text(
            found?.fullName ?? 'no scope',
            textDirection: TextDirection.ltr,
          );
        },
      );
      await tester.pumpWidget(reader());
      expect(found, isNull);
      expect(find.text('no scope'), findsOneWidget);
      await tester.pumpWidget(
        SelahShepherdInviteScope(controller: controller, child: reader()),
      );
      expect(found, same(controller));
      controller.setName('David Okafor');
      await tester.pump();
      expect(find.text('David Okafor'), findsOneWidget);

      final replacement = SelahShepherdInviteController(canAct: () => true);
      replacement.setName('Ruth Okafor');
      await tester.pumpWidget(
        SelahShepherdInviteScope(controller: replacement, child: reader()),
      );
      expect(found, same(replacement));
      controller.setName('Old owner change');
      await tester.pump();
      expect(find.text('Ruth Okafor'), findsOneWidget);
      expect(find.text('Old owner change'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      replacement.dispose();
    },
  );
}
