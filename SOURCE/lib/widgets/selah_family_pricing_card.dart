import 'package:flutter/material.dart';

import '../data/selah_membership_catalog.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// Informational Family calculator. It never changes a plan or creates an
/// entitlement. StoreKit's verified localised price is authoritative at
/// checkout once the commercial integration is enabled.
class SelahFamilyPricingCard extends StatefulWidget {
  const SelahFamilyPricingCard({super.key});

  @override
  State<SelahFamilyPricingCard> createState() => _SelahFamilyPricingCardState();
}

class _SelahFamilyPricingCardState extends State<SelahFamilyPricingCard> {
  int _seekers = 0;
  int _shepherds = 0;

  SelahFamilyQuote get _quote =>
      SelahMembershipCatalog.familyQuote(_seekers, _shepherds);

  void _change({required bool seeker, required int delta}) {
    setState(() {
      if (seeker) {
        _seekers = (_seekers + delta).clamp(
          0,
          SelahMembershipCatalog.familyMaxPerRole,
        );
      } else {
        _shepherds = (_shepherds + delta).clamp(
          0,
          SelahMembershipCatalog.familyMaxPerRole,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SelahColors.iconButtonBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selah Family', style: SelahText.heading(size: 18)),
          const SizedBox(height: 7),
          Text(
            'Choose the paid places your family needs.',
            style: SelahText.subtext(size: 12.5),
          ),
          const SizedBox(height: 18),
          _FamilyRoleStepper(
            label: 'Seeker One',
            pricePence: SelahMembershipCatalog.seekerOneMonthlyPence,
            value: _seekers,
            removeKey: const ValueKey('family-seekers-remove'),
            addKey: const ValueKey('family-seekers-add'),
            outputKey: const ValueKey('family-seekers-count'),
            onRemove: _seekers == 0
                ? null
                : () => _change(seeker: true, delta: -1),
            onAdd: _seekers == SelahMembershipCatalog.familyMaxPerRole
                ? null
                : () => _change(seeker: true, delta: 1),
          ),
          const SizedBox(height: 10),
          _FamilyRoleStepper(
            label: 'Shepherd One',
            pricePence: SelahMembershipCatalog.shepherdOneMonthlyPence,
            value: _shepherds,
            removeKey: const ValueKey('family-shepherds-remove'),
            addKey: const ValueKey('family-shepherds-add'),
            outputKey: const ValueKey('family-shepherds-count'),
            onRemove: _shepherds == 0
                ? null
                : () => _change(seeker: false, delta: -1),
            onAdd: _shepherds == SelahMembershipCatalog.familyMaxPerRole
                ? null
                : () => _change(seeker: false, delta: 1),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: quote.hasMembers
                ? _FamilyQuoteSummary(
                    key: ValueKey(
                      'family-quote-${quote.seekers}-${quote.shepherds}',
                    ),
                    quote: quote,
                  )
                : Container(
                    key: const ValueKey('family-empty'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: SelahColors.surfaceEmphasisFill,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: SelahColors.surfaceBorder),
                    ),
                    child: Text(
                      'Choose at least one place to see the monthly estimate.',
                      style: SelahText.subtext(size: 12.5),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            SelahMembershipCatalog.familyTerms,
            style: SelahText.subtext(size: 12),
          ),
          const SizedBox(height: 10),
          Text(
            SelahMembershipCatalog.familyAvailability,
            style: SelahText.subtext(size: 12),
          ),
        ],
      ),
    );
  }
}

class _FamilyRoleStepper extends StatelessWidget {
  final String label;
  final int pricePence;
  final int value;
  final Key removeKey;
  final Key addKey;
  final Key outputKey;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  const _FamilyRoleStepper({
    required this.label,
    required this.pricePence,
    required this.value,
    required this.removeKey,
    required this.addKey,
    required this.outputKey,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 7, 10),
    decoration: BoxDecoration(
      color: SelahColors.surfaceEmphasisFill,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SelahText.heading(size: 14)),
              const SizedBox(height: 2),
              Text(
                '${SelahMembershipCatalog.pounds(pricePence)} each',
                style: SelahText.subtext(size: 11.5),
              ),
            ],
          ),
        ),
        IconButton(
          key: removeKey,
          tooltip: 'Remove $label place',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_rounded),
          color: SelahColors.foregroundSecondary,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            key: outputKey,
            textAlign: TextAlign.center,
            style: SelahText.heading(size: 16),
          ),
        ),
        IconButton(
          key: addKey,
          tooltip: 'Add $label place',
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          color: SelahColors.journeyGold,
        ),
      ],
    ),
  );
}

class _FamilyQuoteSummary extends StatelessWidget {
  final SelahFamilyQuote quote;

  const _FamilyQuoteSummary({super.key, required this.quote});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surfaceEmphasisFill,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: SelahColors.journeyGold.withValues(alpha: 0.42)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTIMATED MONTHLY TOTAL',
          style: SelahText.chapterLabel(color: SelahColors.journeyGold),
        ),
        const SizedBox(height: 7),
        Text(
          SelahMembershipCatalog.pounds(quote.formulaMonthlyPence),
          key: const ValueKey('family-monthly-total'),
          style: SelahText.heading(size: 25),
        ),
        const SizedBox(height: 10),
        Text(
          '${quote.members} ${quote.members == 1 ? 'place' : 'places'} · '
          '${quote.discountPercent}% estimated saving · '
          'save ${SelahMembershipCatalog.pounds(quote.savingPence)}',
          key: const ValueKey('family-saving-summary'),
          style: SelahText.subtext(size: 12),
        ),
      ],
    ),
  );
}
