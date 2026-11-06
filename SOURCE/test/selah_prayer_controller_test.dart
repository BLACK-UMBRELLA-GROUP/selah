import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_prayer.dart';
import 'package:selah/models/selah_prayer_controller.dart';

const _david = 'draft-shepherd-hassan';
const _joseph = 'draft-shepherd-yusuf';
const _james = 'draft-self';
const _joel = 'prayer-seed-joel';

class _Fixture {
  _Fixture() {
    store = SelahPrayerStore.seeded(
      shepherdId: _david,
      jamesId: _james,
      joelId: _joel,
      clock: () => DateTime.utc(2026, 11, 6, 12),
    );
    controller = createController();
  }
  late final SelahPrayerStore store;
  late SelahPrayerController controller;
  Object lifetime = Object();
  SelahPrayerRole role = SelahPrayerRole.seeker;
  String? actorOverride;
  String? shepherdId = _david;
  String? shepherdName = 'David';
  String? journeyName = 'Esther';
  Set<String> linkedShepherdIds = {_david};
  Set<String> linkedSeekerIds = {_james, _joel};
  bool allowed = true;
  bool ownerThrows = false;
  bool contextThrows = false;
  bool requestThrows = false;
  bool sendThrows = false;
  bool sendSucceeds = true;
  bool prayThrows = false;
  bool emptyThrows = false;
  bool emptyView = false;
  int contextReads = 0;
  int requestReads = 0;
  int sends = 0;
  int prayers = 0;
  int emptyPresets = 0;
  int changes = 0;
  void Function()? duringSend;
  void Function()? duringPray;
  SelahPrayerContext readContext() {
    contextReads++;
    if (contextThrows) throw StateError('context unavailable');
    return SelahPrayerContext(
      lifetime: lifetime,
      role: role,
      actorId:
          actorOverride ?? (role == SelahPrayerRole.seeker ? _james : _david),
      actorFirstName: role == SelahPrayerRole.seeker ? 'James' : 'David',
      shepherdId: shepherdId,
      shepherdName: shepherdName,
      journeyName: journeyName,
      linkedShepherdIds: linkedShepherdIds,
      linkedSeekerIds: linkedSeekerIds,
    );
  }

  SelahPrayerController createController() => SelahPrayerController(
    canAct: () {
      if (ownerThrows) throw StateError('owner unavailable');
      return allowed;
    },
    readContext: readContext,
    readRequest: (id) {
      requestReads++;
      if (requestThrows) throw StateError('request unavailable');
      return store.requestById(id);
    },
    onSend: (context, text, journey) {
      sends++;
      duringSend?.call();
      if (sendThrows) throw StateError('local failure');
      if (!sendSucceeds) return false;
      final request = store.send(
        seekerId: context.actorId,
        seekerFirstName: context.actorFirstName,
        text: text,
        recipientShepherdIds: {context.shepherdId!},
        shepherdName: context.shepherdName!,
        journeyName: journey,
      );
      if (request == null) return false;
      emptyView = false;
      return true;
    },
    onPray: (context, id) {
      prayers++;
      duringPray?.call();
      if (prayThrows) throw StateError('local failure');
      return store.pray(
        requestId: id,
        shepherdId: context.actorId,
        shepherdName: context.actorFirstName,
      );
    },
    onPresetEmpty: (_) {
      emptyPresets++;
      if (emptyThrows) throw StateError('view unavailable');
      emptyView = true;
      return true;
    },
    onChanged: () => changes++,
  );
  void rebind(SelahPrayerRole next) {
    controller.dispose();
    role = next;
    lifetime = Object();
    controller = createController();
  }

  void dispose() => controller.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() {
    SelahDraftRuntime.stop();
    fixture = _Fixture();
  });
  tearDown(() {
    fixture.dispose();
    SelahDraftRuntime.stop();
  });
  void activatePrivateDraft() => expect(
    SelahDraftRuntime.activate(
      bundleId: SelahNativeIdentityPolicy.productionBundleId,
    ),
    isTrue,
    reason: 'Use actual SELAH_DRAFT_LOCAL_ONLY=true; no admission bypass.',
  );

  test(
    'context is read lazily and the three exact suggestions default to the named Journey',
    () {
      expect(fixture.contextReads, 0);
      expect(fixture.controller.suggestions, [
        'For wisdom in my Journey with Esther',
        'For patience while I wait',
        'For my family to be at peace with my choice',
      ]);
      expect(fixture.controller.selectedSuggestion, 0);
      expect(
        fixture.controller.requestText,
        'For wisdom in my Journey with Esther',
      );
      expect(fixture.controller.ownText, isEmpty);
    },
  );

  test(
    'no active Journey uses the locked natural fallback without inventing a person',
    () {
      fixture.journeyName = null;
      expect(fixture.controller.suggestions.first, 'For wisdom in my Journey');
      expect(fixture.controller.send(), isTrue);
      final sent = fixture.store.requestsFor(_david).first;
      expect(sent.journeyName, isNull);
      fixture.rebind(SelahPrayerRole.shepherd);
      expect(fixture.controller.pray(sent.id), isTrue);
      expect(
        fixture.store.updatesFor(_james).first.text,
        'David prayed for you.',
      );
    },
  );

  test(
    'normal send is immediate, one local write, one exact asked update and no repeated tap',
    () {
      expect(SelahDraftRuntime.active, isFalse);
      expect(fixture.controller.send(), isTrue);
      expect(fixture.controller.sendState, SelahPrayerSendState.sent);
      expect(fixture.controller.send(), isFalse);
      expect(fixture.sends, 1);
      expect(fixture.store.requestsFor(_david).length, 5);
      final sent = fixture.store.requestsFor(_david).first;
      expect(sent.seekerId, _james);
      expect(sent.recipientShepherdIds, {_david});
      expect(sent.journeyName, 'Esther');
      expect(
        fixture.store.updatesFor(_james).single.text,
        'You asked David for prayer.',
      );
    },
  );

  test(
    'own text overrides every chosen suggestion and carries no inferred Journey metadata',
    () {
      fixture.controller.chooseSuggestion(2);
      fixture.controller.setOwnText('  Please pray for wisdom with Esther.  ');
      expect(fixture.controller.send(), isTrue);
      final sent = fixture.store.requestsFor(_david).first;
      expect(sent.text, 'Please pray for wisdom with Esther.');
      expect(sent.journeyName, isNull);
      fixture.rebind(SelahPrayerRole.shepherd);
      expect(fixture.controller.pray(sent.id), isTrue);
      expect(
        fixture.store.updatesFor(_james).first.text,
        'David prayed for you.',
      );
    },
  );

  test(
    'whitespace own text falls back to selection; invalid indexes have no effect',
    () {
      fixture.controller.chooseSuggestion(-1);
      fixture.controller.chooseSuggestion(3);
      expect(fixture.changes, 0);
      fixture.controller.chooseSuggestion(2);
      fixture.controller.setOwnText('   ');
      expect(
        fixture.controller.requestText,
        'For my family to be at peace with my choice',
      );
      expect(fixture.controller.send(), isTrue);
      expect(fixture.store.requestsFor(_david).first.journeyName, isNull);
    },
  );

  test(
    'failed/throwing root setters do not invent a send; retry keeps the actual text',
    () {
      fixture.controller.setOwnText('Please pray for my family.');
      fixture.sendSucceeds = false;
      expect(fixture.controller.send(), isFalse);
      expect(fixture.controller.sendState, SelahPrayerSendState.failed);
      fixture.sendThrows = true;
      expect(fixture.controller.send(), isFalse);
      expect(fixture.store.requestsFor(_david).length, 4);
      expect(fixture.store.updatesFor(_james), isEmpty);
      fixture.sendThrows = false;
      fixture.sendSucceeds = true;
      expect(fixture.controller.send(), isTrue);
      expect(
        fixture.store.requestsFor(_david).first.text,
        'Please pray for my family.',
      );
      expect(fixture.store.requestsFor(_david).length, 5);
    },
  );

  test('Seeker cannot pray and Shepherd cannot send using another role', () {
    final first = fixture.store.requestsFor(_david).first;
    expect(fixture.controller.pray(first.id), isFalse);
    expect(fixture.requestReads, 0);
    expect(fixture.prayers, 0);
    fixture.rebind(SelahPrayerRole.shepherd);
    fixture.controller.setOwnText('Denied');
    fixture.controller.chooseSuggestion(1);
    expect(fixture.controller.send(), isFalse);
    expect(fixture.sends, 0);
  });

  test(
    'sending needs an actually linked current Shepherd and an actual name',
    () {
      for (final missing in ['link', 'id', 'name']) {
        fixture.controller.dispose();
        fixture.linkedShepherdIds = missing == 'link' ? {} : {_david};
        fixture.shepherdId = missing == 'id' ? null : _david;
        fixture.shepherdName = missing == 'name' ? ' ' : 'David';
        fixture.controller = fixture.createController();
        expect(fixture.controller.send(), isFalse);
      }
      expect(fixture.sends, 0);
      expect(fixture.store.requestsFor(_david).length, 4);
    },
  );

  test(
    'praying checks the real recipient and linked Seeker before dispatch',
    () {
      fixture.rebind(SelahPrayerRole.shepherd);
      fixture.actorOverride = _joseph;
      expect(
        fixture.controller.pray(fixture.store.requestsFor(_david).first.id),
        isFalse,
      );
      expect(fixture.prayers, 0);
      fixture.rebind(SelahPrayerRole.shepherd);
      fixture.actorOverride = null;
      fixture.linkedSeekerIds = {_joel};
      final requests = fixture.store.requestsFor(_david);
      expect(fixture.controller.pray(requests.first.id), isFalse);
      expect(fixture.prayers, 0);
      expect(fixture.controller.pray(requests[1].id), isTrue);
      expect(fixture.prayers, 1);
    },
  );

  test(
    'one Shepherd prays once; the named request gets the exact Journey update',
    () {
      fixture.rebind(SelahPrayerRole.shepherd);
      final first = fixture.store.requestsFor(_david).first;
      expect(fixture.controller.pray(first.id), isTrue);
      expect(fixture.controller.pray(first.id), isFalse);
      expect(fixture.prayers, 1);
      expect(fixture.store.requestById(first.id)!.prayedCount, 3);
      expect(
        fixture.store.updatesFor(_james).single.text,
        'David prayed for your Journey with Esther.',
      );
    },
  );

  test(
    'missing/throwing request read and throwing prayer setter fail closed',
    () {
      fixture.rebind(SelahPrayerRole.shepherd);
      expect(fixture.controller.pray('missing'), isFalse);
      fixture.requestThrows = true;
      expect(fixture.controller.pray('prayer-seed-1'), isFalse);
      expect(fixture.prayers, 0);
      fixture.requestThrows = false;
      fixture.prayThrows = true;
      expect(fixture.controller.pray('prayer-seed-1'), isFalse);
      expect(fixture.store.requestById('prayer-seed-1')!.prayedCount, 2);
      expect(fixture.store.updatesFor(_james), isEmpty);
    },
  );

  test(
    'private sending/failure need the exact real draft policy and never send by themselves',
    () {
      fixture.controller.showSending();
      fixture.controller.showFailure();
      expect(fixture.controller.sendState, SelahPrayerSendState.idle);
      expect(
        SelahDraftRuntime.activate(bundleId: 'unapproved.bundle'),
        isFalse,
      );
      fixture.controller.showSending();
      expect(fixture.controller.sendState, SelahPrayerSendState.idle);
      activatePrivateDraft();
      fixture.controller.showSending();
      expect(fixture.controller.sendState, SelahPrayerSendState.sending);
      fixture.controller.setOwnText('Denied while sending');
      fixture.controller.chooseSuggestion(1);
      expect(fixture.controller.send(), isFalse);
      expect(fixture.sends, 0);
      fixture.controller.showFailure();
      expect(fixture.controller.sendState, SelahPrayerSendState.failed);
      expect(fixture.controller.send(), isTrue);
      expect(fixture.sends, 1);
      expect(fixture.controller.presetEmpty(), isFalse);
    },
  );

  test(
    'private empty preset affects only the view and retains all request/count/event data',
    () {
      fixture.rebind(SelahPrayerRole.shepherd);
      final requests = fixture.store.requestsFor(_david);
      expect(fixture.controller.presetEmpty(), isFalse);
      activatePrivateDraft();
      expect(fixture.controller.presetEmpty(), isTrue);
      expect(fixture.emptyView, isTrue);
      expect(
        fixture.store.requestsFor(_david).map((request) => request.id),
        requests.map((request) => request.id),
      );
      expect(
        fixture.store.requestsFor(_david).map((request) => request.prayedCount),
        [2, 5, 1, 3],
      );
      expect(fixture.store.updatesFor(_james), isEmpty);
      fixture.rebind(SelahPrayerRole.seeker);
      expect(fixture.controller.send(), isTrue);
      expect(fixture.emptyView, isFalse);
      expect(fixture.store.requestsFor(_david).length, 5);
    },
  );

  test(
    'pending dispatch cannot be cancelled by private presets or reentered',
    () {
      activatePrivateDraft();
      fixture.duringSend = () {
        fixture.controller.showFailure();
        fixture.controller.showSending();
        expect(fixture.controller.presetEmpty(), isFalse);
        expect(fixture.controller.send(), isFalse);
        fixture.controller.setOwnText('Reentrant text');
        fixture.controller.chooseSuggestion(2);
        expect(fixture.controller.ownText, isEmpty);
        expect(fixture.controller.selectedSuggestion, 0);
        expect(fixture.controller.sendState, SelahPrayerSendState.idle);
      };
      expect(fixture.controller.send(), isTrue);
      expect(fixture.sends, 1);
      expect(fixture.controller.sendState, SelahPrayerSendState.sent);
      expect(fixture.emptyPresets, 0);
      fixture.rebind(SelahPrayerRole.shepherd);
      fixture.duringPray = () {
        expect(fixture.controller.pray('prayer-seed-1'), isFalse);
        expect(fixture.controller.presetEmpty(), isFalse);
      };
      expect(fixture.controller.pray('prayer-seed-1'), isTrue);
      expect(fixture.prayers, 1);
    },
  );

  test(
    'revoked or throwing owners never read context or dispatch an action',
    () {
      for (final throws in [false, true]) {
        fixture.controller.dispose();
        fixture.controller = fixture.createController();
        fixture.contextReads = 0;
        fixture.allowed = false;
        fixture.ownerThrows = throws;
        expect(fixture.controller.suggestions, isEmpty);
        expect(fixture.controller.send(), isFalse);
        expect(fixture.controller.pray('prayer-seed-1'), isFalse);
        expect(fixture.controller.presetEmpty(), isFalse);
        fixture.controller.showSending();
        fixture.controller.showFailure();
        fixture.controller.setOwnText('Denied');
        expect(fixture.contextReads, 0);
        fixture.allowed = true;
        fixture.ownerThrows = false;
        expect(fixture.controller.current, isFalse);
      }
      expect(fixture.sends, 0);
      expect(fixture.prayers, 0);
      expect(fixture.changes, 0);
    },
  );

  test('throwing context is terminal and exposes no old draft', () {
    fixture.contextThrows = true;
    expect(fixture.controller.context, isNull);
    expect(fixture.controller.send(), isFalse);
    fixture.contextThrows = false;
    expect(fixture.controller.current, isFalse);
    expect(fixture.controller.requestText, isEmpty);
    expect(fixture.changes, 0);
  });

  test(
    'role, link, Journey and lifetime replacements permanently revoke the old binding',
    () {
      for (final change in ['role', 'link', 'journey', 'lifetime']) {
        fixture.controller.dispose();
        fixture.role = SelahPrayerRole.seeker;
        fixture.linkedShepherdIds = {_david};
        fixture.journeyName = 'Esther';
        fixture.lifetime = Object();
        fixture.controller = fixture.createController();
        final oldLifetime = fixture.lifetime;
        expect(fixture.controller.context, isNotNull);
        switch (change) {
          case 'role':
            fixture.role = SelahPrayerRole.shepherd;
          case 'link':
            fixture.linkedShepherdIds = {};
          case 'journey':
            fixture.journeyName = null;
          case 'lifetime':
            fixture.lifetime = Object();
        }
        expect(fixture.controller.send(), isFalse, reason: change);
        fixture.role = SelahPrayerRole.seeker;
        fixture.linkedShepherdIds = {_david};
        fixture.journeyName = 'Esther';
        fixture.lifetime = oldLifetime;
        expect(
          fixture.controller.send(),
          isFalse,
          reason: '$change cannot revive A B A',
        );
        expect(fixture.controller.context, isNull);
      }
      expect(fixture.sends, 0);
    },
  );

  test(
    'disposal denies callbacks and hides the old composer state without notifying',
    () {
      fixture.controller.setOwnText('Old local draft');
      var notices = 0;
      fixture.controller.addListener(() => notices++);
      fixture.controller.dispose();
      expect(fixture.controller.send(), isFalse);
      expect(fixture.controller.pray('prayer-seed-1'), isFalse);
      expect(fixture.controller.presetEmpty(), isFalse);
      fixture.controller.showSending();
      fixture.controller.showFailure();
      expect(fixture.controller.ownText, isEmpty);
      expect(fixture.controller.suggestions, isEmpty);
      expect(fixture.controller.context, isNull);
      expect(notices, 0);
    },
  );
}
