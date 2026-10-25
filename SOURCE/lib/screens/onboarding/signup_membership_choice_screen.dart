import 'package:flutter/material.dart';

import '../../data/selah_membership_catalog.dart';
import '../../models/selah_signup_membership_choice.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/onboarding_scaffold.dart';

/// The account flow owns saving and navigation. Choosing a card never grants
/// membership, begins a trial, charges a fee or marks identity as verified.
class SignupMembershipChoiceScreen extends StatelessWidget {
  const SignupMembershipChoiceScreen({
    super.key,
    required this.role,
    required this.choice,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
    this.background = SelahBackgroundVariant.neutral,
    this.saving = false,
    this.error,
    this.devPreview = false,
    this.onDevSkip,
    this.expectedUserId,
  });

  final SelahSignupRole role;
  final SelahSignupMembershipChoice? choice;
  final ValueChanged<SelahSignupMembershipChoice> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final SelahBackgroundVariant background;
  final bool saving;
  final String? error;
  final bool devPreview;
  final VoidCallback? onDevSkip;
  final String? expectedUserId;

  bool get _shepherd => role == SelahSignupRole.shepherd;

  // Founder-requested offer comparison, not an active StoreKit product. Keep
  // ordinary pricing/trial copy intact until the trial/eligibility decision and
  // exact commerce activation are approved. The flow supplies protected preview.
  bool get _introOfferPreview => devPreview && !_shepherd;
  // Family's requested comparison applies to both signup roles. Ordinary
  // commerce stays unchanged, just as for the protected Seeker One offer.
  bool get _familyIntroOfferPreview => devPreview;
  static const _previewIntroMonthPence = 499;

  void _select(SelahSignupMembershipKind kind) {
    if (saving || choice?.kind == kind) return;
    onChanged(
      SelahSignupMembershipChoice(
        kind: kind,
        seekers: kind == SelahSignupMembershipKind.family && !_shepherd ? 1 : 0,
        shepherds: kind == SelahSignupMembershipKind.family && _shepherd ? 1 : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final one = _shepherd
        ? SelahMembershipProduct.shepherdOne
        : SelahMembershipProduct.seekerOne;
    final basic = _shepherd
        ? SelahMembershipProduct.shepherdBasic
        : SelahMembershipProduct.seekerBasic;
    return OnboardingScaffold(
      key: const ValueKey('signup_membership_choice'),
      background: background,
      chapterName: 'Membership',
      chapterProgress: choice == null ? 0 : 1,
      progressLabel: 'YOUR MEMBERSHIP CHOICE',
      question: 'Choose how to join',
      subtext:
          error ??
          (_introOfferPreview
              ? 'Basic or your first month of One — both start at £4.99.'
              : 'Choose the membership that suits your journey.'),
      frameContent: false,
      fabActive: !saving && choice?.isValidFor(role) == true,
      onContinue: onContinue,
      onSwipeBack: saving ? null : onBack,
      devPreview: devPreview,
      onDevSkip: saving ? null : onDevSkip,
      devSkipLabel: 'Skip',
      showAccountExit: true,
      accountExitExpectedUserId: expectedUserId,
      continueActionKey: const ValueKey('signup_membership_continue'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceCard(
            key: const ValueKey('signup_membership_basic'),
            icon: Icons.person_outline_rounded,
            title: SelahMembershipCatalog.title(basic),
            price:
                '${SelahMembershipCatalog.pounds(SelahMembershipCatalog.basicJoiningPence)} once',
            detail: 'Joining and verification. No monthly subscription.',
            selected: choice?.kind == SelahSignupMembershipKind.basic,
            onTap: saving
                ? null
                : () => _select(SelahSignupMembershipKind.basic),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            key: const ValueKey('signup_membership_one'),
            icon: Icons.workspace_premium_outlined,
            title: SelahMembershipCatalog.title(one),
            price: _introOfferPreview
                ? '${SelahMembershipCatalog.pounds(_previewIntroMonthPence)} first month'
                : SelahMembershipCatalog.price(one),
            badge: _introOfferPreview
                ? (choice?.kind == SelahSignupMembershipKind.basic
                      ? 'Same starting price as Basic'
                      : 'First month offer')
                : null,
            renewal: _introOfferPreview
                ? 'Then ${SelahMembershipCatalog.pounds(SelahMembershipCatalog.seekerOneMonthlyPence)}/month. Cancel renewal anytime.'
                : null,
            detail: _introOfferPreview
                ? '3 Active Journeys. Joining and verification included.'
                : _shepherd
                ? 'Monthly access to Shepherd One features.'
                : 'Monthly access to Seeker One features. A 14-day trial when eligible.',
            action:
                _introOfferPreview &&
                    choice?.kind == SelahSignupMembershipKind.basic
                ? FilledButton(
                    key: const ValueKey('signup_membership_try_one'),
                    onPressed: saving
                        ? null
                        : () => _select(SelahSignupMembershipKind.one),
                    style: FilledButton.styleFrom(
                      foregroundColor: SelahColors.luxuryDarkPurple,
                      backgroundColor: SelahColors.journeyGold,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      textStyle: SelahText.body(size: 13),
                    ),
                    child: const Text(
                      'Try Seeker One for £4.99',
                      textAlign: TextAlign.center,
                    ),
                  )
                : null,
            selected: choice?.kind == SelahSignupMembershipKind.one,
            onTap: saving ? null : () => _select(SelahSignupMembershipKind.one),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            key: const ValueKey('signup_membership_family'),
            icon: Icons.groups_outlined,
            title: 'SELAH Family',
            price: _familyIntroOfferPreview
                ? '${SelahMembershipCatalog.pounds(SelahMembershipCatalog.familyIntroMonthPerPlacePence)} per person for the first month'
                : 'Monthly places for Seekers and Shepherds',
            emphasizePrice: _familyIntroOfferPreview,
            renewal: _familyIntroOfferPreview
                ? 'Then your chosen Family plan renews monthly. Cancel renewal anytime.'
                : null,
            renewalKey: const ValueKey('signup_membership_family_renewal'),
            detail: 'Choose the One places you need, including your own role.',
            selected: choice?.kind == SelahSignupMembershipKind.family,
            onTap: saving
                ? null
                : () => _select(SelahSignupMembershipKind.family),
          ),
          if (choice?.kind == SelahSignupMembershipKind.family) ...[
            const SizedBox(height: 16),
            _familyEstimate(),
          ],
          const SizedBox(height: 18),
          Text(
            _introOfferPreview || _familyIntroOfferPreview
                ? 'Offer design preview only. No payment or subscription starts here.'
                : 'This saves your choice only. Checkout is not available in this build; no payment will be taken and no trial or paid access starts here.',
            style: SelahText.subtext(size: 12.5),
          ),
          if (choice?.kind == SelahSignupMembershipKind.one &&
              !_shepherd &&
              !_introOfferPreview) ...[
            const SizedBox(height: 12),
            Text(
              SelahMembershipCatalog.trialTerms,
              style: SelahText.subtext(size: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _familyEstimate() {
    final selected = choice!;
    final quote = SelahMembershipCatalog.familyQuote(
      selected.seekers,
      selected.shepherds,
    );
    void change(bool seeker, int delta) {
      if (saving) return;
      onChanged(
        SelahSignupMembershipChoice(
          kind: SelahSignupMembershipKind.family,
          seekers: selected.seekers + (seeker ? delta : 0),
          shepherds: selected.shepherds + (seeker ? 0 : delta),
        ),
      );
    }

    return Container(
      key: const ValueKey('signup_membership_family_estimate'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surfaceEmphasisFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SelahColors.journeyGold.withValues(alpha: .32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Include one ${_shepherd ? 'Shepherd' : 'Seeker'} place for you.',
            style: SelahText.subtext(size: 12.5),
          ),
          const SizedBox(height: 10),
          for (final seeker in [true, false])
            Row(
              children: [
                Expanded(
                  child: Text(
                    seeker ? 'Seeker One' : 'Shepherd One',
                    style: SelahText.body(size: 14),
                  ),
                ),
                IconButton(
                  key: ValueKey(
                    'signup_family_${seeker ? 'seekers' : 'shepherds'}_remove',
                  ),
                  tooltip: 'Remove ${seeker ? 'Seeker' : 'Shepherd'} place',
                  onPressed:
                      saving ||
                          (seeker ? selected.seekers : selected.shepherds) <=
                              (seeker == !_shepherd ? 1 : 0)
                      ? null
                      : () => change(seeker, -1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text(
                  '${seeker ? selected.seekers : selected.shepherds}',
                  key: ValueKey(
                    'signup_family_${seeker ? 'seekers' : 'shepherds'}_count',
                  ),
                  style: SelahText.body(size: 16),
                ),
                IconButton(
                  key: ValueKey(
                    'signup_family_${seeker ? 'seekers' : 'shepherds'}_add',
                  ),
                  tooltip: 'Add ${seeker ? 'Seeker' : 'Shepherd'} place',
                  onPressed:
                      saving ||
                          (seeker ? selected.seekers : selected.shepherds) >= 10
                      ? null
                      : () => change(seeker, 1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (_familyIntroOfferPreview) ...[
            Text(
              '${SelahMembershipCatalog.pounds(quote.introFirstMonthPence)} first month total',
              key: const ValueKey('signup_family_first_month_total'),
              style: SelahText.body(size: 18, color: SelahColors.journeyGold),
            ),
            Text(
              '${quote.members} ${quote.members == 1 ? 'person' : 'people'} × ${SelahMembershipCatalog.pounds(SelahMembershipCatalog.familyIntroMonthPerPlacePence)}',
              key: const ValueKey('signup_family_first_month_calculation'),
              style: SelahText.subtext(size: 12.5),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            _familyIntroOfferPreview
                ? 'Then ${SelahMembershipCatalog.pounds(quote.formulaMonthlyPence)} / month estimate'
                : '${SelahMembershipCatalog.pounds(quote.formulaMonthlyPence)} / month estimate',
            key: const ValueKey('signup_family_monthly_estimate'),
            style: SelahText.body(size: 16, color: SelahColors.journeyGold),
          ),
          Text(
            _familyIntroOfferPreview
                ? '${quote.discountPercent}% saving on monthly renewals across ${quote.members} places.'
                : '${quote.discountPercent}% saving across ${quote.members} places.',
            style: SelahText.subtext(size: 12.5),
          ),
          const SizedBox(height: 10),
          Text(
            'The App Store will show the exact local price before purchase. Family has no trial; selecting places does not invite or link anyone.',
            style: SelahText.subtext(size: 12),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.price,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.badge,
    this.renewal,
    this.renewalKey = const ValueKey('signup_membership_renewal'),
    this.action,
    this.emphasizePrice = true,
  });

  final IconData icon;
  final String title;
  final String price;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;
  final String? badge;
  final String? renewal;
  final Key renewalKey;
  final Widget? action;
  final bool emphasizePrice;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected
          ? SelahColors.surfaceEmphasisFill
          : SelahColors.iconButtonBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? SelahColors.journeyGold.withValues(alpha: .7)
              : SelahColors.iconButtonBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: SelahColors.journeyGold, size: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: SelahText.heading(size: 19)),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.check_circle_outline_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? SelahColors.journeyGold
                        : SelahColors.foregroundMuted,
                    size: 20,
                  ),
                ],
              ),
              if (badge != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const ValueKey('signup_membership_offer_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SelahColors.journeyGold.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: SelahText.body(
                        size: 11,
                        color: SelahColors.journeyGold,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                price,
                style: SelahText.body(
                  size: emphasizePrice ? 18 : 14,
                  color: SelahColors.journeyGold,
                ),
              ),
              if (renewal != null) ...[
                const SizedBox(height: 5),
                Text(
                  renewal!,
                  key: renewalKey,
                  style: SelahText.body(size: 12.5),
                ),
              ],
              const SizedBox(height: 7),
              Text(detail, style: SelahText.subtext(size: 13)),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    ),
  );
}
