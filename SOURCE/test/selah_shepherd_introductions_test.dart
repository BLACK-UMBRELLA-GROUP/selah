import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/models/selah_shepherd_suggestion.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const james = 'draft-self';
  const joel = 'prayer-seed-joel';
  final disposed = <SelahRequestAccountSession>{};

  SelahRequestAccountSession session([bool Function()? canAct]) {
    final owner = SelahRequestAccountSession(
      canAct: canAct ?? () => true,
      palette: SelahDevPalette.stillWater,
      hapticLevel: SelahHapticLevel.off,
      goldEnabled: false,
    );
    addTearDown(() {
      if (!disposed.contains(owner)) owner.dispose();
    });
    return owner;
  }

  void dispose(SelahRequestAccountSession owner) {
    disposed.add(owner);
    owner.dispose();
  }

  ShepherdSuggestion suggestion(String id, {List<String> photos = const []}) =>
      ShepherdSuggestion(
        profile: SeekerProfile(
          id: id,
          firstName: 'Grace',
          age: 29,
          city: 'Leeds',
          photos: photos,
          gender: 'female',
        ),
        suggestedBy: 'Pastor David',
      );

  bool record(
    SelahRequestAccountSession owner,
    String id, {
    String seeker = james,
    bool Function()? guard,
    Iterable<String> Function()? eligible,
  }) => owner.recordIntroduction(
    seekerId: seeker,
    suggestion: suggestion(id),
    canSuggest: guard ?? () => true,
    eligibleProfileIds: eligible ?? () => [id],
  );

  test('owner starts empty without seeded suggestions', () {
    final owner = session();
    expect(owner.introductionsFor(james), isEmpty);
    expect(owner.introductionsFor(joel), isEmpty);
    expect(owner.hasIntroduction(james, draftProfiles.first.id), isFalse);
  });

  test('record is idempotent and detached from caller photo data', () {
    final owner = session();
    var notifications = 0;
    owner.addListener(() => notifications++);
    final photos = ['data:image/jpeg;base64,synthetic'];
    expect(
      owner.recordIntroduction(
        seekerId: james,
        suggestion: suggestion('candidate', photos: photos),
        canSuggest: () => true,
        eligibleProfileIds: () => ['candidate'],
      ),
      isTrue,
    );
    photos.add('later caller mutation');
    final saved = owner.introductionsFor(james);
    expect(saved.single.profile.photos, hasLength(1));
    expect(saved.single.unseen, isTrue);
    expect(() => saved.clear(), throwsUnsupportedError);
    expect(() => saved.single.profile.photos.clear(), throwsUnsupportedError);
    expect(record(owner, 'candidate'), isFalse);
    expect(owner.introductionsFor(james), hasLength(1));
    expect(notifications, 1);
  });

  test('same candidate may be suggested independently to each Seeker', () {
    final owner = session();
    expect(record(owner, 'candidate'), isTrue);
    expect(record(owner, 'candidate', seeker: joel), isTrue);
    expect(owner.introductionsFor(james), hasLength(1));
    expect(owner.introductionsFor(joel), hasLength(1));
    expect(
      owner.dismissIntroduction(james, 'candidate', canDismiss: () => true),
      isTrue,
    );
    expect(owner.introductionsFor(james), isEmpty);
    expect(owner.introductionsFor(joel).single.unseen, isTrue);
    expect(owner.hasIntroduction(james, 'candidate'), isTrue);
    expect(owner.hasIntroduction(joel, 'candidate'), isTrue);
    expect(record(owner, 'candidate'), isFalse);
    expect(
      owner.dismissIntroduction(james, 'candidate', canDismiss: () => true),
      isFalse,
    );
  });

  test('markSeen affects badges only and preserves unresolved records', () {
    final owner = session();
    record(owner, 'first');
    record(owner, 'second');
    record(owner, 'other', seeker: joel);
    final before = owner.introductionsFor(james);
    expect(before.map((item) => item.profile.id), ['second', 'first']);
    expect(owner.markIntroductionsSeen(james, canRead: () => true), isTrue);
    expect(owner.introductionsFor(james), hasLength(2));
    expect(owner.introductionsFor(james).every((item) => !item.unseen), isTrue);
    expect(before.every((item) => item.unseen), isTrue);
    expect(owner.introductionsFor(joel).single.unseen, isTrue);
    expect(owner.hasIntroduction(james, 'first'), isTrue);
    expect(owner.markIntroductionsSeen(james, canRead: () => true), isFalse);
  });

  test('a second account owner never reads or dismisses the first owner', () {
    final first = session();
    final second = session();
    record(first, 'candidate');
    expect(second.introductionsFor(james), isEmpty);
    expect(second.hasIntroduction(james, 'candidate'), isFalse);
    expect(
      second.dismissIntroduction(james, 'candidate', canDismiss: () => true),
      isFalse,
    );
    expect(first.introductionsFor(james), hasLength(1));
  });

  test(
    'actual selected discovery excludes hidden blocked busy and requests',
    () {
      final owner = session();
      final model = ViewRequestDraftModel.freshSeeker(capacity: 3);
      final ids = draftProfiles.map((profile) => profile.id).toList();
      model.hide(ids[0]);
      model.block(ids[1]);
      model.setPeerOccupied(ids[2], true);
      model.request(ids[3]);
      Iterable<String> eligible() => model.discoverableProfiles
          .where((profile) => model.stateFor(profile.id) == null)
          .map((profile) => profile.id);
      for (final id in ids.take(4)) {
        expect(record(owner, id, eligible: eligible), isFalse);
      }
      expect(record(owner, ids[4], eligible: eligible), isTrue);
      expect(model.stateFor(ids[4]), isNull);
      expect(model.states, {ids[3]: DraftJourneyState.sent});
      expect(owner.introductionsFor(joel), isEmpty);
    },
  );

  test('lost eligibility at commit cannot store or notify', () {
    final owner = session();
    var reads = 0;
    var notifications = 0;
    owner.addListener(() => notifications++);
    expect(
      record(
        owner,
        'candidate',
        eligible: () => ++reads == 1 ? ['candidate'] : [],
      ),
      isFalse,
    );
    expect(reads, 2);
    expect(owner.hasIntroduction(james, 'candidate'), isFalse);
    expect(notifications, 0);
  });

  test('denied or throwing role link and discovery guards fail closed', () {
    final owner = session();
    var notifications = 0;
    owner.addListener(() => notifications++);
    expect(record(owner, 'candidate', guard: () => false), isFalse);
    expect(
      record(owner, 'candidate', guard: () => throw StateError('revoked')),
      isFalse,
    );
    expect(
      record(
        owner,
        'candidate',
        eligible: () => throw StateError('unavailable'),
      ),
      isFalse,
    );
    var calls = 0;
    expect(record(owner, 'candidate', guard: () => ++calls == 1), isFalse);
    expect(owner.introductionsFor(james), isEmpty);
    expect(notifications, 0);
  });

  test('owner denial is terminal across an A to B to A lifetime', () {
    var admitted = true;
    final owner = session(() => admitted);
    record(owner, 'candidate');
    admitted = false;
    expect(owner.introductionsFor(james), isEmpty);
    admitted = true;
    expect(owner.hasIntroduction(james, 'candidate'), isFalse);
    expect(record(owner, 'later'), isFalse);
    expect(owner.markIntroductionsSeen(james, canRead: () => true), isFalse);
    expect(
      owner.dismissIntroduction(james, 'candidate', canDismiss: () => true),
      isFalse,
    );
  });

  test('owner revocation during discovery prevents the pending write', () {
    var admitted = true;
    final owner = session(() => admitted);
    var notifications = 0;
    owner.addListener(() => notifications++);
    expect(
      record(
        owner,
        'candidate',
        eligible: () {
          admitted = false;
          return ['candidate'];
        },
      ),
      isFalse,
    );
    admitted = true;
    expect(owner.current, isFalse);
    expect(notifications, 0);
  });

  test('seen and dismissal recheck the captured Seeker guard at commit', () {
    final owner = session();
    record(owner, 'candidate');
    var notifications = 0;
    owner.addListener(() => notifications++);
    var reads = 0;
    expect(
      owner.markIntroductionsSeen(james, canRead: () => ++reads == 1),
      isFalse,
    );
    reads = 0;
    expect(
      owner.dismissIntroduction(
        james,
        'candidate',
        canDismiss: () => ++reads == 1,
      ),
      isFalse,
    );
    expect(owner.introductionsFor(james).single.unseen, isTrue);
    expect(notifications, 0);
  });

  test(
    'disposing owner invalidates retained callbacks without notification',
    () {
      final owner = session();
      record(owner, 'candidate');
      dispose(owner);
      expect(owner.introductionsFor(james), isEmpty);
      expect(owner.hasIntroduction(james, 'candidate'), isFalse);
      expect(record(owner, 'later'), isFalse);
      expect(owner.markIntroductionsSeen(james, canRead: () => true), isFalse);
      expect(
        owner.dismissIntroduction(james, 'candidate', canDismiss: () => true),
        isFalse,
      );
    },
  );

  test('disposal inside a captured guard cannot publish a new record', () {
    final owner = session();
    var calls = 0;
    expect(
      record(
        owner,
        'candidate',
        guard: () {
          if (++calls == 2) dispose(owner);
          return true;
        },
      ),
      isFalse,
    );
    expect(owner.introductionsFor(james), isEmpty);
  });

  test('empty identity and self-suggestion are refused', () {
    final owner = session();
    expect(record(owner, ''), isFalse);
    expect(record(owner, 'candidate', seeker: ''), isFalse);
    expect(record(owner, james), isFalse);
  });
}
