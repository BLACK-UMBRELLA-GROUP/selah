import 'package:flutter/material.dart';

import '../data/selah_membership_catalog.dart';
import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// Display-only purchase catalogue for the protected fictional preview.
///
/// Approved catalogue prices are information, never checkout, a receipt or
/// credit authority. Both offers remain disabled. This surface has no
/// callbacks, basket, payment service, person ID or test-credit controls.
class SelahDraftCompatibilityStorePresentation extends StatelessWidget {
  const SelahDraftCompatibilityStorePresentation({super.key});

  static const _note =
      'Optional one-off purchases, separate from your membership.';
  static const _unavailable = 'Purchasing isn’t available yet.';
  static const _unlock = _StoreTier(
    id: 'unlock',
    title: 'Compatibility Unlock',
    detail:
        'Your overall compatibility, deeper detail and Shepherd information.',
    icon: Icons.stars_outlined,
    singlePence: SelahMembershipCatalog.compatibilitySinglePence,
    fivePence: SelahMembershipCatalog.compatibilityFivePence,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleStyle = SelahText.heading(size: 26).copyWith(height: 1.2);
      final noteStyle = SelahText.subtext(size: 14).copyWith(height: 1.4);
      final statusStyle = SelahText.subtext(size: 13).copyWith(height: 1.4);
      final content = Column(
        key: const ValueKey('draft_compatibility_store_presentation'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Compatibility Unlocks',
              key: const ValueKey('draft_compatibility_store_title'),
              textAlign: TextAlign.left,
              style: titleStyle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _note,
            key: const ValueKey('draft_compatibility_store_note'),
            style: noteStyle,
          ),
          const SizedBox(height: 20),
          const _StoreTierCard(tier: _unlock),
          const SizedBox(height: 16),
          Text(
            _unavailable,
            key: const ValueKey('draft_compatibility_store_unavailable'),
            textAlign: TextAlign.center,
            style: statusStyle,
          ),
        ],
      );

      // One product keeps a compact card instead of stretching an empty
      // interior. Larger reading faces can scroll without clipping text.
      return SingleChildScrollView(
        key: const ValueKey('draft_compatibility_store_viewport'),
        physics: const ClampingScrollPhysics(),
        child: content,
      );
    },
  );
}

class _StoreTier {
  const _StoreTier({
    required this.id,
    required this.title,
    required this.detail,
    required this.icon,
    required this.singlePence,
    required this.fivePence,
  });

  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final int singlePence;
  final int fivePence;
}

class _StoreTierCard extends StatelessWidget {
  const _StoreTierCard({required this.tier});
  final _StoreTier tier;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('draft_compatibility_store_${tier.id}_card'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SelahColors.journeyGold.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(tier.icon, size: 22, color: SelahColors.journeyGold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tier.title,
                style: SelahText.heading(size: 20).copyWith(height: 1.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tier.detail,
          style: SelahText.subtext(size: 14).copyWith(height: 1.4),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DisabledOffer(
                id: '${tier.id}_single',
                label: '1 unlock',
                pricePence: tier.singlePence,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DisabledOffer(
                id: '${tier.id}_five',
                label: '5 unlocks',
                pricePence: tier.fivePence,
                bestValue: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DisabledOffer extends StatelessWidget {
  const _DisabledOffer({
    required this.id,
    required this.label,
    required this.pricePence,
    this.bestValue = false,
  });

  final String id;
  final String label;
  final int pricePence;
  final bool bestValue;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey('draft_compatibility_store_$id'),
    onPressed: null,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      disabledForegroundColor: SelahColors.foregroundSecondary,
      backgroundColor: SelahColors.journeyGold.withValues(alpha: .04),
      side: BorderSide(color: SelahColors.journeyGold.withValues(alpha: .28)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bestValue) ...[
          Container(
            key: const ValueKey('draft_compatibility_store_best_value'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SelahColors.journeyGold.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('BEST VALUE', style: _badgeStyle()),
          ),
          const SizedBox(height: 6),
        ],
        Text(label, textAlign: TextAlign.center, style: _quantityStyle()),
        const SizedBox(height: 6),
        Text(
          SelahMembershipCatalog.pounds(pricePence),
          textAlign: TextAlign.center,
          style: _priceStyle(),
        ),
      ],
    ),
  );
}

TextStyle _quantityStyle() => SelahText.button(size: 13).copyWith(height: 1.2);
TextStyle _priceStyle() => SelahText.body(
  size: 22,
  color: SelahColors.journeyGold,
).copyWith(height: 1.2);
TextStyle _badgeStyle() => SelahText.button(
  size: 10,
  color: SelahColors.journeyGold,
).copyWith(height: 1.2);
