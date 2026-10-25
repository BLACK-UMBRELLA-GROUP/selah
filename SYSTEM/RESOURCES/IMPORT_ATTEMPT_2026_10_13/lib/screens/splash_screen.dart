// Splash — the branded opening.
//
// CURRENT 2026-09-27: Founder selected Quiet Horizon as the main splash.
// The gold wordmark and quiet drawn horizon reuse the selected shared artwork;
// the canonical tagline, 2.4s motion and AuthGate callback stay. Founder
// 2026-09-30 first reduced the completed-frame hold from 2.0s to 1.25s,
// then reduced that still hold again to 0.65s. Motion remains 2.4s.
// Explicit legacy motions remain comparison-only. Earlier design notes below
// document their history and do not override this production choice.
//
// NEW 2026-08-07. The letters arrive one at a time and the tagline lands with
// the last of them. The final motion is now the Founder-approved Soft Bloom +
// Centre Draw (2026-08-26): warm light opens behind the name, then a short
// gold line grows evenly from its centre beneath the tagline. No travelling
// dot remains. Founder timing review later the same day slowed the motion from
// 2.0s to 2.4s while preserving a 1.0s final hold. Founder 2026-09-18 then
// asked for the complete splash to stay roughly one second longer, especially
// the gold line. Motion remains 2.4s; the finished composition now holds 2.0s.
//
// ── IT NOW ALWAYS PLAYS. Founder, 2026-08-07: "every time I open the app I
// want to start with the splash screen."
//
// That is a deliberate reversal of how this file worked an hour ago. The
// first version added ZERO time — it dressed up the wait AuthGate was
// already spending on the session lookup, and vanished the instant that
// finished, sometimes after 80ms. An animation cannot do that: cut it off
// mid-way and it reads as a glitch.
//
// So the splash now runs for [_total] and the app waits for it. The cost is
// real and it is a choice, bought for a first impression. If that ever feels
// too long, [_total] and [_animFraction] are the two timing controls — every
// visual interval below is expressed as a fraction of the motion phase.
//
// AuthGate holds the other half: it shows this until BOTH the animation has
// finished AND the session has resolved. On a slow network the profile
// fetch outlasts the animation and the last frame simply holds, which is
// why the composition ends in a state that is calm to sit in.
//
// ── THE NATIVE LAUNCH IMAGE MUST BE A FLAT COLOUR, and this is not
// optional. iOS and Android paint a static image before Flutter draws
// anything. If that image contains the wordmark — as it did until today —
// the user sees SELAH fully assembled, then watches it vanish and rebuild
// itself letter by letter. flutter_native_splash is now configured with a
// colour and no image; assets/splash/splash_logo.png is no longer
// referenced. Do not put it back.
//
// ── GRADIENT. THE BRAND PURPLE, ALWAYS. Never gender-matched.
//
// The Founder-directed 2026-09-27 palette is Hulu-inspired deep purple
// #30203F → #160E20, shared by production, all twelve preview studies,
// navigation and both roles. Gender never changes this presentation.
//
// ── THIS REVERSES THE 2026-08-07 CHANGE, deliberately. Founder,
// 2026-08-08: "it's got the pink purple colour but it should be the purple
// colour."
//
// That earlier change made the splash gender-matched to kill a flash the
// Founder had reported as "a second of purple before it goes pink" — the
// splash painting neutral, then main.dart's gendered layer taking over
// underneath it. The diagnosis was right and the fix was aimed at the
// wrong half: it removed the flash by making the splash the WRONG COLOUR
// for the whole four seconds, rather than by softening the handoff.
//
// The handoff is now where it belongs — AuthGate cross-fades the splash
// into the resolved screen (see auth_gate.dart), so brand purple resolves
// into the member's own colour as a transition instead of a cut. The
// splash itself stays brand purple start to finish.
//
// If a flash ever reappears, fix it in AuthGate. Do not re-tint the splash.

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_splash_motion.dart';
import '../widgets/selah_splash_artwork.dart';

/// Total time the splash owns the screen.
///
/// 2600 -> 4000ms, Founder 2026-08-08 (benchmarked against Uber): "I want 4
/// seconds with 2 of those seconds showing no animation, just the SELAH."
/// 4000 -> 3000ms, Founder, later the same day: "make the splash screen 3
/// seconds not 4."
///
/// THE SECOND WAS TAKEN OFF THE HOLD, NOT THE ANIMATION. [_animFraction]
/// moved 0.5 -> 2/3 in the same change, which keeps the sequence at the
/// 2000ms he originally approved and cuts the still hold from 2000ms to
/// 1000ms. Shortening the animation instead would have sped up every
/// interval below — a different composition, not a shorter one, and not
/// what "make it 3 seconds" asks for.
///
/// 3000 -> 3400ms, Founder 2026-08-26: the approved Bloom + Draw composition
/// was right but "everything happened too fast". The additional 400ms belongs
/// entirely to motion; the final 1000ms hold remains unchanged.
///
/// 3400 -> 4400ms, Founder 2026-09-18: keep the whole splash about one second
/// longer and let the completed gold line remain on screen. The motion is
/// still 2400ms; the finished wordmark, tagline and line then held for
/// 2000ms. Founder 2026-09-30 shortened only that still hold by 750ms:
/// 2400ms motion + 1250ms hold = 3650ms total. Founder then found the
/// static tail still too long: the current 2400ms motion + 650ms hold is
/// 3050ms total. The shared artwork timing keeps protected previews faithful.
const Duration _total = selahSplashTotalDuration;

/// How much of [_total] the animation occupies. The remainder is a
/// deliberate STILL HOLD on the finished composition.
///
/// ── WHY A HOLD IS A REAL DESIGN ELEMENT AND NOT DEAD TIME.
/// An animation that finishes and immediately hands off reads as a
/// transition — something on the way to somewhere. The same animation
/// followed by stillness reads as an arrival. The pause is what turns
/// motion into a statement. The bloom and line therefore resolve before the
/// still wordmark hold: there has to be something calm to look at while it
/// holds.
///
/// ── HOW IT WORKS. Every interval below is expressed as a fraction of the
/// ANIMATION, not of [_total]. `_at()` divides the controller by this
/// fraction and clamps, so the first 2400ms plays the whole sequence and
/// the remainder holds every value pinned at 1.0. One controller, no
/// second timer, and the two numbers are independently adjustable.
///
/// 2/3 -> 12/17 on 2026-08-26 alongside [_total] 3000 -> 3400. On
/// 2026-09-18 this became 6/11: exactly 2400ms of motion within 4400ms.
/// The current shared fraction is 2400/3050 (48/61), leaving a 650ms
/// finished hold without rounded-decimal drift.
const double _animFraction = selahSplashMotionFraction;

class SplashScreen extends StatefulWidget {
  /// Fired once when the animation completes. AuthGate uses it as one of
  /// the two conditions for moving on.
  final VoidCallback? onFinished;

  /// Null uses the Founder-selected Quiet Horizon production artwork.
  /// Explicit motions preserve the original real-screen comparisons, with
  /// the same lifecycle/timing and no change to the production choice.
  final SelahSplashMotion? motion;
  const SplashScreen({super.key, this.onFinished, this.motion});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: _total,
          // Quiet Horizon renders a still final frame for reduced motion;
          // platform accessibility must not shorten AuthGate ownership.
          animationBehavior: widget.motion == null
              ? AnimationBehavior.preserve
              : AnimationBehavior.normal,
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onFinished?.call();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _letterStagger = 0.085; // ~200ms apart at the 2.4s pace
  static const _letterStart = 0.16;
  static const _letterLen = 0.30;

  // Lands WITH the final letter rather than after it — the name completing
  // and the promise appearing read as one gesture, without a separate beat.
  static const _tagline = Interval(0.66, 0.92, curve: Cubic(.22, .9, .3, 1));

  /// Controller progress remapped onto the animation phase. Past
  /// [_animFraction] this clamps to 1.0, which is what makes the tail of
  /// the splash completely still rather than slowly drifting.
  double get _anim => (_c.value / _animFraction).clamp(0.0, 1.0);

  double _at(Interval i) => i.transform(_anim);

  @override
  Widget build(BuildContext context) {
    final m = _SplashMetrics.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        // GLOBAL BRAND, per DR-SELAH-094. Not genderGradient() — see the
        // note at the top of this file before changing it back.
        gradient: SelahColors.brandGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (widget.motion == null) {
              return SelahSplashArtworkFrame(
                direction: selahPrimarySplashDirection,
                progress: MediaQuery.disableAnimationsOf(context) ? 1 : _anim,
                // The launch design changes, not the canonical brand tagline.
                tagline: 'Connecting Through Trust',
              );
            }
            // ONE BLOCK — 2026-08-09. Founder: "SELAH and Connecting
            // Through Trust doesn't have space, so maybe the line is
            // below Connecting Through Trust."
            //
            // The wordmark and the tagline used to be separated by a
            // generous gap, which made them read as two things stacked on
            // one screen. They are now one unit with a hairline of space
            // between them, and the rule sits under the pair — so it
            // underlines the whole statement instead of dividing it.
            return Align(
              alignment: const Alignment(0, -0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        // Positioned light does not affect the wordmark's
                        // measured size, so every preserved motion keeps the
                        // approved centred composition in exactly one place.
                        left: -m.wordmark * 1.15,
                        right: -m.wordmark * 1.15,
                        top: -m.wordmark * 0.42,
                        bottom: -m.wordmark * 0.42,
                        child: SelahSplashBloom(
                          motion: widget.motion!,
                          progress: _anim,
                        ),
                      ),
                      _Wordmark(progress: _anim, size: m.wordmark),
                    ],
                  ),
                  SizedBox(height: m.gap),
                  Opacity(
                    opacity: _at(_tagline),
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - _at(_tagline))),
                      child: Text(
                        'Connecting Through Trust',
                        style: SelahText.subtext(
                          size: m.tagline,
                          color: SelahColors.ink(0.70),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: m.ruleGap),
                  SelahSplashDrawRule(
                    width: m.ruleWidth,
                    progress: _anim,
                    motion: widget.motion!,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Every dimension on this screen, derived from one number.
///
/// ── WHY. The composition was tuned by eye on a 390pt iPhone and every
/// size was hardcoded. Measured on other devices it degraded in both
/// directions, and the orbs degraded worse than the type:
///
///   iPhone SE 320pt  orbs are WIDER THAN THE SCREEN — they bleed off both
///                    edges and read as two blobs at the margins rather
///                    than two lights meeting
///   iPad 768pt       orbs small in a large field, flung far apart because
///                    the travel was a fraction of screen width; wordmark
///                    ~30% of the width and visibly lost
///
/// The wordmark itself never overflowed anywhere — Syne is narrow, so
/// "SELAH" at 74pt is only 229pt wide and clears a 320pt screen by 46pt
/// each side. The problem was proportion, not fit.
///
/// ── THE DESIGN WIDTH. Everything scales off `min(shortestSide, 480)`.
///
/// Capping at 480 is what makes tablets work: past that a phone
/// composition stops growing and simply centres in the extra space, which
/// is how a splash should behave on an iPad rather than stretching to
/// fill it.
///
/// Using the SHORTEST side, not the width, is what makes landscape work.
/// On a tablet turned sideways the width is enormous and the height is
/// what constrains the composition.
///
/// ── 390pt IS UNCHANGED, deliberately. 390 x 0.19 = 74.1, which is the
/// size the Founder approved on his own device. The ratios were chosen to
/// reproduce the approved composition exactly there and to fix everything
/// either side of it.
class _SplashMetrics {
  final double design;
  final double wordmark;
  final double tagline;

  /// Wordmark to tagline. TIGHT since 2026-08-09 — they are one block.
  final double gap;

  /// Tagline to the rule. The only generous space in the composition.
  final double ruleGap;

  /// Total width of the gold motion rule.
  final double ruleWidth;

  const _SplashMetrics._({
    required this.design,
    required this.wordmark,
    required this.tagline,
    required this.gap,
    required this.ruleGap,
    required this.ruleWidth,
  });

  factory _SplashMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final design = (size.shortestSide).clamp(280.0, 480.0);
    return _SplashMetrics._(
      design: design,
      // Clamps are a safety net, not the mechanism — at the capped design
      // width neither bound is reached. They exist so an unexpected
      // viewport (a foldable's cover screen, a desktop window) cannot
      // produce something absurd.
      wordmark: (design * 0.19).clamp(56.0, 96.0),
      // Formula moved to SelahText.taglineSize so the Welcome screen can
      // share it. Same ratio, floor lifted 11.0 -> 12.5.
      tagline: SelahText.taglineSize(context),
      // 0.0359 -> 0.0128 on 2026-08-09. That is 5pt on a 390pt phone,
      // down from 14 — the wordmark and the tagline are one block now,
      // and 14pt read as two separate things on one screen.
      gap: (design * 0.0128).clamp(4.0, 8.0),
      // 26pt on a 390pt phone. The rule needs real air above it or it
      // reads as an underline on the tagline rather than under the pair.
      ruleGap: (design * 0.0667).clamp(18.0, 34.0),
      // 60% of the design width — wider than the tagline, so the rule
      // holds the block rather than matching it.
      ruleWidth: design * 0.60,
    );
  }
}

/// Z · Y · R · A, each arriving in turn.
///
/// Four Texts in a Row rather than one Text, because each letter needs its
/// own opacity and offset. The last letter's tracking is zeroed — a
/// trailing 4pt on the final glyph would push the whole word 2pt left of
/// centre, which is exactly the kind of thing that looks like nothing and
/// feels wrong.
class _Wordmark extends StatelessWidget {
  final double progress;

  /// Passed in rather than hardcoded — see _SplashMetrics. 74 on the
  /// Founder's 390pt phone, which is the size he approved; smaller on an
  /// SE, larger on a tablet.
  final double size;
  const _Wordmark({required this.progress, required this.size});

  static const _letters = ['Z', 'Y', 'R', 'A'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_letters.length, (i) {
        final begin =
            _SplashScreenState._letterStart +
            i * _SplashScreenState._letterStagger;
        final t = Interval(
          begin,
          (begin + _SplashScreenState._letterLen).clamp(0.0, 1.0),
          curve: const Cubic(.22, .9, .3, 1),
        ).transform(progress);

        // The 74 that produced this on a 390pt phone came from the size
        // comparison the Founder approved — that widget was mislabelled
        // (cards ~215px standing in for a 390pt phone, a 0.55 scale, sizes
        // picked by eye rather than divided through), so the card marked
        // "60" was really drawing at ~74pt. Confirmed against a
        // true-device-scale render, then made proportional here.
        final base = SelahText.wordmark(size: size);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Text(
              _letters[i],
              style: i == _letters.length - 1
                  ? base.copyWith(letterSpacing: 0)
                  : base,
            ),
          ),
        );
      }),
    );
  }
}
