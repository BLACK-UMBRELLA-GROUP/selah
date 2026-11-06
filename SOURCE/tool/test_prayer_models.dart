import 'dart:io';

import 'package:selah/models/selah_prayer.dart';

void runPrayerModelChecks(void Function(bool, String) check) {
  final now = DateTime.utc(2026, 11, 6, 12);
  var clockReads = 0;
  final store = SelahPrayerStore.seeded(
    shepherdId: 'draft-shepherd-hassan',
    jamesId: 'draft-self',
    joelId: 'prayer-seed-joel',
    clock: () {
      clockReads++;
      return now;
    },
  );
  const david = 'draft-shepherd-hassan';
  const joseph = 'draft-shepherd-yusuf';
  final seeds = store.requestsFor(david);
  check(
    clockReads == 1,
    'four prayer seeds use one actual supplied clock reading',
  );
  check(seeds.length == 4, 'Prayer V2 seeds exactly four requests');
  final expected = <(String, String, int, String?)>[
    ('James', 'For wisdom in my Journey with Esther', 2, 'Esther'),
    ('Joel', 'For patience while I wait', 5, null),
    ('James', 'For my family to be at peace with my choice', 1, null),
    ('Joel', 'For courage to ask someone to begin', 3, null),
  ];
  for (var i = 0; i < 4; i++) {
    final (name, text, count, journey) = expected[i];
    check(
      seeds[i].seekerFirstName == name &&
          seeds[i].text == text &&
          seeds[i].prayedCount == count &&
          seeds[i].journeyName == journey,
      'prayer seed ${i + 1} preserves locked name, words, count and stable order',
    );
    check(
      seeds[i].sentAt == now,
      'prayer seed ${i + 1} has no invented earlier timestamp',
    );
    check(
      seeds[i].recipientShepherdIds.single == david &&
          !seeds[i].hasPrayed(david),
      'prayer seed ${i + 1} does not invent who made its aggregate count',
    );
  }
  check(
    store.requestsFor('unrelated').isEmpty,
    'only a recipient sees a prayer request',
  );
  check(
    store.updatesFor('draft-self').isEmpty &&
        store.updatesFor('prayer-seed-joel').isEmpty,
    'seed aggregate counts do not invent sent/prayed events',
  );
  check(
    store.pray(
      requestId: seeds.first.id,
      shepherdId: david,
      shepherdName: 'David',
    ),
    'recipient Shepherd records a real local I prayed action',
  );
  check(
    store.requestById(seeds.first.id)!.prayedCount == 3 &&
        store.requestById(seeds.first.id)!.hasPrayed(david),
    'I prayed increments the locked count exactly once',
  );
  check(
    !store.pray(
      requestId: seeds.first.id,
      shepherdId: david,
      shepherdName: 'David',
    ),
    'repeat I prayed cannot increment again for the same Shepherd',
  );
  check(
    store.requestById(seeds.first.id)!.prayedCount == 3,
    'repeated prayer keeps the existing count',
  );
  check(
    store.updatesFor('draft-self').single.text ==
        'David prayed for your Journey with Esther.',
    'named Journey seed produces the exact conditional update',
  );
  check(
    seeds.first.prayedCount == 2 && !seeds.first.hasPrayed(david),
    'read request snapshots remain immutable after store changes',
  );
  check(
    store.pray(
      requestId: seeds[1].id,
      shepherdId: david,
      shepherdName: 'David',
    ),
    'another Seeker can receive a prayer',
  );
  check(
    store.updatesFor('prayer-seed-joel').single.text == 'David prayed for you.',
    'ordinary request produces the exact general update',
  );
  check(
    store.updatesFor('draft-self').length == 1,
    'Seeker updates do not include another Seeker events',
  );
  check(
    !store.pray(
      requestId: seeds[2].id,
      shepherdId: joseph,
      shepherdName: 'Joseph',
    ),
    'a non-recipient Shepherd cannot add a prayer',
  );
  check(
    !store.pray(requestId: 'missing', shepherdId: david, shepherdName: 'David'),
    'unknown request cannot acquire a prayer',
  );
  check(
    !store.pray(requestId: seeds[2].id, shepherdId: david, shepherdName: ' '),
    'blank actor display does not create an update',
  );

  final newRequest = store.send(
    seekerId: 'draft-self',
    seekerFirstName: 'James',
    text: '  For patience while I wait  ',
    recipientShepherdIds: {david, joseph},
    shepherdName: 'David',
  );
  check(
    newRequest != null && newRequest.text == 'For patience while I wait',
    'send creates a local request from the submitted text',
  );
  check(
    store.requestsFor(david).first.id == newRequest!.id,
    'new request precedes seeds when the real clock readings tie',
  );
  check(
    newRequest.prayedCount == 0 && newRequest.prayedByShepherdIds.isEmpty,
    'new prayer request starts without a fabricated prayer',
  );
  check(
    store.updatesFor('draft-self').first.text ==
            'You asked David for prayer.' &&
        store.updatesFor('draft-self').first.kind == SelahPrayerEventKind.asked,
    'send produces the exact own-Seeker asked update',
  );
  check(
    store.pray(
          requestId: newRequest.id,
          shepherdId: david,
          shepherdName: 'David',
        ) &&
        store.pray(
          requestId: newRequest.id,
          shepherdId: joseph,
          shepherdName: 'Joseph',
        ),
    'each named recipient Shepherd can pray once independently',
  );
  check(
    store.requestById(newRequest.id)!.prayedCount == 2 &&
        store.requestById(newRequest.id)!.prayedByShepherdIds.length == 2,
    'two different recipient prayers count twice',
  );
  check(
    !store.pray(
      requestId: newRequest.id,
      shepherdId: joseph,
      shepherdName: 'Joseph',
    ),
    'the second Shepherd also cannot pray twice',
  );
  check(
    store.updatesFor('draft-self').first.text == 'Joseph prayed for you.',
    'events use the supplied actor name without an invented title',
  );

  var rejected = false;
  try {
    seeds.add(newRequest);
  } on UnsupportedError {
    rejected = true;
  }
  check(rejected, 'request lists cannot mutate the store');
  rejected = false;
  try {
    newRequest.recipientShepherdIds.add('unrelated');
  } on UnsupportedError {
    rejected = true;
  }
  check(rejected, 'request recipient sets cannot be expanded by a reader');
  rejected = false;
  try {
    store.requestById(newRequest.id)!.prayedByShepherdIds.clear();
  } on UnsupportedError {
    rejected = true;
  }
  check(rejected, 'prayed-by sets cannot be cleared by a reader');
  rejected = false;
  try {
    store.updatesFor('draft-self').clear();
  } on UnsupportedError {
    rejected = true;
  }
  check(rejected, 'event lists cannot remove history from the owner');

  final beforeRequests = store.requestsFor(david).length;
  final beforeEvents = store.updatesFor('draft-self').length;
  for (final invalid
      in <
        ({
          String id,
          String name,
          String text,
          Set<String> recipients,
          String shepherd,
        })
      >[
        (
          id: '',
          name: 'James',
          text: 'Request',
          recipients: {david},
          shepherd: 'David',
        ),
        (
          id: ' draft-self ',
          name: 'James',
          text: 'Request',
          recipients: {david},
          shepherd: 'David',
        ),
        (
          id: 'draft-self',
          name: ' ',
          text: 'Request',
          recipients: {david},
          shepherd: 'David',
        ),
        (
          id: 'draft-self',
          name: 'James',
          text: ' ',
          recipients: {david},
          shepherd: 'David',
        ),
        (
          id: 'draft-self',
          name: 'James',
          text: 'Request',
          recipients: {},
          shepherd: 'David',
        ),
        (
          id: 'draft-self',
          name: 'James',
          text: 'Request',
          recipients: {''},
          shepherd: 'David',
        ),
        (
          id: 'draft-self',
          name: 'James',
          text: 'Request',
          recipients: {david},
          shepherd: ' ',
        ),
      ]) {
    check(
      store.send(
            seekerId: invalid.id,
            seekerFirstName: invalid.name,
            text: invalid.text,
            recipientShepherdIds: invalid.recipients,
            shepherdName: invalid.shepherd,
          ) ==
          null,
      'invalid request identity/text/recipient input is rejected',
    );
  }
  check(
    store.requestsFor(david).length == beforeRequests &&
        store.updatesFor('draft-self').length == beforeEvents,
    'invalid sends have no data/event side effects',
  );
  var throwClock = false;
  final clockFailure = SelahPrayerStore(
    clock: () {
      if (throwClock) throw StateError('clock unavailable');
      return now;
    },
  );
  final saved = clockFailure.send(
    seekerId: 'draft-self',
    seekerFirstName: 'James',
    text: 'Request',
    recipientShepherdIds: {david},
    shepherdName: 'David',
  )!;
  throwClock = true;
  check(
    clockFailure.send(
          seekerId: 'draft-self',
          seekerFirstName: 'James',
          text: 'Request',
          recipientShepherdIds: {david},
          shepherdName: 'David',
        ) ==
        null,
    'clock failure does not invent an event timestamp',
  );
  check(
    !clockFailure.pray(
          requestId: saved.id,
          shepherdId: david,
          shepherdName: 'David',
        ) &&
        clockFailure.requestById(saved.id)!.prayedCount == 0,
    'clock failure leaves an existing prayer unchanged',
  );
  final countBeforeClear = store.requestsFor(david).length;
  check(
    countBeforeClear == 5,
    'all four seeds survive real send and prayer actions',
  );
  store.clear();
  check(
    store.requestsFor(david).isEmpty && store.updatesFor('draft-self').isEmpty,
    'owner-lifetime reset clears only this local store',
  );
}

void main() {
  var count = 0;
  runPrayerModelChecks((value, label) {
    count++;
    if (!value) throw StateError('FAILED: $label');
  });
  stdout.writeln('PASS: $count pure Prayer checks.');
}
