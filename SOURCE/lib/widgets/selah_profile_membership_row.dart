import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// The one membership-status treatment used directly on both Profile pages.
///
/// It deliberately looks like profile information rather than a promotional
/// badge. Shepherd can still open membership from the row without adding a
/// different visual hierarchy from Seeker.
class SelahProfileMembershipRow extends StatelessWidget {
  const SelahProfileMembershipRow({
    super.key,
    required this.value,
    required this.isOne,
    this.onTap,
  });

  final String value;
  final bool isOne;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        button: onTap != null,
        label:
            'Membership, $value, ${isOne ? 'manage membership' : 'view membership options'}',
        child: InkWell(
          key: ValueKey(isOne ? 'membership-manage' : 'membership-upgrade'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Icon(
                  isOne
                      ? Icons.workspace_premium_outlined
                      : Icons.person_outline_rounded,
                  size: 20,
                  color: isOne
                      ? SelahColors.journeyGold
                      : SelahColors.foregroundSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SelahText.body(
                          size: 14,
                          color: SelahColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOne ? 'Manage membership' : 'View your options',
                        style: SelahText.subtext(
                          size: 11.5,
                          color: isOne
                              ? SelahColors.journeyGold
                              : SelahColors.foregroundSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: SelahColors.foregroundMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
