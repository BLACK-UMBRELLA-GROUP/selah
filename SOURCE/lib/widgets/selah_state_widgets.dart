// Shared error / empty / disabled-state widgets — implements APP/UX
// Writing/ERROR_AND_EMPTY_STATE_STANDARD_CURRENT_VERSION_V1.md (inherited decision 080).
// Every screen should use these rather than one-off Text() error strings,
// so the warm tone and visual treatment stay consistent app-wide.
//
// 2026-08-23 (Founder, GN Draft 3.2, from phone screenshots): SelahAddCircle
// added at the end of this file — the Shepherds page's large "+" blank-page
// invitation, extracted so every empty Mentor surface (Dashboard, Network,
// Seekers) renders the identical pattern instead of a mid-screen paragraph
// with a pill button. Visuals copied 1:1 from seeker_mentor_tab.dart's
// _AddShepherdButton(large: true) + its label line.

import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// Inline field-level validation message (Category 1 of the standard).
/// Sits directly under a form field — no icon, no modal, low emphasis.
class SelahFieldError extends StatelessWidget {
  final String? message;
  const SelahFieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        message!,
        style: SelahText.subtext(size: 12, color: SelahColors.destructive),
      ),
    );
  }
}

/// LOCK 2 action-failure presentation. Existing retry/dismiss callbacks stay
/// with their original action; the banner never retries a write by itself.
class SelahErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Key? retryKey;

  const SelahErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.retryKey,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: SelahColors.dawnSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SelahColors.dawnLine),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SelahColors.dawn,
            shape: BoxShape.circle,
          ),
          child: Text(
            '!',
            style: SelahText.body(size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: SelahText.body(size: 14, color: SelahColors.foreground),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 12),
          OutlinedButton(
            key: retryKey,
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: SelahColors.foreground,
              side: const BorderSide(color: SelahColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('Try again', style: SelahText.button(size: 13.5)),
          ),
        ],
        if (onDismiss != null)
          IconButton(
            onPressed: onDismiss,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: const Icon(Icons.close, color: SelahColors.muted, size: 16),
          ),
      ],
    ),
  );
}

/// LOCK 2 whole-screen failure, used only at an existing failed load gate.
class SelahLoadFailure extends StatelessWidget {
  const SelahLoadFailure({super.key, required this.contentName, this.onRetry});

  final String contentName;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SelahEmptyState(
    key: const ValueKey('selah_load_failure'),
    icon: Icons.error_outline,
    title: '$contentName didn’t load',
    message: 'Check your connection, then try again. Nothing you did was lost.',
    ctaLabel: onRetry == null ? null : 'Try again',
    onCta: onRetry,
  );
}

/// Full empty-state layout (Category 3) — "nothing here yet", not an
/// error. Centred icon + one line of copy + optional single CTA.
class SelahEmptyState extends StatelessWidget {
  final IconData icon;

  /// Optional heading above the message (2026-08-13). Null on every
  /// existing empty state — those stay exactly as they were, one line
  /// under the icon. Supplied only where the empty state names the
  /// thing that is empty before saying what will fill it.
  final String? title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const SelahEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '’',
              style: const TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontWeight: FontWeight.w600,
                fontSize: 70,
                height: 1,
                color: SelahColors.dawn,
              ),
            ),
            const SizedBox(height: 14),
            if (title != null) ...[
              Text(
                title!,
                style: SelahText.body(
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
            ],
            Text(
              message,
              style: SelahText.subtext(size: 13, color: SelahColors.muted),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              SizedBox(height: 16),
              FilledButton(
                // Shared primary geometry, focus/semantics and disabled
                // state, rather than a small purple gesture-only bubble.
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  backgroundColor: SelahColors.lake,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(ctaLabel!, style: SelahText.button(size: 13.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fallback for anything not anticipated (Category 5) — never a raw
/// exception or blank screen.
class SelahUnknownErrorState extends StatelessWidget {
  final VoidCallback? onRetry;
  final String contentName;
  const SelahUnknownErrorState({
    super.key,
    this.onRetry,
    this.contentName = 'Content',
  });

  @override
  Widget build(BuildContext context) =>
      SelahLoadFailure(contentName: contentName, onRetry: onRetry);
}

/// Small "why is this disabled" hint (Category 4) — used under a
/// disabled Continue button so the user knows what's blocking them
/// rather than silently greying out.
class SelahDisabledHint extends StatelessWidget {
  final String message;
  const SelahDisabledHint(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        style: SelahText.subtext(size: 12, color: SelahColors.ink(0.55)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The large "+" invitation for a blank page — one circle, one short
/// line, centred in the usable page. EXTRACTED 2026-08-23 (GN Draft 3.2) from
/// seeker_mentor_tab.dart's private _AddShepherdButton so the Mentor side's
/// empty surfaces (Dashboard, Network, Seekers) match the Shepherds
/// page exactly (Founder: "it should copy picture 1").
///
/// Layout contract at every empty-state call site (Founder follow-up,
/// 2026-08-23): page title remains at the top; this control sits dead-centre
/// in the remaining usable page, above the floating navigation clearance.
class SelahAddCircle extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;
  const SelahAddCircle({super.key, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: SelahColors.frostFill,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SelahColors.frostBorder, width: 1),
              ),
              child: Icon(Icons.add, size: 34, color: SelahColors.foreground),
            ),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          SizedBox(height: 14),
          Text(
            label!,
            style: SelahText.body(size: 15, color: SelahColors.ink(0.75)),
          ),
        ],
      ],
    );
  }
}
