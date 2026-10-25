// The transitional-moment engine — inherited decision 147/148, built 2026-08-13.
//
// APP/Transitional Moments/TRANSITIONAL_MOMENTS_CURRENT_VERSION_V1.md is
// the governing document. The grammar it ratifies lives HERE, once:
//
//   A BREATH, THEN WORDS, THEN A STEP. Dark calm over the gender
//   gradient, one small mark, lines arriving one at a time (~600ms
//   apart), a single primary action last. Words carry it — no confetti,
//   no badges, no hearts.
//
//   ALWAYS TAP-THROUGH. Any tap settles the page instantly to its
//   finished state. A moment the user cannot skip is a toll, and tolls
//   read as disrespect. This is enforced by the engine, not by callers,
//   so no future moment can forget it.
//
//   ONE ACCENT PER MOMENT. `glow` for celebrations (warm lavender
//   radial), `closure` for endings (darker, stiller). Coral appears in
//   no moment — endings are dignified, not alarmed.
//
// Callers compose moments from lines; they never build their own page.
// That is how eighteen future moments stay one product instead of
// eighteen inventions.

import 'package:flutter/material.dart';
import '../models/seeker_profile.dart';
import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_profile_image.dart';

enum SelahMomentLineKind { whisper, heading, guiding, body, quiet }

class SelahMomentLine {
  final SelahMomentLineKind kind;
  final String text;
  const SelahMomentLine(this.kind, this.text);
  const SelahMomentLine.whisper(this.text) : kind = SelahMomentLineKind.whisper;
  const SelahMomentLine.heading(this.text) : kind = SelahMomentLineKind.heading;
  const SelahMomentLine.guiding(this.text) : kind = SelahMomentLineKind.guiding;
  const SelahMomentLine.body(this.text) : kind = SelahMomentLineKind.body;
  const SelahMomentLine.quiet(this.text) : kind = SelahMomentLineKind.quiet;
}

/// Push a moment as its own full-screen route. Resolves true when the
/// primary action is tapped, false for the secondary, null if popped
/// some other way. The route fades in over 400ms — arriving at a moment
/// is itself part of the moment.
Future<bool?> showSelahMoment(
  BuildContext context, {
  IconData? mark,
  SeekerProfile? pairWith,
  int? ringPercent,
  String? dateChip,
  bool glow = false,
  bool closure = false,
  required List<SelahMomentLine> lines,
  required String ctaLabel,
  String? secondaryLabel,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => SelahMomentScreen(
        mark: mark,
        pairWith: pairWith,
        ringPercent: ringPercent,
        dateChip: dateChip,
        glow: glow,
        closure: closure,
        lines: lines,
        ctaLabel: ctaLabel,
        secondaryLabel: secondaryLabel,
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class SelahMomentScreen extends StatefulWidget {
  final IconData? mark;

  /// The other person, when the moment is about a pair — rendered as two
  /// circular photos with the swap glyph between them. The viewer's side
  /// renders as a frost circle reading "You": honest, and free of the
  /// placeholder-photo problem the old match screen had.
  final SeekerProfile? pairWith;

  /// A compatibility figure, rendered as the ring (R1's reveal moment).
  final int? ringPercent;

  /// A letterspaced chip under the heading — the Marriage date.
  final String? dateChip;
  final bool glow;
  final bool closure;
  final List<SelahMomentLine> lines;
  final String ctaLabel;
  final String? secondaryLabel;

  /// When set, the actions call these instead of popping with a bool —
  /// for surfaces that ARE the route (MatchNotificationScreen embeds
  /// this screen directly rather than pushing it).
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  const SelahMomentScreen({
    super.key,
    this.mark,
    this.pairWith,
    this.ringPercent,
    this.dateChip,
    this.glow = false,
    this.closure = false,
    required this.lines,
    required this.ctaLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  @override
  State<SelahMomentScreen> createState() => _SelahMomentScreenState();
}

class _SelahMomentScreenState extends State<SelahMomentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// Seconds at which each element begins. The mark/pair/ring leads at
  /// 0.3s, lines follow ~600ms apart, the actions arrive last — the
  /// ratified pacing, computed once so every moment breathes alike.
  late final List<double> _starts;
  late final double _total;

  @override
  void initState() {
    super.initState();
    final elementCount =
        (_hasLead ? 1 : 0) +
        widget.lines.length +
        (widget.dateChip != null ? 1 : 0) +
        1;
    _starts = List.generate(elementCount, (i) => 0.3 + i * 0.6);
    _total = _starts.last + 0.9;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    )..forward();
  }

  bool get _hasLead =>
      widget.mark != null ||
      widget.pairWith != null ||
      widget.ringPercent != null;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// THE TAP-THROUGH RULE, enforced here for every moment ever built:
  /// any tap before the reveal finishes settles everything instantly.
  void _settle() {
    if (_c.value < 1) {
      _c.animateTo(1, duration: const Duration(milliseconds: 160));
    }
  }

  Widget _reveal(int index, Widget child) {
    final start = (_starts[index] / _total).clamp(0.0, 0.99);
    final end = ((_starts[index] + 0.8) / _total).clamp(start + 0.01, 1.0);
    final a = CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  Widget _line(SelahMomentLine l) => switch (l.kind) {
    SelahMomentLineKind.whisper => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        l.text,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 13.5, color: SelahColors.ink(0.72)),
      ),
    ),
    SelahMomentLineKind.heading => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        l.text,
        textAlign: TextAlign.center,
        style: SelahText.heading(size: 23),
      ),
    ),
    SelahMomentLineKind.guiding => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '“${l.text}”',
        textAlign: TextAlign.center,
        style: SelahText.subtext(
          size: 13,
          color: SelahColors.ink(0.72),
        ).copyWith(fontStyle: FontStyle.italic),
      ),
    ),
    SelahMomentLineKind.body => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        l.text,
        textAlign: TextAlign.center,
        style: SelahText.body(
          size: 13.5,
          color: SelahColors.ink(0.78),
        ).copyWith(height: 1.55),
      ),
    ),
    SelahMomentLineKind.quiet => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        l.text,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 11.5, color: SelahColors.ink(0.50)),
      ),
    ),
  };

  Widget _lead() {
    if (widget.ringPercent != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: widget.ringPercent! / 100,
                strokeWidth: 5,
                color: SelahColors.actionFill,
                backgroundColor: SelahColors.foreground.withValues(alpha: 0.14),
              ),
              Center(
                child: Text(
                  '${widget.ringPercent}%',
                  style: SelahText.heading(size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.pairWith != null) {
      final p = widget.pairWith!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circle(
              child: p.photos.isEmpty
                  ? Center(
                      child: Text(
                        p.firstName.isEmpty ? '?' : p.firstName[0],
                        style: SelahText.heading(size: 18),
                      ),
                    )
                  : SelahProfileImage(p.photoUrl, width: 56, height: 56),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.swap_horiz,
                size: 18,
                color: SelahColors.foreground.withValues(alpha: 0.6),
              ),
            ),
            _circle(
              child: Center(
                child: Text('You', style: SelahText.subtext(size: 11)),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Icon(
        widget.mark,
        size: 30,
        color: SelahColors.foreground.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _circle({required Widget child}) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: SelahColors.foreground.withValues(alpha: 0.18),
      border: Border.all(
        color: SelahColors.foreground.withValues(alpha: 0.45),
        width: 2,
      ),
    ),
    child: ClipOval(child: child),
  );

  @override
  Widget build(BuildContext context) {
    var i = 0;
    final children = <Widget>[if (_hasLead) _reveal(i++, _lead())];
    for (final l in widget.lines) {
      children.add(_reveal(i++, _line(l)));
      if (l.kind == SelahMomentLineKind.heading && widget.dateChip != null) {
        children.add(
          _reveal(
            i++,
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.dateChip!,
                style: SelahText.subtext(
                  size: 11,
                  color: SelahColors.ink(0.60),
                ).copyWith(letterSpacing: 2),
              ),
            ),
          ),
        );
      }
    }
    children.add(
      _reveal(
        i++,
        Column(
          children: [
            SizedBox(height: 12),
            SizedBox(
              width: 230,
              child: Material(
                color: SelahColors.foreground.withValues(alpha: 0.22),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: SelahColors.foreground.withValues(alpha: 0.42),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap:
                      widget.onPrimary ?? () => Navigator.of(context).pop(true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Center(
                      child: Text(
                        widget.ctaLabel,
                        style: SelahText.button(size: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.secondaryLabel != null)
              TextButton(
                onPressed:
                    widget.onSecondary ??
                    () => Navigator.of(context).pop(false),
                child: Text(
                  widget.secondaryLabel!,
                  style: SelahText.subtext(size: 12),
                ),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _settle,
        child: Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            gradient: SelahColors.genderGradient(AppState.instance.gender),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.closure
                    ? [const Color(0xB8140C1A), const Color(0xE60A060E)]
                    : [const Color(0x8C140C1A), const Color(0xC7140C1A)],
              ),
            ),
            child: Stack(
              children: [
                if (widget.glow)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x47CEA2D1), Color(0x00CEA2D1)],
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 34,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The IN-PLACE BEAT — the no-page weight. The next screen acknowledges
/// what just happened with one settling line, then gets on with its
/// work. Used where the ratified answer was "no page, on purpose":
/// after Greeting Exchange, after Shepherd Gate, on Resume.
class SelahStageBeat extends StatelessWidget {
  final String text;
  final String? sub;
  const SelahStageBeat({super.key, required this.text, this.sub});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x29CEA2D1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x73CEA2D1)),
        ),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: SelahText.body(size: 12.5, color: Colors.white),
            ),
            if (sub != null) ...[
              SizedBox(height: 3),
              Text(
                sub!,
                textAlign: TextAlign.center,
                style: SelahText.subtext(
                  size: 10.5,
                  color: SelahColors.ink(0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
