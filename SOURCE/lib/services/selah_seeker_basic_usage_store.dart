import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/selah_seeker_basic_policy.dart';
import '../state/app_state.dart';
import 'selah_auth.dart';

class SelahSeekerBasicUsage {
  final DateTime swipeWindowStartedAt;
  final int swipes;
  final String considerDay;
  final int considersToday;

  const SelahSeekerBasicUsage({
    required this.swipeWindowStartedAt,
    required this.swipes,
    required this.considerDay,
    required this.considersToday,
  });

  factory SelahSeekerBasicUsage.fresh(DateTime now) => SelahSeekerBasicUsage(
    swipeWindowStartedAt: now,
    swipes: 0,
    considerDay: _dayKey(now),
    considersToday: 0,
  );

  SelahSeekerBasicUsage normalized(DateTime now) {
    final invalidWindow =
        now.isBefore(swipeWindowStartedAt) ||
        now.difference(swipeWindowStartedAt) >=
            SelahSeekerBasicPolicy.swipeWindow;
    final today = _dayKey(now);
    return SelahSeekerBasicUsage(
      swipeWindowStartedAt: invalidWindow ? now : swipeWindowStartedAt,
      swipes: invalidWindow ? 0 : swipes,
      considerDay: today,
      considersToday: considerDay == today ? considersToday : 0,
    );
  }

  bool get swipeLimitReached => SelahSeekerBasicPolicy.swipeLimitReached(swipes);
  bool get advertDue => SelahSeekerBasicPolicy.advertDue(swipes);
  bool get dailyConsiderLimitReached =>
      considersToday >= SelahSeekerBasicPolicy.dailyConsiderLimit;

  Duration remainingInSwipeWindow(DateTime now) {
    final end = swipeWindowStartedAt.add(SelahSeekerBasicPolicy.swipeWindow);
    return end.isAfter(now) ? end.difference(now) : Duration.zero;
  }

  Map<String, Object> toJson() => {
    'swipe_window_started_at': swipeWindowStartedAt.toIso8601String(),
    'swipes': swipes,
    'consider_day': considerDay,
    'considers_today': considersToday,
  };

  static SelahSeekerBasicUsage? fromJson(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final start = DateTime.tryParse('${map['swipe_window_started_at']}');
      if (start == null) return null;
      return SelahSeekerBasicUsage(
        swipeWindowStartedAt: start,
        swipes: (map['swipes'] as num?)?.toInt() ?? 0,
        considerDay: '${map['consider_day'] ?? ''}',
        considersToday: (map['considers_today'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Device-side enforcement for the testable build.
///
/// This state is account-scoped and survives an app restart. It is not a
/// security boundary: production quota enforcement must also run server-side
/// so reinstalling the app or changing devices cannot bypass it.
class SelahSeekerBasicUsageStore {
  SelahSeekerBasicUsageStore._();
  static Future<void> _usageWrites = Future<void>.value();

  static String get _accountKey {
    final userId = SelahAuth.currentUser?.id;
    if (userId != null) return userId;
    final preview = AppState.instance.name?.trim().toLowerCase();
    return 'developer-${preview?.isNotEmpty == true ? preview : 'seeker'}';
  }

  static String get _key => 'selah.seeker_basic_usage.v1.$_accountKey';

  static Future<SelahSeekerBasicUsage> load({DateTime? at}) async {
    final accountKey = _key;
    final now = at ?? DateTime.now();
    try {
      await _usageWrites;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final usage =
          SelahSeekerBasicUsage.fromJson(prefs.getString(accountKey)) ??
          SelahSeekerBasicUsage.fresh(now);
      // Display reads never write normalization back over a newer action.
      // The next serialized write persists the normalized state instead.
      return usage.normalized(now);
    } catch (_) {
      return SelahSeekerBasicUsage.fresh(now);
    }
  }

  static Future<SelahSeekerBasicUsage> recordSwipe({DateTime? at}) =>
      _withCurrent(at, (prefs, accountKey, current) async {
        final next = SelahSeekerBasicUsage(
          swipeWindowStartedAt: current.swipeWindowStartedAt,
          swipes: current.swipes + 1,
          considerDay: current.considerDay,
          considersToday: current.considersToday,
        );
        await _save(prefs, accountKey, next);
        return next;
      });

  static Future<SelahSeekerBasicUsage> recordConsider({DateTime? at}) =>
      _withCurrent(at, (prefs, accountKey, current) async {
        final next = SelahSeekerBasicUsage(
          swipeWindowStartedAt: current.swipeWindowStartedAt,
          swipes: current.swipes,
          considerDay: current.considerDay,
          considersToday: current.considersToday + 1,
        );
        await _save(prefs, accountKey, next);
        return next;
      });

  /// Both Browse and Connections claim the same account-scoped allowance at
  /// action time. Serialize claims and re-read persisted data so a mounted
  /// page's stale display cache cannot permit a sixth Consider. null means
  /// the allowance is full; a failed write throws before profile mutation.
  /// This is one-device coordination, not production/server enforcement.
  static Future<SelahSeekerBasicUsage?> tryRecordConsider({DateTime? at}) =>
      _withCurrent(at, (prefs, accountKey, current) async {
        if (current.dailyConsiderLimitReached) return null;
        final next = SelahSeekerBasicUsage(
          swipeWindowStartedAt: current.swipeWindowStartedAt,
          swipes: current.swipes,
          considerDay: current.considerDay,
          considersToday: current.considersToday + 1,
        );
        await _save(prefs, accountKey, next);
        return next;
      });

  /// Swipe and Consider share one JSON record. Every writer must join this
  /// queue, otherwise a swipe can overwrite a newer Consider count. Capture
  /// the account before waiting so switching accounts cannot retarget a write.
  static Future<T> _withCurrent<T>(
    DateTime? at,
    Future<T> Function(SharedPreferences, String, SelahSeekerBasicUsage) action,
  ) {
    final accountKey = _key;
    final operation = _usageWrites.then<T>((_) async {
      final now = at ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final current =
          (SelahSeekerBasicUsage.fromJson(prefs.getString(accountKey)) ??
                  SelahSeekerBasicUsage.fresh(now))
              .normalized(now);
      return action(prefs, accountKey, current);
    });
    // Failed claims are reported to their caller but must not poison the queue.
    _usageWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String accountKey,
    SelahSeekerBasicUsage usage,
  ) async {
    final saved = await prefs.setString(accountKey, jsonEncode(usage.toJson()));
    if (!saved) throw StateError('The local allowance could not be saved.');
  }
}
