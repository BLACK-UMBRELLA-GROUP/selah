// FULL PROFILE — read-only, for someone you are already in a Journey with.
//
// Founder, 2026-08-10: "we need somewhere where the user can view full
// profile which doesn't take them to browse page.. but I want somewhere they
// can see full photo".
//
// WHY THIS IS A NEW SCREEN AND NOT A REUSE. Before today there was no way to
// look at another person's profile except Browse. "View profile" elsewhere in
// the app does not open a profile at all — it switches the shell to the Browse
// tab and parks the profile there (browse_screen.dart:399,
// connections_screen.dart:87). That is fine for a suggestion you are about to
// decide on, and wrong for someone you are mid-Journey with: Browse is the
// DECIDING surface, carrying Save / Consider / Pass. Sending a Seeker there to
// look at the person they are ALREADY in a Journey with offers them decisions
// they have already made, on a screen whose whole job is making them.
//
// So: no actions on this screen. It is a place to look, not to choose.
//
// AMENDED 2026-08-12 (Founder, Option A of the row-tap mockups: "the row
// IS the person… execute all of it"): the JOURNEY LIST rows now open this
// screen for Potential, Paused and Ended people, and those states carry
// their actions WITH them — an optional [actionBar] rendered at the foot,
// and an optional [stateLabel] chip at the top right. The screen itself
// stays action-agnostic: it renders what it is handed and never decides.
// The Journey header's own "Profile" pill passes neither, so mid-Journey
// viewing is exactly the no-actions place it always was. Browse remains
// the only deciding surface for people you are NOT yet matched with.
//
// PHOTO NAVIGATION MATCHES BROWSE — Founder, 2026-08-10. This was briefly a
// swipeable PageView with dots across the top, which is a second convention
// for the one gesture people use most in this app. Browse settled it long ago:
//   • TAP the left or right half to step back or forward
//   • a VERTICAL dot column on the LEFT edge, middle-aligned
//   • 7px dots, 3px apart, white when active, white32 when not, hairline
//     white30 border so they read on a pale photograph
// Copied to the pixel from browse_screen.dart's own indicator rather than
// approximated, because "nearly the same" is how two conventions start.
//
// WHAT IT CAN SHOW is bounded by SeekerProfile — id, firstName, surnameLine,
// age, city, photos, gender. No bio, occupation or education. Stated rather
// than padded with placeholders: an empty "About" section would imply the data
// exists and is missing, when it has never been modelled.
//
// PHOTO VISIBILITY IS ENFORCED SERVER-SIDE. profile_photos is filtered by
// selah_can_view_profile, verified by impersonation on 2026-08-08. This screen
// renders what it was handed; it is not a gate and must never become one.

import 'package:flutter/material.dart';
import '../../models/seeker_profile.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_name_block.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_pull_down_back_scope.dart';

class SeekerProfileScreen extends StatefulWidget {
  final SeekerProfile profile;

  /// Small chip at the top right — "Paused · 3 months", "Potential",
  /// "Ended in June". Null (the Journey header's use) shows
  /// nothing.
  final String? stateLabel;

  /// The state's actions, rendered at the foot over the photo. The
  /// CALLER owns every button in it (what they say, what they pop, what
  /// they push) — this screen only makes room. Null = the original
  /// look-only screen, unchanged.
  final Widget? actionBar;

  /// A line under the name — who put this person forward.
  ///
  /// ADDED 2026-08-13 (DR-SELAH-160, Founder: "when profile card is
  /// opened show somewhere the text suggested by (then user)"). It
  /// replaces the [stateLabel] chip the introduction flow used to pass,
  /// and the position is the point of the change: a chip in the top
  /// right sat on the photo, away from the person it describes. Under
  /// the name it reads as part of who they are — which is what a
  /// Shepherd's introduction is.
  ///
  /// Same shield glyph the Connections card uses for the same fact, so
  /// the two surfaces say it the same way.
  final String? suggestedBy;

  /// Connections presents a profile as a temporary, full-screen look at the
  /// person rather than as another page in the app hierarchy. Those callers
  /// opt into a downward dismissal gesture and omit the top-left close icon;
  /// all other callers retain the established close-button behaviour.
  final bool swipeDownToDismiss;

  /// Lets the route beneath show through while the full-screen profile is
  /// dragged down. Owner preview uses this to reveal Profile instead of an
  /// unrelated black field. Other profile viewers retain black behind the
  /// photo unless their caller deliberately opts in with a non-opaque route.
  final bool revealRouteOnSwipeDismiss;

  /// Keeps the explicit top-left close control available while downward
  /// dismissal is enabled. Most Connections callers use the gesture-only
  /// presentation; Shepherd Network offers both because the profile is a
  /// temporary inspection surface reached from a dense browsing flow.
  final bool showCloseButtonWhenSwipeDismiss;

  /// Optional presentation for an owner preview before any photo has been
  /// added. Other-person viewers keep the existing privacy-safe dark field.
  final Widget? emptyPhoto;

  /// Uses Browse's exact 340px scrim and 130px identity position. Kept
  /// opt-in because Journey and Connections viewers intentionally place the
  /// identity nearer the bottom when no app navigation sits above it.
  final bool matchBrowseIdentityLayout;

  /// Caller-owned navigation for an embedded, bounded owner preview. Existing
  /// full-profile routes keep their original dismissal when this is absent.
  final VoidCallback? onDismiss;
  final bool Function()? canAct;

  const SeekerProfileScreen({
    super.key,
    required this.profile,
    this.stateLabel,
    this.actionBar,
    this.suggestedBy,
    this.swipeDownToDismiss = false,
    this.revealRouteOnSwipeDismiss = false,
    this.showCloseButtonWhenSwipeDismiss = false,
    this.emptyPhoto,
    this.matchBrowseIdentityLayout = false,
    this.onDismiss,
    this.canAct,
  });

  @override
  State<SeekerProfileScreen> createState() => _SeekerProfileScreenState();
}

class _SeekerProfileScreenState extends State<SeekerProfileScreen> {
  int _photoIndex = 0;
  double _dismissOffset = 0;
  bool _draggingToDismiss = false;
  late final bool _callerOwned = widget.onDismiss != null;
  late final VoidCallback? _ownerDismiss = widget.onDismiss;
  late final bool Function()? _ownerGuard = widget.canAct;
  final Object _returnIdentity = Object();
  bool _revoked = false;

  bool get _canAct {
    if (!mounted || _revoked) return false;
    if (!_callerOwned) return widget.onDismiss == null;
    try {
      if (widget.onDismiss == null ||
          !identical(widget.onDismiss, _ownerDismiss) ||
          _ownerGuard?.call() != true ||
          widget.canAct?.call() != true) {
        _revoked = true;
        return false;
      }
      return ModalRoute.of(context)?.isCurrent ?? true;
    } catch (_) {
      _revoked = true;
      return false;
    }
  }

  // The shared pull scope binds this callback for the route's whole lifetime.
  // ignore: prefer_function_declarations_over_variables
  late final VoidCallback _return = () {
    if (_canAct) {
      _ownerDismiss?.call();
    } else if (mounted) {
      setState(() {});
    }
  };

  static const double _kDismissVelocity = 650;

  void _startDismissDrag(DragStartDetails details) {
    setState(() => _draggingToDismiss = true);
  }

  void _updateDismissDrag(DragUpdateDetails details) {
    final next = (_dismissOffset + details.delta.dy).clamp(
      0.0,
      double.infinity,
    );
    setState(() => _dismissOffset = next.toDouble());
  }

  void _endDismissDrag(DragEndDetails details, double height) {
    final threshold = height * 0.14;
    final velocity = details.primaryVelocity ?? 0;
    if (_dismissOffset >= threshold || velocity >= _kDismissVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _draggingToDismiss = false;
      _dismissOffset = 0;
    });
  }

  void _cancelDismissDrag() {
    setState(() {
      _draggingToDismiss = false;
      _dismissOffset = 0;
    });
  }

  /// Left half steps back, right half steps forward. Same rule and same
  /// wrap behaviour as browse_screen.dart's `_tapPhoto`: forward wraps to
  /// the first photo, back STOPS at the first rather than wrapping to the
  /// last. That asymmetry is deliberate there and is kept here — going
  /// forward is browsing, going back is correcting, and a correction that
  /// jumps you to the end is not a correction.
  void _tapPhoto(TapUpDetails details, double width) {
    if (!_canAct) {
      if (mounted) setState(() {});
      return;
    }
    final photos = widget.profile.photos;
    if (photos.length <= 1) return;
    final goRight = details.localPosition.dx > width / 2;
    setState(() {
      if (goRight) {
        _photoIndex = _photoIndex >= photos.length - 1 ? 0 : _photoIndex + 1;
      } else {
        _photoIndex = _photoIndex <= 0 ? 0 : _photoIndex - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if ((_callerOwned && !_canAct) ||
        (widget.onDismiss != null) != _callerOwned) {
      return const SizedBox.expand(
        key: ValueKey('seeker-profile-preview-unavailable'),
      );
    }
    final p = widget.profile;
    final photos = p.photos;
    // Guard the index the way browse_screen learned to: a stale index against
    // a shorter list threw there once, and the fix was to clamp at the read
    // rather than trust every writer.
    final safeIndex = _photoIndex < photos.length ? _photoIndex : 0;

    final page = Scaffold(
      // Black, not the gender gradient. Every other surface in the app is
      // gradient-backed; here the photo IS the content, and a gradient behind
      // a full-bleed image is a gradient nobody sees, tinting the edges of
      // someone's face for no reason.
      backgroundColor: widget.revealRouteOnSwipeDismiss
          ? Colors.transparent
          : Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: widget.swipeDownToDismiss
              ? const ValueKey('connections-profile-swipe-surface')
              : null,
          onTapUp: (d) => _tapPhoto(d, constraints.maxWidth),
          onVerticalDragStart: widget.swipeDownToDismiss && !_callerOwned
              ? _startDismissDrag
              : null,
          onVerticalDragUpdate: widget.swipeDownToDismiss && !_callerOwned
              ? _updateDismissDrag
              : null,
          onVerticalDragEnd: widget.swipeDownToDismiss && !_callerOwned
              ? (details) => _endDismissDrag(details, constraints.maxHeight)
              : null,
          onVerticalDragCancel: widget.swipeDownToDismiss && !_callerOwned
              ? _cancelDismissDrag
              : null,
          child: AnimatedContainer(
            duration: _draggingToDismiss
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _dismissOffset, 0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: photos.isEmpty && widget.emptyPhoto != null
                      ? widget.emptyPhoto!
                      : _callerOwned &&
                            photos.isNotEmpty &&
                            photos[safeIndex].startsWith('assets/')
                      ? Image.asset(
                          photos[safeIndex],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Colors.black),
                        )
                      : SelahProfileImage(
                          photos.isEmpty ? '' : photos[safeIndex],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),

                // Legibility scrim. The name sits over a photograph nobody chose
                // for its contrast, so the text needs its own background rather
                // than hoping the image is dark at the bottom.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: widget.matchBrowseIdentityLayout ? 340 : 260,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: widget.matchBrowseIdentityLayout
                              ? const [
                                  Colors.transparent,
                                  Color(0x4D000000),
                                  Color(0xB3000000),
                                ]
                              : const [Color(0x00000000), Color(0xE6000000)],
                          stops: widget.matchBrowseIdentityLayout
                              ? const [0.0, 0.32, 1.0]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // LEFT-SIDE VERTICAL DOTS — browse_screen.dart's indicator,
                // matched exactly. Only when there is more than one photo: a
                // single dot says "there is more" and there is not.
                if (photos.length > 1)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(photos.length, (i) {
                          final active = i == safeIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.32),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                Positioned(
                  key: const ValueKey('seeker-profile-identity'),
                  // The name block lifts to make room when a state's action
                  // bar rides along (journey rows); look-only callers keep
                  // the original resting place.
                  left: 20,
                  right: 20,
                  bottom: widget.matchBrowseIdentityLayout
                      ? 130
                      : widget.actionBar == null
                      ? 32
                      : 132,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // THE SHARED BLOCK — DR-SELAH-163. The surname
                        // had its own line here, per the 2026-07-26 Browse
                        // review; Browse itself moved it inline on
                        // 2026-08-13 (DR-SELAH-162) and this followed it,
                        // by using the same widget rather than by being
                        // edited to match. It also gains the two-layer
                        // photo shadow, which was private to Browse and so
                        // never reached this screen at all.
                        SelahProfileNameBlock(profile: p),
                        if ((widget.suggestedBy ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Suggested by ${widget.suggestedBy!.trim()}',
                                  style: SelahText.subtext(
                                    size: 12.5,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (!widget.swipeDownToDismiss ||
                    widget.showCloseButtonWhenSwipeDismiss)
                  Positioned(
                    top: 0,
                    left: 4,
                    child: SafeArea(
                      child: IconButton(
                        key: const ValueKey('seeker-profile-close'),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 26,
                        ),
                        tooltip: 'Close',
                        onPressed: () {
                          if (_callerOwned) {
                            _return();
                          } else if (mounted &&
                              (ModalRoute.of(context)?.isCurrent ?? false)) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ),

                if (widget.swipeDownToDismiss)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Semantics(
                        label: 'Swipe down to close profile',
                        child: Center(
                          child: Container(
                            key: const ValueKey(
                              'connections-profile-swipe-handle',
                            ),
                            margin: const EdgeInsets.only(top: 9),
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (widget.stateLabel != null)
                  Positioned(
                    top: 8,
                    right: 16,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x59140C1A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          widget.stateLabel!,
                          style: SelahText.subtext(
                            size: 10.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (widget.actionBar != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: widget.actionBar!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!_callerOwned) return page;
    return SelahPullDownBackScope(
      key: const ValueKey('concept_pull_down_back_scope'),
      routeIdentity: _returnIdentity,
      onBack: _return,
      enabled: _canAct,
      child: page,
    );
  }
}
