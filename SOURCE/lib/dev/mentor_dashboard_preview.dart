// THE INTENDED SHEPHERD DASHBOARD — a preview, not a build.
//
// inherited decision 165, 2026-08-13 (Founder: "create/show a mock Shepherd
// dashboard inside the toggle so we can review the intended experience
// before implementation").
//
// ── WHAT THIS IS, AND WHAT IT IS CAREFUL NOT TO BE.
//
// The real dashboard (screens/mentor/mentor_dashboard_screen.dart) has two
// sections: linked Seekers, and their Journeys. It is honest and thin.
// This screen shows what the RATIFIED Shepherd capability list implies
// the dashboard should eventually hold, so the shape can be argued about
// before any of it is built.
//
// It is reachable only from the Shepherd dev panel, only in debug and
// profile builds, and it says on screen that it is a preview. Nothing
// here writes anything. No route in the real app leads to it.
//
// ── THE RULE IT INHERITS.
//
// The dev panel's founding rule is "a toggle must change something real;
// every flag names its reader". A preview is the one thing that rule
// cannot cover, so it carries the opposite obligation: EVERY SECTION
// SAYS WHETHER IT IS REAL TODAY. Three states, colour-coded and labelled
// in words, never by colour alone:
//
//   BUILT      the real dashboard already does this
//   DESIGNED   ratified in MENTOR_ARCHITECTURE, no UI yet
//   BLOCKED    cannot be built without a schema or product decision
//
// Without that, a preview becomes a promise. The Shepherd AI Summary is
// the cautionary example already in the codebase: it is generated, it is
// ratified, and it renders on the SEEKER's screen captioned "would be
// shared", because there is no Shepherd surface to receive it
// (data/selah_journey_intelligence.dart).
//
// ── IT READS THE PANEL'S OWN STAGED STATE.
//
// Wards, Journeys, the Family Review and the sent invitations all come
// from SelahDevScenario, so moving a stepper in the panel moves this
// preview too. It is the same data the real screens compose from — which
// is the only way a preview can be argued with rather than admired.

import 'package:flutter/material.dart';
import 'selah_app_gold_preview.dart';

import '../data/selah_journey_stages.dart';
import '../services/selah_mentor_journey_service.dart';
import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_dev_scenario.dart';

/// How real a section is. Never communicated by colour alone — every
/// chip carries its word.
enum _Maturity { built, designed, blocked }

extension _MaturityX on _Maturity {
  String get label => switch (this) {
    _Maturity.built => 'BUILT',
    _Maturity.designed => 'DESIGNED',
    _Maturity.blocked => 'BLOCKED',
  };

  Color get tint => switch (this) {
    // Reuses the app's own tokens rather than inventing a third
    // red/amber/green triad — there are already two.
    _Maturity.built => const Color(0xFF84C88E),
    _Maturity.designed => const Color(0xFFEED26C),
    _Maturity.blocked => const Color(0xFFF47272),
  };
}

class MentorDashboardPreview extends StatefulWidget {
  const MentorDashboardPreview({super.key});

  @override
  State<MentorDashboardPreview> createState() => _MentorDashboardPreviewState();
}

class _MentorDashboardPreviewState extends State<MentorDashboardPreview> {
  final SelahDevScenario _s = SelahDevScenario.instance;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
  }

  @override
  void dispose() {
    _s.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wards = SelahDevScenario.composeMentorWards();
    final journeys = SelahDevScenario.composeMentorJourneys(wards: wards);
    final review = SelahDevScenario.mentorStagedReview();
    final invites = SelahDevScenario.composeMentorSentInvites();
    final main = _s.mentorIsMain;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          'Shepherd dashboard — preview',
          style: SelahText.heading(size: 16),
        ),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _banner(),
              const SizedBox(height: 16),

              // ── 1 · WHO YOU ARE ─────────────────────────────────────
              _section(
                'Your standing',
                _Maturity.designed,
                'The real Profile tab shows name, plan and a linked count. '
                    'It does not say what your ROLE lets you do — which is '
                    'the thing that changes the most.',
                [
                  _row('Role', main ? 'Main Shepherd' : 'Additional Shepherd'),
                  _row('Seekers', '${wards.length}'),
                  _row('Membership', 'No access'),
                  if (!main)
                    _note(
                      'An Additional Shepherd receives full current Journey '
                      'context only while the Seeker includes them in that '
                      'Journey. Family Review, Shepherd Gate and protected '
                      'decisions remain led by the Main Shepherd.',
                    ),
                ],
              ),

              // ── 2 · WAITING ON YOU ──────────────────────────────────
              _section(
                'Waiting on you',
                _Maturity.designed,
                'The one thing on a Shepherd\'s dashboard that is blocked on '
                    'THEM. Today it is a word inside a Journey row; a '
                    'Shepherd has to go looking for it.',
                [
                  if (review == null)
                    _empty('Nothing is waiting on you.')
                  else ...[
                    _row(
                      'Family Review',
                      '${journeys.isEmpty ? "—" : journeys.first.linkedSeekerName} · closes in 41h 12m',
                    ),
                    _row(
                      'Your decision',
                      _s.mentorReviewDecision ?? 'not yet given',
                    ),
                    _note(
                      'A Main Shepherd votes; an Additional Shepherd cannot '
                      '— mentor_review_decision() refuses them server-side.',
                    ),
                  ],
                ],
              ),

              // ── 3 · YOUR SEEKERS ────────────────────────────────────
              _section(
                'Your Seekers',
                _Maturity.built,
                'Real today, on both the Dashboard and the Seekers tab.',
                [
                  if (wards.isEmpty)
                    _empty('No Seekers linked yet.')
                  else
                    for (final w in wards)
                      _row(
                        w.firstName,
                        w.relationshipLabel ?? 'relationship not recorded',
                      ),
                ],
              ),

              // ── 4 · THEIR JOURNEYS ──────────────────────────────────
              _section(
                'Their Journeys',
                _Maturity.built,
                'Real today. Status first, then stage — a paused Journey '
                    'still holds a stage, and printing it would say the '
                    'Journey is moving.',
                [
                  if (journeys.isEmpty)
                    _empty(
                      main
                          ? 'No Journeys yet.'
                          : 'Additional Shepherds see none — see Your standing.',
                    )
                  else
                    for (final j in journeys)
                      _row(
                        '${j.linkedSeekerName} & ${j.partner.firstName}',
                        _statusOf(j, review != null),
                      ),
                ],
              ),

              // ── 5 · THE OTHER FAMILY ────────────────────────────────
              _section(
                'The other family',
                _Maturity.built,
                'Everything a Shepherd may know about the other side, and '
                    'nothing more.',
                [
                  if (journeys.isEmpty)
                    _empty('Nothing to show without a Journey.')
                  else ...[
                    for (final j in journeys.take(1)) ...[
                      _row(
                        'Seeker',
                        '${j.partner.firstName}, ${j.partner.age}',
                      ),
                      _row(
                        'Their Main Shepherd',
                        j.counterpartShepherdName == null
                            ? 'None linked'
                            : '${j.counterpartShepherdName} · ${j.counterpartShepherdSurname ?? ""}',
                      ),
                    ],
                    _note(
                      'City, photos and gender are WITHHELD by design, not '
                      'missing (clause 3, closed 2026-08-08). The screen '
                      'should say so — "this is everything you can see of '
                      'them, and they see the same of yours" — rather than '
                      'leaving a Shepherd to wonder what failed to load.',
                    ),
                  ],
                ],
              ),

              // ── 6 · INVITATIONS ─────────────────────────────────────
              _section(
                'Invitations you sent',
                _Maturity.built,
                'Listed on Invite your Seeker since 2026-08-13. Arguably '
                    'belongs here too — an unredeemed code is outstanding '
                    'work.',
                [
                  if (invites.isEmpty)
                    _empty('No codes outstanding.')
                  else
                    for (final i in invites)
                      _row(
                        i.label ?? i.token,
                        i.expiresAt == null ? 'no expiry' : 'live',
                      ),
                ],
              ),

              // ── 7 · NOT BUILT ───────────────────────────────────────
              _section(
                'Ratified, not built',
                _Maturity.designed,
                'Capabilities in MENTOR_ARCHITECTURE V6 with no Shepherd UI.',
                [
                  _row('Suggest someone to your Seeker', 'no create UI'),
                  _row('See what you put forward', 'inherited upstream action 214'),
                  _row(
                    'Shepherd AI Summary',
                    'generated; shows on the SEEKER\'s screen',
                  ),
                  _row('Family Review notifications', 'must open the Journey'),
                  _row('Raise a concern', 'no Shepherd-side route'),
                ],
              ),

              // ── 8 · BLOCKED ─────────────────────────────────────────
              _section(
                'Blocked on a decision',
                _Maturity.blocked,
                'Cannot be built without schema or a product ruling. Listed '
                    'so the preview does not quietly imply they are coming.',
                [
                  _row(
                    'Invitations received',
                    'mentor_invites has no recipient column',
                  ),
                  _row('Network Discover / Requests', 'no Network data exists'),
                  _row('Invite delivery (SMS/email)', 'no sending backend'),
                  _row('Browse-stage visibility', 'out of scope by decision'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusOf(MentorJourneyView j, bool reviewOpen) {
    if (j.status == 'ended') return 'Journey ended';
    if (j.isSuspended) return 'Journey paused';
    return SelahJourneyStages.labelFor(
      j.journeyStage,
      reviewOpen: reviewOpen && j.isMock,
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This screen is a preview, not the app',
            style: SelahText.body(size: 14, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            'It shows what the Shepherd dashboard could hold, so the shape '
            'can be argued with before it is built. Every section says '
            'whether it exists today. Nothing here writes anything, and no '
            'route in the real app reaches it.\n\n'
            'The numbers follow the dev panel — move a stepper and this '
            'moves with it.',
            style: SelahText.subtext(size: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    _Maturity maturity,
    String why,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: SelahText.chapterLabel(color: Colors.white70),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: maturity.tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: maturity.tint.withValues(alpha: 0.45),
                      width: 0.5,
                    ),
                  ),
                  // The word, not just the colour — a status told only in
                  // hue is a status nobody colour-blind can read.
                  child: Text(
                    maturity.label,
                    style: SelahText.subtext(size: 9, color: maturity.tint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(why, style: SelahText.subtext(size: 11, color: Colors.white38)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String left, String right) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            left,
            style: SelahText.body(size: 13.5, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: SelahText.subtext(size: 12),
          ),
        ),
      ],
    ),
  );

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      message,
      style: SelahText.subtext(size: 12.5, color: Colors.white38),
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: SelahText.subtext(size: 10.5, color: Colors.white38),
    ),
  );
}
