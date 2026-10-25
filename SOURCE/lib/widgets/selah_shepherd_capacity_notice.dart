import 'package:flutter/material.dart';

import '../data/selah_shepherd_capacity.dart';
import '../screens/subscription/upgrade_screen.dart';

/// Keeps limit feedback on the current page; account/link actions remain usable.
void showSelahShepherdCapacityNotice(BuildContext context, String? message) {
  if (!SelahShepherdCapacity.isCapacityMessage(message)) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message!),
      action: message == SelahShepherdCapacity.basicLimitMessage
          ? SnackBarAction(
              label: 'Upgrade',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
            )
          : null,
    ),
  );
}
