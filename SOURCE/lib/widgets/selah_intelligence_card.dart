// ONE visual idiom for every piece of SELAH intelligence, everywhere it
// appears. Added 2026-08-11 with data/selah_journey_intelligence.dart.
//
// It is one widget for the same reason selah_journey_stages.dart is one map:
// this content shows up at six different points in the Journey, and six
// hand-rolled containers would have drifted into six slightly different
// things within a fortnight. Add a FIELD here before adding a second card.
//
// The label — SELAH Insight / SELAH Recommendation / SELAH Summary — comes from
// the model, never from the call site, so no screen can invent a fourth name
// or slip the word "AI" onto a chip.

import 'package:flutter/material.dart';
import '../data/selah_journey_intelligence.dart';
import '../data/selah_membership_catalog.dart';
import '../services/selah_promotion_engine.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_gold_action_pill.dart';
import 'selah_locked_feature_upgrade.dart';

class SelahIntelligenceCard extends StatelessWidget {
  final SelahIntelligence intelligence;

  /// Tightens the vertical margins for use inside an already-padded list.
  final bool compact;

  const SelahIntelligenceCard({
    super.key,
    required this.intelligence,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final it = intelligence;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: SelahColors.accentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.accentBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            it.label.toUpperCase(),
            style: SelahText.chapterLabel(color: const Color(0xCCD8BEEE)),
          ),
          const SizedBox(height: 8),
          Text(it.body, style: SelahText.body(size: 13.5)),
          if (it.followUps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final prompt in it.followUps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 7, right: 9),
                      decoration: const BoxDecoration(
                        color: Color(0x99D8BEEE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(prompt, style: SelahText.subtext(size: 12.5)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Visible membership boundary for Journey intelligence. Basic members keep
/// the same Journey layout, see what belongs here, and can deliberately open
/// membership information without gaining or mutating entitlement.
class SelahIntelligenceInvitation extends StatelessWidget {
  final SelahIntelligenceKind kind;
  final VoidCallback? onTap;

  const SelahIntelligenceInvitation({super.key, required this.kind, this.onTap});

  String get _label => switch (kind) {
    SelahIntelligenceKind.insight => 'SELAH Insight',
    SelahIntelligenceKind.recommendation => 'SELAH Recommendation',
    SelahIntelligenceKind.summary => 'SELAH Summary',
  };

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('selah-intelligence-${kind.name}-locked'),
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 14),
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
    decoration: BoxDecoration(
      color: SelahColors.accentBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SelahColors.accentBorder, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_rounded, size: 17, color: SelahColors.journeyGold),
            const SizedBox(width: 8),
            Text(
              _label.toUpperCase(),
              style: SelahText.chapterLabel(color: SelahColors.journeyGold),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Available with ${SelahMembershipCatalog.seekerOneTitle}.',
          style: SelahText.body(size: 13.5),
        ),
        const SizedBox(height: 14),
        SelahGoldActionPill(
          label: 'View ${SelahMembershipCatalog.seekerOneTitle}',
          icon: Icons.workspace_premium_outlined,
          onPressed:
              onTap ??
              () => openSeekerLockedFeaturePlan(
                context,
                feature: SelahPromotionFeature.selahIntelligence,
              ),
        ),
      ],
    ),
  );
}
