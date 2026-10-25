// The Shepherd's person card — inherited decision 171 (2026-08-15, the full
// Shepherd first-draft build).
//
// THE BRIEF, verbatim: "Seeker profile card → Shepherd profile card
// should feel like the same component family." Before this, the
// Dashboard and Seekers tab drew wards as bare icon rows
// (Icons.person_outline + a name) while every Seeker surface had moved
// to the card system — the exact "separate old Shepherd prototype"
// feeling the Founder named. This widget is the ward-shaped member of
// that family:
//
//   · SelahCardMetrics for every number (thumb 52 / radius 10 / padding
//     12 / card radius 14 / gap 14 / spacing 10) — the same constants
//     the Connections rows, Shepherd Suggestions and Mentor-tab cards use.
//   · SelahProfileImage for the photo, so a ward with no viewable photo
//     degrades to the same quiet block as everywhere else (a Shepherd
//     CAN see their own ward — guard-suite clause 2 — so real wards
//     normally render a real photo).
//   · The frost surface (white .07 fill, .14 line) and text hierarchy
//     every glass card carries.
//
// It deliberately does NOT reuse the Connections _JourneyExpandingCard:
// that widget is private to a 4,000-line screen and coupled to Seeker
// Journey verbs. Extracting it wholesale was considered and rejected
// per the Founder's own rule — "do not compromise the existing Seeker
// baseline just to make Shepherd easier." Same family, own member.

import 'package:flutter/material.dart';

import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_profile_image.dart';

/// One small stat chip — "Active 1", "Saved 4". Used by the Dashboard's
/// per-ward activity row. Zero-count chips should simply not be built
/// (the heading already implies the categories; a row of zeros is
/// noise — the Founder's dots ruling, applied to chips).
class SelahWardChip extends StatelessWidget {
  final String label;
  final int count;
  const SelahWardChip({super.key, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SelahColors.surfaceBorder, width: 0.5),
      ),
      child: Text(
        '$label $count',
        style: SelahText.subtext(size: 10.5, color: SelahColors.ink(0.70)),
      ),
    );
  }
}

/// The 8-stage progress rail — the Journey's canonical stages as dots,
/// filled to the current one. Raw system statuses never reach the
/// Shepherd's eye (brief §6): the label above this rail speaks the
/// ratified chapter names (Faith & Values, Building a Life…), and the
/// rail says how far along that is, wordlessly.
class SelahStageRail extends StatelessWidget {
  /// 1-based order of the current stage, from SelahJourneyStages.of().order.
  final int order;
  final int count;
  const SelahStageRail({super.key, required this.order, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= count; i++) ...[
          Container(
            width: i == order ? 7 : 5,
            height: i == order ? 7 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= order
                  ? SelahColors.foreground.withValues(
                      alpha: i == order ? 0.95 : 0.55,
                    )
                  : SelahColors.foreground.withValues(alpha: 0.18),
            ),
          ),
          if (i < count)
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: i < order ? 0.35 : 0.12),
              ),
            ),
        ],
      ],
    );
  }
}

class SelahWardCard extends StatelessWidget {
  /// Ward's first name — always available (mentor_links join).
  final String name;

  /// Signed photo URL when the ward's profile has been fetched; empty
  /// renders the standard quiet block via SelahProfileImage.
  final String photoUrl;

  /// One line under the name: "Journey with Khadija — Faith & Values",
  /// "You are their Main Shepherd", "No Journey yet".
  final String statusLine;

  /// Optional second quiet line (for example, a neutral Journey status).
  final String? detailLine;

  /// Current stage order (1-based) — non-null draws the stage rail.
  final int? stageOrder;
  final int stageCount;

  /// Attention marker — the coral dot the nav bar uses, meaning "a
  /// decision is waiting inside" (Family Review, Shepherd step).
  final bool needsAttention;

  /// Activity chips (already filtered to non-zero by the caller).
  final List<Widget> chips;

  final VoidCallback? onTap;

  const SelahWardCard({
    super.key,
    required this.name,
    this.photoUrl = '',
    required this.statusLine,
    this.detailLine,
    this.stageOrder,
    this.stageCount = 8,
    this.needsAttention = false,
    this.chips = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SelahCardMetrics.spacing),
      child: Material(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(SelahCardMetrics.padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
              border: Border.all(color: SelahColors.surfaceBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SelahCardMetrics.thumbRadius,
                      ),
                      child: SizedBox(
                        width: SelahCardMetrics.thumb,
                        height: SelahCardMetrics.thumb,
                        child: SelahProfileImage(
                          photoUrl,
                          width: SelahCardMetrics.thumb,
                          height: SelahCardMetrics.thumb,
                        ),
                      ),
                    ),
                    SizedBox(width: SelahCardMetrics.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SelahText.body(
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (needsAttention) ...[
                                SizedBox(width: 7),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFF0A2A0),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 3),
                          Text(
                            statusLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SelahText.subtext(size: 11.5),
                          ),
                          if (detailLine != null) ...[
                            SizedBox(height: 2),
                            Text(
                              detailLine!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SelahText.subtext(
                                size: 10.5,
                                color: SelahColors.foreground.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: SelahColors.foreground.withValues(alpha: 0.35),
                      ),
                  ],
                ),
                if (stageOrder != null) ...[
                  SizedBox(height: 11),
                  SelahStageRail(order: stageOrder!, count: stageCount),
                ],
                if (chips.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
