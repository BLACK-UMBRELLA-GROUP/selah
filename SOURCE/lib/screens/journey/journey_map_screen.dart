// The Journey Map — where we are, on which road.
//
// BUILT 2026-08-12, decision D1 of JOURNEY_EXPERIENCE_REVIEW_2026-08-12_V1
// (Founder-directed experience redesign). The review's diagnosis: progress
// had no geography — the only indicator of position was the stage title
// itself, so every stage felt like the same distance from the end, which is
// the definitional feeling of a wizard: pages, not places.
//
// ONE SCREEN, ONE JOB. The Map is the road; the Timeline is the story —
// forward versus backward, two screens, two jobs, never merged. So this
// screen deliberately fetches nothing: it renders the canonical stage
// sequence (data/selah_journey_stages.dart) against the position it is
// handed, and offers the Timeline for everything that has already been
// lived. No percentages, no progress bar, no numbers — a road with places
// on it, and the destination visible from the first day.
//
// What is AHEAD shows its name and guiding question only — anticipation
// comes from knowing the shape of the road, not its contents.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../data/selah_journey_stages.dart';
import '../../models/seeker_profile.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../matches/journey_timeline_screen.dart';

class JourneyMapScreen extends StatelessWidget {
  final SeekerProfile profile;

  /// The stage value the Journey is currently standing on.
  final String currentStage;

  const JourneyMapScreen({
    super.key,
    required this.profile,
    required this.currentStage,
  });

  @override
  Widget build(BuildContext context) {
    final stages = SelahJourneyStages.all;
    final hereIdx = stages.indexWhere((s) => s.value == currentStage);

    return Scaffold(
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: SelahColors.ink(0.70),
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Your road with ${profile.firstName}',
                        style: SelahText.heading(size: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Balances the back button so the title truly centres.
                    SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    for (var i = 0; i < stages.length; i++)
                      _MapRow(
                        stage: stages[i],
                        state: hereIdx < 0
                            ? _PlaceState.ahead
                            : i < hereIdx
                            ? _PlaceState.behind
                            : i == hereIdx
                            ? _PlaceState.here
                            : _PlaceState.ahead,
                        isFirst: i == 0,
                        isLast: i == stages.length - 1,
                      ),
                    SizedBox(height: 18),
                    Text(
                      'The Map is the road. Your Timeline is the story — '
                      'everything you have already lived, kept with its dates.',
                      style: SelahText.subtext(
                        size: 12,
                        color: SelahColors.ink(0.54),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                JourneyTimelineScreen(withProfile: profile),
                          ),
                        ),
                        child: Text(
                          'Read your Timeline',
                          style: SelahText.button(size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PlaceState { behind, here, ahead }

class _MapRow extends StatelessWidget {
  final SelahJourneyStage stage;
  final _PlaceState state;
  final bool isFirst;
  final bool isLast;
  const _MapRow({
    required this.stage,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final behind = state == _PlaceState.behind;
    final here = state == _PlaceState.here;

    final Widget marker;
    if (behind) {
      marker = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SelahColors.foreground.withValues(alpha: 0.85),
        ),
        child: Icon(Icons.check, size: 12, color: SelahColors.luxuryDarkPurple),
      );
    } else if (here) {
      marker = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SelahColors.actionFill,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
    } else {
      marker = Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SelahColors.foreground.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      );
    }

    Widget line(bool draw) => Expanded(
      child: Container(
        width: 1.5,
        color: draw
            ? SelahColors.foreground.withValues(alpha: behind ? 0.5 : 0.18)
            : Colors.transparent,
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(children: [line(!isFirst), marker, line(!isLast)]),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label,
                    style: here
                        ? SelahText.heading(size: 16)
                        : SelahText.body(
                            size: 14,
                            color: Colors.white.withValues(
                              alpha: behind ? 0.85 : 0.5,
                            ),
                          ),
                  ),
                  if (here) ...[
                    SizedBox(height: 2),
                    Text(
                      'You are here',
                      style: SelahText.subtext(
                        size: 11,
                        color: SelahColors.actionFill,
                      ),
                    ),
                  ],
                  if (stage.guidingQuestion != null) ...[
                    SizedBox(height: 2),
                    Text(
                      stage.guidingQuestion!,
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.foreground.withValues(
                          alpha: behind ? 0.5 : 0.38,
                        ),
                      ),
                    ),
                  ],
                  if (isLast) ...[
                    SizedBox(height: 2),
                    Text(
                      'Where this road leads.',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.foreground.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
