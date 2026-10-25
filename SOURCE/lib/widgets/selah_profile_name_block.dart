// THE NAME BLOCK — one definition, every surface that shows a person.
//
// inherited decision 163, 2026-08-13 (Founder: "in Connections, in profile cards
// when there's the photo it says name, age and underneath location, but
// it's not matching the Browse design. Make it copy the Browse style.
// That applies to all profile views in Connections, in card format or
// full profile").
//
// ── WHY A WIDGET AND NOT A COPY OF BROWSE'S LAYOUT.
//
// The obvious reading of "make it copy the Browse style" is to go and
// retype Browse's block in three more places. That is what this session
// already did with the nav bar, four times, before inherited decision 159 deleted
// the copy: a replica converges on the thing it copies and never
// arrives, because every later change to the original has to be noticed
// and mirrored by hand.
//
// The name block has already drifted exactly that way. Before this file
// there were four versions of one idea:
//
//   Browse            Arif Iqbal      /  36 · Derby
//   Full profile      Arif / Iqbal    /  36 · Derby      (surname own line)
//   Card hero         Arif, 36        /  📍 Derby        (comma, pin icon)
//   Journey hero      Arif, 36        /  📍 Derby        (same again)
//
// Nobody decided on four. They accumulated, because each was written
// where it was needed. One widget is the only version of "copy the
// Browse style" that is still true next month.
//
// ── THREE LINES: FIRST NAME · SURNAME · AGE · LOCATION.
//
// REVERTED 2026-08-13, same day (inherited decision 164, Founder: "revert the name
// surname age area back to old design... line one first name, line 2
// middle surname, line 3 age dot location"). The one-line version
// (inherited decision 162, option C of five) lasted a few hours on device.
//
// THE MIDDLE DOT SURVIVES THE REVERT, and it is the only part of that
// pass that does — "the only small difference is instead of | keep the
// centre dot separating age and location". So the layout goes back and
// the separator stays forward, which is a narrower change than either
// "revert it" or "keep it" on its own.
//
// The reversal costs nothing structural, and that is the point of the
// widget existing: one file changed, and Browse, the full profile and
// both Connections heroes all moved together. Before inherited decision 163 this
// would have been four edits with four chances to leave one behind.
//
// ── PROPORTIONS, NOT SIZES.
//
// Callers pass ONE number, [nameSize]. The surname and the meta line are
// derived from it, so a block at 20pt is the same design as a block at
// 30pt rather than a second set of choices. The ratios are Browse's own
// (30 / 18 / 16).
//
// The meta line has a floor of 12pt. Pure ratio would put it at 10.7 on
// a card hero, which is below where this app lets secondary text go.

import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_text.dart';

/// Two-layer shadow for any text sitting directly on a photograph.
///
/// MOVED HERE from browse_screen.dart, 2026-08-13. It was private to
/// that file, so every other surface drawing text on a photo either did
/// without it or invented its own — which is why the Connections heroes
/// leant on a scrim alone and read as flatter than Browse.
///
/// Two layers on purpose: a tight dark shadow for edge definition
/// against a pale photo, and a wide soft one that lifts the whole block
/// off a busy background without looking like a drop shadow.
const List<Shadow> kSelahOnPhotoTextShadows = [
  Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1)),
  Shadow(color: Color(0x99000000), blurRadius: 14),
];

class SelahProfileNameBlock extends StatelessWidget {
  final SeekerProfile profile;

  /// The first name's size. Everything else is derived — see the header.
  final double nameSize;

  /// Applies [kSelahOnPhotoTextShadows]. True wherever the block sits on
  /// a photograph; false on a solid or frosted surface, where a shadow
  /// is smudge rather than legibility.
  final bool onPhoto;

  /// Drops the surname. For narrow surfaces where a wrapped name would
  /// change the row's height — not a style choice, a space one.
  final bool showSurname;

  const SelahProfileNameBlock({
    super.key,
    required this.profile,
    this.nameSize = 30,
    this.onPhoto = true,
    this.showSurname = true,
  });

  double get _surnameSize => nameSize * 0.6;
  double get _metaSize => nameSize * 0.533 < 12 ? 12 : nameSize * 0.533;

  @override
  Widget build(BuildContext context) {
    final shadows = onPhoto ? kSelahOnPhotoTextShadows : const <Shadow>[];
    final surname = (profile.surnameLine ?? '').trim();
    final hasSurname = showSurname && surname.isNotEmpty;

    // The city can legitimately be withheld rather than missing — a
    // counterpart card returns '—' by design (clause 3, 2026-08-08). Show
    // the age alone rather than "36 · —", which reads as a bug.
    final city = profile.city.trim();
    final hasCity = city.isNotEmpty && city != '—';
    final meta = profile.age > 0
        ? (hasCity ? '${profile.age} · $city' : '${profile.age}')
        : (hasCity ? city : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // LINE 1 — the first name.
        Text(
          profile.firstName,
          style: SelahText.heading(
            size: nameSize,
          ).copyWith(fontWeight: FontWeight.w600, shadows: shadows),
        ),
        // LINE 2 — the surname, on its own line (Founder, 2026-07-26:
        // "first line is Bilal, second line is Abdul Malik", restored
        // 2026-08-13 after the inline version was tried on device).
        //
        // LIGHTER WEIGHT, NOT A DIMMER COLOUR — measured 2026-08-01:
        // dimming white on a white photo subtracts from nothing, and
        // weight is what was making the surname read as secondary all
        // along. w500 against the name's w600, at 0.6 of its size.
        if (hasSurname) ...[
          const SizedBox(height: 2),
          Text(
            surname,
            style: SelahText.heading(size: _surnameSize).copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w500,
              shadows: shadows,
            ),
          ),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          // LINE 3 — a MIDDLE DOT, not a drawn rule and not a pin icon.
          // The one part of the 2026-08-13 layout pass the Founder kept
          // when the rest was reverted.
          //
          // The rule it replaced (Browse) could take no text shadow, so
          // it needed its own alpha raised to stay visible on a bright
          // photo. The pin it replaced (the Connections heroes) said
          // "this is a location" to someone who could already tell.
          // Punctuation sits on the baseline, takes the same shadow as
          // the words either side, and scales with them.
          Text(
            meta,
            style: SelahText.body(
              size: _metaSize,
              color: Colors.white,
            ).copyWith(shadows: shadows),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
