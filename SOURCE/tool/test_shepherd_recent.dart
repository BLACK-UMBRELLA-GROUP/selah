import 'package:selah/models/selah_prayer.dart';
import 'package:selah/models/selah_shepherd_recent.dart';

void runShepherdRecentChecks(void Function(bool, String) check) {
  final now = DateTime(2026, 11, 6, 12);
  SelahPrayerEvent prayer(
    String id,
    int days, {
    String shepherd = 'main',
    String seeker = 'self',
    SelahPrayerEventKind kind = SelahPrayerEventKind.prayed,
    String? journey,
  }) => SelahPrayerEvent(
    kind: kind,
    requestId: id,
    seekerId: seeker,
    shepherdId: shepherd,
    shepherdName: 'David',
    sentAt: now.subtract(Duration(days: days)),
    journeyName: journey,
  );
  SelahShepherdRecentMessage message(
    String id,
    int days, {
    String sender = 'main',
  }) => SelahShepherdRecentMessage(
    id: id,
    senderId: sender,
    body: 'Existing message $id',
    sentAt: now.subtract(Duration(days: days)),
  );
  final recent = selahShepherdRecent(
    seekerId: 'self',
    shepherdId: 'main',
    prayers: [
      prayer('old', 5),
      prayer('journey', 1, journey: 'Esther'),
      prayer('asked', 0, kind: SelahPrayerEventKind.asked),
      prayer('other', 0, shepherd: 'additional'),
      prayer('different-seeker', 0, seeker: 'other'),
    ],
    messages: [
      message('older', 6),
      message('circle', 2),
      message('wrong-sender', 0, sender: 'additional'),
    ],
  );
  check(recent.length == 3, 'Recent is limited to three existing records');
  check(
    recent.map((row) => row.key).join('|') ==
        'prayed:journey:main|circle:circle|prayed:old:main',
    'Recent merges prayer and Circle chronologically, newest first',
  );
  check(
    recent.first.text == 'Prayed for your Journey with Esther',
    'Journey prayer uses its actual name',
  );
  check(recent.last.text == 'Prayed for you', 'General prayer words are exact');
  check(
    recent[1].text == '“Existing message circle”',
    'Circle quotes the existing body',
  );
  check(
    recent.first.lineAt(now).endsWith(' · Yesterday'),
    'Yesterday is calculated from actual date',
  );
  check(
    selahShepherdRecentDate(now.subtract(const Duration(days: 2)), now) ==
        'Wednesday',
    'Recent weekday derives from actual date',
  );
  check(
    selahShepherdRecentDate(DateTime(2026, 10, 12), now) == '12 Oct',
    'Older message uses actual date',
  );
  check(
    selahShepherdRecentDate(DateTime(2025, 10, 12), now) == '12 Oct 2025',
    'Older year is not obscured',
  );
  final duplicate = selahShepherdRecent(
    seekerId: 'self',
    shepherdId: 'main',
    prayers: [prayer('same', 1), prayer('same', 1)],
    messages: [message('same', 1), message('same', 1)],
  );
  check(
    duplicate.length == 2,
    'Source keys deduplicate without merging different source kinds',
  );
  var immutable = false;
  try {
    recent.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Recent returns an immutable projection');
  check(
    selahShepherdRecent(
      seekerId: 'self',
      shepherdId: 'main',
      prayers: [],
      messages: [],
    ).isEmpty,
    'No activity stays empty; no master records are invented',
  );
}

void main() {
  var count = 0;
  runShepherdRecentChecks((value, label) {
    count++;
    if (!value) throw StateError(label);
  });
  // ignore: avoid_print
  print('PASS $count Shepherd Recent checks');
}
