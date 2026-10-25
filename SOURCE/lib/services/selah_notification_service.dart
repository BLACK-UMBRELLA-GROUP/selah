// In-app notifications (#16) — reads the `notifications` table added in
// 20260726140000_notifications.sql. Backs the Bell icon (top-right, per
// APP/Navigation/SEEKER NAVIGATION/Summary.md's ratified "Notifications
// use the Bell Icon... not a navigation tab" rule) and the notifications
// feed screen.
//
// Rows are written server-side only (mutual-Like trigger, new-message
// trigger, accept_mentor_invite RPC) — this service never inserts, only
// reads and marks read_at. Works for both Seeker and Shepherd accounts;
// notifications.user_id is just whichever profile the event was for.

import 'package:flutter/foundation.dart' show debugPrint;

import '../main.dart';
import 'selah_auth.dart';

// THE THREE FETCHES DISTINGUISH FAILURE FROM EMPTY — BUG-05 of the
// 2026-08-14 audit (inherited upstream action 225 path 4, fixed 2026-08-15). Each used to
// return its empty shape on ANY error, so a network failure rendered
// "All caught up — No new notifications" (copy that is most misleading
// exactly when the person needs to retry) and zeroed a badge that was
// still earned. NULL now means "the fetch FAILED — keep what you had /
// show an error"; the empty shape means the server really said empty.
// Signed-out still returns the empty shape: no account genuinely has no
// notifications. The mark-read methods stay best-effort and silent —
// a failed mark leaves a dot showing, which is the harmless direction.

/// Which part of the app a notification points AT — the destination of
/// its navigation dot, not the notification itself.
///
/// ADDED 2026-08-13 (inherited decision 154). Notifications that belong nowhere but
/// the Notifications tab map to null: their dot IS that tab's own count.
enum SelahNavSection { connections, shepherd }

class SelahNotification {
  final String id;
  final String type; // 'new_match' | 'new_message' | 'mentor_request'
  final String title;
  final String? body;
  final String? relatedMatchId;
  final DateTime createdAt;
  final DateTime? readAt;

  const SelahNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedMatchId,
    required this.createdAt,
    required this.readAt,
  });

  bool get isRead => readAt != null;

  /// The section this notification is a pointer to. See
  /// [SelahNotificationService.sectionFor].
  SelahNavSection? get section => SelahNotificationService.sectionFor(type);
}

class SelahNotificationService {
  SelahNotificationService._();

  // ═══════════════════════════════════════════════════════════════════
  // SECTION DOTS — inherited decision 154, 2026-08-13
  // ═══════════════════════════════════════════════════════════════════
  //
  // Founder: "The notification dot is only a navigation indicator showing
  // that something requires attention in that section... The purpose of
  // the dot is navigation awareness, not individual notification
  // tracking."
  //
  // TWO SYSTEMS, ONE PIECE OF STATE. The dot and the Notifications tab
  // answer different questions — "is there anything over there?" versus
  // "what exactly happened?" — but both read `read_at`, and opening a
  // section marks its notifications read (Founder decision, 2026-08-13).
  //
  // The alternative was a second store: a per-section `last_seen_at` so
  // the dot could clear while the row stayed bold. That is a BOOKMARK
  // AGAINST TIME, and the Founder's own 2026-08-06 standard rules on it:
  // "if something seems to require a bookmark against time, you have
  // probably framed the problem incorrectly. Look for the item whose
  // state is unresolved instead." A bookmark is a fact about the
  // observer; `read_at` is a fact about the notification, and it cannot
  // disagree with what it describes because it IS what it describes.
  //
  // THE NOTIFICATIONS TAB IS THE ONE EXCEPTION, and it is principled
  // rather than convenient: everywhere else the dot points at something
  // ELSE, so arriving is proof enough of having seen it. In the tab the
  // notification IS the content, so opening the tab marks nothing — that
  // is what leaves Mark all read something to do.

  /// THE MAP. Every type the LIVE database permits, checked against
  /// notifications_type_check on 2026-08-13 rather than against the
  /// migrations in this repo — the repo knew seven types and the
  /// database holds ten (see inherited upstream action 215). A type this map has not been
  /// taught returns null and shows no dot, which is the safe direction:
  /// a missing dot is a quiet miss, a wrong dot sends someone to the
  /// wrong screen.
  ///
  /// ENDINGS AND DECLINES ROUTE EXACTLY WHERE EVERYTHING ELSE DOES, and
  /// that is load-bearing rather than incidental. inherited upstream action 161's first
  /// safety rule is that a safety ending must be worded IDENTICALLY to
  /// an ordinary one, and inherited upstream action 159 merged decline and expiry into one
  /// type so the requester cannot tell them apart. A destination is a
  /// tell in exactly the way wording is: if `journey_ended` lit a
  /// different dot, the dot would announce what the words were careful
  /// not to. One section for all of them, structurally.
  static SelahNavSection? sectionFor(String type) => switch (type) {
    'new_match' => SelahNavSection.connections,
    'new_message' => SelahNavSection.connections,
    'journey_ended' => SelahNavSection.connections,
    'journey_request' => SelahNavSection.connections,
    'journey_request_accepted' => SelahNavSection.connections,
    'journey_request_declined' => SelahNavSection.connections,
    'milestone_proposed' => SelahNavSection.connections,
    'milestone_confirmed' => SelahNavSection.connections,
    'pause_nudge' => SelahNavSection.connections,
    // SHARED PAUSE HOLDS — inherited decision 170 (2026-08-15). Three types the
    // pause lifecycle finally speaks with: told when paused, told
    // when the other rests too, told when the Journey is active
    // again (the silent re-activation is gone). All point at
    // Connections like every other Journey event. The live
    // notifications_type_check now holds THIRTEEN types and the
    // migration adding them is IN THIS REPO
    // (20260815183000_shared_pause_holds.sql) — narrowing
    // inherited upstream action 215's repo-lags-live gap rather than widening it.
    'journey_paused' => SelahNavSection.connections,
    'journey_also_paused' => SelahNavSection.connections,
    'journey_continued' => SelahNavSection.connections,
    'mentor_request' => SelahNavSection.shepherd,
    'mentor_invite_received' => SelahNavSection.shepherd,
    'mentor_invite_declined' => SelahNavSection.shepherd,
    'mentor_invite_expiring' => SelahNavSection.shepherd,
    'mentor_invite_expired' => SelahNavSection.shepherd,
    'mentor_invite_revoked' => SelahNavSection.shepherd,
    _ => null,
  };

  /// The types that belong to [section] — the inverse of [sectionFor],
  /// derived from it rather than written twice.
  static List<String> typesFor(SelahNavSection section) => [
    for (final t in _allTypes)
      if (sectionFor(t) == section) t,
  ];

  /// Every type the map knows. Kept beside [sectionFor] so adding a type
  /// to one without the other is a visible omission rather than a silent
  /// gap in [typesFor].
  static const List<String> _allTypes = [
    'new_match',
    'new_message',
    'mentor_request',
    'mentor_invite_received',
    'mentor_invite_declined',
    'mentor_invite_expiring',
    'mentor_invite_expired',
    'mentor_invite_revoked',
    'journey_ended',
    'journey_request',
    'journey_request_accepted',
    'journey_request_declined',
    'milestone_proposed',
    'milestone_confirmed',
    'pause_nudge',
    'journey_paused',
    'journey_also_paused',
    'journey_continued',
  ];

  /// Which sections currently have something waiting.
  ///
  /// A SET, NOT A COUNT, and deliberately: the dot answers whether there
  /// is anything, not how much. That is the Founder's 2026-08-06 ruling
  /// on the Connections segment dots — "the heading already says how
  /// many; the dot only has to answer whether there is anything" —
  /// applied to the nav bar. Returning counts here would invite a number
  /// onto a control that should not carry one.
  /// Null = the fetch failed (BUG-05): callers hold their last set
  /// rather than clearing dots that may still be earned.
  static Future<Set<SelahNavSection>?> fetchSectionsWithUnread() async {
    final user = SelahAuth.currentUser;
    if (user == null) return const {};
    try {
      final rows =
          await supabase
                  .from('notifications')
                  .select('type')
                  .filter('read_at', 'is', null)
              as List;
      return {
        for (final r in rows)
          // Null-aware element: a type the map has not been taught
          // drops out rather than needing a guard around it.
          ?sectionFor((r as Map<String, dynamic>)['type'] as String),
      };
    } catch (e) {
      debugPrint('SELAH: fetchSectionsWithUnread failed — $e');
      return null;
    }
  }

  /// Marks everything pointing at [section] read — the dot's clearing
  /// event, fired when the person opens that tab.
  ///
  /// Best-effort and silent, like every other mark-read path here: a
  /// failure leaves the dot showing, which is the harmless direction.
  static Future<void> markSectionRead(SelahNavSection section) async {
    final types = typesFor(section);
    if (types.isEmpty) return;
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('type', types)
          .filter('read_at', 'is', null);
    } catch (_) {}
  }

  /// Marks a chosen set read — the Notifications tab's multi-select.
  ///
  /// One statement rather than a loop over [markRead]: fifty rows is
  /// fifty round trips, and a half-applied selection is a worse state to
  /// land in than none.
  static Future<void> markManyRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
    } catch (_) {}
  }

  /// Most recent notifications for the signed-in user. Empty if not
  /// signed in or genuinely none; NULL if the fetch failed (BUG-05) —
  /// the screen shows an error-with-retry, never "All caught up".
  static Future<List<SelahNotification>?> fetchRecent({int limit = 50}) async {
    final user = SelahAuth.currentUser;
    if (user == null) return [];
    try {
      final rows =
          await supabase
                  .from('notifications')
                  .select(
                    'id, type, title, body, related_match_id, created_at, read_at',
                  )
                  .order('created_at', ascending: false)
                  .limit(limit)
              as List;
      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        return SelahNotification(
          id: map['id'] as String,
          type: map['type'] as String,
          title: map['title'] as String,
          body: map['body'] as String?,
          relatedMatchId: map['related_match_id'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          readAt: map['read_at'] == null
              ? null
              : DateTime.parse(map['read_at'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('SELAH: fetchRecent failed — $e');
      return null;
    }
  }

  /// Unread count for the tab badge. 0 if not signed in or genuinely
  /// none; NULL if the fetch failed (BUG-05) — callers hold the last
  /// known count rather than zeroing a badge that may still be earned.
  static Future<int?> fetchUnreadCount() async {
    final user = SelahAuth.currentUser;
    if (user == null) return 0;
    try {
      final rows =
          await supabase
                  .from('notifications')
                  .select('id')
                  .filter('read_at', 'is', null)
              as List;
      return rows.length;
    } catch (e) {
      debugPrint('SELAH: fetchUnreadCount failed — $e');
      return null;
    }
  }

  static Future<void> markRead(String id) async {
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (_) {
      // Best-effort — not worth surfacing a failure to mark something read.
    }
  }

  static Future<void> markAllRead() async {
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .filter('read_at', 'is', null);
    } catch (_) {}
  }
}
