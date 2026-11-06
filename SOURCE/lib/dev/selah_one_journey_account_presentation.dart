// Disposable account presentation, copied from the current account owners.
// The caller supplies every sample fact and every action. This file neither
// reads a member account nor changes preferences, security or paid access.
import 'package:flutter/material.dart';

import '../data/selah_entitlements.dart';
import '../data/selah_membership_catalog.dart';
import '../data/selah_seeker_basic_policy.dart';
import '../data/selah_seeker_plan_limits.dart';
import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_account_switch_sheet.dart';
import '../widgets/selah_family_pricing_card.dart';
import '../widgets/selah_fade_edges.dart';
import '../widgets/selah_one_profile_avatar.dart';
import '../widgets/selah_profile_membership_row.dart';
import '../widgets/selah_profile_image.dart';

enum SelahConceptAccountAction {
  previewProfile,
  editProfile,
  managePhotos,
  compatibilityStore,
  pastJourneys,
  safetyAdvice,
  invite,
  personalisation,
  settings,
  signOut,
  signInSecurity,
  appLock,
  advanced,
  shepherdPrivacy,
  visibility,
  hiddenProfiles,
  notificationSettings,
  membership,
  helpSupport,
  feedback,
  privacyData,
  background,
  haptics,
  cancelMembership,
  basket,
}

/// Explicit sample data only; no field here establishes account authority.
class SelahConceptAccountData {
  const SelahConceptAccountData({
    required this.shepherd,
    required this.name,
    required this.age,
    required this.gender,
    required this.location,
    required this.membership,
    required this.isOne,
    required this.relationship,
    required this.linkedSeekers,
    required this.shepherdCount,
    required this.signedInWith,
    required this.backgroundLabel,
    required this.hapticLabel,
    required this.gold,
    this.photoAsset,
    this.standardUnlocks,
    this.plusUnlocks,
    this.appLock = false,
    this.smoothSettings = false,
    this.versionLine,
    this.basketCount = 0,
    this.selectedProducts = const {},
  });

  final bool shepherd;
  final String name;
  final String age;
  final String gender;
  final String location;
  final String membership;
  final bool isOne;
  final String relationship;
  final String linkedSeekers;
  final String shepherdCount;
  final String signedInWith;
  final String backgroundLabel;
  final String hapticLabel;
  final bool gold;
  final String? photoAsset;
  final int? standardUnlocks;
  final int? plusUnlocks;
  final bool appLock;
  final bool smoothSettings;
  final String? versionLine;
  final int basketCount;
  final Set<SelahMembershipProduct> selectedProducts;

  SelahMembershipProduct get currentProduct => switch ((shepherd, isOne)) {
    (false, true) => SelahMembershipProduct.seekerOne,
    (false, false) => SelahMembershipProduct.seekerBasic,
    (true, true) => SelahMembershipProduct.shepherdOne,
    (true, false) => SelahMembershipProduct.shepherdBasic,
  };
}

typedef SelahConceptAccountActionCallback =
    void Function(SelahConceptAccountAction action);

/// ProfileScreen/MentorProfileScreen's current hierarchy, labels and metrics.
/// Owns its list padding; mount as a bounded tab body, not inside another list.
class SelahConceptProfilePresentation extends StatelessWidget {
  const SelahConceptProfilePresentation({
    super.key,
    required this.data,
    required this.onAction,
    required this.onSwitchRole,
    this.faithProfile,
    this.simplifiedMethodology = false,
  });

  final SelahConceptAccountData data;
  final SelahConceptAccountActionCallback onAction;
  final VoidCallback onSwitchRole;
  final Widget? faithProfile;
  final bool simplifiedMethodology;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Profile',
                key: const ValueKey('concept_profile_title'),
                textAlign: TextAlign.left,
                style: SelahText.pageTitle(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('concept-current-profile-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final nameStyle = SelahText.heading(size: 20);
                    final firstWord = TextPainter(
                      text: TextSpan(
                        text: data.name.trim().split(RegExp(r'\s+')).first,
                        style: nameStyle,
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    final switchLabel = TextPainter(
                      text: TextSpan(
                        text: 'Switch',
                        style: SelahText.subtext(size: 11.5),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    // Avatar, gaps, and the unchanged shared button's icon/padding.
                    // Stack only when the first word cannot fit beside those controls.
                    final stackSwitch =
                        constraints.maxWidth <
                        68 +
                            16 +
                            10 +
                            16 +
                            8 +
                            22 +
                            switchLabel.width +
                            firstWord.width;
                    firstWord.dispose();
                    switchLabel.dispose();
                    final avatar = SelahOneProfileAvatar(
                      isOne: data.isOne,
                      shepherd: data.shepherd,
                      child: data.photoAsset != null && !data.shepherd
                          ? data.photoAsset!.startsWith('data:image/')
                                ? SelahAvatarImage(
                                    data.photoAsset!,
                                    width: 64,
                                    height: 64,
                                    alignmentX: 0,
                                    alignmentY: 0,
                                  )
                                : data.photoAsset!.startsWith('assets/')
                                ? Image.asset(
                                    data.photoAsset!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox.square(dimension: 64)
                          : Container(
                              width: 64,
                              height: 64,
                              color: SelahColors.iconButtonBg,
                              child: Icon(
                                data.shepherd
                                    ? Icons.shield_outlined
                                    : Icons.person,
                                color: SelahColors.ink(0.38),
                                size: 30,
                              ),
                            ),
                    );
                    final name = Expanded(
                      child: Text(
                        data.name,
                        style: nameStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                    final switchButton = KeyedSubtree(
                      key: ValueKey(
                        data.shepherd
                            ? 'draft_role_seeker'
                            : 'draft_role_shepherd',
                      ),
                      child: SelahAccountSwitchButton(onPressed: onSwitchRole),
                    );
                    final identity = Row(
                      children: [
                        avatar,
                        const SizedBox(width: 16),
                        name,
                        if (!stackSwitch) ...[
                          const SizedBox(width: 10),
                          switchButton,
                        ],
                      ],
                    );
                    if (!stackSwitch) return identity;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: switchButton,
                        ),
                      ],
                    );
                  },
                ),
                if (!data.shepherd && faithProfile != null) ...[
                  const SizedBox(height: 24),
                  faithProfile!,
                ],
                const SizedBox(height: 28),
                const _SectionLabel('MEMBERSHIP'),
                KeyedSubtree(
                  key: const ValueKey('concept_membership'),
                  child: SelahProfileMembershipRow(
                    value: data.membership,
                    isOne: data.isOne,
                    onTap: () => onAction(SelahConceptAccountAction.membership),
                  ),
                ),
                if (!data.shepherd) ...[
                  const SizedBox(height: 24),
                  const _SectionLabel('COMPATIBILITY'),
                  const SizedBox(height: 4),
                  _UnlockBalance(
                    standard: data.standardUnlocks,
                    plus: data.plusUnlocks,
                    onBuyMore: () =>
                        onAction(SelahConceptAccountAction.compatibilityStore),
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel('YOUR PROFILE'),
                  const SizedBox(height: 5),
                  _ProfileAction(
                    key: const ValueKey('concept_preview_profile'),
                    icon: Icons.person_outline,
                    label: 'Preview my profile',
                    hint: 'See exactly what another Seeker sees',
                    onTap: () =>
                        onAction(SelahConceptAccountAction.previewProfile),
                  ),
                  const _ProfileDivider(),
                  _ProfileAction(
                    key: const ValueKey('concept_edit_profile'),
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    hint: 'About you, preferences and compatibility answers',
                    onTap: () =>
                        onAction(SelahConceptAccountAction.editProfile),
                  ),
                  const _ProfileDivider(),
                  _ProfileAction(
                    key: const ValueKey('concept_manage_photos'),
                    icon: Icons.photo_library_outlined,
                    label: 'Manage photos',
                    hint: 'Add, arrange and choose your main photo',
                    onTap: () =>
                        onAction(SelahConceptAccountAction.managePhotos),
                  ),
                ],
                const SizedBox(height: 24),
                const _SectionLabel('ABOUT ME'),
                const SizedBox(height: 10),
                if (data.shepherd) ...[
                  _InfoRow(
                    label: 'Relationship',
                    value: data.relationship,
                    shepherd: true,
                  ),
                  _InfoRow(
                    label: 'Linked Seekers',
                    value: data.linkedSeekers,
                    shepherd: true,
                  ),
                ] else ...[
                  _InfoRow(label: 'Age', value: data.age),
                  _InfoRow(label: 'Gender', value: data.gender),
                  _InfoRow(label: 'Location', value: data.location),
                  if (!simplifiedMethodology) ...[
                    const SizedBox(height: 24),
                    const _SectionLabel('JOURNEY HISTORY'),
                    const SizedBox(height: 6),
                    _ProfileSettingsRow(
                      key: const ValueKey('concept_past_journeys'),
                      label: 'Past Journeys',
                      onTap: () =>
                          onAction(SelahConceptAccountAction.pastJourneys),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                const _SectionLabel('SAFETY & SHARING'),
                const SizedBox(height: 6),
                _ProfileSettingsRow(
                  key: const ValueKey('concept_safety_advice'),
                  label: 'Safety & advice',
                  onTap: () => onAction(SelahConceptAccountAction.safetyAdvice),
                ),
                _ProfileSettingsRow(
                  key: const ValueKey('concept_invite'),
                  label: 'Invite someone to SELAH',
                  onTap: () => onAction(SelahConceptAccountAction.invite),
                ),
                const SizedBox(height: 24),
                if (!data.shepherd) const SizedBox(height: 8),
                const _SectionLabel('PERSONALISATION'),
                const SizedBox(height: 6),
                _ProfileSettingsRow(
                  key: const ValueKey('concept_personalisation'),
                  label: 'Appearance & haptics',
                  onTap: () =>
                      onAction(SelahConceptAccountAction.personalisation),
                ),
                const SizedBox(height: 14),
                _ProfileSettingsRow(
                  key: const ValueKey('concept_settings'),
                  label: 'Settings',
                  onTap: () => onAction(SelahConceptAccountAction.settings),
                ),
                _ProfileSettingsRow(
                  key: const ValueKey('concept_sign_out'),
                  label: 'Sign Out',
                  onTap: () => onAction(SelahConceptAccountAction.signOut),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// SettingsScreen's current sections and row copy. All actions stay caller-owned.
class SelahConceptSettingsPresentation extends StatelessWidget {
  const SelahConceptSettingsPresentation({
    super.key,
    required this.data,
    required this.onAction,
    required this.onBack,
    this.showBackButton = true,
  });

  final SelahConceptAccountData data;
  final SelahConceptAccountActionCallback onAction;
  final VoidCallback onBack;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final smooth = data.smoothSettings;
    Widget row(
      String label,
      SelahConceptAccountAction action, {
      String? value,
    }) => _SettingsRow(
      key: ValueKey('concept_settings_${action.name}'),
      label: label,
      value: value,
      smooth: smooth,
      onTap: () => onAction(action),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: smooth
            ? null
            : Text('Settings', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
        automaticallyImplyLeading: false,
        leading: showBackButton ? BackButton(onPressed: onBack) : null,
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('concept-current-settings-scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
          children: [
            if (smooth) ...[
              const SizedBox(height: 38),
              _SettingsReveal(
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
            _SettingsReveal(
              enabled: smooth,
              child: _SettingsSummary(data: data),
            ),
            const SizedBox(height: 28),
            _SettingsSection(
              title: 'ACCOUNT',
              smooth: smooth,
              children: [
                row(
                  'Sign-in & security',
                  SelahConceptAccountAction.signInSecurity,
                  value: data.signedInWith,
                ),
                row(
                  'App lock',
                  SelahConceptAccountAction.appLock,
                  value: data.appLock ? 'On' : 'Off',
                ),
                row('Advanced', SelahConceptAccountAction.advanced),
              ],
            ),
            _SettingsSection(
              title: 'PRIVACY',
              smooth: smooth,
              children: data.shepherd
                  ? [
                      row(
                        'Shepherd privacy',
                        SelahConceptAccountAction.shepherdPrivacy,
                        value: 'Not discoverable',
                      ),
                    ]
                  : [
                      row(
                        'Discovery & visibility',
                        SelahConceptAccountAction.visibility,
                      ),
                      row(
                        'Hidden Profiles',
                        SelahConceptAccountAction.hiddenProfiles,
                      ),
                    ],
            ),
            _SettingsSection(
              title: 'NOTIFICATIONS',
              smooth: smooth,
              children: [
                row(
                  'Notifications & emails',
                  SelahConceptAccountAction.notificationSettings,
                ),
              ],
            ),
            _SettingsSection(
              title: 'MEMBERSHIP',
              smooth: smooth,
              children: [
                row(
                  'Membership',
                  SelahConceptAccountAction.membership,
                  value: data.membership,
                ),
              ],
            ),
            _SettingsSection(
              title: 'SUPPORT',
              smooth: smooth,
              children: [
                row('Help & support', SelahConceptAccountAction.helpSupport),
                row('Send feedback', SelahConceptAccountAction.feedback),
              ],
            ),
            _SettingsSection(
              title: 'LEGAL',
              smooth: smooth,
              children: [
                row('Privacy & data', SelahConceptAccountAction.privacyData),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SelahWordmark(),
                  if (data.versionLine != null) ...[
                    const SizedBox(height: 3),
                    SelectableText(
                      data.versionLine!,
                      style: SelahText.subtext(
                        size: 11,
                        color: SelahColors.ink(0.24),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UpgradeScreen's current management hierarchy and catalogue. Basket callbacks
/// are local prototype callbacks only; no receipt/payment flow is imported.
class SelahConceptMembershipPresentation extends StatelessWidget {
  const SelahConceptMembershipPresentation({
    super.key,
    required this.data,
    required this.onAction,
    required this.onProductSelected,
    required this.onBack,
    this.showBackButton = true,
    this.storeName = 'App Store',
    this.simplifiedMethodology = false,
  });

  final SelahConceptAccountData data;
  final SelahConceptAccountActionCallback onAction;
  final ValueChanged<SelahMembershipProduct> onProductSelected;
  final VoidCallback onBack;
  final bool showBackButton;
  final String storeName;
  final bool simplifiedMethodology;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(showBackButton ? 8 : 20, 8, 20, 0),
            child: Row(
              children: [
                if (showBackButton)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back,
                      color: SelahColors.foregroundSecondary,
                    ),
                  ),
                Expanded(
                  child: Text('Membership', style: SelahText.heading(size: 18)),
                ),
                _BasketButton(
                  count: data.basketCount,
                  onTap: () => onAction(SelahConceptAccountAction.basket),
                ),
              ],
            ),
          ),
          Expanded(
            child: SelahFadeEdges.bottomOnly(
              bottom: 30,
              child: ListView(
                key: const ValueKey('concept-current-membership-scroll'),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 64),
                children: [
                  Text(
                    'Current membership',
                    style: SelahText.heading(size: 25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your plan, family places and billing controls in one place.',
                    style: SelahText.subtext(size: 12.5),
                  ),
                  const SizedBox(height: 18),
                  _CurrentMembershipCard(
                    product: data.currentProduct,
                    basicPreview: !data.isOne,
                  ),
                  const SizedBox(height: 30),
                  const _MembershipSectionHeading(
                    eyebrow: 'MEMBERSHIPS',
                    title: 'Choose the access you need',
                    subtitle:
                        'Choose Basic with a one-time joining fee or One with a monthly subscription. Review your choice before continuing.',
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < SelahMembershipCatalog.products.length;
                    index++
                  ) ...[
                    _MembershipPlanCard(
                      product: SelahMembershipCatalog.products[index],
                      features: _membershipFeatures(
                        SelahMembershipCatalog.products[index],
                        simplifiedMethodology: simplifiedMethodology,
                      ),
                      current:
                          data.currentProduct ==
                          SelahMembershipCatalog.products[index],
                      selected: data.selectedProducts.contains(
                        SelahMembershipCatalog.products[index],
                      ),
                      onAdd:
                          data.currentProduct ==
                              SelahMembershipCatalog.products[index]
                          ? null
                          : () => onProductSelected(
                              SelahMembershipCatalog.products[index],
                            ),
                    ),
                    if (index < SelahMembershipCatalog.products.length - 1)
                      const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 30),
                  const SelahFamilyPricingCard(
                    key: ValueKey('concept_membership_family'),
                  ),
                  const SizedBox(height: 24),
                  _MembershipAction(
                    key: const ValueKey('concept_compatibility'),
                    icon: Icons.insights_outlined,
                    title: 'Compatibility Unlocks',
                    detail:
                        'Compatibility Unlock is separate from your membership.',
                    onTap: () =>
                        onAction(SelahConceptAccountAction.compatibilityStore),
                  ),
                  const SizedBox(height: 26),
                  const _MembershipSectionLabel('IMPORTANT DETAILS'),
                  const SizedBox(height: 10),
                  const _MembershipInfoTile(
                    title: 'Membership terms',
                    body:
                        '${SelahMembershipCatalog.basicTerms}\n\n${SelahMembershipCatalog.shepherdBasicTerms}\n\n${SelahMembershipCatalog.trialTerms}\n\n${SelahMembershipCatalog.availability}\n\nUsing both experiences does not make you your own Shepherd. Shepherd permissions and romantic exclusions still apply.\n\nBlocking, reporting, privacy and account controls do not require a subscription. Membership changes do not erase Shepherd links or Journey history.',
                  ),
                  if (data.isOne) ...[
                    const SizedBox(height: 34),
                    const _MembershipSectionLabel('MANAGE BILLING'),
                    const SizedBox(height: 10),
                    _MembershipAction(
                      key: const ValueKey('concept_cancel_membership'),
                      icon: Icons.cancel_outlined,
                      title: 'Cancel membership',
                      detail: data.shepherd
                          ? 'If billed to you, manage or cancel securely in $storeName.'
                          : 'Turn off renewal securely in $storeName.',
                      destructive: true,
                      onTap: () =>
                          onAction(SelahConceptAccountAction.cancelMembership),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: SelahText.chapterLabel(color: SelahColors.ink(0.54)));
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
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

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 34, color: SelahColors.ink(0.10));
}

class _ProfileSettingsRow extends StatelessWidget {
  const _ProfileSettingsRow({
    super.key,
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: SelahText.body(size: 13.5, color: SelahColors.foreground),
            ),
          ),
          Icon(Icons.chevron_right, color: SelahColors.ink(0.24), size: 16),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.shepherd = false,
  });
  final String label;
  final String value;
  final bool shepherd;
  @override
  Widget build(BuildContext context) => Padding(
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
            style: SelahText.body(
              size: 13,
              color: shepherd ? SelahColors.foreground : SelahColors.foreground,
            ),
          ),
        ),
      ],
    ),
  );
}

class _UnlockBalance extends StatelessWidget {
  const _UnlockBalance({
    required this.standard,
    required this.plus,
    required this.onBuyMore,
  });
  final int? standard;
  final int? plus;
  final VoidCallback onBuyMore;
  Widget count(String label, int? value) => Text.rich(
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
  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('concept_compatibility'),
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
                  style: SelahText.body(
                    size: 14,
                    color: SelahColors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  runSpacing: 5,
                  children: [
                    count('Unlocks', plus),
                    if (standard != null && standard! > 0)
                      count('Earlier overall credits', standard),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: const ValueKey('concept_compatibility_buy_more'),
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

class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({required this.data});
  final SelahConceptAccountData data;
  Widget line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: SelahText.subtext(size: 13, color: SelahColors.ink(0.54)),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SelahText.body(size: 14, color: SelahColors.foreground),
          ),
        ),
      ],
    ),
  );
  Widget divider() => Container(
    height: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 3),
    color: SelahColors.foreground.withValues(alpha: 0.08),
  );
  @override
  Widget build(BuildContext context) {
    final smooth = data.smoothSettings;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: smooth ? 20 : 18,
        vertical: smooth ? 22 : 18,
      ),
      decoration: BoxDecoration(
        color: SelahColors.foreground.withValues(alpha: smooth ? .11 : .09),
        borderRadius: BorderRadius.circular(
          smooth ? 24 : SelahCardMetrics.cardRadius,
        ),
        border: Border.all(
          color: smooth
              ? SelahColors.unlockText.withValues(alpha: .28)
              : SelahColors.foreground.withValues(alpha: .14),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          if (smooth) ...[
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
          line('Membership', data.membership),
          divider(),
          line(
            data.shepherd ? 'Linked Seekers' : 'Shepherds',
            data.shepherd ? data.linkedSeekers : data.shepherdCount,
          ),
          divider(),
          line('Signed in with', data.signedInWith),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    required this.smooth,
  });
  final String title;
  final List<Widget> children;
  final bool smooth;
  @override
  Widget build(BuildContext context) => _SettingsReveal(
    enabled: smooth,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          SizedBox(height: smooth ? 12 : 10),
          Container(
            decoration: BoxDecoration(
              color: SelahColors.foreground.withValues(
                alpha: smooth ? .085 : .05,
              ),
              borderRadius: BorderRadius.circular(
                smooth ? 23 : SelahCardMetrics.cardRadius,
              ),
              border: Border.all(
                color: SelahColors.foreground.withValues(
                  alpha: smooth ? .16 : .10,
                ),
                width: 0.5,
              ),
            ),
            clipBehavior: smooth ? Clip.antiAlias : Clip.none,
            child: Column(children: children),
          ),
        ],
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.label,
    required this.onTap,
    required this.smooth,
    this.value,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool smooth;
  IconData get icon => switch (label) {
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
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: smooth ? 18 : 16,
          vertical: smooth ? 17 : 15,
        ),
        child: Row(
          children: [
            if (smooth) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SelahColors.unlockText.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: SelahColors.unlockText),
              ),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Text(
                label,
                style: SelahText.body(size: 15, color: SelahColors.foreground),
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
              const SizedBox(width: 8),
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

class _SettingsReveal extends StatelessWidget {
  const _SettingsReveal({this.enabled = true, required this.child});
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

List<String> _membershipFeatures(
  SelahMembershipProduct product, {
  bool simplifiedMethodology = false,
}) =>
    simplifiedMethodology &&
        (product == SelahMembershipProduct.seekerOne ||
            product == SelahMembershipProduct.seekerBasic)
    ? [
        'Request a Journey without swiping',
        product == SelahMembershipProduct.seekerOne
            ? 'Up to three current Journeys in this preview'
            : 'One current Journey in this preview',
        'Compatibility opens through mutual reveal',
        'Linked Shepherd support',
        'Ended Journey history remains read-only',
        'Preview features only; no payment or entitlement change',
      ]
    : switch (product) {
        SelahMembershipProduct.seekerOne => [
          'One paid Seeker account',
          '14-day trial when eligible and verified',
          '${SelahEntitlements.one.active} Active Journeys',
          'Unlimited Potential Journeys and active Considers',
          '${SelahEntitlements.one.paused} Paused Journeys',
          '${SelahSeekerPlanLimits.one.savedProfiles} Saved profiles',
          'Up to ${SelahSeekerPlanLimits.one.linkedShepherds} linked Shepherds',
          'Ad-free experience',
        ],
        SelahMembershipProduct.seekerBasic => [
          'No monthly subscription after the one-time joining fee',
          '${SelahEntitlements.basic.active} Active Journey',
          '${SelahEntitlements.basic.potential} Potential Journeys',
          '${SelahEntitlements.basic.paused} Paused Journey',
          '${SelahSeekerPlanLimits.basic.savedProfiles} Saved profiles',
          '${SelahSeekerPlanLimits.basic.activeConsiders} active Considers · ${SelahSeekerPlanLimits.basic.dailyConsiders} per day',
          '${SelahSeekerBasicPolicy.swipeLimit} profile swipes every 4 hours',
          '${SelahSeekerPlanLimits.basic.linkedShepherds} linked Shepherd',
          'Insights and initiating Journey returns are not included',
          'Ad-supported plan; live adverts are not available in this build',
        ],
        SelahMembershipProduct.shepherdOne => const [
          'One paid Shepherd account',
          'View permitted Journeys',
          'Chat in permitted Journeys',
          'Shepherd Circle when every participant has paid access',
          'Shepherd Network discovery — coming soon',
        ],
        SelahMembershipProduct.shepherdBasic => const [
          'No monthly subscription after the one-time joining fee',
          'View permitted linked Journeys and Timeline',
          'Essential relationship, consent, Main Shepherd review and safety controls',
          'Conversation, compatibility answering and Network access are not included',
        ],
      };

class _MembershipSectionLabel extends StatelessWidget {
  const _MembershipSectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: SelahText.chapterLabel(color: SelahColors.foregroundMuted),
  );
}

class _MembershipSectionHeading extends StatelessWidget {
  const _MembershipSectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _MembershipSectionLabel(eyebrow),
      const SizedBox(height: 7),
      Text(title, style: SelahText.heading(size: 19)),
      const SizedBox(height: 4),
      Text(subtitle, style: SelahText.subtext(size: 11.75)),
    ],
  );
}

class _BasketButton extends StatelessWidget {
  const _BasketButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count == 0 ? 'Basket, empty' : 'Basket, $count items',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('concept_membership_basket'),
          tooltip: 'Basket',
          onPressed: onTap,
          icon: const Icon(Icons.shopping_bag_outlined),
          color: SelahColors.foregroundSecondary,
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: SelahColors.journeyGold,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: SelahColors.mentorSheetBg,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: SelahText.button(
                  size: 9,
                  color: SelahColors.onPrimaryAction,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CurrentMembershipCard extends StatelessWidget {
  const _CurrentMembershipCard({
    required this.product,
    this.basicPreview = false,
  });
  final SelahMembershipProduct product;
  final bool basicPreview;
  bool get one =>
      product == SelahMembershipProduct.seekerOne ||
      product == SelahMembershipProduct.shepherdOne;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('concept_membership_current'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: SelahColors.surfaceEmphasisFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius + 4),
      border: Border.all(
        color: one
            ? SelahColors.journeyGold.withValues(alpha: 0.44)
            : SelahColors.surfaceEmphasisBorder,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: one
                ? SelahColors.journeyGold.withValues(alpha: 0.13)
                : SelahColors.iconButtonBg,
          ),
          child: Icon(
            one
                ? Icons.workspace_premium_outlined
                : Icons.person_outline_rounded,
            color: one
                ? SelahColors.journeyGold
                : SelahColors.foregroundSecondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CURRENT',
                style: SelahText.chapterLabel(
                  color: one
                      ? SelahColors.journeyGold
                      : SelahColors.foregroundMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product == SelahMembershipProduct.shepherdOne
                    ? 'Shepherd access active'
                    : one
                    ? SelahMembershipCatalog.title(product)
                    : basicPreview
                    ? '${SelahMembershipCatalog.title(product)} · Preview'
                    : 'No active membership',
                style: SelahText.heading(size: 18),
              ),
              const SizedBox(height: 3),
              Text(
                product == SelahMembershipProduct.shepherdOne
                    ? 'Included or separately subscribed. Check your billing provider for payment details.'
                    : one
                    ? SelahMembershipCatalog.price(product)
                    : basicPreview
                    ? 'Local rehearsal only. No joining fee has been paid.'
                    : 'Choose a membership. A signup choice is not payment confirmation.',
                style: SelahText.subtext(size: 12.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MembershipAction extends StatelessWidget {
  const _MembershipAction({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? SelahColors.negativeRed
        : SelahColors.foregroundSecondary;
    return Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
            border: Border.all(
              color: accent.withValues(alpha: destructive ? 0.34 : 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SelahText.body(size: 14, color: accent)),
                    const SizedBox(height: 3),
                    Text(detail, style: SelahText.subtext(size: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: SelahColors.foregroundMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipPlanCard extends StatelessWidget {
  const _MembershipPlanCard({
    required this.product,
    required this.features,
    required this.current,
    required this.selected,
    required this.onAdd,
  });
  final SelahMembershipProduct product;
  final List<String> features;
  final bool current;
  final bool selected;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('concept_plan_${product.name}'),
    color: SelahColors.surfaceFill,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      side: BorderSide(
        color: current
            ? SelahColors.journeyGold.withValues(alpha: 0.35)
            : SelahColors.surfaceBorder,
      ),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('concept_membership_plan_${product.name}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: SelahColors.foregroundSecondary,
        collapsedIconColor: SelahColors.foregroundMuted,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SelahColors.journeyGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                product == SelahMembershipProduct.seekerOne ||
                        product == SelahMembershipProduct.seekerBasic
                    ? Icons.person_outline_rounded
                    : Icons.shield_outlined,
                size: 18,
                color: SelahColors.journeyGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                SelahMembershipCatalog.title(product),
                style: SelahText.body(size: 14),
              ),
            ),
            _AddToBasketButton(
              current: current,
              selected: selected,
              onTap: onAdd,
              label: SelahMembershipCatalog.title(product),
            ),
          ],
        ),
        subtitle: Text(
          current
              ? '${SelahMembershipCatalog.price(product)} · Current'
              : SelahMembershipCatalog.price(product),
          style: SelahText.subtext(size: 11.5),
        ),
        children: [
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: SelahColors.journeyGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: SelahText.subtext(size: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _AddToBasketButton extends StatelessWidget {
  const _AddToBasketButton({
    required this.current,
    required this.selected,
    required this.onTap,
    required this.label,
  });
  final bool current;
  final bool selected;
  final VoidCallback? onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    final active = current || selected;
    return Tooltip(
      message: current
          ? '$label is current'
          : selected
          ? '$label is in your basket'
          : 'Add $label to basket',
      child: Semantics(
        button: !current,
        label: current
            ? '$label, current membership'
            : selected
            ? '$label, added to basket'
            : 'Add $label to basket',
        child: Material(
          color: active
              ? SelahColors.journeyGold.withValues(alpha: 0.18)
              : SelahColors.iconButtonBg,
          shape: CircleBorder(
            side: BorderSide(
              color: active
                  ? SelahColors.journeyGold.withValues(alpha: 0.58)
                  : SelahColors.iconButtonBorder,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 38,
              child: Center(
                child: Transform.translate(
                  offset: active ? const Offset(1, 1) : Offset.zero,
                  child: Icon(
                    active
                        ? Icons.check_rounded
                        : Icons.add_shopping_cart_outlined,
                    size: 19,
                    color: active
                        ? SelahColors.journeyGold
                        : SelahColors.foregroundSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipInfoTile extends StatelessWidget {
  const _MembershipInfoTile({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.surfaceFill,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      side: BorderSide(color: SelahColors.surfaceBorder),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('concept_membership_info_$title'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: SelahColors.foregroundSecondary,
        collapsedIconColor: SelahColors.foregroundMuted,
        title: Text(title, style: SelahText.body(size: 14)),
        children: [Text(body, style: SelahText.subtext(size: 12))],
      ),
    ),
  );
}
