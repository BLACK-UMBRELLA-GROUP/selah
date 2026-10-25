// Shared three-door developer control for Seeker and Shepherd shells.
//
// The edge rail is deliberately navigation, not independent stores:
// Preview reads the current page, Actions changes the existing scenario,
// and Home owns session/account entry points. Founder lock, 2026-08-29:
// visual comparison controls moved out of Developer Tools. Member-safe
// background, type and haptic choices now live in Profile > Personalisation.
// Exact Trio became the one Compatibility Breakdown treatment on 2026-08-29,
// so neither it nor the retired Three-part Rail remains a developer toggle.
// Both roles keep their existing scenario readers and one reset.
// Founder 2026-09-27 exception: the Mobbin splash comparison belongs in
// shared Home.
// Founder 2026-09-29: onboarding styles stay a separate category. Each starts
// the complete local first-use flow at Welcome, without real Auth writes.
// Founder 2026-10-08 cleanup: Home no longer offers gender, app gold, mobile
// menu, opening slide motion or app-icon comparisons. Gold accents remain a
// saved member choice in Personalisation; canonical menu defaults stay intact.
// Founder 2026-10-11: the protected request-style shell supplies Home/Actions
// only. Retained member coordinators keep their existing three-door default.

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'dev_splash_directions.dart';
import 'dev_onboarding_directions.dart';
import 'dev_settings_design.dart';
import 'dev_discovery_directions.dart';
import 'selah_dev_tool_section.dart';

// The rail is ordered by enum declaration. Home deliberately comes first so
// the one global/reset door is always the first control the Founder reaches;
// page inspection and scenario staging follow underneath it.
enum SelahDevControlSection { home, preview, actions }

extension SelahDevControlSectionX on SelahDevControlSection {
  String get label => switch (this) {
    SelahDevControlSection.preview => 'Preview',
    SelahDevControlSection.actions => 'Actions',
    SelahDevControlSection.home => 'Home',
  };

  IconData get icon => switch (this) {
    SelahDevControlSection.preview => Icons.visibility_outlined,
    SelahDevControlSection.actions => Icons.tune,
    SelahDevControlSection.home => Icons.home_outlined,
  };
}

/// Developer doors on the right edge, in the caller's requested order.
///
/// The retained member coordinators keep all three doors by default. A caller
/// can omit a door entirely; an omitted door has no widget or semantics target.
class SelahDevControlRail extends StatelessWidget {
  final bool open;
  final SelahDevControlSection selected;
  final ValueChanged<SelahDevControlSection> onSelected;
  final Map<SelahDevControlSection, Key> buttonKeys;
  final Map<SelahDevControlSection, String> labels;
  final List<SelahDevControlSection> visibleSections;

  const SelahDevControlRail({
    super.key,
    required this.open,
    required this.selected,
    required this.onSelected,
    this.buttonKeys = const {},
    this.labels = const {},
    this.visibleSections = SelahDevControlSection.values,
  });

  static const double width = 36;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: SelahColors.modalSheetSurface.withValues(alpha: 242 / 255),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final section in visibleSections)
                  Tooltip(
                    message: labels[section] ?? section.label,
                    child: Semantics(
                      button: true,
                      selected: open && selected == section,
                      label:
                          '${labels[section] ?? section.label} developer control',
                      child: InkWell(
                        key:
                            buttonKeys[section] ??
                            ValueKey('dev_rail_${section.name}'),
                        onTap: () => onSelected(section),
                        child: SizedBox(
                          width: width,
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                section.icon,
                                size: 17,
                                color: open && selected == section
                                    ? SelahColors.unlockText
                                    : Colors.white54,
                              ),
                              if (open && selected == section)
                                const Positioned(
                                  right: 0,
                                  child: SizedBox(
                                    width: 2,
                                    height: 22,
                                    child: ColoredBox(
                                      color: SelahColors.unlockText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

class SelahDevPreviewLauncher extends StatelessWidget {
  final String pageLabel;
  final VoidCallback onOpen;

  const SelahDevPreviewLauncher({
    super.key,
    required this.pageLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$pageLabel preview', style: SelahText.heading(size: 20)),
        const SizedBox(height: 8),
        _DevSharedAction(
          key: const ValueKey('dev_open_page_preview'),
          icon: Icons.open_in_new,
          title: 'Open complete page preview',
          onTap: onOpen,
        ),
      ],
    );
  }
}

class SelahDevHomeTools extends StatelessWidget {
  final bool busy;
  final bool shepherd;
  final VoidCallback onHome;
  final VoidCallback onRestart;
  final VoidCallback? onReset;
  final VoidCallback onAccounts;
  final VoidCallback onSeekerSignUp;
  final VoidCallback onShepherdSignUp;
  final VoidCallback? onOpenSplashPreview;

  const SelahDevHomeTools({
    super.key,
    required this.busy,
    this.shepherd = false,
    required this.onHome,
    required this.onRestart,
    required this.onReset,
    required this.onAccounts,
    required this.onSeekerSignUp,
    required this.onShepherdSignUp,
    this.onOpenSplashPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_navigation'),
          child: _DevSharedAction(
            key: const ValueKey('dev_home_navigation'),
            icon: Icons.home_outlined,
            title: 'Home',
            onTap: busy ? null : onHome,
          ),
        ),
        const SizedBox(height: 16),
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_discovery_direction'),
          child: DevDiscoveryDirectionPicker(
            enabled: !busy,
            onBeforeOpen: onOpenSplashPreview,
          ),
        ),
        const SizedBox(height: 16),
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_splash'),
          child: DevSplashDirectionPicker(
            enabled: !busy,
            onBeforeOpen: onOpenSplashPreview,
          ),
        ),
        const SizedBox(height: 16),
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_onboarding'),
          child: DevOnboardingDirectionPicker(
            enabled: !busy,
            onBeforeOpen: onOpenSplashPreview,
          ),
        ),
        const SizedBox(height: 16),
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_settings'),
          child: DevSettingsDesignPicker(
            shepherd: shepherd,
            enabled: !busy,
            onBeforeOpen: onOpenSplashPreview,
          ),
        ),
        const SizedBox(height: 16),
        SelahDevToolSection(
          key: const ValueKey('dev_home_section_account'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account controls', style: SelahText.body(size: 13)),
              const SizedBox(height: 6),
              _DevSharedAction(
                key: const ValueKey('dev_home_login'),
                icon: Icons.login_rounded,
                title: 'Restart at login',
                onTap: onRestart,
              ),
              const SizedBox(height: 8),
              _DevSharedAction(
                key: const ValueKey('dev_reset_state'),
                icon: Icons.restart_alt,
                title: busy ? 'Resetting…' : 'Reset account',
                onTap: busy ? null : onReset,
              ),
              const SizedBox(height: 8),
              _DevSharedAction(
                key: const ValueKey('dev_switch_accounts'),
                icon: Icons.switch_account_outlined,
                title: 'Switch test account',
                onTap: onAccounts,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One app-wide surface selector, deliberately placed in Home rather than a
/// page lab. Every option rebuilds the shared SELAH tokens and both Dashboards.
class SelahDevAppSurfacePicker extends StatelessWidget {
  const SelahDevAppSurfacePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SelahColors.appSurfaceStyleSelection,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'APP SURFACE',
            style: SelahText.chapterLabel(color: Colors.white38),
          ),
          const SizedBox(height: 7),
          for (final style in SelahAppSurfaceStyle.values)
            _DevAppSurfaceOption(
              style: style,
              selected: SelahColors.appSurfaceStyle == style,
              onTap: () => SelahColors.selectAppSurfaceStyle(style),
            ),
        ],
      ),
    );
  }
}

class _DevAppSurfaceOption extends StatelessWidget {
  final SelahAppSurfaceStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _DevAppSurfaceOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (style) {
      SelahAppSurfaceStyle.classicGlass => Icons.blur_on_rounded,
      SelahAppSurfaceStyle.glassSignals => Icons.linear_scale_rounded,
      SelahAppSurfaceStyle.statusAccents => Icons.palette_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? SelahColors.primaryAction.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('dev_app_surface_${style.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.09),
                    border: Border.all(
                      color: selected
                          ? SelahColors.primaryAction
                          : Colors.white24,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? SelahColors.primaryAction : Colors.white60,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    style.label,
                    style: SelahText.body(size: 12, color: Colors.white),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: SelahColors.primaryAction,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Session-only visual laboratory. The approved wordmark remains locked;
/// relaunching returns to the current Midnight Plum + Poppins defaults.
class SelahDevStylePanel extends StatelessWidget {
  const SelahDevStylePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SelahColors.devPaletteSelection,
        SelahColors.devLightAccentSelection,
        SelahText.appFontSelection,
        SelahInteractionStyle.navStyleSelection,
        SelahInteractionStyle.hapticLevelSelection,
      ]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Style lab', style: SelahText.heading(size: 20)),
            const SizedBox(height: 15),
            Text(
              'DARK BACKGROUNDS',
              style: SelahText.chapterLabel(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            for (final palette in SelahDevPalette.values.where(
              (palette) => !palette.isLight,
            ))
              _PaletteOption(
                palette: palette,
                selected: SelahColors.devPalette == palette,
              ),
            const SizedBox(height: 16),
            Text(
              'LIGHT BACKGROUNDS',
              style: SelahText.chapterLabel(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            for (final palette in SelahDevPalette.values.where(
              (palette) => palette.isLight,
            ))
              _PaletteOption(
                palette: palette,
                selected: SelahColors.devPalette == palette,
              ),
            if (SelahColors.isLightPalette) ...[
              const SizedBox(height: 14),
              Text(
                'ACCENT ON WHITE',
                style: SelahText.chapterLabel(color: Colors.white38),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final accent in SelahDevLightAccent.values)
                    _LightAccentChoice(
                      accent: accent,
                      selected: SelahColors.devLightAccent == accent,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'NAVIGATION',
              style: SelahText.chapterLabel(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            for (final style in SelahNavStyle.values)
              _NavStyleChoice(
                style: style,
                selected: SelahInteractionStyle.navStyle == style,
              ),
            const SizedBox(height: 16),
            Text(
              'HAPTIC FEEL',
              style: SelahText.chapterLabel(color: Colors.white38),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.vibration_outlined,
                  size: 17,
                  color: Colors.white54,
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('dev_haptic_level'),
                    min: 0,
                    max: (SelahHapticLevel.values.length - 1).toDouble(),
                    divisions: SelahHapticLevel.values.length - 1,
                    value: SelahInteractionStyle.hapticLevel.index.toDouble(),
                    label: SelahInteractionStyle.hapticLevel.label,
                    onChanged: (value) {
                      final level = SelahHapticLevel.values[value.round()];
                      if (SelahInteractionStyle.selectHapticLevel(level)) {
                        SelahInteractionStyle.emitSelectionHaptic();
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    SelahInteractionStyle.hapticLevel.label,
                    textAlign: TextAlign.end,
                    style: SelahText.subtext(size: 10.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'APP TEXT',
              style: SelahText.chapterLabel(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            for (final font in SelahAppFont.values)
              _FontChoice(font: font, selected: SelahText.appFont == font),
            const SizedBox(height: 12),
            _DevSharedAction(
              key: const ValueKey('dev_style_reset'),
              icon: Icons.restore,
              title: 'Restore default style',
              onTap: () {
                SelahColors.selectDevPalette(SelahColors.currentDefaultPalette);
                SelahColors.selectDevLightAccent(SelahDevLightAccent.purple);
                SelahColors.selectAppSurfaceStyle(
                  SelahColors.currentDefaultSurfaceStyle,
                );
                SelahText.selectAppFont(SelahText.currentDefaultFont);
                SelahInteractionStyle.restoreDefaults();
              },
            ),
          ],
        );
      },
    );
  }
}

class _NavStyleChoice extends StatelessWidget {
  final SelahNavStyle style;
  final bool selected;

  const _NavStyleChoice({required this.style, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: ValueKey('dev_nav_style_${style.name}'),
          borderRadius: BorderRadius.circular(11),
          onTap: () => SelahInteractionStyle.selectNavStyle(style),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                _NavStyleGlyph(style: style),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(style.label, style: SelahText.body(size: 12.5)),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: SelahColors.unlockText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavStyleGlyph extends StatelessWidget {
  final SelahNavStyle style;
  const _NavStyleGlyph({required this.style});

  @override
  Widget build(BuildContext context) {
    final accent = switch (style) {
      SelahNavStyle.goldUnderline => SelahColors.journeyGold,
      SelahNavStyle.labelledDock => Colors.white,
      _ => SelahColors.primaryAction,
    };
    return Container(
      width: 52,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: style == SelahNavStyle.labelledDock
            ? const Color(0xFF242326)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          final active = index == 0;
          return Container(
            width: active && style == SelahNavStyle.labelledDock ? 18 : 7,
            height: style == SelahNavStyle.goldUnderline && active ? 2 : 7,
            decoration: BoxDecoration(
              color: active ? accent : Colors.white38,
              shape: style == SelahNavStyle.accentRing
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              borderRadius: style == SelahNavStyle.accentRing
                  ? null
                  : BorderRadius.circular(8),
              border: style == SelahNavStyle.accentRing && active
                  ? Border.all(color: accent, width: 1.5)
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class _LightAccentChoice extends StatelessWidget {
  final SelahDevLightAccent accent;
  final bool selected;

  const _LightAccentChoice({required this.accent, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${accent.label} accent',
      child: InkWell(
        key: ValueKey('dev_light_accent_${accent.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => SelahColors.selectDevLightAccent(accent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.color.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent.color
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(accent.label, style: SelahText.subtext(size: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  final SelahDevPalette palette;
  final bool selected;

  const _PaletteOption({required this.palette, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: ValueKey('dev_palette_${palette.name}'),
          borderRadius: BorderRadius.circular(11),
          onTap: () => SelahColors.selectDevPalette(palette),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: palette.gradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    palette.label,
                    style: SelahText.body(size: 12.5, color: Colors.white),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: SelahColors.unlockText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FontChoice extends StatelessWidget {
  final SelahAppFont font;
  final bool selected;

  const _FontChoice({required this.font, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('dev_font_${font.name}'),
        onTap: () => SelahText.selectAppFont(font),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 21,
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 15,
                        color: SelahColors.unlockText,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  font.label,
                  style: SelahText.preview(
                    font,
                    size: 13.5,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              Text(
                'Aa',
                style: SelahText.preview(font, size: 16, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevSharedAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _DevSharedAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9);
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: onTap == null
                      ? Colors.white38
                      : SelahColors.primaryAction,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: SelahText.body(
                      size: 12.5,
                      color: onTap == null ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
