// Feedback — ideas and problem reports from users.
//
// NEW 2026-08-07. Founder: "in setting we need a feedback section where we
// can improve the app from users requests."
//
// A TABLE, NOT AN EMAIL, and the distinction is the point. Help & Support
// already ends in "email us", which is right for someone who is stuck and
// wants a person. This is the other case: someone who is fine and has an
// idea. Those arrive in volume, want counting and grouping, and die in an
// inbox.
//
// Writes go through selah_submit_feedback() — there is deliberately no
// INSERT grant on app_feedback itself, so this service cannot become a
// write-anything endpoint even if someone calls it with odd values. The
// RPC trims, validates the category, stamps user_id server-side and
// rate-limits to ten an hour.

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart';
import 'selah_auth.dart';

enum SelahFeedbackCategory { idea, problem, other }

extension SelahFeedbackCategoryX on SelahFeedbackCategory {
  String get wire => switch (this) {
    SelahFeedbackCategory.idea => 'idea',
    SelahFeedbackCategory.problem => 'problem',
    SelahFeedbackCategory.other => 'other',
  };

  String get label => switch (this) {
    SelahFeedbackCategory.idea => 'Idea',
    SelahFeedbackCategory.problem => 'Problem',
    SelahFeedbackCategory.other => 'Other',
  };
}

enum SelahFeedbackResult { sent, empty, tooLong, rateLimited, failed }

class SelahFeedbackService {
  SelahFeedbackService._();

  /// Reads the version from the installed bundle, matching the Settings
  /// footer. A lookup failure is sent as NULL rather than inventing a build.
  static Future<String?> _installedAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      if (version.isEmpty) return null;
      return build.isEmpty ? version : '$version+$build';
    } catch (error) {
      debugPrint('SELAH: installed app version unavailable.\n$error');
      return null;
    }
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      _ => defaultTargetPlatform.name,
    };
  }

  /// [screen] is where they were when they wrote it — the single most
  /// useful field in a bug report after the message itself.
  static Future<SelahFeedbackResult> submit({
    required SelahFeedbackCategory category,
    required String message,
    String? screen,
  }) async {
    if (!SelahAuth.isSignedIn) return SelahFeedbackResult.failed;
    try {
      final appVersion = await _installedAppVersion();
      final res =
          await supabase.rpc(
                'selah_submit_feedback',
                params: {
                  'p_category': category.wire,
                  'p_message': message,
                  'p_app_version': appVersion,
                  'p_platform': _platform,
                  'p_screen': screen,
                },
              )
              as Map<String, dynamic>;

      return switch (res['status'] as String?) {
        'sent' => SelahFeedbackResult.sent,
        'empty' => SelahFeedbackResult.empty,
        'too_long' => SelahFeedbackResult.tooLong,
        'rate_limited' => SelahFeedbackResult.rateLimited,
        _ => SelahFeedbackResult.failed,
      };
    } catch (e) {
      debugPrint('SELAH: selah_submit_feedback failed.\n$e');
      return SelahFeedbackResult.failed;
    }
  }
}
