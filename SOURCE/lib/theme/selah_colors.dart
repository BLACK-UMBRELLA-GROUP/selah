// LOCKs 1 and 2: Still Water. Historical enum values are inert compatibility data.
import 'package:flutter/material.dart';
export 'selah_visual_comparison.dart';

/// Background directions available to members from Profile → Personalisation.
/// Light studies remain in the enum only for historical visual fixtures and
/// are rejected by the member-facing selection boundary.
enum SelahDevPalette {
  stillWater(
    'Still Water',
    'LOCK 1',
    LinearGradient(colors: [Color(0xFFEEF1F0), Color(0xFFEEF1F0)]),
    isLight: true,
  ),
  quietSanctuary(
    'Quiet Sanctuary · Current',
    'Deep sanctuary navy with a still, candlelit finish',
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C303C), Color(0xFF101B26)],
    ),
  ),
  selahPurple(
    'SELAH Purple',
    'Royal Purple to Luxury Dark Purple',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF8A6A9E), Color(0xFF3D2A4A)],
    ),
  ),
  royalBlue(
    'Royal Blue',
    'The earlier blue direction, deepened',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF607BA7), Color(0xFF26364F)],
    ),
  ),
  rosePink(
    'Rose Pink',
    'The earlier rose direction, softened',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFA6788F), Color(0xFF503343)],
    ),
  ),
  midnightPlum(
    'Midnight Plum · Archive',
    'The inherited purple comparison',
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF30203F), Color(0xFF160E20)],
    ),
  ),
  deepEmerald(
    'Deep Emerald',
    'Calm, grounded and family-led',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF47756B), Color(0xFF18352F)],
    ),
  ),
  sapphireNight(
    'Sapphire Night',
    'Cool navy with a premium finish',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF48698B), Color(0xFF192A3E)],
    ),
  ),
  desertRose(
    'Desert Rose',
    'Warm clay without becoming bright',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFA26F70), Color(0xFF513436)],
    ),
  ),
  warmCocoa(
    'Warm Cocoa',
    'Earthy neutral with soft warmth',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF7B665F), Color(0xFF352A28)],
    ),
  ),
  charcoalGold(
    'Charcoal Gold',
    'Near-neutral so the gold details lead',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF55505D), Color(0xFF211E27)],
    ),
  ),
  paperWhite(
    'Paper White',
    'White canvas with dark plum contrast',
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF4EFF6)],
    ),
    isLight: true,
  ),
  crystalMist(
    'Crystal UI',
    'Translucent mist with bright white glass surfaces',
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE7E2EC), Color(0xFFDCE5F4), Color(0xFFF8FAFD)],
      stops: [0.0, 0.54, 1.0],
    ),
    isLight: true,
    usesWhiteGlass: true,
  );

  final String label;
  final String detail;
  final LinearGradient gradient;
  final bool isLight;
  final bool usesWhiteGlass;
  const SelahDevPalette(
    this.label,
    this.detail,
    this.gradient, {
    this.isLight = false,
    this.usesWhiteGlass = false,
  });
}

/// Accent directions for the separate Paper White comparison family.
/// The colour directions reuse the SELAH comparisons above; Black is the
/// Founder's explicit additional 2026-08-24 light-theme comparison. All are
/// developer-only and reset on relaunch.
enum SelahDevLightAccent {
  lake('Still Water', Color(0xFF3E6B78)),
  purple('Purple', Color(0xFF6B4B7D)),
  royalBlue('Royal Blue', Color(0xFF395B88)),
  rose('Rose', Color(0xFF8A4E69)),
  emerald('Emerald', Color(0xFF2F665A)),
  sapphire('Sapphire', Color(0xFF355A7D)),
  gold('Gold', Color(0xFF9B7835)),
  black('Black', Color(0xFF171219));

  final String label;
  final Color color;
  const SelahDevLightAccent(this.label, this.color);
}

/// App-wide surface language selected from protected developer controls.
/// Semantic safety and compatibility colours remain authoritative.
enum SelahAppSurfaceStyle {
  classicGlass(
    'Quiet Surfaces',
    'Low-contrast sanctuary surfaces with minimal emphasis.',
  ),
  glassSignals(
    'Stillness & Light · Current',
    'Quiet surfaces with candle bronze reserved for meaningful signals.',
  ),
  statusAccents(
    'Stronger Signals',
    'More visible semantic colour on active and status surfaces.',
  );

  final String label;
  final String detail;
  const SelahAppSurfaceStyle(this.label, this.detail);
}

/// Which gender-derived background variant to show. `neutral` is used only
/// for the very first onboarding question (before gender is known).
enum SelahBackgroundVariant { neutral, male, female }

class SelahColors {
  SelahColors._();
  static const mist = Color(0xFFEEF1F0);
  static const surface = Color(0xFFFFFFFF);
  static const inkColor = Color(0xFF1E2B33);
  static const muted = Color(0xFF5E6C72);
  static const line = Color(0xFFD5DCDC);
  static const lake = Color(0xFF3E6B78);
  static const onLake = Color(0xFFFFFFFF);
  static const soft = Color(0xFFDCE7E8);
  static const dawn = Color(0xFFC7826B);
  static const dawnSoft = Color(0xFFF6E9E3);
  static const dawnLine = Color(0xFFE8C9BC);

  // Retained names resolve to the locked look for existing screen callers.
  static const sanctuaryInk = inkColor;
  static const sanctuaryBlue = surface;
  static const sanctuaryRaised = soft;
  static const warmIvory = inkColor;
  static const mutedStone = muted;
  static const candleBronze = lake;
  static const mutedCopper = dawn;
  static const sanctuarySage = lake;
  static const royalPurple = lake;
  static const luxuryDarkPurple = mist;
  static const darkPlumSurface = surface;
  static const splashWordmark = inkColor;
  static const splashTagline = muted;
  static const journeyGold = lake;
  static const positiveGreen = lake;
  static const journeyDotGreen = lake;
  static const negativeRed = dawn;
  static const successTick = lake;
  static const primaryAction = lake;
  static const onPrimaryAction = onLake;
  static const destructive = dawn;
  static const destructiveBorder = dawn;
  static const progressCompleteFill = lake;
  static const publicDot = lake;
  static const publicText = muted;
  static const unlockDot = lake;
  static const unlockText = lake;
  static const privateDot = muted;
  static const privateText = muted;

  // Historical, unused comparison constants: deliberately not recoloured.
  static const wafaGreen = Color(0xFF123F32);
  static const wafaInk = Color(0xFF182D25);
  static const wafaMuted = Color(0xFF68776F);
  static const wafaMint = Color(0xFFEDF5EF);
  static const wafaLine = Color(0xFFE3EAE5);
  static const wafaCanvas = LinearGradient(
    colors: [Colors.white, Colors.white],
  );
  static bool get isWafaPreview => false;
  static bool get isLightPalette => true;
  static const currentDefaultPalette = SelahDevPalette.stillWater;
  static const currentPaletteRevision = 'still-water-lock-1-2026-11-03';
  static const currentDefaultSurfaceStyle = SelahAppSurfaceStyle.classicGlass;
  static final devPaletteSelection = ValueNotifier<SelahDevPalette>(
    currentDefaultPalette,
  );
  static final devLightAccentSelection = ValueNotifier<SelahDevLightAccent>(
    SelahDevLightAccent.purple,
  );
  static final appSurfaceStyleSelection = ValueNotifier<SelahAppSurfaceStyle>(
    currentDefaultSurfaceStyle,
  );
  static SelahDevPalette get devPalette => currentDefaultPalette;
  static SelahDevLightAccent get devLightAccent => SelahDevLightAccent.lake;
  static SelahAppSurfaceStyle get appSurfaceStyle => currentDefaultSurfaceStyle;
  static void selectDevPalette(SelahDevPalette _) {
    devPaletteSelection.value = currentDefaultPalette;
  }

  static void selectAppPalette(SelahDevPalette _) =>
      selectDevPalette(currentDefaultPalette);
  static void restoreCurrentAppPalette() =>
      selectDevPalette(currentDefaultPalette);
  static void restoreAppPalette(String? _) => restoreCurrentAppPalette();
  static void selectDevLightAccent(SelahDevLightAccent _) {}
  static void selectAppSurfaceStyle(SelahAppSurfaceStyle _) {
    appSurfaceStyleSelection.value = currentDefaultSurfaceStyle;
  }

  static void restoreAppSurfaceStyle(String? _) =>
      selectAppSurfaceStyle(currentDefaultSurfaceStyle);
  static Color ink(double opacity) => inkColor.withValues(alpha: opacity);
  static const brandGradient = LinearGradient(colors: [mist, mist]);
  static const brandGradientMale = brandGradient;
  static const brandGradientFemale = brandGradient;
  static LinearGradient genderGradient(String? _) => brandGradient;
  static LinearGradient backgroundFor(SelahBackgroundVariant _) =>
      brandGradient;
  static const sheetGradient = LinearGradient(colors: [surface, surface]);
  static const accentBg = soft;
  static const accentBorder = line;
  static const modalSheetSurface = surface;
  static const mentorSheetBg = surface;
  static const foreground = inkColor;
  static const foregroundBody = inkColor;
  static const foregroundSecondary = muted;
  static const foregroundMuted = muted;
  static const surfaceFill = surface;
  static const surfaceBorder = line;
  static const surfaceEmphasisFill = soft;
  static const surfaceEmphasisBorder = line;
  static const surfaceSignal = lake;
  static const progressFill = lake;
  static const progressTrack = line;
  static const iconButtonBg = surface;
  static const iconButtonBorder = line;
  static const frostFill = soft;
  static const frostBorder = line;
  static const frostSelectedFill = soft;
  static const frostSelectedBorder = line;
  static const glassFill = surface;
  static const glassBorder = line;
  static const menuSurface = surface;
  static const sheetSurface = surface;
  static const toastSurface = inkColor;
  static const fabDimmedBg = soft;
  static const fabDimmedBorder = line;
  static const fabDimmedArrow = muted;
  static const fabActiveBg = lake;
  static const fabActiveBorder = lake;
  static const fabActiveArrow = onLake;
  static const actionFill = lake;
  static const onAction = onLake;
  static const accentOnCanvas = lake;
}
