// Every style starts the protected local onboarding journey at Welcome.
// In-flow choices restart its nested Navigator; live Auth stays unchanged.
import 'package:flutter/material.dart';

import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_onboarding_study.dart';
import '../widgets/selah_segmented_toggle.dart';
import 'dev_onboarding_gold_design.dart';
import 'dev_onboarding_interaction.dart';
import 'dev_onboarding_transition.dart';
import 'dev_onboarding_welcome_motion.dart';
import 'selah_dev_signup.dart';
import 'selah_dev_surface_coordinator.dart';

export '../widgets/selah_onboarding_study.dart' show SelahOnboardingDirection;

/// A separate Home category shared by Seeker, Shepherd and entry previews.
/// The chosen style is session-local, never a live onboarding default.
class DevOnboardingDirectionPicker extends StatelessWidget {
  const DevOnboardingDirectionPicker({
    super.key,
    this.enabled = true,
    this.onBeforeOpen,
  });

  final bool enabled;
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onboarding directions', style: SelahText.body(size: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final direction in SelahOnboardingDirection.values)
              ActionChip(
                key: ValueKey('dev_onboarding_${direction.name}'),
                label: Text(direction.label, style: SelahText.body(size: 11)),
                onPressed: !enabled
                    ? null
                    : () {
                        // Capability may be revoked while this panel is open.
                        // The full flow also observes revocation.
                        if (!SelahDeveloperAccess.canUseDeveloperTools) return;
                        onBeforeOpen?.call();
                        if (SelahDevSurfaceCoordinator.instance
                            .restartOnboarding(direction)) {
                          return;
                        }
                        SelahDevSignUp.start(context, direction: direction);
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Opening story', style: SelahText.body(size: 13)),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: SelahDevOnboardingStoryNavigation.changes,
          builder: (context, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in SelahOnboardingStoryNavigation.values)
                ActionChip(
                  key: ValueKey('dev_onboarding_story_${mode.name}'),
                  backgroundColor:
                      SelahDevOnboardingStoryNavigation.current == mode
                      ? SelahColors.frostSelectedFill
                      : SelahColors.frostFill,
                  label: Text(
                    mode == SelahOnboardingStoryNavigation.tapThrough
                        ? 'Tap through'
                        : 'Scroll down',
                    style: SelahText.body(size: 11),
                  ),
                  onPressed: enabled
                      ? () => SelahDevOnboardingStoryNavigation.select(mode)
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Onboarding navigation', style: SelahText.body(size: 13)),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: SelahDevOnboardingInteraction.changes,
          builder: (context, _) {
            final selected = SelahDevOnboardingInteraction.current;
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: SelahColors.frostFill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: SelahColors.frostBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    for (final mode in SelahOnboardingAdvanceMode.values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected == mode,
                          enabled: enabled,
                          label:
                              mode == SelahOnboardingAdvanceMode.continueButton
                              ? 'Continue button'
                              : 'Animated down arrow',
                          child: InkWell(
                            key: ValueKey(
                              'dev_onboarding_advance_${mode.name}',
                            ),
                            borderRadius: BorderRadius.circular(19),
                            onTap: enabled
                                ? () =>
                                      SelahDevOnboardingInteraction.select(mode)
                                : null,
                            child: AnimatedContainer(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : SelahSegmentedMotion.selectionDuration,
                              curve: SelahSegmentedMotion.selectionCurve,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected == mode
                                    ? SelahColors.frostSelectedFill
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: selected == mode
                                      ? SelahColors.frostSelectedBorder
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                mode == SelahOnboardingAdvanceMode.continueButton
                                    ? 'Continue'
                                    : 'Animated down arrow',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SelahText.button(
                                  size: 11,
                                  color: selected == mode
                                      ? SelahColors.foreground
                                      : SelahColors.foregroundSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Kept in its own developer-toggle section: changing the motion does not
/// restart the four-page welcome story or alter an ordinary signup route.
class DevOnboardingTransitionPicker extends StatelessWidget {
  const DevOnboardingTransitionPicker({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDeveloperAccess.authorizationChanges,
      SelahDevOnboardingTransition.changes,
      SelahDevWelcomeTextMotion.changes,
      SelahDevWelcomePulseIntensity.changes,
      SelahDevWelcomePulseDesign.changes,
      SelahDevOnboardingGoldDesign.changes,
      SelahDevOnboardingGoldMotion.changes,
    ]),
    builder: (context, _) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        return const SizedBox.shrink();
      }
      final selected = SelahDevOnboardingTransition.current;
      final welcomeSelected = SelahDevWelcomeTextMotion.current;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Opening slide motion', style: SelahText.body(size: 13)),
          const SizedBox(height: 8),
          for (final family in [SelahWelcomeTextMotionFamily.descent]) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final motion in SelahWelcomeTextMotion.values.where(
                  (candidate) => candidate.family == family,
                ))
                  Semantics(
                    button: true,
                    selected: welcomeSelected == motion,
                    enabled: enabled,
                    label: motion.label,
                    child: InkWell(
                      key: ValueKey('dev_welcome_text_motion_${motion.name}'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: enabled
                          ? () => SelahDevWelcomeTextMotion.select(motion)
                          : null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: welcomeSelected == motion
                              ? SelahColors.frostSelectedFill
                              : SelahColors.frostFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: welcomeSelected == motion
                                ? SelahColors.frostSelectedBorder
                                : SelahColors.frostBorder,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Text(
                            motion.label,
                            style: SelahText.button(
                              size: 11,
                              color: welcomeSelected == motion
                                  ? SelahColors.foreground
                                  : SelahColors.foregroundSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text('Opening gold accents', style: SelahText.body(size: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final design in SelahOnboardingGoldDesign.values)
                Semantics(
                  button: true,
                  selected: SelahDevOnboardingGoldDesign.current == design,
                  enabled: enabled,
                  label: design.label,
                  child: InkWell(
                    key: ValueKey('dev_onboarding_gold_design_${design.name}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: enabled
                        ? () => SelahDevOnboardingGoldDesign.select(design)
                        : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: SelahDevOnboardingGoldDesign.current == design
                            ? SelahColors.frostSelectedFill
                            : SelahColors.frostFill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: SelahDevOnboardingGoldDesign.current == design
                              ? SelahColors.frostSelectedBorder
                              : SelahColors.frostBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(7, 4, 12, 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelahOnboardingGoldSwatch(design),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                design.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SelahText.button(size: 11),
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
          const SizedBox(height: 16),
          Text('Gold animation', style: SelahText.body(size: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final motion in SelahOnboardingGoldMotion.values)
                ActionChip(
                  key: ValueKey('dev_onboarding_gold_motion_${motion.name}'),
                  backgroundColor: SelahDevOnboardingGoldMotion.current == motion
                      ? SelahColors.frostSelectedFill
                      : SelahColors.frostFill,
                  label: Text(motion.label, style: SelahText.body(size: 11)),
                  onPressed: enabled
                      ? () => SelahDevOnboardingGoldMotion.select(motion)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Separate comparison page transition',
            style: SelahText.body(size: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final transition in SelahOnboardingPageTransition.values)
                Semantics(
                  button: true,
                  selected: selected == transition,
                  enabled: enabled,
                  label: transition.label,
                  child: InkWell(
                    key: ValueKey(
                      'dev_onboarding_transition_${transition.name}',
                    ),
                    borderRadius: BorderRadius.circular(18),
                    onTap: enabled
                        ? () => SelahDevOnboardingTransition.select(transition)
                        : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected == transition
                            ? SelahColors.frostSelectedFill
                            : SelahColors.frostFill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected == transition
                              ? SelahColors.frostSelectedBorder
                              : SelahColors.frostBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Text(
                          transition.label,
                          style: SelahText.button(
                            size: 11,
                            color: selected == transition
                                ? SelahColors.foreground
                                : SelahColors.foregroundSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
