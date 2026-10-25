// ONE place that asks the server for ages.
//
// ── WHY THIS FILE EXISTS. Founder, 2026-08-08: "the ages are showing as 0."
//
// Every age in the app was 0. The cause was a rule I added the same
// morning and a fact I asserted without checking.
//
//   ages_for() gained a 50-id cap (I10, anti-enumeration). The migration
//   comment read: "50 = Browse's page size, so every legitimate caller
//   fits."
//
//   Browse has no page size. fetchCandidates() has no .limit() at all — it
//   selects every active, complete, opposite-gender Seeker. Measured
//   2026-08-08: 72 candidates per gender. 72 > 50, so ages_for() raised
//   ages_for_batch_too_large on EVERY Browse load.
//
// The failure was then invisible, because all four callers had their own
// private copy of the same method ending in `catch (_) { return {}; }`,
// and every caller falls back to age 0 on an empty map. A hard server
// error surfaced as a plausible-looking number.
//
// ── SO THE CAP IS NOT THE BUG AND IS NOT BEING RAISED. Capping the batch
// is correct: a caller asking for 500 ages is enumerating the database.
// What was wrong is that the client sent one oversized request instead of
// paging, and then hid the refusal. Both are fixed here.
//
// ── AND WHY IT IS SHARED. There were FOUR copies of `_fetchAges` —
// discovery, match, journey, shepherd suggestions — identical but for the
// debug string. That is invariant I3 ("one path, or the paths will
// drift"): one bug, four places to fix it, and no guarantee a future fix
// reaches all four. They now all delegate here.

import 'package:flutter/foundation.dart' show debugPrint;

// `supabase` lives in main.dart, same as every other service here.
import '../main.dart';

class SelahAgesService {
  SelahAgesService._();

  /// Must stay <= the cap inside ages_for(). If the server cap ever
  /// changes, this is the only number that follows it.
  static const int _maxPerCall = 50;

  /// Server-computed ages for [ids], keyed by profile id.
  ///
  /// Raw `date_of_birth` is not selectable by the client
  /// (20260726120000_hide_raw_dob_expose_age.sql), so the derived age from
  /// ages_for() is the only route. Visibility is enforced inside that
  /// function: an id the caller may not see simply returns no row, so a
  /// missing key means "not visible", not "failed".
  ///
  /// Best-effort by design — Browse must not break over an age lookup —
  /// but NOT silent. A failure is logged with the batch size, because the
  /// whole reason this bug survived a day is that it was not.
  static Future<Map<String, int>> forIds(
    List<String> ids, {
    String context = 'ages',
  }) async {
    if (ids.isEmpty) return const {};

    final out = <String, int>{};
    for (var start = 0; start < ids.length; start += _maxPerCall) {
      final end = (start + _maxPerCall) > ids.length
          ? ids.length
          : start + _maxPerCall;
      final batch = ids.sublist(start, end);
      try {
        final rows =
            await supabase.rpc('ages_for', params: {'p_ids': batch}) as List;
        for (final r in rows) {
          final row = r as Map<String, dynamic>;
          final age = row['age'];
          // A null age would mean a null date_of_birth, which the schema
          // forbids — but reading it defensively costs nothing and beats
          // a cast error taking out the whole batch.
          if (age is num) out[row['id'] as String] = age.toInt();
        }
      } catch (e) {
        // Carry on with the other batches. A partial map is strictly
        // better than none: the candidates whose ages did arrive show a
        // real number instead of everyone showing 0.
        debugPrint(
          'SELAH: ages_for failed for $context — ${batch.length} ids '
          '(batch ${start ~/ _maxPerCall + 1} of '
          '${(ids.length / _maxPerCall).ceil()}) — $e',
        );
      }
    }
    return out;
  }

  /// Single id. Uses ages_for_one(), which exists precisely so that asking
  /// about one person is not indistinguishable from a batch read (I10).
  static Future<int?> forOne(String id) async {
    try {
      final v = await supabase.rpc('ages_for_one', params: {'p_id': id});
      return v is num ? v.toInt() : null;
    } catch (e) {
      debugPrint('SELAH: ages_for_one failed for $id — $e');
      return null;
    }
  }
}
