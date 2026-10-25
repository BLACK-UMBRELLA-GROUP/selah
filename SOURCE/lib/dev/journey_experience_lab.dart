// THE JOURNEY EXPERIENCE LAB — round 2 (inherited decision 184, 2026-08-16).
//
// Round 1 offered five DIRECTIONS; the Founder walked all of them and
// named the elements that earned their place:
//   · the Path's side rail            ("i like path how theres a side bar")
//   · the Veil's page-turn entry      ("like a book")
//   · the Ritual's tap + breathing dot
//   · the Table's two circles up top
//   · and the app's STANDARD LOADING LINES whenever the Journey is
//     waiting on the other person.
//
// Round 2 is those elements, COMPOSED five new ways. Every option now
// carries the waiting treatment (SelahLoading — the comet rule, the
// same lines the rest of the app waits with); they differ in which of
// the other elements they wear:
//
//   1 · BOOK   — the two of you above, a veil that parts per chapter
//   2 · TRAIL  — the side rail + a breath (tap-beat) before each chapter
//   3 · RITE   — veil, then breath: the fullest ceremony, nothing else
//   4 · DUO    — the two of you + the rail, always visible, no gates
//   5 · FULL   — everything at once: orbs, rail, veil, breath
//
// DESIGN RULE OF THE LAB (unchanged): every option EMBEDS the real
// stage view. Chrome and motion around the same truth — mechanics are
// never mocked. Colours come from SelahColors only (inherited decision 182).
//
// PER-CHAPTER REPLAY COMES FREE: journey_flow_screen keys its stage
// switcher by stage value, so each stage change REMOUNTS the wrapper —
// veils re-draw, beats replay — with no cross-stage state here.
//
// Protected internal Founder capability only; public builds never expose it.
// When a composite is chosen it graduates into a ratified build and
// this lab retires.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../data/selah_journey_stages.dart';
import '../models/seeker_profile.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_loading.dart';

class JourneyExperienceLab {
  JourneyExperienceLab._();

  static const labels = ['Now', 'Book', 'Trail', 'Rite', 'Duo', 'Full'];

  /// [option] 0 returns [current] untouched — today's experience.
  ///
  /// [stage] is the Journey's CURRENT stage value (null only while the
  /// first fetch is in flight — treated as the first stage).
  /// [isOpening] marks the pre-stage welcome beats: veils and breaths
  /// pass those through undressed — the opening is itself an entry
  /// rite, and a gate on a welcome would stack ceremony on ceremony.
  /// [waitingReason] is the server's own word for what the Journey is
  /// waiting on (waiting_for_greeting / _reveal / _continue), null when
  /// nothing is known to be waited for; every composite renders the
  /// standard waiting lines when it is set.
  static Widget wrapJourney({
    required int option,
    required SeekerProfile profile,
    required String? stage,
    required bool isOpening,
    String? waitingReason,
    required Widget current,
  }) {
    final s = SelahJourneyStages.of(stage) ?? SelahJourneyStages.all.first;
    Widget inner = current;
    switch (option) {
      case 1: // BOOK — orbs above, a page that turns per chapter.
        if (!isOpening) {
          inner = _VeilGate(stage: s, profile: profile, child: inner);
        }
        return _Frame(
          orbs: true,
          rail: false,
          header: false,
          stage: s,
          profile: profile,
          waitingReason: waitingReason,
          child: inner,
        );
      case 2: // TRAIL — the rail, and a breath before each chapter.
        if (!isOpening) {
          inner = _BeatGate(stage: s, profile: profile, child: inner);
        }
        return _Frame(
          orbs: false,
          rail: true,
          header: true,
          stage: s,
          profile: profile,
          waitingReason: waitingReason,
          child: inner,
        );
      case 3: // RITE — veil, then breath. The ceremony, unaccompanied.
        if (!isOpening) {
          inner = _VeilGate(
            stage: s,
            profile: profile,
            child: _BeatGate(stage: s, profile: profile, child: inner),
          );
        }
        return _Frame(
          orbs: false,
          rail: false,
          header: true,
          stage: s,
          profile: profile,
          waitingReason: waitingReason,
          child: inner,
        );
      case 4: // DUO — the two of you and the road, no gates at all.
        return _Frame(
          orbs: true,
          rail: true,
          header: false,
          stage: s,
          profile: profile,
          waitingReason: waitingReason,
          child: _RiseIn(child: inner),
        );
      case 5: // FULL — everything the Founder liked, at once.
        if (!isOpening) {
          inner = _VeilGate(
            stage: s,
            profile: profile,
            child: _BeatGate(stage: s, profile: profile, child: inner),
          );
        }
        return _Frame(
          orbs: true,
          rail: true,
          header: false,
          stage: s,
          profile: profile,
          waitingReason: waitingReason,
          child: inner,
        );
      default:
        return current;
    }
  }
}

// ─── shared bits ──────────────────────────────────────────────────────

const _gold = Color(0xFFE8C98A);

const _chapterWords = [
  'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', //
];

String _word(int n) =>
    (n >= 1 && n <= _chapterWords.length) ? _chapterWords[n - 1] : '$n';

/// One-shot rise-and-fade entry, the lab's common arrival gesture.
class _RiseIn extends StatelessWidget {
  final Widget child;
  const _RiseIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

// ─── the assembler ────────────────────────────────────────────────────

/// Puts a composite together: orbs above, rail beside, header over the
/// content, waiting lines below. Each option chooses its pieces; the
/// pieces themselves are single-sourced here.
class _Frame extends StatelessWidget {
  final bool orbs;
  final bool rail;
  final bool header;
  final SelahJourneyStage stage;
  final SeekerProfile profile;
  final String? waitingReason;
  final Widget child;
  const _Frame({
    required this.orbs,
    required this.rail,
    required this.header,
    required this.stage,
    required this.profile,
    required this.waitingReason,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (header) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: _RiseIn(
              key: ValueKey('hdr-${stage.value}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOU ARE HERE · ${stage.order} OF '
                    '${SelahJourneyStages.count}',
                    style: SelahText.chapterLabel(color: _gold),
                  ),
                  const SizedBox(height: 2),
                  Text(stage.label, style: SelahText.heading(size: 18)),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    if (rail) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StationRail(stage: stage),
          Expanded(child: body),
        ],
      );
    }
    return Column(
      children: [
        if (orbs) _OrbsHeader(stage: stage, profile: profile),
        Expanded(child: body),
        if (waitingReason != null)
          _WaitingStrip(profile: profile, reason: waitingReason),
      ],
    );
  }
}

// ─── the two of you (from the Table) ──────────────────────────────────

class _OrbsHeader extends StatefulWidget {
  final SelahJourneyStage stage;
  final SeekerProfile profile;
  const _OrbsHeader({required this.stage, required this.profile});

  @override
  State<_OrbsHeader> createState() => _OrbsHeaderState();
}

class _OrbsHeaderState extends State<_OrbsHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(String letter) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: _gold.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.22), blurRadius: 14),
        ],
      ),
      child: Text(letter, style: SelahText.heading(size: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stage;
    final them = widget.profile.firstName.isEmpty
        ? '·'
        : widget.profile.firstName[0];
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: _RiseIn(
        child: Column(
          children: [
            FadeTransition(
              opacity: Tween(
                begin: 0.75,
                end: 1.0,
              ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _orb('You'[0]),
                  Container(
                    width: 26,
                    height: 1.5,
                    color: _gold.withValues(alpha: 0.4),
                  ),
                  _orb(them),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chapter ${_word(s.order)} of '
              '${_word(SelahJourneyStages.count)} · ${s.label}',
              style: SelahText.subtext(
                size: 10.5,
                color: _gold.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── the side rail (from the Path) ────────────────────────────────────

class _StationRail extends StatelessWidget {
  final SelahJourneyStage stage;
  const _StationRail({required this.stage});

  @override
  Widget build(BuildContext context) {
    final stages = SelahJourneyStages.all;
    final here = stage.order; // 1-based
    return SizedBox(
      width: 52,
      child: _RiseIn(
        child: Column(
          children: [
            const SizedBox(height: 18),
            for (var i = 0; i < stages.length; i++) ...[
              Builder(
                builder: (_) {
                  final n = i + 1;
                  final isHere = n == here;
                  final walked = n < here;
                  return Container(
                    width: isHere ? 20 : 14,
                    height: isHere ? 20 : 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: walked
                          ? _gold.withValues(alpha: 0.12)
                          : SelahColors.luxuryDarkPurple.withValues(alpha: 0.4),
                      border: Border.all(
                        color: isHere
                            ? _gold
                            : walked
                            ? _gold.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.22),
                        width: isHere ? 1.5 : 1,
                      ),
                      boxShadow: isHere
                          ? [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.35),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontSize: isHere ? 9 : 7,
                        color: isHere
                            ? _gold
                            : walked
                            ? _gold.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  );
                },
              ),
              if (i < stages.length - 1)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: i + 1 < here
                        ? _gold.withValues(alpha: 0.30)
                        : Colors.white.withValues(
                            alpha: i + 1 == here ? 0.25 : 0.10,
                          ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ─── the veil (from the Chamber) ──────────────────────────────────────

class _VeilGate extends StatefulWidget {
  final SelahJourneyStage stage;
  final SeekerProfile profile;
  final Widget child;
  const _VeilGate({
    required this.stage,
    required this.profile,
    required this.child,
  });

  @override
  State<_VeilGate> createState() => _VeilGateState();
}

class _VeilGateState extends State<_VeilGate> {
  /// Once per MOUNT — the flow remounts per stage change, so each
  /// chapter gets its own page-turn.
  bool _parted = false;

  /// inherited decision 182. A BackdropFilter keeps blurring its backdrop even at
  /// opacity 0; once the part completes, the veil leaves the tree.
  bool _veilLifted = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stage;
    final line =
        s.guidingQuestion ??
        '${s.label} — walked with ${widget.profile.firstName}.';
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedScale(
          scale: _parted ? 1 : 0.96,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _parted ? 1 : 0.35,
            duration: const Duration(milliseconds: 900),
            child: widget.child,
          ),
        ),
        if (!_veilLifted)
          IgnorePointer(
            ignoring: _parted,
            child: AnimatedOpacity(
              opacity: _parted ? 0 : 1,
              duration: const Duration(milliseconds: 900),
              onEnd: () {
                if (_parted && mounted) setState(() => _veilLifted = true);
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  // The scrim is the app's own dark stop (inherited decision 182).
                  color: SelahColors.luxuryDarkPurple.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'YOU ARE ENTERING',
                          style: SelahText.chapterLabel(color: Colors.white54),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Chapter ${_word(s.order)}',
                          style: SelahText.heading(size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.label,
                          style: SelahText.subtext(size: 13.5, color: _gold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          line,
                          textAlign: TextAlign.center,
                          style: SelahText.subtext(size: 12.5),
                        ),
                        const SizedBox(height: 22),
                        Material(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => setState(() => _parted = true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 12,
                              ),
                              child: Text(
                                'Part the veil',
                                style: SelahText.button(size: 13.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── the breath (from the Ritual) ─────────────────────────────────────

class _BeatGate extends StatefulWidget {
  final SelahJourneyStage stage;
  final SeekerProfile profile;
  final Widget child;
  const _BeatGate({
    required this.stage,
    required this.profile,
    required this.child,
  });

  @override
  State<_BeatGate> createState() => _BeatGateState();
}

class _BeatGateState extends State<_BeatGate> {
  bool _entered = false;

  @override
  Widget build(BuildContext context) {
    if (_entered) return _RiseIn(child: widget.child);
    final s = widget.stage;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _entered = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RiseIn(
              child: Column(
                children: [
                  Text(
                    'CHAPTER ${_word(s.order).toUpperCase()} OF '
                    '${_word(SelahJourneyStages.count).toUpperCase()}',
                    style: SelahText.chapterLabel(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: SelahText.heading(size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.guidingQuestion ??
                        'You and ${widget.profile.firstName} are both '
                            'here. Take a breath — then enter.',
                    textAlign: TextAlign.center,
                    style: SelahText.subtext(size: 13),
                  ),
                  const SizedBox(height: 30),
                  const _Breath(),
                  const SizedBox(height: 14),
                  Text(
                    'tap to continue',
                    style: SelahText.subtext(
                      size: 10.5,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breath extends StatefulWidget {
  const _Breath();
  @override
  State<_Breath> createState() => _BreathState();
}

class _BreathState extends State<_Breath> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.7,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── the waiting lines (the app's own) ────────────────────────────────

/// "when its waiting for other person… the standard loading lines we
/// have" — so it IS the standard: [SelahLoading], the comet rule every
/// other waiting screen in SELAH speaks, with the server's own reason
/// put into words.
class _WaitingStrip extends StatelessWidget {
  final SeekerProfile profile;
  final String? reason;
  const _WaitingStrip({required this.profile, required this.reason});

  String get _line {
    final name = profile.firstName;
    return switch (reason) {
      'waiting_for_greeting' => "Waiting for $name's Greeting",
      'waiting_for_reveal' => 'Waiting for $name to reveal',
      'waiting_for_continue' => 'Waiting for $name to continue',
      _ => 'Waiting for $name',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: _RiseIn(
        key: ValueKey('wait-$reason'),
        child: SelahLoading(label: _line),
      ),
    );
  }
}
