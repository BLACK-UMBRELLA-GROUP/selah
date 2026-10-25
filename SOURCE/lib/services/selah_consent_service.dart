// Article 9 consent — Founder approved 2026-08-04.
//
// Chapter 2 asks for religious belief (sect, revert status) and ethnic
// origin (ethnicity, and by inference country of birth and nationality).
// Under UK GDPR these are SPECIAL-CATEGORY data, needing a lawful basis
// beyond ordinary consent — realistically explicit consent, freely given,
// specific, and separately recorded.
//
// Until 2026-08-04 the app collected all of it with no consent step of any
// kind. The Founder's decision was to build consent and persistence
// together rather than ship storage first: making the data durable without
// a consent gate makes the position worse, not better.
//
// NOT LEGAL ADVICE, and this is not a solicitor's wording. The Founder has
// confirmed a solicitor will review the consent text, Privacy Policy, Terms
// and the Compatibility Unlock flow before public launch. The schema is
// built so that review can change the WORDING without changing the
// STRUCTURE — which is what `policyVersion` is for.
//
// APPEND-ONLY. Withdrawal is a new row with granted=false, never an update.
// "Did this person consent at the moment we processed their data, and to
// which wording" is unanswerable from a table you can overwrite. The
// database has no UPDATE or DELETE policy on `consents`, not even for the
// subject themselves.

import 'package:flutter/foundation.dart';

import '../main.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';

/// The consent text currently in force.
///
/// BUMP THIS whenever [kArticle9ConsentBody] changes in any material way.
/// Consent is to a specific text: if the wording changes, prior consent
/// does not automatically carry over, and without a version there is no way
/// to tell who agreed to what.
///
/// Date-based rather than sequential so the record is legible a year later
/// without cross-referencing a changelog.
const String kArticle9PolicyVersion = '2026-08-04';

/// Draft wording — FOR SOLICITOR REVIEW BEFORE PUBLIC LAUNCH.
///
/// Written to satisfy the four things explicit consent has to be: specific
/// (it names the exact categories), informed (it says what they are used
/// for), freely given (declining is a real option, and the app must
/// continue to work without these answers), and withdrawable.
const String kArticle9ConsentTitle = 'Some of these questions are sensitive';

const String kArticle9ConsentBody =
    'The next questions ask about your faith and your background — your '
    'sect, whether you have reverted to Christianity, your ethnicity, where you '
    'were born and your nationality.\n\n'
    'UK data protection law treats these as special-category information '
    'and asks us to get your explicit permission before recording them.\n\n'
    'SELAH uses them only to find you compatible matches. Your actual '
    'answers are never shown to anyone. Another member who unlocks your '
    'compatibility sees a score — never what you wrote.\n\n'
    'You can withdraw this permission at any time in Settings, and we will '
    'delete these answers.';

const String kArticle9ConsentDeclineNote =
    'You can carry on without answering these. Some matches may be less '
    'accurate.';

class SelahConsentService {
  SelahConsentService._();

  static const _type = 'article9_special_category';

  /// Cached for the session after the first read.
  ///
  /// Not a permanent cache: [record] updates it, so a withdrawal takes
  /// effect immediately rather than at next launch.
  static bool? _cached;
  static String? _owner;
  static int _epoch = 0;

  static void _synchronizeOwner() {
    final owner = SelahAuth.currentUser?.id;
    if (_owner == owner) return;
    clearForSignOut();
    _owner = owner;
  }

  static bool _isCurrent(String owner, int epoch) =>
      epoch == _epoch && owner == _owner && owner == SelahAuth.currentUser?.id;

  /// Whether the signed-in user currently consents.
  ///
  /// DEFAULTS TO FALSE on any failure, including a network error. That is
  /// deliberate and is the opposite of how the rest of this codebase treats
  /// failed reads: elsewhere a failure degrades to "carry on". Here it must
  /// degrade to "do not record special-category data", because the cost of
  /// being wrong is asymmetric — a lost answer is an inconvenience, an
  /// unlawfully stored one is not.
  static Future<bool> hasArticle9Consent() async {
    _synchronizeOwner();
    if (_cached != null) return _cached!;
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    final epoch = _epoch;
    try {
      final v = await supabase.rpc('has_article9_consent');
      if (!_isCurrent(user.id, epoch)) return false;
      _cached = v == true;
      return _cached!;
    } catch (e) {
      debugPrint('SELAH: consent check failed — treating as NOT consented. $e');
      return false;
    }
  }

  /// Records a grant or a withdrawal. Both are inserts.
  static Future<bool> record({required bool granted}) async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    final epoch = _epoch;
    try {
      await supabase.from('consents').insert({
        'user_id': user.id,
        'consent_type': _type,
        'granted': granted,
        'policy_version': kArticle9PolicyVersion,
      });
      if (!_isCurrent(user.id, epoch)) return false;
      _cached = granted;
      return true;
    } catch (e) {
      // Loud, because a consent that the user gave and we failed to record
      // is a consent we cannot later evidence.
      debugPrint(
        'SELAH: FAILED to record Article 9 consent (granted=$granted). '
        'Chapter 2 answers will not be saved without it. $e',
      );
      return false;
    }
  }

  /// The user's own consent history, newest first — for Settings, and for
  /// answering a subject access request without a database console.
  ///
  /// Onboarding restore opts into [throwOnError] so an unreadable decision
  /// is not mistaken for a user who has never been asked. Default read-only
  /// consumers retain the original empty-list failure behavior.
  static Future<List<({bool granted, String version, DateTime at})>> history({
    String? expectedUserId,
    bool throwOnError = false,
  }) async {
    try {
      _synchronizeOwner();
      final owner = _owner;
      final epoch = _epoch;
      final generation = SelahAccountState.generation;
      if (owner == null ||
          SelahAccountState.isSigningOut ||
          (expectedUserId != null && expectedUserId != owner)) {
        throw StateError('The consent account is no longer available.');
      }
      final rows =
          await supabase
                  .from('consents')
                  .select('granted, policy_version, recorded_at')
                  .eq('user_id', owner)
                  .eq('consent_type', _type)
                  .order('recorded_at', ascending: false)
              as List;
      if (!_isCurrent(owner, epoch) ||
          SelahAccountState.isSigningOut ||
          SelahAccountState.generation != generation) {
        throw StateError('The consent account changed.');
      }
      return [
        for (final r in rows)
          (
            granted: (r as Map)['granted'] as bool,
            version: r['policy_version'] as String,
            at: DateTime.parse(r['recorded_at'] as String),
          ),
      ];
    } catch (e) {
      debugPrint('SELAH: consent history fetch failed (${e.runtimeType}).');
      if (throwOnError) rethrow;
      return const [];
    }
  }

  /// Latest explicit decision, preserving the difference between "declined"
  /// and "not asked yet" when deferred onboarding is resumed.
  /// In strict mode, null means no recorded decision, never a failed read.
  static Future<bool?> currentArticle9Decision({
    String? expectedUserId,
    bool throwOnError = false,
  }) async {
    try {
      _synchronizeOwner();
      final owner = _owner;
      final epoch = _epoch;
      final generation = SelahAccountState.generation;
      if (owner == null ||
          SelahAccountState.isSigningOut ||
          (expectedUserId != null && expectedUserId != owner)) {
        throw StateError('The consent account is no longer available.');
      }
      final rows = await history(expectedUserId: owner, throwOnError: true);
      if (!_isCurrent(owner, epoch) ||
          SelahAccountState.isSigningOut ||
          SelahAccountState.generation != generation) {
        throw StateError('The consent account changed.');
      }
      return rows.isEmpty ? null : rows.first.granted;
    } catch (e) {
      debugPrint('SELAH: consent decision restore failed (${e.runtimeType}).');
      if (throwOnError) rethrow;
      return null;
    }
  }

  /// Sign-out must drop the cache, or the next account inherits this one's
  /// answer. Same failure shape as SelahUnlockService.clearForSignOut.
  static void clearForSignOut() {
    _epoch++;
    _owner = null;
    _cached = null;
  }
}
