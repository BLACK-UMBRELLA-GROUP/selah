import 'package:flutter/material.dart';

import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_profile_service.dart';
import '../home/home_shell.dart';
import 'account_path_overview_screen.dart';

/// Leaving an optional profile chapter is not a verification bypass.
Future<bool> returnToMySelah(
  BuildContext context, {
  required bool devPreview,
  required String? expectedUserId,
  required int expectedGeneration,
}) async {
  SelahOnboardingProgress? progress;
  if (devPreview) {
    if (!SelahDeveloperAccess.canUseDeveloperTools ||
        !SelahInternalPreviewClient.isActive) {
      return false;
    }
    progress = SeekerPostIdentityChoiceScreen.previewIncompleteProgress;
  } else {
    final owner = expectedUserId;
    if (owner == null ||
        SelahAuth.currentUser?.id != owner ||
        SelahAccountState.generation != expectedGeneration) {
      return false;
    }
    try {
      final identity = await SelahIdentityVerificationService.fetchMyState(
        expectedUserId: owner,
      ).timeout(const Duration(seconds: 10));
      if (identity?.allowsApp != true) return false;
      progress = await SelahProfileService.fetchOnboardingProgress().timeout(
        const Duration(seconds: 10),
      );
      if (progress == null ||
          SelahAuth.currentUser?.id != owner ||
          SelahAccountState.generation != expectedGeneration) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
  if (!context.mounted) return false;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      allowSnapshotting: !devPreview,
      builder: (_) => HomeShell(
        initialTab: 2,
        deferredOnboardingDevPreview: devPreview,
        initialOnboardingProgress: progress,
      ),
    ),
    (_) => false,
  );
  return true;
}
