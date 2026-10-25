// Shepherd notification settings use the same persisted five-category
// service and the same honest device-permission state as Seeker settings.
// Copy adapts by role; storage codes and consent semantics do not fork.

import 'package:flutter/material.dart';

import '../../services/selah_notification_prefs_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../settings/notification_settings_screen.dart';

class MentorNotificationSettingsScreen extends StatelessWidget {
  final Future<Map<SelahNotifyCategory, bool>?> Function()? loadPreferences;
  final Future<bool> Function(SelahNotifyCategory, bool)? savePreference;

  const MentorNotificationSettingsScreen({
    super.key,
    this.loadPreferences,
    this.savePreference,
  });

  @override
  Widget build(BuildContext context) => NotificationSettingsScreen(
    role: SelahPromotionRole.shepherd,
    loadPreferences: loadPreferences,
    savePreference: savePreference,
  );
}
