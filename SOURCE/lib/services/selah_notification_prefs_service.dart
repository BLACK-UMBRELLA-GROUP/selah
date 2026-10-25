// Notification preferences — persisted, 2026-08-06.
//
// WHAT THIS REPLACES: three switches that wrote to AppState and nowhere
// else. In memory, gone on restart. The old screen's own header comment
// admitted it.
//
// WHY IT STOPPED BEING SURVIVABLE: the Founder's Settings brief adds
// Marketing Emails and Product Updates. Those are not product toggles —
// under UK GDPR and PECR they are records of CONSENT. A consent switch that
// forgets on restart means the consent was never recorded, a withdrawal is
// never honoured, and neither can be evidenced if anyone asks.
//
// APPEND-ONLY. `selah_set_notification_preference` INSERTs every time; there
// is no update path and `authenticated` holds no UPDATE or DELETE grant on
// the table. Opt in, withdraw, opt in again and all three survive — a
// single mutable row could only ever prove the last one. Same shape as
// unlock_credits and article9_consents_log, for the same reason.
//
// DEFAULTS LIVE IN THE DATABASE, not here. Product notifications default on;
// marketing and product updates default OFF, because under UK GDPR consent
// must be a positive opt-in and a pre-ticked box is not consent. Putting
// that in the client would let a future screen quietly disagree with it.

import 'package:flutter/foundation.dart';
import '../main.dart';
import 'selah_auth.dart';
import 'selah_internal_preview_client.dart';

/// The five categories. Codes match the CHECK constraint on
/// `notification_preferences.category` — store the code, never the label.
enum SelahNotifyCategory {
  matchesJourneys(
    'matches_journeys',
    'Matches & Journeys',
    'Mutual interest, and movement on an Active Journey',
  ),
  shepherdActivity(
    'shepherd_activity',
    'Shepherd Activity',
    'When a Shepherd acts on something of yours',
  ),
  introductions(
    'introductions',
    'Introductions',
    'When a Shepherd puts someone forward',
  ),
  marketingEmails(
    'marketing_emails',
    'Marketing Emails',
    'Offers and news from SELAH. Off unless you turn it on',
  ),
  productUpdates(
    'product_updates',
    'Product Updates',
    "What's new in the app. Off unless you turn it on",
  );

  const SelahNotifyCategory(this.code, this.label, this.hint);
  final String code;
  final String label;
  final String hint;

  /// True where switching this is a consent decision rather than a
  /// preference. Surfaced in the UI so the two are not presented as the
  /// same kind of choice, and so the copy can be accurate about what
  /// turning it on means.
  bool get isConsent =>
      this == SelahNotifyCategory.marketingEmails ||
      this == SelahNotifyCategory.productUpdates;

  static SelahNotifyCategory? fromCode(String code) {
    for (final c in SelahNotifyCategory.values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

class SelahNotificationPrefsService {
  SelahNotificationPrefsService._();

  /// Founder/external previews are deliberately blocked from every data API
  /// request by [SelahInternalPreviewClient]. Give that isolated experience a
  /// complete, mutable local preference model rather than sending a request
  /// we know will be denied and rendering an empty error page.
  ///
  /// This map is never consulted for a real member. Marketing still begins
  /// off, and real consent remains append-only in Supabase.
  static Map<SelahNotifyCategory, bool>? _previewValues;
  static int? _previewSession;

  static Map<SelahNotifyCategory, bool> _previewDefaults() => {
    SelahNotifyCategory.matchesJourneys: true,
    SelahNotifyCategory.shepherdActivity: true,
    SelahNotifyCategory.introductions: true,
    SelahNotifyCategory.marketingEmails: false,
    SelahNotifyCategory.productUpdates: false,
  };

  static Map<SelahNotifyCategory, bool> _localPreviewValues() {
    final session = SelahInternalPreviewClient.previewSession;
    if (_previewSession != session) {
      _previewSession = session;
      _previewValues = _previewDefaults();
    }
    return _previewValues ??= _previewDefaults();
  }

  /// Current state for all five categories, defaults applied server-side.
  ///
  /// On failure returns null rather than an empty map: rendering every
  /// switch as off would misstate what the user has agreed to, which is
  /// exactly the failure this table exists to prevent.
  static Future<Map<SelahNotifyCategory, bool>?> fetch() async {
    if (SelahInternalPreviewClient.isActive) {
      return Map.of(_localPreviewValues());
    }
    if (SelahAuth.currentUser == null) return null;
    try {
      final rows = await supabase.rpc('selah_notification_preferences') as List;
      final out = <SelahNotifyCategory, bool>{};
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        final c = SelahNotifyCategory.fromCode(m['category'] as String);
        if (c != null) out[c] = (m['enabled'] as bool?) ?? false;
      }
      return out;
    } catch (e) {
      debugPrint('SELAH: selah_notification_preferences failed — $e');
      return null;
    }
  }

  /// Appends a change. Returns true on success.
  ///
  /// The caller must NOT optimistically assume success for a consent
  /// category — if this returns false the switch has to go back, because
  /// showing "on" for a consent we failed to record is the one outcome
  /// worse than the switch not working.
  static Future<bool> set(SelahNotifyCategory category, bool enabled) async {
    if (SelahInternalPreviewClient.isActive) {
      _localPreviewValues()[category] = enabled;
      return true;
    }
    if (SelahAuth.currentUser == null) return false;
    try {
      final ok = await supabase.rpc(
        'selah_set_notification_preference',
        params: {'p_category': category.code, 'p_enabled': enabled},
      );
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: set ${category.code} = $enabled failed — $e');
      return false;
    }
  }
}
