// SELAH typography — Jost is bundled and is the current Quiet Sanctuary
// reading face. Its open, humanist construction gives Selah a calmer rhythm
// than the inherited Poppins/Syne pairing and never requires a font download.
// Weights: 300 (headings/body), 400 (buttons), 500 (wordmark/emphasis).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'selah_colors.dart';

/// The eighteen body-type candidates available in Developer Tools.
///
/// This deliberately excludes the SELAH wordmark: [SelahText.wordmark] stays
/// Jost regardless of this selection, so comparing the app's reading face
/// can never accidentally reopen the current brand mark.
enum SelahAppFont {
  jost('Jost · Current', 'Jost'),
  manrope('Manrope', 'Manrope'),
  dmSans('DM Sans', 'DM Sans'),
  plusJakartaSans('Plus Jakarta Sans', 'Plus Jakarta Sans'),
  outfit('Outfit', 'Outfit'),
  urbanist('Urbanist', 'Urbanist'),
  montserrat('Montserrat', 'Montserrat'),
  raleway('Raleway', 'Raleway'),
  lora('Lora', 'Lora'),
  cormorantGaramond('Cormorant Garamond', 'Cormorant Garamond'),
  inter('Inter', 'Inter'),
  poppins('Poppins · Archive', 'Poppins'),
  nunitoSans('Nunito Sans', 'Nunito Sans'),
  sourceSans3('Source Sans 3', 'Source Sans 3'),
  workSans('Work Sans', 'Work Sans'),
  quicksand('Quicksand', 'Quicksand'),
  libreBaskerville('Libre Baskerville', 'Libre Baskerville'),
  merriweather('Merriweather', 'Merriweather');

  final String label;
  final String family;
  const SelahAppFont(this.label, this.family);
}

class SelahText {
  SelahText._();

  /// Current Quiet Sanctuary launch default, 2026-10-13.
  static const SelahAppFont currentDefaultFont = SelahAppFont.jost;

  /// In-memory on purpose: this is a protected Founder comparison tool, not a
  /// member preference. The chosen face survives navigation for the running
  /// test session and resets to official Jost on relaunch.
  static final ValueNotifier<SelahAppFont> appFontSelection =
      ValueNotifier<SelahAppFont>(currentDefaultFont);

  /// Flutter widget tests deliberately block HTTP. This keeps typography
  /// policy tests focused on selection/rebuild behaviour without starting
  /// asynchronous Google Font downloads that the test binding must refuse.
  @visibleForTesting
  static bool useTestFontStubs = false;

  /// Golden tests may supply bundled aliases so screenshot evidence retains
  /// real glyphs and production metrics without network access. Ordinary
  /// widget tests leave these null and retain the lightweight stub behaviour.
  @visibleForTesting
  static String? testReadingFontFamily;

  @visibleForTesting
  static String? testWordmarkFontFamily;

  static SelahAppFont get appFont => appFontSelection.value;

  static void selectAppFont(SelahAppFont font) {
    if (appFontSelection.value != font) appFontSelection.value = font;
  }

  /// Restores the official reading face before the first frame. A legacy
  /// member font choice is ignored; only protected Developer Tools can make
  /// a temporary comparison selection during the current session.
  static void restoreAppFont(String? _) {
    appFontSelection.value = currentDefaultFont;
  }

  static TextStyle _appStyle({
    required double size,
    required FontWeight weight,
    required Color? color,
    double? letterSpacing,
    SelahAppFont? font,
  }) {
    final selected = font ?? appFont;
    if (useTestFontStubs) {
      return TextStyle(
        fontFamily: testReadingFontFamily ?? selected.family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
    return switch (selected) {
      // Jost is bundled in pubspec as the live default. Resolve it
      // synchronously so first paint and offline use never trigger the
      // google_fonts runtime loader or a post-paint text re-layout.
      SelahAppFont.jost => TextStyle(
        fontFamily: SelahAppFont.jost.family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.manrope => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.dmSans => GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.plusJakartaSans => GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.outfit => GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.urbanist => GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.montserrat => GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.raleway => GoogleFonts.raleway(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.lora => GoogleFonts.lora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.cormorantGaramond => GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.inter => GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      // Poppins is bundled in pubspec as the live default. Resolve it
      // synchronously so first paint and offline use never trigger the
      // google_fonts runtime loader (which can re-layout text after paint).
      SelahAppFont.poppins => TextStyle(
        fontFamily: SelahAppFont.poppins.family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.nunitoSans => GoogleFonts.nunitoSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.sourceSans3 => GoogleFonts.sourceSans3(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.workSans => GoogleFonts.workSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.quicksand => GoogleFonts.quicksand(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.libreBaskerville => GoogleFonts.libreBaskerville(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
      SelahAppFont.merriweather => GoogleFonts.merriweather(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
    };
  }

  /// Candidate-specific rendering for the eighteen-option comparison list.
  static TextStyle preview(
    SelahAppFont font, {
    double size = 14,
    FontWeight weight = FontWeight.w300,
    Color? color,
  }) => _appStyle(
    size: size,
    weight: weight,
    color: color ?? SelahColors.foreground,
    font: font,
  );

  /// Covers the small number of Material widgets that use theme defaults
  /// instead of an explicit SelahText style.
  static TextTheme textTheme(TextTheme base) => useTestFontStubs
      ? base.apply(fontFamily: testReadingFontFamily ?? appFont.family)
      : switch (appFont) {
          SelahAppFont.jost => base.apply(fontFamily: SelahAppFont.jost.family),
          SelahAppFont.manrope => GoogleFonts.manropeTextTheme(base),
          SelahAppFont.dmSans => GoogleFonts.dmSansTextTheme(base),
          SelahAppFont.plusJakartaSans => GoogleFonts.plusJakartaSansTextTheme(
            base,
          ),
          SelahAppFont.outfit => GoogleFonts.outfitTextTheme(base),
          SelahAppFont.urbanist => GoogleFonts.urbanistTextTheme(base),
          SelahAppFont.montserrat => GoogleFonts.montserratTextTheme(base),
          SelahAppFont.raleway => GoogleFonts.ralewayTextTheme(base),
          SelahAppFont.lora => GoogleFonts.loraTextTheme(base),
          SelahAppFont.cormorantGaramond =>
            GoogleFonts.cormorantGaramondTextTheme(base),
          SelahAppFont.inter => GoogleFonts.interTextTheme(base),
          SelahAppFont.poppins => base.apply(
            fontFamily: SelahAppFont.poppins.family,
          ),
          SelahAppFont.nunitoSans => GoogleFonts.nunitoSansTextTheme(base),
          SelahAppFont.sourceSans3 => GoogleFonts.sourceSans3TextTheme(base),
          SelahAppFont.workSans => GoogleFonts.workSansTextTheme(base),
          SelahAppFont.quicksand => GoogleFonts.quicksandTextTheme(base),
          SelahAppFont.libreBaskerville =>
            GoogleFonts.libreBaskervilleTextTheme(base),
          SelahAppFont.merriweather => GoogleFonts.merriweatherTextTheme(base),
        };

  static TextStyle heading({double size = 20, Color? color}) => _appStyle(
    size: size,
    weight: SelahColors.isWafaPreview ? FontWeight.w600 : FontWeight.w300,
    color: color ?? SelahColors.foreground,
  );

  /// One reading-face size, weight and colour for the main tab headings.
  static const double pageTitleSize = 26;
  static TextStyle pageTitle() => heading(size: pageTitleSize);

  /// Selah's live wordmark uses the same bundled Jost family at medium weight
  /// with wide tracking. The consistency is intentional: the sanctuary mark,
  /// colour and spacing carry the identity rather than an inherited display
  /// face. Native icon assets are separate release artifacts and must be
  /// regenerated and visually accepted before a public release.
  static TextStyle wordmark({double size = 34, Color? color}) =>
      useTestFontStubs
      ? TextStyle(
          fontFamily: testWordmarkFontFamily ?? 'Jost',
          fontSize: size,
          fontWeight: FontWeight.w500,
          color: color ?? SelahColors.splashWordmark,
          letterSpacing: 6,
        )
      : TextStyle(
          fontFamily: 'Jost',
          fontSize: size,
          fontWeight: FontWeight.w500,
          color: color ?? SelahColors.splashWordmark,
          letterSpacing: 6,
        );

  static TextStyle body({double size = 13, Color? color}) => _appStyle(
    size: size,
    weight: FontWeight.w300,
    color: color ?? SelahColors.foregroundBody,
  );

  static TextStyle subtext({double size = 12.5, Color? color}) => _appStyle(
    size: size,
    weight: FontWeight.w300,
    color: color ?? SelahColors.foregroundSecondary,
  );

  /// "Connecting Through Trust" — ONE size, two screens.
  ///
  /// Added 2026-08-09 after the Founder asked whether the splash and the
  /// Welcome screen matched. They did not, and the difference reversed
  /// depending on the device:
  ///
  ///   device        splash   Welcome
  ///   iPhone SE      11.00     12.50   <- Welcome bigger
  ///   iPhone 14/15   12.99     12.50
  ///   Pro Max        14.32     12.50
  ///   iPad           15.98     12.50
  ///
  /// The splash scaled with the screen; Welcome was a hardcoded 12.5 from
  /// [subtext]'s default, which is the size of ordinary body subtext and
  /// not a decision anyone made about the tagline.
  ///
  /// Founder's rule was "choose the bigger one". Because the winner
  /// changes by device, that is not one number — it is the splash's own
  /// ratio with the floor lifted from 11.0 to 12.5, which is >= both
  /// values at every width. Small phones stop shrinking it; everything
  /// else keeps scaling.
  ///
  /// Both screens now call this. Neither hardcodes a tagline size.
  static double taglineSize(BuildContext context) {
    final design = MediaQuery.sizeOf(context).shortestSide.clamp(280.0, 480.0);
    return (design * 0.0333).clamp(12.5, 17.0);
  }

  static TextStyle option({double size = 14, Color? color}) => _appStyle(
    size: size,
    weight: FontWeight.w300,
    color: color ?? SelahColors.foreground,
  );

  /// DEFAULT COLOUR REMOVED 2026-08-11 (Frost UI pass). This used to
  /// default to Colors.white, which every FilledButton call site passed
  /// through unchanged — so when main.dart gained a real ColorScheme
  /// (primary = Candle Bronze, onPrimary = Sanctuary Ink),
  /// a hardcoded white here would have sat on the lavender fill at ~2:1
  /// contrast and silently defeated the theme's onPrimary on all ~30
  /// FilledButtons at once.
  ///
  /// A null colour inherits from the enclosing button's foreground:
  /// FilledButtons get onPrimary (sanctuary ink), TextButtons/
  /// OutlinedButtons get their themed white (main.dart), and non-button
  /// uses fall back to the dark theme's near-white default — visually
  /// what they showed before. Call sites that pass an explicit colour
  /// (e.g. End Journey coral) are unaffected.
  static TextStyle button({double size = 15, Color? color}) => _appStyle(
    size: size,
    weight: FontWeight.w400,
    color: color,
    letterSpacing: 0.5,
  );

  static TextStyle chapterLabel({Color? color}) => _appStyle(
    size: 10,
    weight: FontWeight.w300,
    color: color ?? SelahColors.foregroundSecondary,
    letterSpacing: 0.8,
  );

  static TextStyle privacyText({Color? color}) => _appStyle(
    size: 11,
    weight: FontWeight.w300,
    color: color ?? SelahColors.foregroundMuted,
  );
}
