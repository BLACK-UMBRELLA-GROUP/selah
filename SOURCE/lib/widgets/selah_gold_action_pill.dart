import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// SELAH's premium action control.
///
/// Founder-selected 2026-08-29 from five Compatibility Unlock directions:
/// Option 3, the soft gold wash. Gold is reserved for premium and Journey
/// meaning in SELAH, so this is intentionally not the app-wide replacement for
/// ordinary primary actions.
///
/// The control owns its enabled, disabled and busy states so premium actions
/// do not drift back to stock Material filled-button colours at individual
/// call sites.
class SelahGoldActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final String busyLabel;
  final bool showTrailingChevron;

  const SelahGoldActionPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.busyLabel = 'Unlocking…',
    this.showTrailingChevron = true,
  });

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final foreground = SelahColors.foreground;
    final gold = SelahColors.journeyGold;
    const radius = BorderRadius.all(Radius.circular(999));

    return Semantics(
      button: true,
      enabled: _enabled,
      label: busy ? busyLabel : label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: _enabled || busy ? 1 : 0.42,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  gold.withValues(alpha: 0.25),
                  gold.withValues(alpha: 0.07),
                ],
              ),
              border: Border.all(color: gold.withValues(alpha: 0.48), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: _enabled ? onPressed : null,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        // Keep the centred label clear of the trailing action
                        // at large accessibility text sizes. Equal left/right
                        // space preserves optical centring.
                        padding: EdgeInsets.symmetric(
                          horizontal: showTrailingChevron && !busy ? 28 : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (busy)
                              SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.7,
                                  color: gold,
                                ),
                              )
                            else
                              Icon(icon, size: 17, color: gold),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                busy ? busyLabel : label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SelahText.button(
                                  size: 14,
                                  color: foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showTrailingChevron && !busy)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: gold.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: gold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
