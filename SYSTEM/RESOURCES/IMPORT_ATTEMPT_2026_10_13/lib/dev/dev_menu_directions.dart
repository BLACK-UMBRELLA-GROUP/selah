// Founder-requested structural navigation comparisons. No saved member choice,
// route/entitlement changes or production-default adoption.
import 'package:flutter/material.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahMenuDesign {
  current(
    'Current · Floating menu',
    'Keep the existing navigation',
    Icons.view_week_outlined,
  ),
  grid('Grid', 'Open a grid of your app destinations', Icons.grid_view_rounded),
  sideMenu('Side Menu', 'A menu drawer on the left', Icons.menu_rounded),
  tabBar(
    'Tab Bar',
    'A labelled bar across the bottom',
    Icons.space_dashboard_outlined,
  ),
  fab(
    'FAB',
    'A floating button opens destination shortcuts',
    Icons.add_rounded,
  ),
  sheet(
    'Sheet',
    'Open navigation in a bottom sheet',
    Icons.expand_less_rounded,
  ),
  threeDots(
    'Three Dots',
    'A compact anchored destination menu',
    Icons.more_horiz_rounded,
  ),
  rectangular(
    'Rectangular',
    'A slim navigation rail on the left',
    Icons.view_sidebar_outlined,
  ),
  rudder(
    'Rudder',
    'A bottom bar with a raised dashboard button',
    Icons.navigation_outlined,
  );

  const SelahMenuDesign(this.label, this.detail, this.icon);
  final String label;
  final String detail;
  final IconData icon;

  bool get opensMenu => switch (this) {
    grid || sideMenu || fab || sheet || threeDots => true,
    _ => false,
  };
}

class SelahDevMenuDesign extends ChangeNotifier {
  SelahDevMenuDesign._() {
    SelahDeveloperAccess.authorizationChanges.addListener(_reset);
    AppState.instance.addListener(_accountChanged);
  }

  static final instance = SelahDevMenuDesign._();
  SelahMenuDesign _selection = SelahMenuDesign.current;
  int _generation = SelahAccountState.generation;
  int _revision = 0;

  int get revision => _revision;
  SelahMenuDesign get effectiveDesign =>
      SelahDeveloperAccess.canUseDeveloperTools &&
          !SelahAccountState.isSigningOut &&
          _generation == SelahAccountState.generation
      ? _selection
      : SelahMenuDesign.current;

  bool isCurrent(int generation, int revision) =>
      SelahDeveloperAccess.canUseDeveloperTools &&
      !SelahAccountState.isSigningOut &&
      generation == SelahAccountState.generation &&
      revision == _revision;

  bool select(
    SelahMenuDesign value, {
    required int expectedGeneration,
    required int expectedRevision,
  }) {
    if (!isCurrent(expectedGeneration, expectedRevision)) return false;
    if (_generation == expectedGeneration && _selection == value) return true;
    _generation = expectedGeneration;
    _selection = value;
    _revision++;
    notifyListeners();
    return true;
  }

  void _accountChanged() {
    if (_generation != SelahAccountState.generation) _reset();
  }

  void _reset() {
    _selection = SelahMenuDesign.current;
    _generation = SelahAccountState.generation;
    _revision++;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    assert(() {
      _reset();
      return true;
    }());
  }
}

class DevMenuDirectionPicker extends StatelessWidget {
  const DevMenuDirectionPicker({super.key, this.enabled = true});
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDevMenuDesign.instance,
    builder: (context, _) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        return const SizedBox.shrink();
      }
      final state = SelahDevMenuDesign.instance;
      final generation = SelahAccountState.generation;
      final revision = state.revision;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mobile menu', style: SelahText.body(size: 15)),
          const SizedBox(height: 6),
          Text(
            'Try these in the Seeker or Shepherd app. Session-only; '
            'Current remains the default. Close this toggle to compare.',
            style: SelahText.subtext(
              size: 12,
              color: SelahColors.foregroundSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final design in SelahMenuDesign.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: state.effectiveDesign == design
                    ? SelahColors.journeyGold.withValues(alpha: .13)
                    : SelahColors.surfaceFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: state.effectiveDesign == design
                        ? SelahColors.journeyGold.withValues(alpha: .6)
                        : SelahColors.surfaceBorder,
                  ),
                ),
                child: InkWell(
                  key: ValueKey('dev_menu_design_${design.name}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: !enabled
                      ? null
                      : () => state.select(
                          design,
                          expectedGeneration: generation,
                          expectedRevision: revision,
                        ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          design.icon,
                          color: SelahColors.journeyGold,
                          size: 23,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                design.label,
                                style: SelahText.body(size: 14),
                              ),
                              Text(
                                design.detail,
                                style: SelahText.subtext(
                                  size: 11.5,
                                  color: SelahColors.foregroundSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          state.effectiveDesign == design
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          color: state.effectiveDesign == design
                              ? SelahColors.journeyGold
                              : SelahColors.foregroundMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
