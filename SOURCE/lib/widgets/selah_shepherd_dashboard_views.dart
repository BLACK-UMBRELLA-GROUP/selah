import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/selah_shepherd_dashboard.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';

/// LOCK20 presentation. The caller owns all existing source data, current-link
/// checks, action guards and Circle navigation; this view owns no authority.
class SelahShepherdDashboardView extends StatelessWidget {
  const SelahShepherdDashboardView({
    super.key,
    required this.prayerRequests,
    required this.needs,
    required this.checkIns,
    required this.updates,
    required this.onNeed,
    required this.onMessage,
    this.needsStatus,
  });

  final Widget prayerRequests;
  final List<SelahShepherdDashboardNeed> needs;
  final List<SelahShepherdCheckIn> checkIns;
  final Widget updates;
  final ValueChanged<SelahShepherdDashboardNeed> onNeed;
  final ValueChanged<SelahShepherdCheckIn> onMessage;

  /// The existing owner's loading/unavailable card replaces the ordinary
  /// Needs you card. A failed source is never rendered as a successful empty.
  final Widget? needsStatus;

  @override
  Widget build(BuildContext context) {
    final reserve =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('shepherd_dashboard_scroll'),
        padding: EdgeInsets.fromLTRB(22, 6, 22, reserve + 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SelahWordmark(),
              Text('Shepherd', style: SelahText.subtext(size: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Dashboard',
            key: const ValueKey('concept_shepherd_dashboard_title'),
            style: SelahText.pageTitle(),
          ),
          const SizedBox(height: 14),
          prayerRequests,
          const SizedBox(height: 14),
          _label('Needs you'),
          const SizedBox(height: 14),
          needsStatus ??
              _card(
                key: const ValueKey('shepherd_dashboard_needs'),
                child: needs.isEmpty
                    ? Text(
                        'Nothing needs you right now.',
                        key: const ValueKey('shepherd_dashboard_needs_empty'),
                        style: SelahText.subtext(
                          size: 13,
                        ).copyWith(height: 1.4),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < needs.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: SelahColors.line),
                            _row(
                              title: needs[i].title,
                              detail: needs[i].detail,
                              action: needs[i].actionLabel,
                              actionKey: ValueKey(
                                'shepherd_dashboard_need_${needs[i].id}',
                              ),
                              onTap: () => onNeed(needs[i]),
                            ),
                          ],
                        ],
                      ),
              ),
          if (checkIns.isNotEmpty) ...[
            const SizedBox(height: 14),
            _label('A good time to check in'),
            const SizedBox(height: 14),
            for (var i = 0; i < checkIns.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _card(
                key: ValueKey('shepherd_dashboard_check_in_${checkIns[i].key}'),
                child: _row(
                  title: checkIns[i].title,
                  detail: 'Ask how it’s going, or pray for them this week.',
                  action: 'Message ${checkIns[i].identity.seekerFirstName}',
                  actionKey: ValueKey(
                    'shepherd_dashboard_message_${checkIns[i].key}',
                  ),
                  onTap: () => onMessage(checkIns[i]),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          _label('Updates'),
          const SizedBox(height: 14),
          updates,
          const SizedBox(height: 14),
          Text(
            'Seekers you walk with can ask you for prayer. They see when you have prayed.',
            key: const ValueKey('shepherd_dashboard_prayer_note'),
            style: SelahText.body(size: 13, color: SelahColors.muted),
          ),
        ],
      ),
    );
  }

  static Widget _label(String text) => Text(
    text.toUpperCase(),
    style: SelahText.body(
      size: 11,
      color: SelahColors.muted,
    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.32, height: 1),
  );

  static Widget _card({Key? key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surface,
      border: Border.all(color: SelahColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  static Widget _row({
    required String title,
    required String detail,
    required String action,
    required Key actionKey,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SelahText.body(
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
              ),
              Text(
                detail,
                style: SelahText.subtext(size: 13).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          key: actionKey,
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 35.5),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: SelahText.body(
              size: 13.5,
            ).copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}
