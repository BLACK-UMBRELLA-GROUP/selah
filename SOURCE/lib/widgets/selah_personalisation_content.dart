import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';

/// Presentation values only. This snapshot neither reads nor saves an account.
@immutable
class SelahPersonalisationSnapshot {
  const SelahPersonalisationSnapshot({
    required this.palette,
    required this.hapticLevel,
    required this.goldEnabled,
  });

  final SelahDevPalette palette;
  final SelahHapticLevel hapticLevel;
  final bool goldEnabled;
}

/// Retained member content with explicit caller-owned values and actions.
/// No account lookup, preference setter or default action fallback exists here.
class SelahPersonalisationContent extends StatelessWidget {
  const SelahPersonalisationContent({
    super.key,
    required this.snapshot,
    required this.onChooseBackground,
    required this.onChooseHaptic,
    required this.onGoldChanged,
    this.previewGradient,
    this.scrollKey = const ValueKey('personalisation-scroll'),
  });

  final SelahPersonalisationSnapshot snapshot;
  final VoidCallback? onChooseBackground;
  final VoidCallback? onChooseHaptic;
  final ValueChanged<bool>? onGoldChanged;
  final LinearGradient? previewGradient;
  final Key scrollKey;

  @override
  Widget build(BuildContext context) => ListView(
    key: scrollKey,
    physics: const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
    children: [
      Text(
        'MAKE IT YOURS',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose how SELAH looks and responds.',
        style: SelahText.heading(size: 23),
      ),
      const SizedBox(height: 7),
      Text(
        'Your choices apply across the app on this device. They never change your profile or account.',
        style: SelahText.subtext(size: 12.5, color: SelahColors.ink(0.52)),
      ),
      const SizedBox(height: 22),
      _PersonalisationPreview(
        key: const ValueKey('personalisation_preview'),
        gradient: previewGradient,
      ),
      const SizedBox(height: 26),
      Text(
        'YOUR EXPERIENCE',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SelahColors.surfaceBorder, width: 0.6),
        ),
        child: Column(
          children: [
            _PersonalisationRow(
              key: const ValueKey('personalisation_haptic'),
              icon: Icons.vibration_outlined,
              title: 'Haptic feel',
              value: snapshot.hapticLevel.label,
              hint: 'Set how strongly controls respond to your touch.',
              onTap: onChooseHaptic,
            ),
          ],
        ),
      ),
    ],
  );
}

class _PersonalisationPreview extends StatelessWidget {
  const _PersonalisationPreview({super.key, this.gradient});

  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        color: gradient == null ? SelahColors.surfaceFill : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SelahColors.surfaceBorder, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SelahColors.journeyGold,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'LIVE PREVIEW',
                  style: SelahText.chapterLabel(color: SelahColors.unlockText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const SelahWordmark(size: 36),
          const SizedBox(height: 5),
          Text(
            'Connecting Through Trust',
            style: SelahText.preview(
              SelahAppFont.figtree,
              size: 15,
              color: SelahColors.foreground,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your background changes appear immediately.',
            style: SelahText.preview(
              SelahAppFont.figtree,
              size: 11,
              color: SelahColors.ink(0.46),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 74,
            height: 1.2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  SelahColors.journeyGold.withValues(alpha: 0),
                  SelahColors.journeyGold,
                  SelahColors.journeyGold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalisationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final VoidCallback? onTap;

  const _PersonalisationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 13, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SelahColors.accentBg,
                  border: Border.all(
                    color: SelahColors.accentBorder,
                    width: 0.6,
                  ),
                ),
                child: Icon(icon, size: 19, color: SelahColors.foreground),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SelahText.body(
                        size: 14,
                        color: SelahColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SelahText.subtext(
                        size: 12,
                        color: SelahColors.unlockText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: SelahText.subtext(
                        size: 10.5,
                        color: SelahColors.ink(0.40),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: SelahColors.ink(0.34),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SelahPersonalisationChoiceSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T selected;
  final String Function(T option) labelFor;
  final String? Function(T option)? detailFor;
  final Widget Function(T option)? leadingFor;
  final Widget Function(T option)? trailingFor;
  final TextStyle Function(T option, bool selected)? titleStyleFor;
  final ValueChanged<T> onSelected;

  const SelahPersonalisationChoiceSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.detailFor,
    this.leadingFor,
    this.trailingFor,
    this.titleStyleFor,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.76;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(title, style: SelahText.heading(size: 18)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  final detail = detailFor?.call(option);
                  return Material(
                    color: isSelected
                        ? SelahColors.accentBg
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      key: ValueKey(
                        'personalisation_choice_${option.toString()}',
                      ),
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (leadingFor != null) ...[
                              leadingFor!(option),
                              const SizedBox(width: 11),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    labelFor(option),
                                    style:
                                        titleStyleFor?.call(
                                          option,
                                          isSelected,
                                        ) ??
                                        SelahText.body(
                                          size: 14,
                                          color: SelahColors.foreground,
                                        ),
                                  ),
                                  if (detail != null && detail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      detail,
                                      style: SelahText.subtext(
                                        size: 10.5,
                                        color: SelahColors.ink(0.44),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (trailingFor != null) ...[
                              trailingFor!(option),
                              const SizedBox(width: 10),
                            ],
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: isSelected
                                  ? SelahColors.journeyGold
                                  : SelahColors.ink(0.24),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
