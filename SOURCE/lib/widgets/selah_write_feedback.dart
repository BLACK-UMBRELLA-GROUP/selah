import 'package:flutter/material.dart';

import '../services/selah_developer_access.dart';

/// Decision cards stay optimistically advanced, but a failed persistence
/// write is never silent and retry remains safe because the writes are
/// idempotent.
void showSelahDecisionWriteFailure(
  BuildContext context, {
  required String decision,
  required Future<bool> Function() retry,
}) {
  // Developer comparison cards can deliberately be disconnected from a
  // persistable server row. Their visual decision feedback is already on the
  // card; a product failure snackbar across the bottom makes the preview look
  // broken and can survive after Reset removes the card. Production retains
  // the truthful retry surface below.
  if (SelahDeveloperAccess.canUseDeveloperTools) {
    debugPrint('SELAH dev decision write skipped UI feedback: $decision');
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Your $decision didn't save — check your connection."),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () async {
          final ok = await retry();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? '$decision saved.'
                    : "Still couldn't save — please try again later.",
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    ),
  );
}

void showSelahFamilyAnswersWriteFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        "Some answers didn't save — check your connection and press Submit again.",
      ),
    ),
  );
}
