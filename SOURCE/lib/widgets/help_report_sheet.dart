// Help/Report menu — dark-glass bottom sheet.
//
// PRESENTATION HISTORY, because this has moved five times and the reasons
// matter more than the moves:
//
//   1. anchored card from a top-right "..." icon
//   2. centred showDialog card, dark glass
//   3. bottom sheet in the solid brand gradient  (2026-07-27)
//   4. bottom sheet, dark translucent glass      (2026-07-27, 3rd pass)
//   5. bottom sheet, ratified gender gradient    (2026-08-01)
//   6. centred glass card                        (2026-08-01)
//   7. BOTTOM SHEET, RATIFIED SHEET GLASS        (2026-08-11, current)
//
// The file was `help_report_card.dart` / class `HelpReportCard` through
// stages 1–2 and was renamed at stage 3 to match what it had become. At
// stage 7 the name is accurate again.
//
// STAGE 7 (Founder, screenshot review of stage 6: "im 50/50 on it.
// theres somethign i dont like about it… lets see if it matches the
// general ui" — plus the approved Frost UI brief, Fable session
// 2026-08-11). What the 50/50 was, named: the centred card floats
// mid-screen ANCHORED TO NOTHING, directly over the person's face — and
// in this app every other small menu either hangs off the control that
// opened it (anchored_card_overlay.dart) or rises from a screen edge.
// An unanchored rectangle over a photo reads as system UI, not SELAH.
//
// So: back to a bottom sheet — it rises from an edge, never covers the
// face, and keeps "closed by tapping anywhere else" via the barrier.
// NOT a return to stage 4/5's look, and the difference is the point:
//   - surface is SelahColors.sheetSurface, the base RATIFIED for bottom
//     sheets app-wide in selah_colors.dart's 2026-08-01 block ("a surface
//     anchored to the bottom of the screen… continuous with whatever
//     gradient is behind it"). Stage 5's gender gradient predated that
//     ratification; stage 4's dark glass was the unratified near-black.
//   - blur σ30 kept from stage 6, so the photo still reads through.
//
// The stage-6 glass recipe (white 14/22, radius 24, inset 36) remains
// the ratified language for CENTRED surfaces (selah_glass_dialog.dart) —
// this is the edge-anchored counterpart, not a replacement for it.
//
// Opened from browse_screen.dart's long-press-centre gesture
// (_openHelpReportSheet, now showModalBottomSheet) — see that file's
// header for the gesture history, including why the hold is 300ms and
// not Flutter's default.
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

class HelpReportSheet extends StatelessWidget {
  final VoidCallback onHelp;
  final VoidCallback onReport;

  /// Retained for call-site compatibility and still unused at stage 7 —
  /// the sheet wears the ratified neutral sheetSurface, not a gender
  /// gradient (see the stage-7 note above).
  final String? gender;

  const HelpReportSheet({
    super.key,
    required this.onHelp,
    required this.onReport,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          // Uses the same opaque modal surface as every other bottom sheet,
          // so the background beneath it cannot alter the perceived colour.
          decoration: BoxDecoration(
            color: SelahColors.modalSheetSurface,
            border: Border(
              top: BorderSide(color: SelahColors.ink(0.14), width: 1),
            ),
          ),
          // Clears the home indicator; the rows keep their own touch
          // padding.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The drag handle returns with the sheet (it left at stage
              // 6 because a centred card is not draggable).
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: SelahColors.ink(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // SPLIT 2026-08-01 (Founder: "the 2 options open the
              // same thing"). Both rows used to push
              // HelpSupportScreen, so there was no way to report
              // anyone in SELAH at all. They are now genuinely
              // different destinations:
              //
              //   Report  -> about a PERSON. Reason list, writes to
              //              profile_reports, blocks them.
              //   Help    -> about the APP. Billing, bugs, how
              //              things work. No subject.
              //
              // Subtitles were added and removed the same day
              // (Founder: "it doesn't seem correct to write
              // 'something wrong with this person'"). Correct call —
              // they were solving a problem that stopped existing
              // the moment the two rows pointed somewhere different.
              _Row(
                icon: Icons.flag_outlined,
                label: 'Report this profile',
                onTap: onReport,
              ),
              Divider(
                color: SelahColors.ink(0.12),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              _Row(
                icon: Icons.help_outline,
                label: 'Help and support',
                onTap: onHelp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: SelahColors.ink(0.8), size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: SelahText.body(size: 15, color: SelahColors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
