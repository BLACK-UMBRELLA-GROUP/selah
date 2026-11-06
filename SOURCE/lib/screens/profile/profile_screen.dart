// Profile tab — APP/Profiles/Script/Script_V1.md: no white content
// containers, info sits directly on the page background, white section
// headings, membership status replaces the generic
// "Member" label. Includes the Passed/Saved/Considered review lists
// (inherited decision 099 labels, 2026-07-25) per the same spec's Connection
// Profile Expansion section (kept as a simple list here rather than
// the full reused-Browse-viewer expansion, which is a larger follow-up).

import 'package:flutter/material.dart';
import '../../data/selah_membership_catalog.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../models/selah_gender.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_account_switch_sheet.dart';
import '../../widgets/selah_one_profile_avatar.dart';
import '../../widgets/selah_profile_membership_row.dart';
import '../../services/selah_app_invite.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_unlock_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
// Hidden Profiles, Help, Notifications, Privacy and Membership are all reached
// through SettingsScreen now. Profile knows about Settings and nothing else.
import '../settings/settings_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/personalisation_screen.dart';
import '../subscription/upgrade_screen.dart';
import '../welcome_screen.dart';
import '../onboarding/account_path_overview_screen.dart';
import '../mentor/mentor_home_shell.dart';
import 'edit_photos_screen.dart';
import 'edit_profile_screen.dart';
import 'my_profile_preview_screen.dart';
import 'past_journeys_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _standardUnlocks;
  int? _plusUnlocks;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onChange);
    _loadUnlockBalances();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _loadUnlockBalances() async {
    final balance = await SelahUnlockService.balances();
    if (!mounted) return;
    setState(() {
      _standardUnlocks = balance[UnlockTier.standard] ?? 0;
      _plusUnlocks = balance[UnlockTier.plus] ?? 0;
    });
  }

  void _preview(BuildContext context) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, secondaryAnimation) =>
          const MyProfilePreviewScreen(),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: child,
          ),
    ),
  );

  /// One authenticated identity can enter either account context. The
  /// Founder preview performs the full local shell switch now; ordinary
  /// accounts stay migration-gated until the server can express dual-role
  /// ownership without relying on profiles.role.
  Future<void> _switchAccount(BuildContext context) async {
    // A previously rendered preview button can outlive its authorisation.
    // Check current authority at entry and bind the picker to its owner.
    if (!context.mounted ||
        !SelahDeveloperAccess.isMainAppFounderPreview ||
        SelahAccountState.isSigningOut ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    String? ownerId() {
      try {
        return SelahAuth.currentUser?.id;
      } catch (_) {
        return null; // Local preview without a configured client.
      }
    }

    final owner = ownerId();
    final generation = SelahAccountState.generation;
    bool canContinue() =>
        context.mounted &&
        SelahDeveloperAccess.isMainAppFounderPreview &&
        !SelahAccountState.isSigningOut &&
        SelahAccountState.generation == generation &&
        ownerId() == owner &&
        ModalRoute.of(context)?.isCurrent != false;

    final founderPreview = SelahDeveloperAccess.isMainAppFounderPreview;
    final shepherdOf = founderPreview
        ? const <MentorLinkedPerson>[]
        : await SelahMentorLinkService.fetchLinkedPeople(asMentor: true);
    if (!context.mounted || !canContinue()) return;
    final names = shepherdOf.map((person) => person.firstName).join(' · ');
    final selection = await showSelahAccountSwitchPage(
      context: context,
      options: [
        SelahAccountSwitchOption(
          context: SelahAccountContext.seeker,
          title: 'Seeker Account',
          subtitle: SelahDevLocalPreview.seekerMembershipLabel,
          icon: Icons.person_outline,
          current: true,
        ),
        SelahAccountSwitchOption(
          context: SelahAccountContext.shepherd,
          title: 'Shepherd Account',
          subtitle: founderPreview
              ? SelahDevLocalPreview.shepherdMembershipLabel
              : shepherdOf.isEmpty
              ? 'Set up separately · identity check reused'
              : 'Supporting $names',
          icon: Icons.shield_outlined,
          actionLabel: !founderPreview && shepherdOf.isEmpty
              ? 'SET UP ›'
              : 'SWITCH ›',
        ),
      ],
    );
    if (!context.mounted ||
        !canContinue() ||
        selection != SelahAccountContext.shepherd) {
      return;
    }

    if (founderPreview) {
      await SelahDevLocalPreview.switchAccountContext(context, toShepherd: true);
      return;
    }

    await SelahPromotionEngine.instance.clearForAccountSwitch();
    if (!context.mounted || !canContinue()) return;
    await SelahPromotionEngine.instance.initialize();
    if (!context.mounted || !canContinue()) return;
    if (shepherdOf.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ShepherdOnboardingOverviewScreen(
            migrationGatedPreview: true,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MentorHomeShell()),
      (route) => false,
    );
  }

  // ── "IMPROVE YOUR PROFILE" — REMOVED 2026-08-07 ─────────────────────
  //
  // Founder: "remove the improve your profile section."
  //
  // It listed two prompts: add more photos, and finish your compatibility
  // answers. Both are now reachable directly and obviously — Edit Photos
  // and Edit Profile sit side by side one line above where this card used
  // to be — so it was telling someone to press a button they were already
  // looking at.
  //
  // It was already a careful thing: not a percentage, nothing invented,
  // hidden entirely once there was nothing to say. It still earned its
  // place on the page by pointing at what the page already offered.
  //
  // If a nudge ever comes back it should measure MATCHING QUALITY rather
  // than cosmetic completion — the Founder's own condition, and not
  // something a checklist of two items was ever going to do.

  /// Membership is the first account section beneath the personal header.
  /// Compatibility follows it, then profile actions and About Me.
  ///
  /// "Member since" is still NOT here and is still not faked.
  /// `profiles.created_at` exists and IS selectable by the owner; AppState
  /// simply never loads it. One field plus one line in the session router,
  /// alongside `bio` and `surname_line`, and all three arrive together.
  Widget _membershipRow(BuildContext context, AppState state) =>
      SelahProfileMembershipRow(
        key: const ValueKey('seeker-profile-membership'),
        value: state.plan == SelahPlan.one
            ? SelahMembershipCatalog.seekerOneTitle
            : (SelahDevLocalPreview.basicMembershipPreviewLabel(
                    shepherd: false,
                  ) ??
                  'No active membership'),
        isOne: state.plan == SelahPlan.one,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
      );
  Future<void> _signOut(BuildContext context) async {
    // Real sign-out (OA-102) — only meaningful once Supabase is
    // configured; no-ops harmlessly via SelahAuth otherwise since
    // there's no session to end.
    await SelahAuth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // Account deletion MOVED 2026-08-06 to
  // screens/settings/account_advanced_screen.dart. It is now two taps
  // below Settings rather than a row on this page — Founder: "Delete
  // should never be visible in the main list."

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    // 2026-08-01: prefer AppState.age, which SelahSessionRouter hydrates
    // from ages_for() on every cold start. AppState.dob is only populated
    // during the onboarding session that captured it and is null on every
    // subsequent launch — `profiles.date_of_birth` is no longer selectable
    // by the client (audit C2). Computing from dob is kept as the
    // in-session path so the age appears immediately after Chapter 1,
    // before any rehydrate has happened.
    int? age = state.age;
    if (age == null && state.dob != null) {
      final now = DateTime.now();
      final dob = state.dob!;
      age = now.year - dob.year;
      final hadBirthdayThisYear =
          now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day);
      if (!hadBirthdayThisYear) age -= 1;
    }

    return Container(
      // 2026-07-25: gender-matched gradient (inherited decision 094/inherited upstream action 123)
      // instead of the neutral brand gradient — Blue for male, Pink for
      // female. Was previously hardcoded to the neutral gradient here;
      // see SelahColors.genderGradient() doc comment.
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
                  isOne: state.plan == SelahPlan.one,
                  child: state.photos.isNotEmpty
                      ? SelahAvatarImage(
                          state.photos.first,
                          width: 64,
                          height: 64,
                          alignmentX: state.avatarAlignmentX,
                          alignmentY: state.avatarAlignmentY,
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: SelahColors.iconButtonBg,
                          child: Icon(
                            Icons.person,
                            color: SelahColors.ink(0.38),
                            size: 30,
                          ),
                        ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FULL NAME as of 2026-08-07 — "Maryam Fatima Ahmed",
                      // which the Founder asked for on 2026-08-06 and which
                      // was deliberately left as a first name at the time
                      // rather than faked: surname_line existed in the
                      // database but AppState never carried it.
                      //
                      // It does now (see AppState.fullName), hydrated in
                      // the same round trip the router already made. Falls
                      // back to the first name on its own when there is no
                      // surname, which is a real state — nothing in
                      // onboarding asks for one yet.
                      Text(
                        state.fullName ?? 'Your Profile',
                        style: SelahText.heading(size: 20),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // PLAN BADGE REMOVED 2026-08-07 (Founder: "membership
                      // already appears elsewhere on the page, so this is
                      // duplicate information. The top of the Profile page
                      // should feel personal rather than repeating
                      // subscription information").
                      //
                      // Membership is on the YOUR PROFILE row below.
                      //
                      // The Founder asked for a full name here instead —
                      // "Maryam Fatima Ahmed". NOT done, and deliberately
                      // not faked: `profiles.surname_line` exists and is
                      // writable, but AppState carries only `name`. Showing
                      // a first name where a full name was asked for is
                      // honest; inventing one is not. One field plus one
                      // line in the session router, alongside `bio` and
                      // `created_at`, and all three arrive together.
                    ],
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
            const SizedBox(height: 28),
            Text(
              'MEMBERSHIP',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            _membershipRow(context, state),

            const SizedBox(height: 24),
            Text(
              'COMPATIBILITY',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            const SizedBox(height: 4),
            _UnlockBalanceRow(
              standard: _standardUnlocks,
              plus: _plusUnlocks,
              onBuyMore: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompatibilityUnlockStoreScreen(),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'YOUR PROFILE',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            const SizedBox(height: 5),
            _ProfileActionRow(
              key: const ValueKey('preview-profile-action'),
              icon: Icons.person_outline,
              label: 'Preview my profile',
              hint: 'See exactly what another Seeker sees',
              onTap: () => _preview(context),
            ),
            const _ProfileActionDivider(),
            _ProfileActionRow(
              key: const ValueKey('edit-profile-action'),
              icon: Icons.edit_outlined,
              label: 'Edit profile',
              hint: 'About you, preferences and compatibility answers',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            const _ProfileActionDivider(),
            _ProfileActionRow(
              key: const ValueKey('edit-photos-action'),
              icon: Icons.photo_library_outlined,
              label: 'Manage photos',
              hint: 'Add, arrange and choose your main photo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditPhotosScreen()),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'ABOUT ME',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SizedBox(height: 10),
            _InfoRow(label: 'Age', value: age?.toString() ?? '—'),
            _InfoRow(
              label: 'Gender',
              value: SelahGender.profileLabel(state.gender),
            ),
            _InfoRow(label: 'Location', value: state.location ?? '—'),

            SizedBox(height: 24),
            Text(
              'JOURNEY HISTORY',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SizedBox(height: 6),
            _SettingsRow(
              label: 'Past Journeys',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelahDeveloperAccess.isMainAppFounderPreview
                      ? const PastJourneysScreen(
                          previewPaused: [],
                          previewEnded: [],
                        )
                      : const PastJourneysScreen(),
                ),
              ),
            ),

            SizedBox(height: 24),
            Text(
              'SAFETY & SHARING',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SizedBox(height: 6),
            _SettingsRow(
              label: 'Safety & advice',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(
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
            SizedBox(height: 24),
            // Profile answers are edited through Edit Profile; the photo
            // count is already available from the carousel and Edit Photos.

            //
            // YOUR CONNECTIONS is removed for the same reason it was removed
            // from the Settings section this morning: Connections owns it.
            //
            // Membership and Compatibility live above YOUR PROFILE; see
            // _membershipRow and _UnlockBalanceRow.
            // ── REMOVED 2026-08-06 ────────────────────────────────────
            //
            // Passed / Saved / Considered were rendered here as rows. That
            // was the exact duplication the Founder's own principle
            // forbids: "Connections should stay in the Connections page…
            // Settings should configure the account, not become a
            // duplicate navigation hub."
            //
            // The whole SETTINGS section has also moved out, to
            // screens/settings/settings_screen.dart. It was seven flat rows
            // with Delete Account among them — a section cannot carry a
            // dashboard, cannot group six categories, and has no hierarchy
            // to demote a destructive action into. All three of those are
            // possible now that Settings is a screen.
            //
            // Profile is a profile again.
            SizedBox(height: 8),
            Text(
              'PERSONALISATION',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SizedBox(height: 6),
            _SettingsRow(
              label: 'Appearance & haptics',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PersonalisationScreen(),
                ),
              ),
            ),
            SizedBox(height: 14),
            _SettingsRow(
              label: 'Settings',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            _SettingsRow(label: 'Sign Out', onTap: () => _signOut(context)),
          ],
        ),
      ),
    );
  }
}

/// Profile actions deliberately sit directly on the page rather than inside
/// four competing glass cards. The hierarchy comes from type, icons and calm
/// hairline separators, matching the rest of Profile and Settings.
class _ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  const _ProfileActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: SelahColors.foregroundSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SelahText.body(
                      size: 14,
                      color: SelahColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: SelahText.subtext(
                      size: 11.5,
                      color: SelahColors.ink(0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: SelahColors.ink(0.28),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionDivider extends StatelessWidget {
  const _ProfileActionDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 34, color: SelahColors.ink(0.10));
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
              style: SelahText.body(size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockBalanceRow extends StatelessWidget {
  const _UnlockBalanceRow({
    required this.standard,
    required this.plus,
    required this.onBuyMore,
  });

  final int? standard;
  final int? plus;
  final VoidCallback onBuyMore;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('profile-compatibility-balances'),
    label: 'Compatibility unlock balance',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 20,
            color: SelahColors.journeyGold,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compatibility unlocks',
                  style: SelahText.body(size: 14, color: SelahColors.foreground),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  runSpacing: 5,
                  children: [
                    _UnlockCount(label: 'Unlock', value: plus),
                    if ((standard ?? 0) > 0)
                      _UnlockCount(
                        label: 'Earlier overall credits',
                        value: standard,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: const ValueKey('profile-compatibility-buy-more'),
            onPressed: onBuyMore,
            style: OutlinedButton.styleFrom(
              foregroundColor: SelahColors.journeyGold,
              side: BorderSide(
                color: SelahColors.journeyGold.withValues(alpha: 0.46),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Buy more', style: SelahText.button(size: 11.5)),
          ),
        ],
      ),
    ),
  );
}

class _UnlockCount extends StatelessWidget {
  const _UnlockCount({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: value?.toString() ?? '—',
          style: SelahText.body(size: 12.5, color: SelahColors.journeyGold),
        ),
        TextSpan(text: '  $label', style: SelahText.subtext(size: 11.5)),
      ],
    ),
  );
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
