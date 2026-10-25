import 'package:flutter/foundation.dart' show debugPrint;

/// Runs an idempotent persistence write without turning an exception into a
/// success signal.
///
/// The caller owns the UI policy (retry, keep text, or keep a confirmation
/// open). This helper owns only the shared truth boundary: `true` means the
/// requested server state exists; `false` means it is not known to exist.
Future<bool> runSelahTruthfulWrite({
  required String context,
  required Future<void> Function() write,
  bool duplicateIsSuccess = false,
}) async {
  try {
    await write();
    return true;
  } catch (error) {
    if (duplicateIsSuccess && error.toString().contains('duplicate key')) {
      return true;
    }
    debugPrint('SELAH: $context failed - $error');
    return false;
  }
}

/// The Pause write has named business refusals and one important default:
/// every unknown failure remains an exception so the confirmation surface
/// stays open and can say the pause did not happen.
Future<void> runSelahPauseWrite({
  required Future<void> Function() write,
  required Object Function() pausedLimit,
  required Object Function() legacyPlanRefusal,
}) async {
  try {
    await write();
  } catch (error) {
    final message = error.toString();
    if (message.contains('paused_limit_reached')) throw pausedLimit();
    if (message.contains('suspension_requires_one')) {
      throw legacyPlanRefusal();
    }
    rethrow;
  }
}
