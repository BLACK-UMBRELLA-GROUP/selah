import 'package:flutter/material.dart';

import '../screens/subscription/upgrade_screen.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// A visible membership boundary, not an empty list or a purchase action.
/// The Upgrade route only opens the existing honest membership information.
class SelahMembershipHistoryLock extends StatelessWidget {
  final String description;

  const SelahMembershipHistoryLock({super.key, required this.description});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 19, color: SelahColors.ink(0.65)),
            const SizedBox(width: 10),
            Expanded(child: Text(description, style: SelahText.subtext())),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
          ),
          child: const Text('Upgrade'),
        ),
        const SizedBox(height: 6),
        Text(
          'View membership information. Purchases are not available yet.',
          style: SelahText.subtext(size: 11.5),
        ),
      ],
    ),
  );
}
