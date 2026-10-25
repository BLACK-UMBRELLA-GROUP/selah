// Settings — the account control centre.
//
// NEW 2026-08-06. Settings was previously a SECTION inside
// profile_screen.dart: a label and seven flat rows, below the profile card
// and a list of Connections counts.
//
// That one fact explained most of the Founder's review. A section cannot
// have a dashboard. Six groups nested inside a Profile page make it longer,
// not clearer. Delete Account was prominent because a flat list of seven has
// no hierarchy to demote anything into. And the page already duplicated
// Connections — Passed, Saved and Considered were rendered as rows, which is
// exactly what the "don't duplicate" principle forbids.
//
// THE DIVISION OF RESPONSIBILITY, Founder 2026-08-06,
// AMENDED 2026-08-07 — compatibility moved to Edit Profile:
//   Connections   manages relationships
//   Shepherd page manages Shepherds
//   Edit Profile  manages compatibility — what you look like to others
//   Settings      manages the account, privacy, notifications, support
//
// DELIBERATELY ABSENT:
//   Appearance      theme and language do not exist. An empty section
//                   labelled "future" is the dumping ground §8 warns about.
//   Data Export     Article 15, unbuilt, and three of its rules are open
//                   solicitor questions. Founder confirmed out of scope.
//   Change password SELAH is OAuth-only — Google and Apple, no password for
//                   ANY user (selah_auth.dart, Founder instruction
//                   2026-07-18). A row that errors for everyone is worse
//                   than no row.
//
// Privacy Policy appears under both Privacy and Support in the brief. It is
// here once, under Support, because two routes to one document is the same
// duplication in miniature.

import 'package:flutter/material.dart';
import '../../data/selah_membership_catalog.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../dev/dev_settings_design_state.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_notification_prefs_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_product_telemetry.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../theme/selah_card_metrics.dart';
import '../subscription/upgrade_screen.dart';
import '../../services/selah_app_lock.dart';
import 'account_advanced_screen.dart';
import 'app_lock_screen.dart';
import 'hidden_profiles_screen.dart';
import 'feedback_screen.dart';
import 'help_support_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_and_data_screen.dart';
import 'privacy_settings_screen.dart';
import 'sign_in_security_screen.dart';
import '../../widgets/selah_glass_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final bool shepherd;
  final bool? shepherdHasOne;
  final Future<Map<SelahNotifyCategory, bool>?> Function()?
  loadNotificationPreferences;
  final Future<bool> Function(SelahNotifyCategory, bool)?
  saveNotificationPreference;
  final Future<SelahSourceResult<List<MentorLinkedPerson>>> Function(bool asMentor)?
  loadLinkedPeople;

  const SettingsScreen({
    super.key,
    this.shepherd = false,
    this.shepherdHasOne,
    this.loadNotificationPreferences,
    this.saveNotificationPreference,
    this.loadLinkedPeople,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<MentorLinkedPerson>? _linkedPeople;
  bool _linksLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedPeople();
  }

  String? _ownerId() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null; // Local preview or widget test without a client.
    }
  }

  Future<void> _loadLinkedPeople() async {
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    SelahSourceResult<List<MentorLinkedPerson>> result;
    try {
      result =
          await (widget.loadLinkedPeople?.call(widget.shepherd) ??
              SelahMentorLinkService.fetchLinkedPeopleResult(
                asMentor: widget.shepherd,
              ));
    } catch (_) {
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!mounted) return;
    final sameOwner =
        !SelahAccountState.isSigningOut &&
        SelahAccountState.generation == generation &&
        _ownerId() == owner;
    setState(() {
      _linkedPeople = sameOwner ? result.valueOrNull : null;
      _linksLoaded = true;
    });
  }

  String get _relationshipValue {
    if (!_linksLoaded) return 'Checking…';
    final people = _linkedPeople;
    if (people == null) return 'Unavailable';
    if (people.isEmpty) return 'None linked';
    if (widget.shepherd) return '${people.length} linked';
    return people.any((p) => p.isMain)
        ? '${people.length} linked · 1 Main'
        : '${people.length} linked · no Main';
  }

  /// The provider the user actually signed in with. Shown rather than
  /// inferred: SELAH has no password, so "how do I get in" is a question
  /// only the provider can answer, and saying so is more useful than
  /// hiding it.
  String? get _providerRaw {
    try {
      return SelahAuth.currentUser?.appMetadata['provider'] as String?;
    } catch (_) {
      // Settings must still render in local previews and widget tests where
      // Supabase is intentionally not initialised.
      return null;
    }
  }

  /// Short label — the summary card and the ACCOUNT row. Kept to one or
  /// two words so neither overflows.
  ///
  /// THE DEFAULT BRANCH USED TO RETURN 'Your provider'. Founder 2026-08-07:
  /// fix it so developers notice a misconfiguration immediately. That
  /// wording read as a deliberate design choice and so concealed a real
  /// fact — every one of the 149 accounts in the database today has
  /// `provider = 'email'` (seeded test accounts through the password
  /// provider, which is still enabled server-side). Not one Google or
  /// Apple identity has ever been created, so the panel has been reading
  /// "Signed in with Your provider" for its entire life and looking
  /// deliberate while doing it. A fallback that produces a plausible
  /// string is how a display bug survives to launch.
  String get _provider {
    if (_providerRaw == 'email' && SelahAuth.hasLinkedOAuth) {
      return 'Recovery email';
    }
    return switch (_providerRaw) {
      'google' => 'Google',
      'apple' => 'Apple',
      'email' =>
        SelahDeveloperAccess.canUseDeveloperTools ? 'Test account' : 'Email',
      null => SelahDeveloperAccess.canUseDeveloperTools ? 'NOT SET' : 'Unknown',
      _ => _providerRaw ?? 'Unknown',
    };
  }

  bool get _hasMembership => widget.shepherd
      ? (widget.shepherdHasOne ?? AppState.instance.mentorHasMentorOne)
      : AppState.instance.plan == SelahPlan.one;

  String get _membershipLabel => _hasMembership
      ? (widget.shepherd
            ? SelahMembershipCatalog.shepherdOneTitle
            : SelahMembershipCatalog.seekerOneTitle)
      : (SelahDevLocalPreview.basicMembershipPreviewLabel(
              shepherd: widget.shepherd,
            ) ??
            'No active membership');

  void _showShepherdPrivacy(BuildContext context) {
    showSelahGlassNotice(
      context: context,
      icon: Icons.shield_outlined,
      title: 'Shepherd privacy',
      body:
          "Shepherd accounts don't appear in Browse. Your identity is shared "
          'only with a Seeker who has linked you, and with the other Shepherds '
          'in a Journey where your access applies.',
      buttonLabel: 'Got it',
      bodyTextAlign: TextAlign.left,
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<SelahSettingsDesign>(
        valueListenable: SelahDevSettingsDesign.selection,
        builder: (context, design, _) => _buildSettings(
          context,
          SelahDeveloperAccess.isMainAppFounderPreview &&
              design == SelahSettingsDesign.smoothCards,
        ),
      );

  Widget _buildSettings(BuildContext context, bool smoothCards) {
    final state = AppState.instance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: smoothCards
            ? null
            : Text('Settings', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(state.gender),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
            children: [
              if (smoothCards) ...[
                const SizedBox(height: 38),
                _SettingsReveal(
                  key: const ValueKey('settings_smooth_header'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: SelahText.heading(size: 30)),
                      const SizedBox(height: 5),
                      Text(
                        'Your account, your choices.',
                        style: SelahText.subtext(
                          size: 13,
                          color: SelahColors.ink(.58),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
              // §1 — the page answers "what can I control?" before it offers
              // anything to control. Every value here is real; nothing is a
              // placeholder for a feature that does not exist.
              _SettingsReveal(
                key: ValueKey('settings_summary_$smoothCards'),
                enabled: smoothCards,
                child: _SummaryCard(
                  membership: _membershipLabel,
                  relationshipLabel: widget.shepherd
                      ? 'Linked Seekers'
                      : 'Shepherds',
                  relationshipValue: _relationshipValue,
                  signedInWith: _provider,
                ),
              ),

              SizedBox(height: 28),
              _Section(
                title: 'ACCOUNT',
                children: [
                  _Row(
                    label: 'Sign-in & security',
                    value: _provider,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignInSecurityScreen(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  // ADDED 2026-08-07. Sits in ACCOUNT rather than PRIVACY
                  // deliberately: it protects the account as a whole, not
                  // one aspect of what other people can see, and it is the
                  // row people will come looking for after being told the
                  // feature exists.
                  _Row(
                    label: 'App lock',
                    value: SelahAppLock.instance.enabled ? 'On' : 'Off',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppLockScreen(),
                        ),
                      );
                      if (mounted) setState(() {}); // the row shows On/Off
                    },
                  ),
                  // §5 — Delete is two levels down, never in the main list.
                  _Row(
                    label: 'Advanced',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AccountAdvancedScreen(shepherd: widget.shepherd),
                      ),
                    ),
                  ),
                ],
              ),

              // ── COMPATIBILITY — MOVED OUT 2026-08-07 ─────────────────
              //
              // Founder: "in settings if the compatibility section is the
              // same as edit profile then you gotta maybe move that section
              // into edit profile part."
              //
              // It was the same. Profile had an Edit Profile button that
              // went nowhere while the five editors it implied lived here,
              // which made Settings the second route to an intention that
              // belonged on the first.
              //
              // Now in screens/profile/edit_profile_screen.dart, on the
              // Founder's own principle: "Settings should configure the
              // account, not become a duplicate navigation hub." Sect,
              // lifestyle and what someone wants in a marriage are not
              // account configuration — they are the profile.
              //
              // This supersedes the division of responsibility in this
              // file's header, which gave compatibility to Settings.
              _Section(
                title: 'PRIVACY',
                children: widget.shepherd
                    ? [
                        _Row(
                          label: 'Shepherd privacy',
                          value: 'Not discoverable',
                          onTap: () => _showShepherdPrivacy(context),
                        ),
                      ]
                    : [
                        _Row(
                          label: 'Discovery & visibility',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacySettingsScreen(),
                            ),
                          ),
                        ),
                        _Row(
                          label: 'Hidden Profiles',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HiddenProfilesScreen(),
                            ),
                          ),
                        ),
                      ],
              ),

              _Section(
                title: 'NOTIFICATIONS',
                children: [
                  _Row(
                    label: 'Notifications & emails',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationSettingsScreen(
                          role: widget.shepherd
                              ? SelahPromotionRole.shepherd
                              : SelahPromotionRole.seeker,
                          loadPreferences: widget.loadNotificationPreferences,
                          savePreference: widget.saveNotificationPreference,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              _Section(
                title: 'MEMBERSHIP',
                children: [
                  _Row(
                    label: 'Membership',
                    value: _membershipLabel,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UpgradeScreen(
                          telemetrySurface: widget.shepherd
                              ? SelahTelemetrySurface.shepherd
                              : SelahTelemetrySurface.seeker,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              _Section(
                title: 'SUPPORT',
                children: [
                  _Row(
                    label: 'Help & support',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HelpSupportScreen(
                          telemetrySurface: widget.shepherd
                              ? SelahTelemetrySurface.shepherd
                              : SelahTelemetrySurface.seeker,
                        ),
                      ),
                    ),
                  ),
                  // ADDED 2026-08-07 (Founder: "a feedback section where we
                  // can improve the app from users requests").
                  //
                  // A SEPARATE ROW from Help & support, not a section inside
                  // it. Help is for someone stuck who wants an answer;
                  // feedback is for someone fine who has a thought. Folding
                  // the second into the first would put every idea behind a
                  // door marked "problem".
                  _Row(
                    label: 'Send feedback',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    ),
                  ),
                ],
              ),

              // ADDED 2026-08-09 (Founder, from the Muzz teardown: "they
              // have a privacy and cookie setting"). A LEGAL section, not a
              // row inside PRIVACY — the existing PRIVACY section is about
              // choices the member makes (who sees them, who is blocked).
              // This is about what the company does, which is a different
              // question and belongs under its own heading.
              //
              // One row for now. The Privacy Policy and Terms get their own
              // rows the day the drafted text exists; until then a row that
              // opens nothing is worse than no row.
              _Section(
                title: 'LEGAL',
                children: [
                  _Row(
                    label: 'Privacy & data',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PrivacyAndDataScreen(shepherd: widget.shepherd),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),
              Center(child: _VersionFooter()),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String membership;
  final String relationshipLabel;
  final String relationshipValue;
  final String signedInWith;

  const _SummaryCard({
    required this.membership,
    required this.relationshipLabel,
    required this.relationshipValue,
    required this.signedInWith,
  });

  @override
  Widget build(BuildContext context) {
    final smoothCards = _settingsSmoothCards;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: smoothCards ? 20 : 18,
        vertical: smoothCards ? 22 : 18,
      ),
      decoration: BoxDecoration(
        color: SelahColors.foreground.withValues(alpha: smoothCards ? .11 : .09),
        borderRadius: BorderRadius.circular(
          smoothCards ? 24 : SelahCardMetrics.cardRadius,
        ),
        border: Border.all(
          color: smoothCards
              ? SelahColors.unlockText.withValues(alpha: .28)
              : SelahColors.foreground.withValues(alpha: .14),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          if (smoothCards) ...[
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: SelahColors.unlockText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your account',
                    maxLines: 2,
                    style: SelahText.body(size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _line('Membership', membership),
          _divider(),
          _line(relationshipLabel, relationshipValue),
          _divider(),
          _line('Signed in with', signedInWith),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: SelahText.subtext(size: 13, color: SelahColors.ink(0.54)),
          ),
        ),
        if (_settingsSmoothCards)
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SelahText.body(size: 14, color: Colors.white),
            ),
          )
        else
          Text(v, style: SelahText.body(size: 14, color: Colors.white)),
      ],
    ),
  );

  Widget _divider() => Container(
    height: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 3),
    color: SelahColors.foreground.withValues(alpha: 0.08),
  );
}

// ── Section ────────────────────────────────────────────────────────────
/// The version line at the foot of Settings — "1.0.0 (1)".
///
/// ADDED 2026-08-09. Founder, from the Muzz teardown: "at bottom a version
/// number with 8.77.1 (563)". Same shape: marketing version, then build
/// number in brackets.
///
/// ── WHY package_info_plus AND NOT A CONSTANT. A hand-maintained
/// `const kVersion = '1.0.0'` is wrong the first time someone bumps
/// pubspec and forgets, and a version string that lies is worse than no
/// version string — its entire purpose is for a user to read it back to
/// support. This reads the real value out of the built app bundle, so it
/// cannot disagree with what was shipped.
///
/// ── WHY IT IS ALLOWED TO SHOW NOTHING. The lookup is async and can fail
/// on a platform that has not been configured. On failure this renders the
/// wordmark alone, exactly as the footer did before today — an empty space
/// where a version should be is a smaller problem than an error, and this
/// is the least important element on the screen.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String? _line;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _line = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Deliberately silent — see the class comment.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'SELAH',
        style: SelahText.wordmark(size: 11, color: SelahColors.ink(0.24)),
      ),
      if (_line != null) ...[
        SizedBox(height: 3),
        // SelectableText, not Text: the one thing anybody ever does
        // with a version number is send it to support.
        SelectableText(
          _line!,
          style: SelahText.subtext(size: 11, color: SelahColors.ink(0.24)),
        ),
      ],
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final smoothCards = _settingsSmoothCards;
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
          ),
          SizedBox(height: smoothCards ? 12 : 10),
          Container(
            decoration: BoxDecoration(
              color: SelahColors.foreground.withValues(
                alpha: smoothCards ? .085 : .05,
              ),
              borderRadius: BorderRadius.circular(
                smoothCards ? 23 : SelahCardMetrics.cardRadius,
              ),
              border: Border.all(
                color: SelahColors.foreground.withValues(
                  alpha: smoothCards ? .16 : .10,
                ),
                width: 0.5,
              ),
            ),
            clipBehavior: smoothCards ? Clip.antiAlias : Clip.none,
            child: Column(children: children),
          ),
        ],
      ),
    );
    return _SettingsReveal(
      key: ValueKey('settings_section_${title}_$smoothCards'),
      enabled: smoothCards,
      child: content,
    );
  }
}

// ── Row ────────────────────────────────────────────────────────────────
//
// §6 — where a setting has a current value, show it. "Membership · SELAH One"
// answers the question without costing a tap.
class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _Row({required this.label, required this.onTap, this.value});

  @override
  Widget build(BuildContext context) {
    final smoothCards = _settingsSmoothCards;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: smoothCards ? 18 : 16,
            vertical: smoothCards ? 17 : 15,
          ),
          child: Row(
            children: [
              if (smoothCards) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SelahColors.unlockText.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _settingsIcon(label),
                    size: 18,
                    color: SelahColors.unlockText,
                  ),
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Text(
                  label,
                  style: SelahText.body(size: 15, color: Colors.white),
                ),
              ),
              if (value != null && value!.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahText.subtext(
                      size: 13,
                      color: SelahColors.ink(0.38),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: SelahColors.foreground.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool get _settingsSmoothCards =>
    SelahDeveloperAccess.isMainAppFounderPreview &&
    SelahDevSettingsDesign.current == SelahSettingsDesign.smoothCards;

IconData _settingsIcon(String label) => switch (label) {
  'Sign-in & security' => Icons.verified_user_outlined,
  'App lock' => Icons.lock_outline_rounded,
  'Advanced' => Icons.tune_rounded,
  'Shepherd privacy' || 'Discovery & visibility' => Icons.visibility_outlined,
  'Hidden Profiles' => Icons.person_off_outlined,
  'Notifications & emails' => Icons.notifications_outlined,
  'Membership' => Icons.workspace_premium_outlined,
  'Help & support' => Icons.help_outline_rounded,
  'Send feedback' => Icons.chat_bubble_outline_rounded,
  'Privacy & data' => Icons.shield_outlined,
  _ => Icons.chevron_right_rounded,
};

class _SettingsReveal extends StatelessWidget {
  const _SettingsReveal({super.key, this.enabled = true, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
