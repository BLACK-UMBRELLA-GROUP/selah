// Accepting a Shepherd invitation you RECEIVED.
//
// ADDED 2026-08-07. Founder: "pressing accept should take me to a new page
// with last button on that page being confirm."
//
// A full page rather than a sheet, deliberately: agreeing to a Shepherd is
// one of the few decisions in SELAH that a family will treat as binding, and
// it deserves a screen rather than something that slides over the one behind
// it.
//
// WHOSE ANSWER IS THIS?
//
// The relationship is a statement about the SHEPHERD, so the Shepherd makes
// it — ratified 2026-08-07. He already said "I am her father" when he
// created the invite, so his answer arrives PRE-SELECTED here.
//
// She is confirming, not authoring. But it is editable, because he can be
// wrong and she is the one who will live with the label. One tap in the
// normal case; a correction is possible without being invited.
//
// PREVIEW ONLY. `mentor_invites` has no recipient, so there is no real
// invitation to accept — see SelahDevScenario.fakeReceived. The layout is
// real so it can be judged; Confirm does not write anything yet.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../data/selah_reference_data.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_fade_edges.dart';
import '../../theme/selah_card_metrics.dart';

class AcceptShepherdInviteScreen extends StatefulWidget {
  final String from;

  /// The relationship code the inviting Shepherd stated. Pre-selects.
  final String? theirAnswer;

  const AcceptShepherdInviteScreen({
    super.key,
    required this.from,
    this.theirAnswer,
  });

  @override
  State<AcceptShepherdInviteScreen> createState() =>
      _AcceptShepherdInviteScreenState();
}

class _AcceptShepherdInviteScreenState
    extends State<AcceptShepherdInviteScreen> {
  String? _relationship;

  @override
  void initState() {
    super.initState();
    _relationship = widget.theirAnswer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(iconTheme: IconThemeData(color: SelahColors.ink(0.70))),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                // Same fade as the Shepherd detail page. Content passing the
                // viewport edge dissolves rather than being cut, which is
                // what produced the "line" — most visibly on the monogram,
                // where a sliced circle reads as a horizontal rule.
                child: SelahFadeEdges(
                  top: 34,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Center(child: _Monogram(letter: widget.from)),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          widget.from,
                          style: SelahText.heading(size: 26),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'wants to be your Shepherd',
                          style: SelahText.subtext(
                            size: 14.5,
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                      ),

                      SizedBox(height: 36),
                      // The wording the Founder settled on: it covers Imam and
                      // Legal Shepherd, which "How are you related?" does not.
                      Text(
                        'What best describes their role in your marriage journey?',
                        style: SelahText.body(size: 16, color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        widget.theirAnswer == null
                            ? 'Choose one.'
                            : '${widget.from} chose this. Change it if it is not right.',
                        style: SelahText.subtext(
                          size: 12.5,
                          color: SelahColors.ink(0.38),
                        ),
                      ),
                      SizedBox(height: 18),

                      // GROUPED CHIPS — the full proposed list, 2026-08-07.
                      //
                      // Grouping is what makes twenty-three values scannable
                      // where a flat wrap would be a wall. Five headings, and
                      // the eye lands on the right one before reading any
                      // chip.
                      //
                      // Values outside the live seven cannot be SAVED yet —
                      // the CHECK constraint on mentor_links.relationship still
                      // allows seven. Harmless here because Confirm writes
                      // nothing, and the point of the screen is to judge the
                      // layout at full size.
                      for (final g in selahShepherdRelationshipGroups) ...[
                        Text(
                          g.title.toUpperCase(),
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            for (final r in g.items)
                              _RelChip(
                                label: r.name,
                                selected: _relationship == r.code,
                                // Dimmed where the value cannot yet be stored,
                                // so the preview never pretends the enum is
                                // wider than it is.
                                preview: !selahRelationshipIsLive(r.code),
                                onTap: () =>
                                    setState(() => _relationship = r.code),
                              ),
                          ],
                        ),
                        SizedBox(height: 22),
                      ],

                      SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: SelahColors.foreground.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            SelahCardMetrics.cardRadius,
                          ),
                          border: Border.all(
                            color: SelahColors.foreground.withValues(
                              alpha: 0.10,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Once linked, ${widget.from} can follow your Journey and '
                          'read conversations within it. You can remove them at '
                          'any time.',
                          style: SelahText.subtext(
                            size: 12.5,
                            color: SelahColors.ink(0.60),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // LAST on the page, as asked. Pinned rather than scrolled with
              // the content: the decision should be reachable without
              // hunting for it, and the list above may grow.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _relationship == null
                          ? SelahColors.iconButtonBg
                          : SelahColors.accentBg,
                      border: Border.all(
                        color: _relationship == null
                            ? SelahColors.iconButtonBorder
                            : SelahColors.accentBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _relationship == null
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Preview only — nothing linked. (dev)',
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop(true);
                              },
                        child: Center(
                          child: Text('Confirm', style: SelahText.button()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelChip extends StatelessWidget {
  final String label;
  final bool selected;

  /// Not yet in the live enum — selectable here, unsavable in production.
  final bool preview;
  final VoidCallback onTap;
  const _RelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SelahColors.accentBg : SelahColors.iconButtonBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? SelahColors.accentBorder
                  : SelahColors.iconButtonBorder,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: SelahText.body(
              size: 14,
              color: SelahColors.foreground.withValues(
                alpha: selected ? 1 : (preview ? 0.42 : 0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  final String letter;
  const _Monogram({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SelahColors.foreground.withValues(alpha: 0.28),
            SelahColors.foreground.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: SelahColors.foreground.withValues(alpha: 0.28),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          letter.isEmpty ? '?' : letter.characters.first.toUpperCase(),
          style: SelahText.heading(size: 38),
        ),
      ),
    );
  }
}
