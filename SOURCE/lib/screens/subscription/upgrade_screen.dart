// The historical route name remains compatible with callers. This page is
// the truthful membership control centre: it shows current access, explains
// available plans, and hands store-owned changes to the App Store / Play
// subscription centre. It never mutates an entitlement locally.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/selah_entitlements.dart';
import '../../data/selah_membership_catalog.dart';
import '../../data/selah_seeker_basic_policy.dart';
import '../../data/selah_seeker_plan_limits.dart';
import '../../models/selah_signup_membership_choice.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_initial_signup_draft_service.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_product_telemetry.dart';
import '../../state/app_state.dart';
import '../../theme/selah_card_metrics.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_fade_edges.dart';
import '../../widgets/selah_family_pricing_card.dart';

typedef MembershipStoreLauncher = Future<bool> Function(Uri uri);

class UpgradeScreen extends StatefulWidget {
  final SelahTelemetrySurface telemetrySurface;
  final MembershipStoreLauncher? openStore;
  final TargetPlatform? storePlatform;
  final bool compatibilityOnly;

  const UpgradeScreen({
    super.key,
    this.telemetrySurface = SelahTelemetrySurface.seeker,
    this.openStore,
    this.storePlatform,
  }) : compatibilityOnly = false;

  const UpgradeScreen._compatibilityStore({
    this.telemetrySurface = SelahTelemetrySurface.seeker,
  }) : openStore = null,
       storePlatform = null,
       compatibilityOnly = true;

  static final appleSubscriptionsUri = Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  );
  static final playSubscriptionsUri = Uri.parse(
    'https://play.google.com/store/account/subscriptions',
  );

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

/// The one purchase destination for Compatibility Unlock credits.
/// Membership remains discoverable separately and never acts as an indirect
/// scroll-to route for these one-off purchases.
class CompatibilityUnlockStoreScreen extends StatelessWidget {
  final SelahTelemetrySurface telemetrySurface;

  const CompatibilityUnlockStoreScreen({
    super.key,
    this.telemetrySurface = SelahTelemetrySurface.seeker,
  });

  @override
  Widget build(BuildContext context) =>
      UpgradeScreen._compatibilityStore(telemetrySurface: telemetrySurface);
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final Map<String, int> _basket = <String, int>{};
  Timer? _basketConfirmationTimer;
  SelahSignupMembershipIntent? _signupChoice;
  String? _signupChoiceOwner;
  int? _signupChoiceGeneration;
  bool _signupChoiceUnavailable = false;

  bool get _shepherd =>
      widget.telemetrySurface == SelahTelemetrySurface.shepherd;

  bool get _isOne => _shepherd
      ? AppState.instance.mentorHasMentorOne
      : AppState.instance.plan == SelahPlan.one;

  SelahMembershipProduct get _currentProduct => switch ((_shepherd, _isOne)) {
    (false, false) => SelahMembershipProduct.seekerBasic,
    (false, true) => SelahMembershipProduct.seekerOne,
    (true, false) => SelahMembershipProduct.shepherdBasic,
    (true, true) => SelahMembershipProduct.shepherdOne,
  };

  List<SelahMembershipProduct> get _roleProducts =>
      SelahMembershipCatalog.products;

  _MembershipOffer _offerFor(String id) =>
      _membershipOffers.singleWhere((offer) => offer.id == id);

  _MembershipOffer _offerForProduct(SelahMembershipProduct product) =>
      _membershipOffers.singleWhere((offer) => offer.product == product);

  bool _isCurrentProduct(SelahMembershipProduct product) =>
      !_shepherd && _isOne && product == _currentProduct;

  TargetPlatform get _storePlatform =>
      widget.storePlatform ?? defaultTargetPlatform;

  Uri get _storeUri => switch (_storePlatform) {
    TargetPlatform.android => UpgradeScreen.playSubscriptionsUri,
    _ => UpgradeScreen.appleSubscriptionsUri,
  };

  String get _storeName =>
      _storePlatform == TargetPlatform.android ? 'Google Play' : 'App Store';

  @override
  void initState() {
    super.initState();
    if (!widget.compatibilityOnly) unawaited(_loadSignupChoice());
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.membership,
      name: SelahTelemetryEventName.opened,
      action: SelahTelemetryAction.pageView,
      surface: widget.telemetrySurface,
    );
  }

  bool get _ownsSignupChoice =>
      !SelahInternalPreviewClient.isActive &&
      _signupChoiceOwner != null &&
      _signupChoiceGeneration != null &&
      SelahAccountState.isCurrent(_signupChoiceOwner!, _signupChoiceGeneration!);

  Future<void> _loadSignupChoice() async {
    final owner = SelahAccountState.userId;
    if (owner == null ||
        !SelahInitialSignupDraftService.supportedOnThisPlatform ||
        SelahInternalPreviewClient.isActive) {
      return;
    }
    final generation = SelahAccountState.generation;
    try {
      final intent = await SelahInitialSignupDraftService.readMembershipIntent(
        expectedUserId: owner,
      ).timeout(const Duration(seconds: 8));
      if (!mounted ||
          !SelahAccountState.isCurrent(owner, generation) ||
          SelahInternalPreviewClient.isActive) {
        return;
      }
      setState(() {
        _signupChoiceOwner = owner;
        _signupChoiceGeneration = generation;
        _signupChoice = intent;
        _signupChoiceUnavailable = false;
      });
    } catch (_) {
      if (!mounted ||
          !SelahAccountState.isCurrent(owner, generation) ||
          SelahInternalPreviewClient.isActive) {
        return;
      }
      setState(() {
        _signupChoiceOwner = owner;
        _signupChoiceGeneration = generation;
        _signupChoice = null;
        _signupChoiceUnavailable = true;
      });
    }
  }

  Widget? _signupChoiceCard() {
    if (!_ownsSignupChoice) return null;
    if (_signupChoiceUnavailable) {
      return _MembershipAction(
        key: const ValueKey('membership-signup-choice-retry'),
        icon: Icons.refresh_rounded,
        title: 'Your signup choice could not be loaded',
        detail: 'Retry without changing your current membership.',
        onTap: () => unawaited(_loadSignupChoice()),
      );
    }
    final intent = _signupChoice;
    if (intent == null ||
        !intent.isValid ||
        intent.role !=
            (_shepherd ? SelahSignupRole.shepherd : SelahSignupRole.seeker)) {
      return null;
    }
    final choice = intent.choice;
    final product = switch ((_shepherd, choice.kind)) {
      (false, SelahSignupMembershipKind.basic) =>
        SelahMembershipProduct.seekerBasic,
      (true, SelahSignupMembershipKind.basic) =>
        SelahMembershipProduct.shepherdBasic,
      (false, SelahSignupMembershipKind.one) => SelahMembershipProduct.seekerOne,
      (true, SelahSignupMembershipKind.one) => SelahMembershipProduct.shepherdOne,
      (_, SelahSignupMembershipKind.family) => null,
    };
    final description = product == null
        ? 'SELAH Family · ${choice.seekers} Seeker and ${choice.shepherds} Shepherd places\n'
              '${SelahMembershipCatalog.pounds(SelahMembershipCatalog.familyQuote(choice.seekers, choice.shepherds).formulaMonthlyPence)} / month estimated'
        : '${SelahMembershipCatalog.title(product)} · ${SelahMembershipCatalog.price(product)}';
    return Container(
      key: const ValueKey('membership-signup-choice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your signup choice', style: SelahText.body(size: 14)),
          const SizedBox(height: 6),
          Text(description, style: SelahText.subtext(size: 12.5)),
          const SizedBox(height: 7),
          Text(
            'Saved as a preference only. No payment, trial or membership has been activated by this choice.',
            style: SelahText.subtext(size: 11.5),
          ),
        ],
      ),
    );
  }

  int get _basketCount => _basket.values.fold(0, (sum, value) => sum + value);

  int get _basketTotalPence => _basket.entries.fold(
    0,
    (sum, entry) => sum + _offerFor(entry.key).pricePence * entry.value,
  );

  void _addToBasket(_MembershipOffer offer) {
    setState(() {
      if (offer.product != null) {
        // Basic is a membership choice too, although it is not recurring.
        // A basket never holds duplicate Basic fees or conflicting plans.
        _basket.removeWhere((id, _) => _offerFor(id).product != null);
        _basket[offer.id] = 1;
      } else {
        _basket.update(offer.id, (count) => count + 1, ifAbsent: () => 1);
      }
    });
    _basketConfirmationTimer?.cancel();
    final confirmation = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('${offer.title} added to your basket.'),
          action: SnackBarAction(label: 'View', onPressed: _showBasket),
        ),
      );
    _basketConfirmationTimer = Timer(
      const Duration(seconds: 3),
      confirmation.hideCurrentSnackBar,
    );
  }

  @override
  void dispose() {
    _basketConfirmationTimer?.cancel();
    super.dispose();
  }

  void _removeFromBasket(String id) {
    setState(() {
      final count = _basket[id] ?? 0;
      if (count <= 1) {
        _basket.remove(id);
      } else {
        _basket[id] = count - 1;
      }
    });
  }

  Future<void> _openStoreManagement() async {
    var opened = false;
    try {
      opened =
          await (widget.openStore?.call(_storeUri) ??
              launchUrl(_storeUri, mode: LaunchMode.externalApplication));
    } catch (error) {
      debugPrint(
        'SELAH subscription centre could not open (${error.runtimeType}).',
      );
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open $_storeName subscriptions. Open $_storeName and choose Subscriptions.',
        ),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: SelahColors.mentorSheetBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SelahColors.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel membership', style: SelahText.heading(size: 20)),
              const SizedBox(height: 10),
              Text(
                '$_storeName securely manages this change. It will show the effective date and ask you to confirm before anything changes. SELAH never removes your saved account data or Shepherd links because a membership changes.',
                style: SelahText.subtext(size: 12.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text('Not now', style: SelahText.button(size: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('membership-store-continue'),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text('Continue', style: SelahText.button(size: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (proceed == true && mounted) await _openStoreManagement();
  }

  Future<void> _showBasket() async {
    var checkoutUnavailable = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final entries = _basket.entries.toList(growable: false);
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              decoration: BoxDecoration(
                color: SelahColors.mentorSheetBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: SelahColors.surfaceBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SelahColors.ink(0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your basket',
                          style: SelahText.heading(size: 21),
                        ),
                      ),
                      Text(
                        '$_basketCount ${_basketCount == 1 ? 'item' : 'items'}',
                        style: SelahText.subtext(size: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: SelahColors.ink(0.42),
                            size: 31,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your basket is empty',
                            style: SelahText.body(size: 14),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: SelahColors.ink(0.10)),
                        itemBuilder: (_, index) {
                          final entry = entries[index];
                          final offer = _offerFor(entry.key);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  offer.icon,
                                  size: 20,
                                  color: SelahColors.journeyGold,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        offer.title,
                                        style: SelahText.body(size: 13),
                                      ),
                                      Text(
                                        entry.value == 1
                                            ? offer.price
                                            : '${entry.value} × ${offer.price}',
                                        style: SelahText.subtext(size: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('basket-remove-${offer.id}'),
                                  tooltip: 'Remove ${offer.title}',
                                  onPressed: () {
                                    _removeFromBasket(offer.id);
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: SelahColors.foregroundSecondary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Estimated total',
                            style: SelahText.body(size: 13),
                          ),
                        ),
                        Text(
                          SelahMembershipCatalog.pounds(_basketTotalPence),
                          key: ValueKey(
                            widget.compatibilityOnly
                                ? 'compatibility-basket-total'
                                : 'membership-basket-total',
                          ),
                          style: SelahText.heading(
                            size: 18,
                            color: SelahColors.journeyGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: ValueKey(
                        widget.compatibilityOnly
                            ? 'compatibility-basket-checkout'
                            : 'membership-basket-checkout',
                      ),
                      onPressed: () =>
                          setSheetState(() => checkoutUnavailable = true),
                      icon: const Icon(Icons.lock_outline_rounded, size: 18),
                      label: Text(
                        'Continue securely',
                        style: SelahText.button(size: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (checkoutUnavailable) ...[
                      Container(
                        key: ValueKey(
                          widget.compatibilityOnly
                              ? 'compatibility-checkout-unavailable'
                              : 'membership-checkout-unavailable',
                        ),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: SelahColors.surfaceEmphasisFill,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: SelahColors.surfaceBorder),
                        ),
                        child: Text(
                          widget.compatibilityOnly
                              ? 'Compatibility checkout is not available yet. No purchase has been made.'
                              : 'Membership checkout is not available yet. Your current membership has not changed.',
                          textAlign: TextAlign.center,
                          style: SelahText.subtext(size: 10.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'The App Store or Google Play will show the final price before any payment.',
                      textAlign: TextAlign.center,
                      style: SelahText.subtext(size: 10.5),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _compatibilitySection() => [
    Container(
      key: const ValueKey('compatibility-purchase-options'),
      child: const _SectionHeading(
        eyebrow: 'COMPATIBILITY UNLOCKS',
        title: 'Reveal more when you choose',
      ),
    ),
    const SizedBox(height: 16),
    const _CompatibilityGroupHeading(
      key: ValueKey('compatibility-unlock-group'),
      label: 'COMPATIBILITY UNLOCK',
      title: 'Compatibility Unlock',
      detail:
          'Your overall compatibility, deeper detail and Shepherd information.',
      icon: Icons.insights_outlined,
    ),
    const SizedBox(height: 9),
    for (final offer in _compatibilityOffers) ...[
      _CompatibilityOfferCard(
        offer: offer,
        quantity: _basket[offer.id] ?? 0,
        onAdd: () => _addToBasket(offer),
      ),
      if (offer != _compatibilityOffers.last) const SizedBox(height: 9),
    ],
  ];

  Widget _compatibilityStorePage(BuildContext context) => Scaffold(
    body: Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: SelahColors.foregroundSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Compatibility Unlocks',
                      style: SelahText.heading(size: 18),
                    ),
                  ),
                  _BasketButton(
                    count: _basketCount,
                    onTap: _showBasket,
                    keyPrefix: 'compatibility',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SelahFadeEdges.bottomOnly(
                bottom: 30,
                child: ListView(
                  key: const PageStorageKey('compatibility-purchases'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 64),
                  children: [
                    Text(
                      'Choose what to reveal',
                      style: SelahText.heading(size: 25),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Compatibility Unlock is a one-off purchase. It does not change your monthly membership.',
                      style: SelahText.subtext(size: 12.5),
                    ),
                    const SizedBox(height: 24),
                    ..._compatibilitySection(),
                    const SizedBox(height: 28),
                    _SectionLabel('IMPORTANT DETAILS'),
                    const SizedBox(height: 10),
                    _MembershipInfoTile(
                      title: 'Compatibility purchase terms',
                      body:
                          '${SelahMembershipCatalog.compatibilityTerms}\n\n${SelahMembershipCatalog.compatibilityPrices}\n\n${SelahMembershipCatalog.compatibilityAvailability}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => widget.compatibilityOnly
      ? _compatibilityStorePage(context)
      : Scaffold(
          body: Container(
            decoration: SelahAppGoldDecoration(
              gradient: SelahColors.genderGradient(AppState.instance.gender),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back,
                            color: SelahColors.foregroundSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Membership',
                            style: SelahText.heading(size: 18),
                          ),
                        ),
                        _BasketButton(count: _basketCount, onTap: _showBasket),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SelahFadeEdges.bottomOnly(
                      bottom: 30,
                      child: ListView(
                        key: const PageStorageKey('membership-management'),
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
                            product: _currentProduct,
                            basicPreview:
                                !_isOne &&
                                SelahInternalPreviewClient.isActive &&
                                SelahDeveloperAccess.canUseDeveloperTools,
                          ),
                          if (_signupChoiceCard() case final choiceCard?) ...[
                            const SizedBox(height: 12),
                            choiceCard,
                          ],
                          const SizedBox(height: 30),
                          _SectionHeading(
                            eyebrow: 'MEMBERSHIPS',
                            title: 'Choose the access you need',
                            subtitle:
                                'Choose Basic with a one-time joining fee or One with a monthly subscription. Review your choice before continuing.',
                          ),
                          const SizedBox(height: 10),
                          for (
                            var index = 0;
                            index < _roleProducts.length;
                            index++
                          ) ...[
                            _MembershipPlanCard(
                              product: _roleProducts[index],
                              features: _features(_roleProducts[index]),
                              current: _isCurrentProduct(_roleProducts[index]),
                              selected:
                                  _basket[_offerForProduct(
                                    _roleProducts[index],
                                  ).id] ==
                                  1,
                              onAdd: _isCurrentProduct(_roleProducts[index])
                                  ? null
                                  : () => _addToBasket(
                                      _offerForProduct(_roleProducts[index]),
                                    ),
                            ),
                            if (index < _roleProducts.length - 1)
                              const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 30),
                          const SelahFamilyPricingCard(
                            key: ValueKey('membership-family'),
                          ),
                          const SizedBox(height: 24),
                          _MembershipAction(
                            key: const ValueKey(
                              'membership-compatibility-store',
                            ),
                            icon: Icons.insights_outlined,
                            title: 'Compatibility Unlocks',
                            detail:
                                'Buy Compatibility Unlocks separately from your membership.',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CompatibilityUnlockStoreScreen(
                                  telemetrySurface: widget.telemetrySurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SectionLabel('IMPORTANT DETAILS'),
                          const SizedBox(height: 10),
                          _MembershipInfoTile(
                            title: 'Membership terms',
                            body:
                                '${SelahMembershipCatalog.basicTerms}\n\n${SelahMembershipCatalog.shepherdBasicTerms}\n\n${SelahMembershipCatalog.trialTerms}\n\n${SelahMembershipCatalog.availability}\n\nUsing both experiences does not make you your own Shepherd. Shepherd permissions and romantic exclusions still apply.\n\nBlocking, reporting, privacy and account controls do not require a subscription. Membership changes do not erase Shepherd links or Journey history.',
                          ),
                          if (_isOne) ...[
                            const SizedBox(height: 34),
                            _SectionLabel('MANAGE BILLING'),
                            const SizedBox(height: 10),
                            _MembershipAction(
                              key: const ValueKey('membership-cancel'),
                              icon: Icons.cancel_outlined,
                              title: 'Cancel membership',
                              detail: _shepherd
                                  ? 'If billed to you, manage or cancel securely in $_storeName.'
                                  : 'Turn off renewal securely in $_storeName.',
                              destructive: true,
                              onTap: _confirmCancellation,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

  List<String> _features(SelahMembershipProduct product) => switch (product) {
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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: SelahText.chapterLabel(color: SelahColors.foregroundMuted),
  );
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(eyebrow),
      const SizedBox(height: 7),
      Text(title, style: SelahText.heading(size: 19)),
      if (subtitle case final subtitle?) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: SelahText.subtext(size: 11.75)),
      ],
    ],
  );
}

class _CompatibilityGroupHeading extends StatelessWidget {
  final String label;
  final String title;
  final String detail;
  final IconData icon;

  const _CompatibilityGroupHeading({
    super.key,
    required this.label,
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: SelahColors.journeyGold.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: SelahColors.journeyGold),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: SelahText.chapterLabel(color: SelahColors.journeyGold),
            ),
            const SizedBox(height: 2),
            Text(title, style: SelahText.body(size: 14)),
            const SizedBox(height: 1),
            Text(detail, style: SelahText.subtext(size: 10.75)),
          ],
        ),
      ),
    ],
  );
}

class _BasketButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final String keyPrefix;

  const _BasketButton({
    required this.count,
    required this.onTap,
    this.keyPrefix = 'membership',
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count == 0 ? 'Basket, empty' : 'Basket, $count items',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: ValueKey('$keyPrefix-basket'),
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
              key: ValueKey('$keyPrefix-basket-count'),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: SelahColors.journeyGold,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: SelahColors.mentorSheetBg, width: 1.5),
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
  final SelahMembershipProduct product;
  final bool basicPreview;
  const _CurrentMembershipCard({
    required this.product,
    this.basicPreview = false,
  });

  bool get _one =>
      product == SelahMembershipProduct.seekerOne ||
      product == SelahMembershipProduct.shepherdOne;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('membership-current'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: SelahColors.surfaceEmphasisFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius + 4),
      border: Border.all(
        color: _one
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
            color: _one
                ? SelahColors.journeyGold.withValues(alpha: 0.13)
                : SelahColors.iconButtonBg,
          ),
          child: Icon(
            _one
                ? Icons.workspace_premium_outlined
                : Icons.person_outline_rounded,
            color: _one
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
                  color: _one
                      ? SelahColors.journeyGold
                      : SelahColors.foregroundMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product == SelahMembershipProduct.shepherdOne
                    ? 'Shepherd access active'
                    : _one
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
                    : _one
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
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  const _MembershipAction({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

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
  final SelahMembershipProduct product;
  final List<String> features;
  final bool current;
  final bool selected;
  final VoidCallback? onAdd;

  const _MembershipPlanCard({
    required this.product,
    required this.features,
    required this.current,
    required this.selected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('membership-${product.name}'),
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
        key: PageStorageKey('membership-plan-${product.name}'),
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
              key: ValueKey('membership-add-${product.name}'),
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
  final bool current;
  final bool selected;
  final VoidCallback? onTap;
  final String label;

  const _AddToBasketButton({
    super.key,
    required this.current,
    required this.selected,
    required this.onTap,
    required this.label,
  });

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
                  // The check glyph is optically weighted to its upper-left.
                  // A one-pixel nudge makes it read as centred in the circle.
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

class _CompatibilityOfferCard extends StatelessWidget {
  final _MembershipOffer offer;
  final int quantity;
  final VoidCallback onAdd;

  const _CompatibilityOfferCard({
    required this.offer,
    required this.quantity,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('compatibility-offer-${offer.id}'),
    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      border: Border.all(
        color: quantity > 0
            ? SelahColors.journeyGold.withValues(alpha: 0.40)
            : SelahColors.surfaceBorder,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SelahColors.journeyGold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(offer.icon, size: 21, color: SelahColors.journeyGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title, style: SelahText.body(size: 13.5)),
              const SizedBox(height: 2),
              Text(offer.detail, style: SelahText.subtext(size: 10.75)),
              const SizedBox(height: 4),
              Text(
                offer.price,
                style: SelahText.body(size: 12, color: SelahColors.journeyGold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: ValueKey('compatibility-add-${offer.id}'),
              tooltip: 'Add ${offer.title} to basket',
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              color: SelahColors.journeyGold,
            ),
            if (quantity > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: SelahColors.journeyGold,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$quantity',
                    style: SelahText.button(
                      size: 8.5,
                      color: SelahColors.onPrimaryAction,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _MembershipInfoTile extends StatelessWidget {
  final String title;
  final String body;

  const _MembershipInfoTile({required this.title, required this.body});

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
        key: PageStorageKey('membership-info-$title'),
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

class _MembershipOffer {
  final String id;
  final String title;
  final String detail;
  final int pricePence;
  final IconData icon;
  final bool subscription;
  final SelahMembershipProduct? product;

  const _MembershipOffer({
    required this.id,
    required this.title,
    required this.detail,
    required this.pricePence,
    required this.icon,
    this.subscription = false,
    this.product,
  });

  String get price => product != null
      ? SelahMembershipCatalog.price(product!)
      : subscription
      ? '${SelahMembershipCatalog.pounds(pricePence)} / month'
      : SelahMembershipCatalog.pounds(pricePence);
}

const _membershipOffers = <_MembershipOffer>[
  _MembershipOffer(
    id: 'seeker-one',
    title: 'Seeker One',
    detail: 'One paid Seeker account',
    pricePence: SelahMembershipCatalog.seekerOneMonthlyPence,
    icon: Icons.person_outline_rounded,
    subscription: true,
    product: SelahMembershipProduct.seekerOne,
  ),
  _MembershipOffer(
    id: 'seeker-basic',
    title: 'Seeker Basic',
    detail: 'One-time joining fee · no monthly subscription',
    pricePence: SelahMembershipCatalog.basicJoiningPence,
    icon: Icons.person_outline_rounded,
    product: SelahMembershipProduct.seekerBasic,
  ),
  _MembershipOffer(
    id: 'shepherd-one',
    title: 'Shepherd One',
    detail: 'One paid Shepherd account',
    pricePence: SelahMembershipCatalog.shepherdOneMonthlyPence,
    icon: Icons.shield_outlined,
    subscription: true,
    product: SelahMembershipProduct.shepherdOne,
  ),
  _MembershipOffer(
    id: 'shepherd-basic',
    title: 'Shepherd Basic',
    detail: 'One-time joining fee · no monthly subscription',
    pricePence: SelahMembershipCatalog.basicJoiningPence,
    icon: Icons.shield_outlined,
    product: SelahMembershipProduct.shepherdBasic,
  ),
  _MembershipOffer(
    id: 'unlock-plus-one',
    title: 'Compatibility Unlock',
    detail: 'One complete reveal',
    pricePence: SelahMembershipCatalog.compatibilitySinglePence,
    icon: Icons.query_stats_rounded,
  ),
  _MembershipOffer(
    id: 'unlock-plus-five',
    title: '5 Compatibility Unlocks',
    detail: 'Five complete reveals · save £4.96',
    pricePence: SelahMembershipCatalog.compatibilityFivePence,
    icon: Icons.stars_outlined,
  ),
];

final _compatibilityOffers = _membershipOffers
    .where((offer) => offer.product == null)
    .toList(growable: false);
