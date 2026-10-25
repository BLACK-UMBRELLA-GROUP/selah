// Real glassmorphism icon button — backdrop blur (not just a flat
// translucent tint), border, inset highlight. Adapted from the
// founder's old Lovable prototype (src/components/AppShell.tsx
// GLASS_BTN: "bg-white/15 backdrop-blur-2xl border border-white/25" +
// inset shadow) — Flutter needs an actual BackdropFilter to get the
// same frosted-glass-over-photo effect; a flat translucent Container
// alone (what the rest of this app used before) doesn't blur what's
// behind it.

import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double size;
  final Color? tint;
  final VoidCallback? onTap;

  // FIXED 2026-07-27 (Founder: "check the bell icon transparence. make
  // it the same as navigation bar so the system looks similar... the
  // bell icon looks less transparent then the navigation bar"). Tint
  // was white/15 (0x26) with a 18-sigma blur and a 0.25-opacity border —
  // all three slightly stronger than FloatingNavBar's own idle-state
  // glass (white/10, 22-sigma blur, 0.18 border), which read as visibly
  // more solid sitting right next to it. Now matches that idle state
  // exactly, since this is the shared glass-button component (also used
  // by DevNavOverlay's Home button, MentorHomeShell's Dev Access button,
  // etc.), so the fix is systemic rather than a Bell-only special case —
  // matching the Founder's own framing ("so the system looks similar").
  const GlassIconButton({
    super.key,
    required this.icon,
    this.iconColor,
    this.size = 40,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint ?? SelahColors.frostFill,
              border: Border.all(color: SelahColors.frostBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: SelahColors.ink(0.18),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? SelahColors.foreground,
              size: size * 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Larger glass circle used for the brief decision-flash moment
/// (Decline/Save/Like confirmation), matching the Lovable prototype's
/// `flash` overlay: tinted background per action, backdrop blur, white
/// border, inset sheen.
class GlassFlashCircle extends StatelessWidget {
  final IconData icon;
  final Color tint;

  const GlassFlashCircle({super.key, required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}
