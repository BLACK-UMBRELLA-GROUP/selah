import 'package:flutter/material.dart';

import '../screens/settings/settings_screen.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'dev_settings_design_state.dart';

/// Founder-only visual comparison. It opens the existing Settings routes, so
/// the candidate shows the real Seeker/Shepherd content and never fabricates
/// a theme, language or account control that SELAH does not support.
class DevSettingsDesignPicker extends StatelessWidget {
  const DevSettingsDesignPicker({
    super.key,
    required this.shepherd,
    this.enabled = true,
    this.onBeforeOpen,
  });

  final bool shepherd;
  final bool enabled;
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (!SelahDeveloperAccess.isMainAppFounderPreview) {
        return const SizedBox.shrink();
      }
      return ValueListenableBuilder<SelahSettingsDesign>(
        valueListenable: SelahDevSettingsDesign.selection,
        builder: (context, selected, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings design', style: SelahText.body(size: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final design in SelahSettingsDesign.values)
                  ChoiceChip(
                    key: ValueKey('dev_settings_design_${design.name}'),
                    selected: selected == design,
                    label: Text(
                      design == SelahSettingsDesign.current
                          ? 'Current'
                          : 'Smooth cards',
                      style: SelahText.body(size: 11),
                    ),
                    selectedColor: SelahColors.unlockText.withValues(alpha: .24),
                    onSelected: enabled
                        ? (_) => SelahDevSettingsDesign.select(design)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('dev_settings_open'),
              onPressed: enabled
                  ? () {
                      onBeforeOpen?.call();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(shepherd: shepherd),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      );
    },
  );
}
