// Compatibility stub for the retired notification bell.
//
// My SELAH > Now is the notification centre for both roles. Keeping this class
// as an inert widget means an overlooked legacy import cannot reintroduce a
// bell or navigate to the retired standalone Notifications screen.
import 'package:flutter/material.dart';

@Deprecated('Notifications are owned by My SELAH > Now.')
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
