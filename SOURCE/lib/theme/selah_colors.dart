// SELAH visual foundation.
//
// Quiet Sanctuary / Stillness & Light is the current Selah-only direction:
// deep sanctuary navy, warm ivory, candle bronze and restrained sage. Older
// comparison palettes remain available to protected developer tooling, but
// they are not the launch identity and must not become the default again.

import 'package:flutter/material.dart';
import 'selah_visual_comparison.dart';
export 'selah_visual_comparison.dart';

import '../services/selah_local_prefs.dart';

/// Background directions available to members from Profile → Personalisation.
/// Light studies remain in the enum only for historical visual fixtures and
/// are rejected by the member-facing selection boundary.
enum SelahDevPalette {
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

  // Quiet Sanctuary — current Selah identity, 2026-10-13.
  static const Color sanctuaryInk = Color(0xFF101B26);
  static const Color sanctuaryBlue = Color(0xFF182A36);
  static const Color sanctuaryRaised = Color(0xFF203440);
  static const Color warmIvory = Color(0xFFF5F0E8);
  static const Color mutedStone = Color(0xFFB9B3A9);
  static const Color candleBronze = Color(0xFFC79A62);
  static const Color mutedCopper = Color(0xFFC98363);
  static const Color sanctuarySage = Color(0xFF809587);

  /// Founder-requested Wafa visual study. This does not re-enable retired
  /// member light palettes, persist a theme or replace the Current default.
  static bool get isWafaPreview => SelahVisualComparison.instance.option2;
  static const Color wafaGreen = Color(0xFF123F32);
  static const Color wafaInk = Color(0xFF182D25);
  static const Color wafaMuted = Color(0xFF68776F);
  static const Color wafaMint = Color(0xFFEDF5EF);
  static const Color wafaLine = Color(0xFFE3EAE5);
  static const LinearGradient wafaCanvas = LinearGradient(
    colors: [Colors.white, Colors.white],
  );

  // Compatibility aliases keep inherited call sites functional while the
  // product moves away from the copied purple identity. New Selah code should
  // use the sanctuary names above.
  static const Color royalPurple = sanctuaryBlue;
  static const Color luxuryDarkPurple = sanctuaryInk;
  static const Color darkPlumSurface = sanctuaryBlue;

  // The main Quiet Horizon splash is the colour authority for the brand
  // lockup on Welcome as well. Keep these separate from theme-dependent
  // foreground and from the slightly different Journey gold accent.
  static const Color splashWordmark = warmIvory;
  static Color get splashTagline => mutedStone.withValues(alpha: 0.88);

  // Soft selected-state accent. Paper White follows its explicitly selected
  // comparison accent; the live dark direction uses candle bronze.
  static Color get accentBg => isWafaPreview
      ? wafaMint
      : isLightPalette
      ? devLightAccent.color.withValues(alpha: 0.14)
      : candleBronze.withValues(alpha: 0.12);
  static Color get accentBorder => isWafaPreview
      ? wafaLine
      : isLightPalette
      ? devLightAccent.color.withValues(alpha: 0.40)
      : candleBronze.withValues(alpha: 0.38);

  // ── UI GATE P1 (inherited upstream action 257 / inherited decision 214, 2026-08-23): repeated screen
  //    literals promoted to named tokens VALUE-UNCHANGED — zero pixels
  //    moved by this change. NOTE the near-duplicate families (greens
  //    84D0A8 / 78C69D / 50B478, soft reds E08080 / E18A91 / DF7D82):
  //    whether they merge is a Founder design decision recorded in
  //    SYSTEM/RESOURCES/UI_GATE/P1_TRIAGE_2026-08-23.md — do not unify
  //    values here without that ruling.
  static const Color journeyGold = candleBronze;
  static const Color positiveGreen = sanctuarySage;
  static const Color journeyDotGreen = sanctuarySage;
  static const Color negativeRed = Color(0xFFE18A91);
  static const Color successTick = Color(0xFF50B478);

  /// Canonical surface for every modal sheet that rises from the bottom.
  ///
  /// Keep this opaque: sheets can appear over photos, gradients and cards,
  /// and must retain the same colour in every part of the app.
  static Color get modalSheetSurface => isWafaPreview
      ? Colors.white
      : isLightPalette
      ? const Color(0xFFF7F2F8)
      : darkPlumSurface;

  /// Backwards-compatible name used by the Shepherd and membership flows.
  static Color get mentorSheetBg => modalSheetSurface;

  // Contrast-aware foreground and translucent chrome. Dark palettes retain
  // their exact approved values; Paper White swaps only the neutral ink.
  static bool get isLightPalette => isWafaPreview || devPalette.isLight;
  static Color get foreground => isWafaPreview
      ? wafaInk
      : isLightPalette
      ? luxuryDarkPurple
      : warmIvory;
  static Color get foregroundBody => isWafaPreview
      ? wafaInk
      : isLightPalette
      ? const Color(0xE63D2A4A)
      : warmIvory.withValues(alpha: 0.90);
  static Color get foregroundSecondary => isWafaPreview
      ? wafaMuted
      : isLightPalette
      ? const Color(0xB33D2A4A)
      : mutedStone.withValues(alpha: 0.92);
  static Color get foregroundMuted => isWafaPreview
      ? wafaMuted
      : isLightPalette
      ? const Color(0x8A3D2A4A)
      : mutedStone.withValues(alpha: 0.68);

  /// Neutral app-card fill. This is the shared visual-language boundary for
  /// the three App Surface choices; page code should use this rather than
  /// inventing a private white-alpha recipe.
  static Color get surfaceFill {
    if (isWafaPreview) return Colors.white;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xB8FFFFFF)
        : isLightPalette
        ? const Color(0x123D2A4A)
        : sanctuaryBlue.withValues(alpha: 0.88);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass ||
      SelahAppSurfaceStyle.glassSignals => neutral,
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.10),
        neutral,
      ),
    };
  }

  static Color get surfaceBorder {
    if (isWafaPreview) return wafaLine;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xE8FFFFFF)
        : isLightPalette
        ? const Color(0x303D2A4A)
        : candleBronze.withValues(alpha: 0.20);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass ||
      SelahAppSurfaceStyle.glassSignals => neutral,
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.32),
        neutral,
      ),
    };
  }

  /// Stronger surface used for selected/expanded/priority cards.
  static Color get surfaceEmphasisFill {
    if (isWafaPreview) return wafaMint;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xE6FFFFFF)
        : isLightPalette
        ? const Color(0x293D2A4A)
        : sanctuaryRaised.withValues(alpha: 0.94);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.10),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.18),
        neutral,
      ),
    };
  }

  static Color get surfaceEmphasisBorder {
    if (isWafaPreview) return wafaLine;
    final neutral = devPalette.usesWhiteGlass
        ? Colors.white
        : isLightPalette
        ? const Color(0x383D2A4A)
        : candleBronze.withValues(alpha: 0.30);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.46),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.46),
        neutral,
      ),
    };
  }

  /// App-surface signal colour. Semantic colours remain authoritative where
  /// the domain has one (destructive, traffic light, Journey gold).
  static Color get surfaceSignal => isWafaPreview
      ? wafaGreen
      : switch (appSurfaceStyle) {
          SelahAppSurfaceStyle.classicGlass => foreground,
          SelahAppSurfaceStyle.glassSignals => journeyGold,
          SelahAppSurfaceStyle.statusAccents => actionFill,
        };

  // Progress bar. Glass Signals limits colour to meaningful progress and
  // selection; Status Accents also tints containing surfaces.
  static Color get progressFill {
    if (isWafaPreview) return wafaGreen;
    final neutral = isLightPalette
        ? const Color(0x473D2A4A)
        : const Color(0x47FFFFFF);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.58),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.48),
        neutral,
      ),
    };
  }

  static Color get progressTrack {
    if (isWafaPreview) return wafaMint;
    final neutral = isLightPalette
        ? const Color(0x143D2A4A)
        : const Color(0x12FFFFFF);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.10),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.12),
        neutral,
      ),
    };
  }

  static const Color progressCompleteFill = Color(
    0x9950B478,
  ); // rgba(80,180,120,0.6)

  // Icon buttons
  static Color get iconButtonBg {
    return surfaceFill;
  }

  static Color get iconButtonBorder {
    return surfaceBorder;
  }

  // Shared Quiet Sanctuary action and surface tokens. These compatibility
  // names are retained because existing screens already use them, but their
  // live values now resolve to opaque navy surfaces and candle-bronze focus
  // rather than the inherited lavender/white-glass treatment.

  /// Primary action fill — restrained candle bronze on the sanctuary canvas.
  static const Color primaryAction = candleBronze;

  /// Text/icon colour ON [primaryAction]. Always this, never white.
  static const Color onPrimaryAction = luxuryDarkPurple;

  /// Destructive text/accents (End Journey coral).
  static const Color destructive = Color(0xFFE08080);
  static const Color destructiveBorder = Color(0x66E08080); // coral 0.4

  // Frost pills — sampled from the Connections segmented control.
  static Color get frostFill => isWafaPreview
      ? wafaMint
      : devPalette.usesWhiteGlass
      ? const Color(0x8FFFFFFF)
      : isLightPalette
      ? const Color(0x123D2A4A)
      : sanctuaryBlue.withValues(alpha: 0.88);
  static Color get frostBorder => isWafaPreview
      ? wafaLine
      : devPalette.usesWhiteGlass
      ? const Color(0xD9FFFFFF)
      : isLightPalette
      ? const Color(0x293D2A4A)
      : candleBronze.withValues(alpha: 0.20);
  static Color get frostSelectedFill {
    if (isWafaPreview) return wafaMint;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xE6FFFFFF)
        : isLightPalette
        ? const Color(0x293D2A4A)
        : sanctuaryRaised.withValues(alpha: 0.96);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.13),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.16),
        neutral,
      ),
    };
  }

  static Color get frostSelectedBorder {
    if (isWafaPreview) return wafaLine;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xFFFFFFFF)
        : isLightPalette
        ? const Color(0x383D2A4A)
        : candleBronze.withValues(alpha: 0.28);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass => neutral,
      SelahAppSurfaceStyle.glassSignals => Color.alphaBlend(
        journeyGold.withValues(alpha: 0.46),
        neutral,
      ),
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.40),
        neutral,
      ),
    };
  }

  // Glass cards — the ratified selah_glass_dialog recipe (blur σ30).
  static Color get glassFill {
    if (isWafaPreview) return Colors.white;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xC2FFFFFF)
        : isLightPalette
        ? const Color(0x143D2A4A)
        : sanctuaryBlue.withValues(alpha: 0.92);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass ||
      SelahAppSurfaceStyle.glassSignals => neutral,
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.10),
        neutral,
      ),
    };
  }

  static Color get glassBorder {
    if (isWafaPreview) return wafaLine;
    final neutral = devPalette.usesWhiteGlass
        ? const Color(0xF2FFFFFF)
        : isLightPalette
        ? const Color(0x303D2A4A)
        : candleBronze.withValues(alpha: 0.26);
    return switch (appSurfaceStyle) {
      SelahAppSurfaceStyle.classicGlass ||
      SelahAppSurfaceStyle.glassSignals => neutral,
      SelahAppSurfaceStyle.statusAccents => Color.alphaBlend(
        actionFill.withValues(alpha: 0.34),
        neutral,
      ),
    };
  }

  // ---------------------------------------------------------------------
  // CORRECTED 2026-08-11, same-day (Founder, on-device: "the top right
  // isnt clear"). The Journey ⋮ menu shipped that morning wearing
  // glassFill — white 14% — which is fine for a CENTRED dialog because
  // the black-55% barrier darkens everything behind it first. An
  // anchored menu has NO barrier (the ratified no-dim rule in
  // anchored_card_overlay.dart) and hangs at the TOP of the screen,
  // where the gender gradient is at its lightest — white text on white
  // glass over pale rose, and the coral End Journey row disappeared
  // into it entirely.
  //
  // Anchored menus therefore wear dark plum glass: Luxury Dark Purple at
  // 92% + blur, the same ratified family as sheetSurface below. White
  // and coral text both pass on it over ANY gradient region.
  // ---------------------------------------------------------------------

  /// Anchored floating menus (Journey ⋮, etc.) — dark plum glass.
  static Color get menuSurface => isWafaPreview
      ? Colors.white
      : isLightPalette
      ? const Color(0xF7FCFAFD)
      : darkPlumSurface.withValues(alpha: .92);

  // Bottom-sheet colour is centralised in modalSheetSurface. This retained
  // getter prevents an older shell from reintroducing a second colour.

  /// Backwards-compatible gradient shape for existing sheet shells.
  /// Both stops intentionally use [modalSheetSurface], so these shells render
  /// exactly like sheets that use a solid colour.
  static LinearGradient get sheetGradient {
    final surface = modalSheetSurface;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [surface, surface],
    );
  }

  /// Compatibility alias for older sheet call sites.
  static Color get sheetSurface => modalSheetSurface;

  /// Toasts/SnackBars — same family, fully opaque since they sit over
  /// arbitrary content (often a photo) and must stay legible.
  static Color get toastSurface => isWafaPreview
      ? Colors.white
      : isLightPalette
      ? const Color(0xFFFCFAFD)
      : darkPlumSurface;

  // FAB states
  static Color get fabDimmedBg =>
      isLightPalette ? const Color(0x0A3D2A4A) : const Color(0x0AFFFFFF);
  static Color get fabDimmedBorder =>
      isLightPalette ? const Color(0x173D2A4A) : const Color(0x17FFFFFF);
  static Color get fabDimmedArrow =>
      isLightPalette ? const Color(0x663D2A4A) : const Color(0x33FFFFFF);
  static Color get fabActiveBg =>
      isLightPalette ? const Color(0x143D2A4A) : const Color(0x1AFFFFFF);
  static Color get fabActiveBorder =>
      isLightPalette ? const Color(0x473D2A4A) : const Color(0x38FFFFFF);
  static Color get fabActiveArrow =>
      isLightPalette ? luxuryDarkPurple : const Color(0xD9FFFFFF);

  // Privacy indicator states
  static const Color publicDot = Color(0xD9809587);
  static const Color publicText = Color(0x99809587);
  static const Color unlockDot = Color(0xD9C79A62);
  static const Color unlockText = Color(0x99C79A62);
  static const Color privateDot = Color(0xB3B9B3A9);
  static const Color privateText = Color(0x80B9B3A9);

  // ---------------------------------------------------------------------
  // UNIFIED 2026-08-20 — Founder direction.
  //
  // Selah no longer changes its background palette according to gender.
  // Quiet Sanctuary is shared by every role; safety and destructive feedback
  // remain semantic accents rather than alternate app themes.
  // ---------------------------------------------------------------------

  /// Current Selah launch identity. The revision deliberately migrates older
  /// inherited palette choices to Quiet Sanctuary once, while still allowing
  /// explicit protected comparisons during the current session.
  static const SelahDevPalette currentDefaultPalette =
      SelahDevPalette.quietSanctuary;
  static const String currentPaletteRevision = 'quiet-sanctuary-2026-10-13-v1';

  /// Current app-wide surface treatment for Quiet Sanctuary.
  static const SelahAppSurfaceStyle currentDefaultSurfaceStyle =
      SelahAppSurfaceStyle.glassSignals;

  static final ValueNotifier<SelahDevPalette> devPaletteSelection =
      ValueNotifier<SelahDevPalette>(currentDefaultPalette);

  static final ValueNotifier<SelahDevLightAccent> devLightAccentSelection =
      ValueNotifier<SelahDevLightAccent>(SelahDevLightAccent.purple);

  static final ValueNotifier<SelahAppSurfaceStyle> appSurfaceStyleSelection =
      ValueNotifier<SelahAppSurfaceStyle>(currentDefaultSurfaceStyle);

  static SelahDevPalette get devPalette => devPaletteSelection.value;
  static SelahDevLightAccent get devLightAccent =>
      devLightAccentSelection.value;
  static SelahAppSurfaceStyle get appSurfaceStyle =>
      appSurfaceStyleSelection.value;

  static void selectDevPalette(SelahDevPalette palette) {
    if (devPaletteSelection.value != palette) {
      devPaletteSelection.value = palette;
    }
  }

  /// Selects the member's persisted background from Profile →
  /// Personalisation. Light experiments are deliberately refused here, not
  /// merely hidden by the screen, so an old/deep link cannot reactivate a
  /// retired light appearance.
  static void selectAppPalette(SelahDevPalette palette) {
    if (palette.isLight) return;
    selectDevPalette(palette);
    SelahLocalPrefs.setCachedAppPaletteName(palette.name);
    SelahLocalPrefs.setCachedAppPaletteRevision(currentPaletteRevision);
  }

  /// Startup-only adoption of the current app-wide theme. Only palette
  /// preferences change; account state, fonts, haptics and app lock survive.
  /// Both writes capture the same owner/generation synchronously, so a queued
  /// update cannot stamp the next account. Later explicit choices still work.
  static void restoreCurrentAppPalette() {
    if (SelahLocalPrefs.cachedAppPaletteRevision == currentPaletteRevision) {
      restoreAppPalette(SelahLocalPrefs.cachedAppPaletteName);
      return;
    }
    restoreAppPalette(null);
    SelahLocalPrefs.setCachedAppPaletteName(currentDefaultPalette.name);
    SelahLocalPrefs.setCachedAppPaletteRevision(currentPaletteRevision);
  }

  /// Hydrates the background before `runApp` without rewriting disk.
  /// Unknown, retired and light values fall back to Quiet Sanctuary.
  static void restoreAppPalette(String? storedName) {
    final restored = SelahDevPalette.values.where(
      (palette) => !palette.isLight && palette.name == storedName,
    );
    devPaletteSelection.value = restored.isEmpty
        ? currentDefaultPalette
        : restored.first;
  }

  static void selectDevLightAccent(SelahDevLightAccent accent) {
    if (devLightAccentSelection.value != accent) {
      devLightAccentSelection.value = accent;
    }
  }

  static void selectAppSurfaceStyle(SelahAppSurfaceStyle style) {
    if (appSurfaceStyleSelection.value != style) {
      appSurfaceStyleSelection.value = style;
    }
  }

  /// Restores the locked production surface and removes any retired stored
  /// comparison from builds that previously exposed the three-way picker.
  static void restoreAppSurfaceStyle(String? _) {
    appSurfaceStyleSelection.value = currentDefaultSurfaceStyle;
    SelahLocalPrefs.setCachedAppSurfaceStyleName(null);
  }

  /// Active interactive accent. Dark backgrounds use candle bronze; Paper
  /// White keeps its explicit comparison accent.
  static Color get actionFill => isWafaPreview
      ? wafaGreen
      : isLightPalette
      ? devLightAccent.color
      : primaryAction;
  static Color get onAction => isLightPalette ? Colors.white : onPrimaryAction;

  /// Neutral contrast helpers for glass and page-level UI.
  static Color ink(double opacity) => foreground.withValues(alpha: opacity);
  static Color get accentOnCanvas => isWafaPreview
      ? wafaGreen
      : isLightPalette
      ? devLightAccent.color
      : unlockText;

  /// The live app background. Quiet Sanctuary is the launch identity;
  /// explicit protected comparison choices remain session-local.
  static LinearGradient get brandGradient =>
      isWafaPreview ? wafaCanvas : devPalette.gradient;

  /// Compatibility aliases retained while older call sites and documents
  /// are retired. Both deliberately resolve to the one SELAH gradient.
  @Deprecated('Use brandGradient; SELAH has one unified background theme.')
  static LinearGradient get brandGradientMale => brandGradient;

  @Deprecated('Use brandGradient; SELAH has one unified background theme.')
  static LinearGradient get brandGradientFemale => brandGradient;

  /// Compatibility helper for existing profile-context call sites.
  /// [gender] remains accepted so this colour change does not disturb
  /// identity or onboarding data; it no longer changes presentation.
  static LinearGradient genderGradient(String? gender) => brandGradient;

  /// Onboarding shares the same unified background. The enum remains a flow
  /// input only so the colour change does not alter navigation or saved data.
  static LinearGradient backgroundFor(SelahBackgroundVariant variant) {
    switch (variant) {
      case SelahBackgroundVariant.neutral:
      case SelahBackgroundVariant.male:
      case SelahBackgroundVariant.female:
        return brandGradient;
    }
  }
}
