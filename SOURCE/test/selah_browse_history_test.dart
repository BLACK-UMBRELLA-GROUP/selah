// Pure disposable navigation bookkeeping. No visibility, relationship,
// payment, account, backend, image, or persistence authority is exercised.
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/selah_browse_history.dart';

SelahBrowseHistory _trail(Iterable<String> ids) {
  final history = SelahBrowseHistory();
  for (final id in ids) {
    expect(history.appendFrontier(id), isTrue);
  }
  return history;
}

void main() {
  test('fresh history has no invented previous or forward visit', () {
    final history = SelahBrowseHistory();
    expect(history.ids, isEmpty);
    expect(history.cursor, -1);
    expect(history.currentId, isNull);
    expect(history.canBack, isFalse);
    expect(history.hasForwardReplay, isFalse);
    expect(history.back(), isNull);
    expect(history.forwardReplay(), isNull);
    expect(history.appendFrontier('first'), isTrue);
    expect(history.ids, ['first']);
    expect(history.currentId, 'first');
    expect(history.canBack, isFalse);
    expect(history.back(), isNull);
  });

  test('twelve profiles allow exactly ten Back steps then ordered replay', () {
    final profiles = List.generate(12, (index) => 'profile-$index');
    final history = _trail(profiles);
    expect(history.ids, profiles.skip(1).toList());
    expect(history.currentId, 'profile-11');
    for (var index = 10; index >= 1; index--) {
      expect(history.canBack, isTrue);
      expect(history.back(), 'profile-$index');
    }
    expect(history.cursor, 0);
    expect(history.canBack, isFalse);
    expect(history.back(), isNull);
    expect(history.currentId, 'profile-1');
    expect(history.appendFrontier('must-not-branch'), isFalse);
    for (var index = 2; index <= 11; index++) {
      expect(history.hasForwardReplay, isTrue);
      expect(history.forwardReplay(), 'profile-$index');
    }
    expect(history.hasForwardReplay, isFalse);
    expect(history.forwardReplay(), isNull);
    expect(history.appendFrontier('profile-12'), isTrue);
    expect(history.currentId, 'profile-12');
    expect(history.ids, [
      for (var index = 2; index <= 12; index++) 'profile-$index',
    ]);
    expect(history.ids.length, SelahBrowseHistory.maxStoredProfiles);
  });

  test('bounded memory keeps only current plus ten previous visits', () {
    final history = SelahBrowseHistory();
    for (var index = 0; index < 1000; index++) {
      expect(history.appendFrontier('profile-$index'), isTrue);
      expect(
        history.ids.length,
        lessThanOrEqualTo(SelahBrowseHistory.maxStoredProfiles),
      );
      expect(history.currentId, 'profile-$index');
      expect(history.cursor, history.ids.length - 1);
    }
    expect(history.ids, [
      for (var index = 989; index <= 999; index++) 'profile-$index',
    ]);
  });

  test('nonadjacent repeats and cycles retain exact chronological order', () {
    final visits = [
      'a',
      'b',
      'c',
      'a',
      'b',
      'c',
      'a',
      'b',
      'c',
      'a',
      'b',
      'c',
      'a',
    ];
    final history = _trail(visits);
    final retained = visits.skip(visits.length - 11).toList();
    expect(history.ids, retained);
    for (var index = retained.length - 2; index >= 0; index--) {
      expect(history.back(), retained[index]);
    }
    expect(history.back(), isNull);
    for (var index = 1; index < retained.length; index++) {
      expect(history.forwardReplay(), retained[index]);
    }
    expect(history.forwardReplay(), isNull);
    expect(history.appendFrontier('b'), isTrue);
    expect(history.currentId, 'b');
    expect(history.ids, [...retained.skip(1), 'b']);
  });

  test('adjacent duplicate and invalid IDs cannot grow or move history', () {
    final history = _trail(['a', 'b']);
    final before = history.ids;
    expect(history.appendFrontier('b'), isFalse);
    for (final id in ['', ' ', ' a', 'a ', '\n']) {
      expect(history.appendFrontier(id), isFalse);
    }
    expect(history.ids, before);
    expect(history.currentId, 'b');
    expect(history.cursor, 1);
  });

  test(
    'reconcile prunes past visits while preserving the current occurrence',
    () {
      final history = _trail(['a', 'b', 'c', 'd']);
      history.reconcile(['b', 'd']);
      expect(history.ids, ['b', 'd']);
      expect(history.currentId, 'd');
      expect(history.cursor, 1);
      expect(history.back(), 'b');
      expect(history.back(), isNull);
    },
  );

  test('reconcile prunes future visits without jumping away from current', () {
    final history = _trail(['a', 'b', 'c', 'd']);
    expect(history.back(), 'c');
    expect(history.back(), 'b');
    history.reconcile(['a', 'b', 'd']);
    expect(history.currentId, 'b');
    expect(history.ids, ['a', 'b', 'd']);
    expect(history.forwardReplay(), 'd');
    expect(history.forwardReplay(), isNull);
    expect(history.appendFrontier('e'), isTrue);
  });

  test('excluded current chooses closest surviving future before past', () {
    final history = _trail(['a', 'b', 'c', 'd', 'e']);
    expect(history.back(), 'd');
    expect(history.back(), 'c');
    history.reconcile(['a', 'b', 'e'], fallbackId: 'a');
    expect(history.ids, ['a', 'b', 'e']);
    expect(history.currentId, 'e');
    expect(history.cursor, 2);
    expect(history.back(), 'b');
  });

  test('excluded current uses nearest prior when no future remains', () {
    final history = _trail(['a', 'b', 'c', 'd']);
    history.reconcile(['a', 'c']);
    expect(history.ids, ['a', 'c']);
    expect(history.currentId, 'c');
    expect(history.cursor, 1);
  });

  test(
    'all occurrences of excluded ID are removed and never auto-restored',
    () {
      final history = _trail(['a', 'x', 'b', 'x', 'c', 'x']);
      history.reconcile(['a', 'b', 'c']);
      expect(history.ids, ['a', 'b', 'c']);
      expect(history.currentId, 'c');
      history.reconcile(['a', 'b', 'c', 'x']);
      expect(history.ids, ['a', 'b', 'c']);
      expect(history.currentId, 'c');
    },
  );

  test(
    'pruning coalesces newly adjacent repeats with current mapping intact',
    () {
      final history = _trail(['a', 'x', 'a', 'b']);
      expect(history.back(), 'a');
      history.reconcile(['a', 'b']);
      expect(history.ids, ['a', 'b']);
      expect(history.currentId, 'a');
      expect(history.cursor, 0);
      expect(history.canBack, isFalse);
      expect(history.forwardReplay(), 'b');
    },
  );

  test('pruned current mapped to coalesced future has no no-op replay', () {
    final history = _trail(['a', 'x', 'a', 'b']);
    expect(history.back(), 'a');
    expect(history.back(), 'x');
    history.reconcile(['a', 'b']);
    expect(history.ids, ['a', 'b']);
    expect(history.currentId, 'a');
    expect(history.cursor, 0);
    expect(history.forwardReplay(), 'b');
  });

  test(
    'only a valid eligible fallback can seed an otherwise empty history',
    () {
      final history = _trail(['removed']);
      history.reconcile(['new'], fallbackId: 'unknown');
      expect(history.ids, isEmpty);
      expect(history.cursor, -1);
      expect(history.currentId, isNull);
      expect(history.canBack, isFalse);
      expect(history.hasForwardReplay, isFalse);
      for (final id in ['', ' ', ' new', 'new ']) {
        history.reconcile(['new', id], fallbackId: id);
        expect(history.ids, isEmpty);
      }
      history.reconcile(['new'], fallbackId: 'new');
      expect(history.ids, ['new']);
      expect(history.currentId, 'new');
      history.reconcile(['new', 'other'], fallbackId: 'other');
      expect(history.ids, ['new']);
      expect(history.currentId, 'new');
    },
  );

  test(
    'empty eligibility clears trail even when an old fallback is supplied',
    () {
      final history = _trail(['a', 'b']);
      history.reconcile(const [], fallbackId: 'a');
      expect(history.ids, isEmpty);
      expect(history.cursor, -1);
      expect(history.currentId, isNull);
      expect(history.back(), isNull);
      expect(history.forwardReplay(), isNull);
    },
  );

  test('reset clears history and allows a fresh single current profile', () {
    final history = _trail(['a', 'b', 'c']);
    expect(history.back(), 'b');
    history.reset();
    expect(history.ids, isEmpty);
    expect(history.cursor, -1);
    expect(history.currentId, isNull);
    expect(history.canBack, isFalse);
    expect(history.hasForwardReplay, isFalse);
    history.reconcile(['fresh'], fallbackId: 'fresh');
    expect(history.ids, ['fresh']);
    expect(history.canBack, isFalse);
    expect(history.appendFrontier('new'), isTrue);
  });

  test('history snapshots and caller eligibility inputs are defensive', () {
    final history = _trail(['a', 'b']);
    final snapshot = history.ids;
    expect(() => snapshot.add('forbidden'), throwsUnsupportedError);
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(() => snapshot[0] = 'forbidden', throwsUnsupportedError);
    history.appendFrontier('c');
    expect(snapshot, ['a', 'b']);
    final eligible = ['a', 'c'];
    history.reconcile(eligible);
    eligible.clear();
    expect(history.ids, ['a', 'c']);
    expect(history.currentId, 'c');
    history.reset();
    expect(snapshot, ['a', 'b']);
  });
}
