// Founder comparison, 2026-09-27. Opening a study is visual-only; the OS
// icon changes only after the separate, explicitly labelled iPhone action.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/selah_dev_app_icon.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

class DevAppIconDirectionPicker extends StatelessWidget {
  const DevAppIconDirectionPicker({
    super.key,
    this.enabled = true,
    this.onBeforeOpen,
  });

  final bool enabled;
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App icon directions', style: SelahText.body(size: 13)),
          const SizedBox(height: 4),
          Text(
            'Current + ten new ideas. Tap to preview; changing your icon is optional.',
            style: SelahText.subtext(size: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in SelahDevAppIcon.values)
                ActionChip(
                  key: ValueKey('dev_app_icon_${option.name}'),
                  avatar: _IconArtwork(option: option, size: 28),
                  label: Text(option.label, style: SelahText.body(size: 11)),
                  onPressed: !enabled
                      ? null
                      : () {
                          onBeforeOpen?.call();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DevAppIconDirectionsScreen(
                                initialIcon: option,
                              ),
                            ),
                          );
                        },
                ),
            ],
          ),
        ],
      );
    },
  );
}

class DevAppIconDirectionsScreen extends StatefulWidget {
  const DevAppIconDirectionsScreen({
    super.key,
    this.initialIcon = SelahDevAppIcon.goldHorizonCurrent,
    this.controller,
  });

  final SelahDevAppIcon initialIcon;
  final SelahDevAppIconController? controller;

  @override
  State<DevAppIconDirectionsScreen> createState() =>
      _DevAppIconDirectionsScreenState();
}

class _DevAppIconDirectionsScreenState
    extends State<DevAppIconDirectionsScreen> {
  late SelahDevAppIcon _icon = widget.initialIcon;
  SelahDevAppIconController get _controller =>
      widget.controller ?? SelahDevAppIconController.instance;

  @override
  void initState() {
    super.initState();
    // No native channel call at all for an unauthorized direct route.
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      unawaited(_controller.load(force: true));
    }
  }

  void _step(int delta) => setState(() {
    _icon = SelahDevAppIcon
        .values[(_icon.index + delta) % SelahDevAppIcon.values.length];
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDeveloperAccess.authorizationChanges,
      _controller,
    ]),
    builder: (context, _) {
      final authorized = SelahDeveloperAccess.canUseDeveloperTools;
      final onHomeScreen =
          _controller.loaded &&
          _controller.supported &&
          !_controller.hasRetiredIcon &&
          _controller.selected == _icon;
      return Scaffold(
        backgroundColor: SelahColors.luxuryDarkPurple,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: SelahColors.brandGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close icon preview',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('App icon preview', style: SelahText.body()),
                      ),
                      if (authorized)
                        Text(
                          '${_icon.index + 1} / ${SelahDevAppIcon.values.length}',
                          style: SelahText.subtext(size: 12),
                        ),
                    ],
                  ),
                ),
                if (!authorized)
                  Expanded(
                    child: Center(
                      key: const ValueKey('dev_app_icon_directions_denied'),
                      child: Text(
                        'Preview unavailable',
                        style: SelahText.body(),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => _IconArtwork(
                              key: ValueKey('dev_app_icon_art_${_icon.name}'),
                              option: _icon,
                              size: math.min(240, constraints.maxWidth),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _icon.label,
                            textAlign: TextAlign.center,
                            style: SelahText.heading(size: 24),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _icon.detail,
                            textAlign: TextAlign.center,
                            style: SelahText.subtext(size: 13),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Previous icon',
                                onPressed: () => _step(-1),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              // Actual launcher scale as well as the large artwork.
                              Column(
                                children: [
                                  _IconArtwork(option: _icon, size: 60),
                                  const SizedBox(height: 5),
                                  Text(
                                    'SELAH',
                                    style: SelahText.subtext(size: 11),
                                  ),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Next icon',
                                onPressed: () => _step(1),
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final option in SelahDevAppIcon.values)
                                Semantics(
                                  button: true,
                                  selected: option == _icon,
                                  label: option.label,
                                  child: InkWell(
                                    key: ValueKey(
                                      'dev_app_icon_compare_${option.name}',
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    onTap: () => setState(() => _icon = option),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: option == _icon
                                              ? SelahColors.unlockText
                                              : Colors.white12,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: _IconArtwork(
                                        option: option,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (_controller.supported)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('dev_app_icon_apply'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SelahColors.primaryAction,
                                  foregroundColor: SelahColors.onPrimaryAction,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                ),
                                onPressed: _controller.busy || onHomeScreen
                                    ? null
                                    : () {
                                        if (SelahDeveloperAccess
                                            .canUseDeveloperTools) {
                                          unawaited(_controller.select(_icon));
                                        }
                                      },
                                icon: Icon(
                                  onHomeScreen
                                      ? Icons.check_rounded
                                      : Icons.add_to_home_screen_rounded,
                                ),
                                label: Text(
                                  _controller.busy
                                      ? 'Changing icon…'
                                      : onHomeScreen
                                      ? 'On your Home Screen'
                                      : 'Use on iPhone',
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Previewing never changes your login or app theme.',
                            textAlign: TextAlign.center,
                            style: SelahText.subtext(size: 11),
                          ),
                          if (_controller.message != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _controller.message!,
                              key: const ValueKey('dev_app_icon_message'),
                              textAlign: TextAlign.center,
                              style: SelahText.subtext(
                                size: 12,
                                color: _controller.messageIsError
                                    ? SelahColors.destructive
                                    : Colors.white60,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Exact generated PNGs, not approximated Flutter wordmarks. The thumbnail,
// full preview and native icon therefore show the same composition.
class _IconArtwork extends StatelessWidget {
  const _IconArtwork({super.key, required this.option, required this.size});

  final SelahDevAppIcon option;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .223),
    child: Image.asset(
      option.previewAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}
