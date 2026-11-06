// Reporting and blocking — 2026-08-01 (Founder request).
//
// Backed by profile_reports and profile_blocks (migrations
// profile_reports_and_blocks + fix_block_mutual_hide_rls_recursion).
// Before this, SELAH had no way to report or block anyone at all: the
// Browse long-press menu's "Report a Problem" opened the generic Help &
// Support screen, with no subject and nowhere for a report to go.
//
// Blocking and reporting are distinct: hiding a person does not require
// a moderation review and should not create an incident report.
//
//   block()  -> mutual invisibility, instant, no moderation involvement
//   report() -> goes to a moderation queue, permanent, not retractable
//
// A report ALSO blocks by default (reportAndBlock) — nobody who has just
// reported someone for harassment wants to keep seeing them while the
// report is reviewed.
//
// Blocking is enforced in profiles_select's RLS, not here, so it applies
// to every query path — Browse, Matches, Journey, chat participant
// lookups — including ones not written yet. This service only writes the
// rows; it is not where the rule lives.

import 'package:flutter/foundation.dart' show debugPrint;
import '../main.dart';
import 'selah_auth.dart';
import 'selah_account_state.dart';
import 'selah_internal_preview_client.dart';

/// Where the report was raised from. Moderation needs this: a report from
/// an active Journey is a materially different signal to one from a
/// Browse card someone saw for four seconds. Values must match the
/// `source` CHECK constraint on profile_reports.
enum SelahReportSource { browse, chat, journey, connections, profile, shepherd }

/// Values must match the `reason` CHECK constraint on profile_reports.
enum SelahReportReason {
  fakeProfile,
  inappropriateContent,
  harassment,
  underage,
  violence,
  privacy,
  other,
}

class SelahSafetyCase {
  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SelahSafetyCase({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  String get typeLabel => switch (type) {
    'profile' => 'Member report',
    'shepherd_circle' => 'Shepherd Circle report',
    _ => 'Safety report',
  };

  String get statusLabel => switch (status) {
    'pending' => 'Received',
    'reviewing' => 'Under review',
    'actioned' => 'Review complete',
    'dismissed' => 'Review complete',
    _ => 'Status unavailable',
  };

  static SelahSafetyCase? fromRow(Map<String, dynamic> row) {
    final id = row['case_id'];
    final type = row['case_type'];
    final status = row['status'];
    final created = row['created_at'];
    final updated = row['updated_at'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    final updatedAt = updated is String ? DateTime.tryParse(updated) : null;
    if (id is! String ||
        id.isEmpty ||
        type is! String ||
        type.isEmpty ||
        status is! String ||
        status.isEmpty ||
        createdAt == null ||
        (updated != null && updatedAt == null)) {
      return null;
    }
    return SelahSafetyCase(
      id: id,
      type: type,
      status: status,
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt?.toLocal(),
    );
  }
}

extension SelahReportReasonX on SelahReportReason {
  String get dbValue => switch (this) {
    SelahReportReason.fakeProfile => 'fake_profile',
    SelahReportReason.inappropriateContent => 'inappropriate_content',
    SelahReportReason.harassment => 'harassment',
    SelahReportReason.underage => 'underage',
    SelahReportReason.violence => 'violence',
    SelahReportReason.privacy => 'privacy',
    SelahReportReason.other => 'other',
  };

  /// User-facing label. Plain, non-clinical language — someone using this
  /// screen is usually upset, and this is not the moment for product
  /// voice.
  String get label => switch (this) {
    SelahReportReason.fakeProfile => 'Impersonation or fake profile',
    SelahReportReason.inappropriateContent => 'Nudity or sexual content',
    SelahReportReason.harassment => 'Harassment or abusive behaviour',
    SelahReportReason.underage => 'Minor or underage',
    SelahReportReason.violence => 'Violence or disturbing content',
    SelahReportReason.privacy => 'Privacy or personal information',
    SelahReportReason.other => 'Something else',
  };

  /// Reasons where we should say plainly that we act fast. Underage is
  /// the one that must never sit in a queue behind a bio complaint.
  bool get isUrgent =>
      this == SelahReportReason.underage || this == SelahReportReason.violence;
}

class SelahReportService {
  SelahReportService._();

  /// Whether [id] is a real `profiles` row rather than one of the demo
  /// candidates in seeker_profile.dart, whose ids are '1', '2', '3'.
  ///
  /// Needed because SelahDiscoveryService still falls back to mockProfiles
  /// on five separate paths, so a demo card can appear in Browse and be
  /// long-pressed. Without this check, both block() and report() would
  /// fail on a uuid cast and the user would see a generic "that didn't
  /// work" for something that was never going to work.
  ///
  /// Reject synthetic IDs before any persistence call. This guard remains
  /// needed while retained display paths can expose a local fixture.
  static bool isPersistableId(String id) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(id);

  /// Caller-scoped status only. The RPC deliberately withholds the reported
  /// person's identity and remains callable when paid membership has expired.
  static Future<List<SelahSafetyCase>?> safetyCases() async {
    // Founder and external-tester previews are intentionally isolated from
    // member reports. An empty local list is the truthful preview state; a
    // blocked network request is not a load failure the member should see.
    if (SelahInternalPreviewClient.isActive) return const [];
    if (SelahAuth.currentUser == null) return null;
    try {
      final raw = await supabase.rpc('selah_my_safety_cases');
      if (raw is! List) return null;
      final cases = <SelahSafetyCase>[];
      for (final item in raw) {
        if (item is! Map) return null;
        final value = SelahSafetyCase.fromRow(Map<String, dynamic>.from(item));
        if (value == null) return null;
        cases.add(value);
      }
      return cases;
    } catch (e) {
      debugPrint('SELAH: safety case status read failed — ${e.runtimeType}.');
      return null;
    }
  }

  /// Hides [otherUserId] and the caller from each other, everywhere,
  /// immediately. No report is filed and nobody is notified.
  ///
  /// Idempotent — a duplicate block hits the UNIQUE (blocker_id,
  /// blocked_id) constraint, which is treated as success rather than an
  /// error, because from the user's point of view the desired state is
  /// already true.
  // ═══════════════════════════════════════════════════════════════════
  // RELEASE BLOCKER FIX, 2026-08-09 — audit finding 1.2.
  // Blocking did nothing and reported success. Both directions.
  // ═══════════════════════════════════════════════════════════════════
  //
  // This method wrote `profile_blocks` directly. `authenticated` has NO
  // INSERT, UPDATE or DELETE on that table — the RLS policies
  // profile_blocks_insert and profile_blocks_delete both exist and are
  // declared TO public, with no grant behind them. Every block was
  // refused with 42501. Verified live 2026-08-09, rolled back.
  //
  // Someone reporting harassment was told it worked, kept seeing that
  // person, and any Journey between them stayed open.
  //
  // AND THE REPLACEMENT WAS ALREADY WRITTEN. selah_block_user(p_other) is
  // SECURITY DEFINER, granted to `authenticated`, inserts the block AND
  // ends any live Journey between the two via selah_end_match_internal(…,
  // 'safety_concern'). A grep of all 109 Dart files found it called
  // NOWHERE. Same for selah_unblock_user. Both verified callable and
  // working as `authenticated` on 2026-08-09.
  //
  // So this is not "add the missing grant" — granting the table would
  // leave two paths that do different things, and the direct write is the
  // weaker one. It does not end the Journey (invariant I3).

  /// Hides [otherUserId] and the caller from each other, everywhere,
  /// immediately, AND ends any live Journey between them. No report is
  /// filed and nobody is notified.
  ///
  /// Idempotent — blocking someone already blocked is success, because
  /// from the user's point of view the desired state is already true.
  static Future<bool> block(String otherUserId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase.rpc('selah_block_user', params: {'p_other': otherUserId});
      return true;
    } catch (e) {
      debugPrint('SELAH: block($otherUserId) failed — $e');
      return false;
    }
  }

  /// Reverses a block the caller made. Free and self-service, from the
  /// Settings list — DR-K (proposed) forbids ever SELLING the undo, not
  /// letting someone correct their own mistake.
  static Future<bool> unblock(String otherUserId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      // Via the RPC, for the same reason as block() above — the direct
      // DELETE was refused with 42501 and reported success.
      await supabase.rpc('selah_unblock_user', params: {'p_other': otherUserId});
      return true;
    } catch (e) {
      debugPrint('SELAH: unblock($otherUserId) failed — $e');
      return false;
    }
  }

  /// Ids the caller has blocked. Note this is only blocks the caller
  /// MADE — RLS deliberately prevents anyone seeing who blocked them.
  static Future<List<String>> blockedIds() async {
    return await blockedIdsOrNull() ?? const [];
  }

  /// A confirmed empty list is distinct from an unavailable read. Display
  /// surfaces must not claim that nobody is hidden when the server is offline.
  /// An account replacement also invalidates an in-flight result.
  static Future<List<String>?> blockedIdsOrNull() async {
    final user = SelahAuth.currentUser;
    if (user == null || SelahAccountState.isSigningOut) return null;
    final generation = SelahAccountState.generation;
    try {
      final rows =
          await supabase
                  .from('profile_blocks')
                  .select('blocked_id')
                  .eq('blocker_id', user.id)
                  .timeout(const Duration(seconds: 10))
              as List;
      if (SelahAuth.currentUser?.id != user.id ||
          SelahAccountState.generation != generation ||
          SelahAccountState.isSigningOut) {
        return null;
      }
      return rows
          .map((r) => (r as Map<String, dynamic>)['blocked_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('SELAH: blockedIdsOrNull() failed — $e');
      return null;
    }
  }

  /// Files a report AND blocks, which is almost always what the user
  /// wants — nobody reporting harassment wants to keep seeing that person
  /// while the report is reviewed.
  ///
  /// Returns true only if the REPORT was stored. The block is best-effort
  /// on top: if the report saved but the block failed, that is still a
  /// success from a safety standpoint (moderation has the signal) and the
  /// user can block manually.
  ///
  /// Unlike almost every other write in this codebase, a failure here is
  /// surfaced to the user rather than silently swallowed. A report that
  /// quietly vanishes is the worst possible outcome for this feature.
  /// [alsoBlock] false files the report and leaves the relationship alone.
  ///
  /// ADDED 2026-08-06 for Shepherd reports. Report and remove answer two
  /// different questions — *"this person broke the rules"* versus *"I no
  /// longer want them linked"* — and they are not always the same decision.
  /// Someone may report an impersonated Shepherd account and still want the
  /// link kept while it is looked into.
  ///
  /// It is also not merely semantic here: blocking sets the condition
  /// `selah_block_exists` tests, and `shepherds_for_unlocked` checks that
  /// before disclosing Shepherds. Blocking your own Shepherd would quietly
  /// change what other Seekers see on YOUR profile.
  static Future<bool> reportAndBlock({
    required String reportedId,
    required SelahReportReason reason,
    String? detail,
    SelahReportSource source = SelahReportSource.browse,
    bool alsoBlock = true,
  }) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase.from('profile_reports').insert({
        'reporter_id': user.id,
        'reported_id': reportedId,
        'reason': reason.dbValue,
        'detail': (detail != null && detail.trim().isNotEmpty)
            ? detail.trim()
            : null,
        'source': source.name,
      });
    } catch (e) {
      debugPrint(
        'SELAH: report($reportedId, ${reason.dbValue}) FAILED — nothing was stored. $e',
      );
      return false;
    }

    // Best-effort, deliberately after the report and not bundled into it:
    // the report is the part that must not be lost.
    //
    // The return value used to be discarded outright. Keeping the
    // contract (true means the REPORT stored — see the doc above) but not
    // the silence: for a month `block()` returned false on every single
    // call and nothing anywhere said so. Audit finding 1.2.
    if (alsoBlock) {
      final blocked = await block(reportedId);
      if (!blocked) {
        debugPrint(
          'SELAH: report($reportedId) stored, but the accompanying '
          'block FAILED. The reporter can still see this person.',
        );
      }
    }
    return true;
  }
}
