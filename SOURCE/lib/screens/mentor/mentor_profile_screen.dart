// Shepherd Profile follows the same ownership rule as Seeker Profile:
// identity and role-specific information live here; account controls live
// in Settings. Shepherd remains intentionally smaller because it has no
// Browse-visible profile, photos, compatibility balance or Journey History.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_app_invite.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_entitlement_service.dart';
import '../../services/selah_notification_prefs_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_product_telemetry.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_account_switch_sheet.dart';
import '../../widgets/selah_one_profile_avatar.dart';
import '../../widgets/selah_profile_membership_row.dart';
import '../onboarding/account_path_overview_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/personalisation_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/upgrade_screen.dart';
import '../welcome_screen.dart';

class MentorProfileScreen extends StatefulWidget {
  // Retained for shell compatibility. Membership opens the shared plan page.
  final VoidCallback? onNavigateToNetwork;
  final Future<Map<SelahNotifyCategory, bool>?> Function()?
  loadNotificationPreferences;
  final Future<bool> Function(SelahNotifyCategory, bool)?
  saveNotificationPreference;
  final Future<SelahSourceResult<List<MentorLinkedPerson>>> Function()?
  loadLinkedSeekers;

  const MentorProfileScreen({
    super.key,
    this.onNavigateToNetwork,
    this.loadNotificationPreferences,
    this.saveNotificationPreference,
    this.loadLinkedSeekers,
  });

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  // 2026-07-26 (#19): real entitlement, not AppState.mentorHasMentorOne.
  bool _hasMentorOne = false;
  bool _linksLoading = true;
  bool _linksUnavailable = false;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onChange);
    _loadLinkedSeekers();
    if (SelahDeveloperAccess.isMainAppFounderPreview) {
      _hasMentorOne = AppState.instance.mentorHasMentorOne;
    } else {
      SelahEntitlementService.hasMentorOne().then((has) {
        if (mounted) setState(() => _hasMentorOne = has);
      });
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  String? _ownerId() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null; // Local preview or widget test without a client.
    }
  }

  Future<void> _loadLinkedSeekers() async {
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    SelahSourceResult<List<MentorLinkedPerson>> result;
    try {
      result =
          await (widget.loadLinkedSeekers?.call() ??
              SelahMentorLinkService.fetchLinkedPeopleResult(asMentor: true));
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
    if (sameOwner && result.isAvailable) {
      AppState.instance.setMentorRealLinkedSeekers(result.valueOrNull!);
    }
    setState(() {
      _linksLoading = false;
      _linksUnavailable = !sameOwner || result.isUnavailable;
    });
  }

  void _openMembership(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          const UpgradeScreen(telemetrySurface: SelahTelemetrySurface.shepherd),
    ),
  );

  /// CHANGED 2026-08-06. This row read `AppState.mentorRelationship` — the
  /// answer given at Shepherd onboarding, held in memory and never written
  /// anywhere. It now reads the live links, which is both authoritative and
  /// more truthful:
  ///
  /// relationship is per LINK, not per Shepherd. The same man is father to
  /// his daughter and paternal uncle to his niece, so a single stored value
  /// on his profile could only ever have been right about one of them. Where
  /// the links genuinely differ, all of them are named rather than one being
  /// picked to stand for the rest.
  String _relationshipSummary(AppState state) {
    final labels = <String>{
      for (final p in state.mentorRealLinkedSeekers)
        if (p.relationshipLabel != null) p.relationshipLabel!,
    };
    if (labels.isEmpty) {
      if (_linksLoading) return 'Checking…';
      return _linksUnavailable ? 'Unavailable' : '—';
    }
    return labels.join(', ');
  }

  String _linkedSeekerCount(AppState state) {
    if (state.mentorRealLinkedSeekers.isNotEmpty) {
      return '${state.mentorRealLinkedSeekers.length}';
    }
    if (_linksLoading) return 'Checking…';
    return _linksUnavailable ? 'Unavailable' : '0';
  }

  Future<void> _signOut(BuildContext context) async {
    await SelahAuth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  /// The Shepherd-side half of the one-identity context switch.
  /// Authentication is untouched: selecting Seeker either replaces the
  /// whole shell (once the context exists) or opens its first-time setup.
  /// The latter remains preview-gated until the server migration lands.
  Future<void> _switchAccount(BuildContext context) async {
    // Revoked preview callbacks must not reopen the account picker.
    if (!context.mounted ||
        !SelahDeveloperAccess.isMainAppFounderPreview ||
        SelahAccountState.isSigningOut ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    bool canContinue() =>
        context.mounted &&
        SelahDeveloperAccess.isMainAppFounderPreview &&
        !SelahAccountState.isSigningOut &&
        SelahAccountState.generation == generation &&
        _ownerId() == owner &&
        ModalRoute.of(context)?.isCurrent != false;

    final founderPreview = SelahDeveloperAccess.isMainAppFounderPreview;
    final selection = await showSelahAccountSwitchPage(
      context: context,
      options: [
        SelahAccountSwitchOption(
          context: SelahAccountContext.shepherd,
          title: 'Shepherd Account',
          subtitle: founderPreview
              ? SelahDevLocalPreview.shepherdMembershipLabel
              : (_hasMentorOne ? 'Shepherd One' : 'No active membership'),
          icon: Icons.shield_outlined,
          current: true,
        ),
        SelahAccountSwitchOption(
          context: SelahAccountContext.seeker,
          title: 'Seeker Account',
          subtitle: founderPreview
              ? SelahDevLocalPreview.seekerMembershipLabel
              : 'Set up separately · identity check reused',
          icon: Icons.person_outline,
          actionLabel: founderPreview ? 'SWITCH ›' : 'SET UP ›',
        ),
      ],
    );
    if (!context.mounted ||
        !canContinue() ||
        selection != SelahAccountContext.seeker) {
      return;
    }

    if (founderPreview) {
      await SelahDevLocalPreview.switchAccountContext(
        context,
        toShepherd: false,
      );
      return;
    }

    await SelahPromotionEngine.instance.clearForAccountSwitch();
    if (!context.mounted || !canContinue()) return;
    await SelahPromotionEngine.instance.initialize();
    if (!context.mounted || !canContinue()) return;

    // The client shell switch is ready, but the current database cannot yet
    // say this Shepherd also has a Seeker presentation. Keep the user inside
    // an honest setup preview instead of navigating to a shell whose server
    // reads would refuse them. This branch is removed when the migration is
    // explicitly authorised and its availability read is wired.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeekerOnboardingOverviewScreen(
          gender: AppState.instance.gender,
          migrationGatedPreview: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Container(
      // 2026-07-25: was hardcoded to brandGradientMale regardless of the
      // signed-in Mentor's actual gender (inherited decision 094/inherited upstream action 123 gap) —
      // now reads the Shepherd's own gender like every other profile-context
      // screen. Every current test Mentor persona is male, so this is a
      // no-op today but is correct once a female Mentor persona exists.
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(state.gender),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          children: [
            Row(
              children: [
                SelahOneProfileAvatar(
                  isOne: _hasMentorOne,
                  shepherd: true,
                  child: Container(
                    color: SelahColors.iconButtonBg,
                    child: Icon(
                      Icons.shield_outlined,
                      color: SelahColors.ink(0.38),
                      size: 30,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    state.mentorName ?? 'Your Profile',
                    style: SelahText.heading(size: 20),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (SelahDeveloperAccess.isMainAppFounderPreview) ...[
                  SizedBox(width: 10),
                  SelahAccountSwitchButton(
                    onPressed: () => _switchAccount(context),
                  ),
                ],
              ],
            ),
            // Follow the Seeker Profile hierarchy while keeping Shepherd-only
            // content honest: Shepherd has no Browse profile/photo gallery,
            // compatibility balance or Journey History section.
            const SizedBox(height: 28),
            Text(
              'MEMBERSHIP',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SelahProfileMembershipRow(
              key: const ValueKey('shepherd-profile-membership'),
              value: _hasMentorOne
                  ? 'Shepherd One'
                  : (SelahDevLocalPreview.basicMembershipPreviewLabel(
                          shepherd: true,
                        ) ??
                        'No active membership'),
              isOne: _hasMentorOne,
              onTap: () => _openMembership(context),
            ),
            const SizedBox(height: 24),
            Text(
              'ABOUT ME',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            const SizedBox(height: 10),
            _InfoRow(label: 'Relationship', value: _relationshipSummary(state)),
            _InfoRow(label: 'Linked Seekers', value: _linkedSeekerCount(state)),
            const SizedBox(height: 24),
            Text(
              'SAFETY & SHARING',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            const SizedBox(height: 6),
            _SettingsRow(
              label: 'Safety & advice',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(
                    telemetrySurface: SelahTelemetrySurface.shepherd,
                    initialQuery: 'Safety and reporting',
                  ),
                ),
              ),
            ),
            Builder(
              builder: (inviteContext) => _SettingsRow(
                label: 'Invite someone to SELAH',
                onTap: () => SelahAppInvite.share(inviteContext),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PERSONALISATION',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            const SizedBox(height: 6),
            _SettingsRow(
              label: 'Appearance & haptics',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PersonalisationScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SettingsRow(
              label: 'Settings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    shepherd: true,
                    shepherdHasOne: _hasMentorOne,
                    loadNotificationPreferences:
                        widget.loadNotificationPreferences,
                    saveNotificationPreference:
                        widget.saveNotificationPreference,
                  ),
                ),
              ),
            ),
            _SettingsRow(label: 'Sign Out', onTap: () => _signOut(context)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: SelahText.subtext(size: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: SelahText.body(size: 13, color: SelahColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SettingsRow({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: SelahText.body(size: 13.5, color: Colors.white),
              ),
            ),
            Icon(Icons.chevron_right, color: SelahColors.ink(0.24), size: 16),
          ],
        ),
      ),
    );
  }
}
