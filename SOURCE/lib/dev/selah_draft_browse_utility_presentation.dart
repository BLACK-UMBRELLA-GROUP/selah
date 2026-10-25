import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// Display-only Scan for the protected fictional preview. No camera, member
/// lookup, code parser, credits or completion callback is available here.
class SelahDraftScanPresentation extends StatelessWidget {
  const SelahDraftScanPresentation({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final frameSide = math.min(
        constraints.maxWidth * .92,
        constraints.hasBoundedHeight ? constraints.maxHeight * .44 : 280.0,
      );
      return _UtilityViewport(
        viewportKey: const ValueKey('draft_scan_viewport'),
        minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        child: Column(
          key: const ValueKey('draft_scan_presentation'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _UtilityTitle('Scan', id: 'draft_scan_title'),
                const SizedBox(height: 14),
                Text(
                  'Find a profile from a shared SELAH Code.',
                  style: SelahText.body(size: 16).copyWith(height: 1.4),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Semantics(
                  label: 'SELAH Code scan illustration. Camera is not active.',
                  excludeSemantics: true,
                  child: SizedBox.square(
                    key: const ValueKey('draft_scan_frame'),
                    dimension: frameSide,
                    child: CustomPaint(
                      painter: _ScanCorners(SelahColors.journeyGold),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .035),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: frameSide * .44,
                              color: SelahColors.journeyGold,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'SELAH CODE',
                              style: SelahText.chapterLabel(
                                color: SelahColors.journeyGold,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _UnavailableAction(
                  id: 'draft_scan_action',
                  label: 'Scan a SELAH Code',
                  icon: Icons.qr_code_scanner_rounded,
                ),
                const SizedBox(height: 12),
                Text(
                  'Scanning isn’t available yet.',
                  textAlign: TextAlign.center,
                  style: SelahText.subtext(size: 14).copyWith(height: 1.4),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// These labels intentionally mirror the existing report reason picker. This
/// display enum has no backend values or submission/preview-store dependency.
enum SelahDraftReportReason {
  fakeProfile('Impersonation or fake profile'),
  inappropriateContent('Nudity or sexual content'),
  harassment('Harassment or abusive behaviour'),
  underage('Minor or underage'),
  violence('Violence or disturbing content'),
  privacy('Privacy or personal information'),
  other('Something else');

  const SelahDraftReportReason(this.label);
  final String label;
}

/// Local reason selection only. The caller supplies the exact public target
/// and guards any optional fictional Hide/Block actions. Submit is always
/// disabled; no real report or simulated moderation record can be created.
class SelahDraftReportPresentation extends StatefulWidget {
  const SelahDraftReportPresentation({
    super.key,
    this.profile,
    this.canSelect,
    this.onHide,
    this.onBlock,
  });

  final SeekerProfile? profile;
  final bool Function()? canSelect;
  final VoidCallback? onHide;
  final VoidCallback? onBlock;

  @override
  State<SelahDraftReportPresentation> createState() =>
      _SelahDraftReportPresentationState();
}

class _SelahDraftReportPresentationState
    extends State<SelahDraftReportPresentation> {
  SelahDraftReportReason? _selected;
  int _renderEpoch = 0;

  @override
  void didUpdateWidget(covariant SelahDraftReportPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    ++_renderEpoch;
    if (oldWidget.profile?.id != widget.profile?.id) _selected = null;
  }

  bool _current(int epoch) =>
      mounted &&
      epoch == _renderEpoch &&
      widget.profile != null &&
      (widget.canSelect?.call() ?? true);

  VoidCallback? _localAction(VoidCallback? action, int epoch) => action == null
      ? null
      : () {
          if (_current(epoch)) action();
        };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final profile = widget.profile;
      final epoch = _renderEpoch;
      final height = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
      if (profile == null) {
        return _UtilityViewport(
          viewportKey: const ValueKey('draft_report_viewport'),
          minHeight: height,
          child: Column(
            key: const ValueKey('draft_report_presentation'),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _UtilityTitle('Safety', id: 'draft_report_title'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 100,
                      color: SelahColors.journeyGold,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose a profile to report.',
                      textAlign: TextAlign.center,
                      style: SelahText.heading(size: 23),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Open the person’s profile and choose Report. '
                      'You can then select the reason that best fits.',
                      textAlign: TextAlign.center,
                      style: SelahText.body(size: 16).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const _UnavailableAction(
                id: 'draft_report_submit',
                label: 'Submit report',
                icon: Icons.flag_outlined,
              ),
            ],
          ),
        );
      }
      final name = [
        profile.firstName,
        if (profile.surnameLine?.trim().isNotEmpty ?? false)
          profile.surnameLine!.trim(),
      ].join(' ');
      return _UtilityViewport(
        viewportKey: const ValueKey('draft_report_viewport'),
        minHeight: height,
        child: Column(
          key: const ValueKey('draft_report_presentation'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _UtilityTitle('Report profile', id: 'draft_report_title'),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Reporting profile: $name',
                  child: Row(
                    key: const ValueKey('draft_report_target'),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox.square(
                          dimension: 64,
                          child: _LocalReportPhoto(
                            profile.photos.isEmpty ? '' : profile.photos.first,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(name, style: SelahText.heading(size: 21)),
                            const SizedBox(height: 4),
                            Text(
                              'Select the reason for your concern.',
                              style: SelahText.subtext(
                                size: 13,
                              ).copyWith(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final reason in SelahDraftReportReason.values) ...[
                    if (reason != SelahDraftReportReason.values.first)
                      const SizedBox(height: 6),
                    Semantics(
                      selected: _selected == reason,
                      child: OutlinedButton(
                        key: ValueKey('draft_report_reason_${reason.name}'),
                        onPressed: !_current(epoch)
                            ? null
                            : () {
                                if (!_current(epoch)) return;
                                setState(() {
                                  _selected = _selected == reason
                                      ? null
                                      : reason;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                          foregroundColor: SelahColors.foreground,
                          backgroundColor: _selected == reason
                              ? SelahColors.journeyGold.withValues(alpha: .12)
                              : Colors.white.withValues(alpha: .045),
                          side: BorderSide(
                            color: _selected == reason
                                ? SelahColors.journeyGold.withValues(alpha: .6)
                                : Colors.white.withValues(alpha: .16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selected == reason
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: _selected == reason
                                  ? SelahColors.journeyGold
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reason.label,
                                style: SelahText.body(
                                  size: 14,
                                ).copyWith(height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _UnavailableAction(
                  id: 'draft_report_submit',
                  label: 'Submit report',
                  icon: Icons.flag_outlined,
                ),
                const SizedBox(height: 10),
                Text(
                  'Reporting isn’t available for this profile.',
                  textAlign: TextAlign.center,
                  style: SelahText.subtext(size: 13).copyWith(height: 1.35),
                ),
                if (widget.onHide != null || widget.onBlock != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (widget.onHide != null)
                        TextButton(
                          key: const ValueKey('draft_safety_hide'),
                          onPressed: _current(epoch)
                              ? _localAction(widget.onHide, epoch)
                              : null,
                          style: _quietActionStyle,
                          child: const Text('Hide profile'),
                        ),
                      if (widget.onBlock != null)
                        TextButton(
                          key: const ValueKey('draft_safety_block'),
                          onPressed: _current(epoch)
                              ? _localAction(widget.onBlock, epoch)
                              : null,
                          style: _quietActionStyle,
                          child: const Text('Block profile'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );

  ButtonStyle get _quietActionStyle => TextButton.styleFrom(
    minimumSize: const Size(44, 44),
    foregroundColor: SelahColors.journeyGold,
    textStyle: SelahText.body(size: 13),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _UtilityViewport extends StatelessWidget {
  const _UtilityViewport({
    required this.viewportKey,
    required this.minHeight,
    required this.child,
  });

  final Key viewportKey;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: viewportKey,
    physics: const ClampingScrollPhysics(),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    ),
  );
}

class _UtilityTitle extends StatelessWidget {
  const _UtilityTitle(this.title, {required this.id});
  final String title;
  final String id;

  @override
  Widget build(BuildContext context) => Text(
    title,
    key: ValueKey(id),
    textAlign: TextAlign.left,
    style: SelahText.heading(size: 26),
  );
}

class _UnavailableAction extends StatelessWidget {
  const _UnavailableAction({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey(id),
    onPressed: null,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      disabledForegroundColor: SelahColors.journeyGold.withValues(alpha: .6),
      backgroundColor: SelahColors.journeyGold.withValues(alpha: .06),
      side: BorderSide(color: SelahColors.journeyGold.withValues(alpha: .25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SelahText.button(size: 14),
          ),
        ),
      ],
    ),
  );
}

class _LocalReportPhoto extends StatelessWidget {
  const _LocalReportPhoto(this.photo);
  final String photo;

  @override
  Widget build(BuildContext context) {
    const neutral = ColoredBox(
      color: SelahColors.luxuryDarkPurple,
      child: Icon(Icons.person_outline, size: 28, color: Colors.white38),
    );
    // Only the caller's in-memory public sample can render. A URL cannot
    // silently open a network provider or load a real member/cached image.
    if (!photo.startsWith('data:image/')) return neutral;
    try {
      final comma = photo.indexOf(',');
      if (comma < 0) return neutral;
      return Image.memory(
        base64Decode(photo.substring(comma + 1)),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => neutral,
      );
    } on FormatException {
      return neutral;
    }
  }
}

class _ScanCorners extends CustomPainter {
  const _ScanCorners(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final length = size.shortestSide * .14;
    const inset = 2.0;
    for (final corner in [
      (Offset(inset, inset), 1.0, 1.0),
      (Offset(size.width - inset, inset), -1.0, 1.0),
      (Offset(inset, size.height - inset), 1.0, -1.0),
      (Offset(size.width - inset, size.height - inset), -1.0, -1.0),
    ]) {
      final point = corner.$1;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + length * corner.$3)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + length * corner.$2, point.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanCorners oldDelegate) =>
      oldDelegate.color != color;
}
