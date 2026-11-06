import 'selah_prayer.dart';

/// Read-only presentation projection of an existing Circle message.
class SelahShepherdRecentMessage {
  const SelahShepherdRecentMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
  });
  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;
}

class SelahShepherdRecentItem {
  const SelahShepherdRecentItem({
    required this.key,
    required this.text,
    required this.sentAt,
  });
  final String key;
  final String text;
  final DateTime sentAt;

  String lineAt(DateTime now) =>
      '$text · ${selahShepherdRecentDate(sentAt, now)}';
}

/// Reads existing events/messages only; it owns no chat or prayer state.
List<SelahShepherdRecentItem> selahShepherdRecent({
  required String seekerId,
  required String shepherdId,
  required Iterable<SelahPrayerEvent> prayers,
  required Iterable<SelahShepherdRecentMessage> messages,
}) {
  final byKey = <String, SelahShepherdRecentItem>{};
  for (final event in prayers) {
    if (event.kind != SelahPrayerEventKind.prayed ||
        event.seekerId != seekerId ||
        event.shepherdId != shepherdId) {
      continue;
    }
    final journey = event.journeyName;
    final key = '${event.kind.name}:${event.requestId}:${event.shepherdId}';
    byKey[key] = SelahShepherdRecentItem(
      key: key,
      text: journey == null || journey.trim().isEmpty
          ? 'Prayed for you'
          : 'Prayed for your Journey with $journey',
      sentAt: event.sentAt,
    );
  }
  for (final message in messages) {
    if (message.senderId != shepherdId || message.body.trim().isEmpty) continue;
    final key = 'circle:${message.id}';
    byKey[key] = SelahShepherdRecentItem(
      key: key,
      text: '“${message.body}”',
      sentAt: message.sentAt,
    );
  }
  final indexed = byKey.values.indexed.toList()
    ..sort((a, b) {
      final newest = b.$2.sentAt.compareTo(a.$2.sentAt);
      return newest == 0 ? a.$1.compareTo(b.$1) : newest;
    });
  return List.unmodifiable(indexed.take(3).map((row) => row.$2));
}

String selahShepherdRecentDate(DateTime time, DateTime now) {
  final date = time.toLocal();
  final today = now.toLocal();
  final day = DateTime(date.year, date.month, date.day);
  final currentDay = DateTime(today.year, today.month, today.day);
  final calendarDays = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  if (calendarDays == 1) return 'Yesterday';
  if (!day.isAfter(currentDay) && calendarDays < 7) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
  }
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];
  return '${date.day} $month${date.year == today.year ? '' : ' ${date.year}'}';
}
