// LOCK 1: a 46 × 28 Still Water track, with Flutter's switch interaction.
import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

class SelahSwitch extends StatelessWidget {
  const SelahSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 28,
    child: Transform.scale(
      // Flutter 3.44's Material 3 switch paints a 52 × 32 track. Scaling only
      // its paint keeps the normal drag, keyboard and semantics machinery.
      scaleX: 46 / 52,
      scaleY: 28 / 32,
      transformHitTests: false,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        thumbColor: const WidgetStatePropertyAll(SelahColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SelahColors.lake
              : SelahColors.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
    ),
  );
}

/// The existing SwitchListTile contract, with the locked shared switch.
class SelahSwitchListTile extends StatelessWidget {
  const SelahSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.dense,
    this.contentPadding,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      title: title,
      subtitle: subtitle,
      dense: dense,
      contentPadding: contentPadding,
      enabled: onChanged != null,
      // Preserve SwitchListTile's normal trailing allocation and row tap.
      trailing: SizedBox(
        width: 60,
        height: 48,
        child: Center(
          child: SelahSwitch(value: value, onChanged: onChanged),
        ),
      ),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    ),
  );
}
