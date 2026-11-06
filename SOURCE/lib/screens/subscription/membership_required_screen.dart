import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../services/selah_auth.dart';
import '../../services/selah_product_telemetry.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../settings/account_advanced_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/privacy_and_data_screen.dart';
import '../settings/safety_case_status_screen.dart';
import 'upgrade_screen.dart';

/// Paid-only boundary shown after identity/account routing but before any
/// product shell is built. It deliberately keeps only the controls a locked
/// member must retain: restore/resubscribe, billing, safety/support, data and
/// deletion, legal/privacy information, and sign out.
class MembershipRequiredScreen extends StatelessWidget {
  final bool shepherd;

  const MembershipRequiredScreen({super.key, required this.shepherd});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: SelahAppGoldDecoration(
      gradient: SelahColors.genderGradient(AppState.instance.gender),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Selah', style: SelahText.wordmark(size: 24)),
              const Spacer(),
              Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: SelahColors.journeyGold,
              ),
              const SizedBox(height: 18),
              Text(
                'Your membership is not active',
                textAlign: TextAlign.center,
                style: SelahText.heading(size: 25),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account and saved information are still here. Restore '
                'or choose a monthly membership to continue using Selah.',
                textAlign: TextAlign.center,
                style: SelahText.subtext(size: 13.25),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                key: const ValueKey('membership-required-restore'),
                onPressed: () => _open(
                  context,
                  UpgradeScreen(
                    telemetrySurface: shepherd
                        ? SelahTelemetrySurface.shepherd
                        : SelahTelemetrySurface.seeker,
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_outlined, size: 19),
                label: Text(
                  'Restore or choose membership',
                  style: SelahText.button(size: 13),
                ),
              ),
              const SizedBox(height: 12),
              _RestrictedAction(
                icon: Icons.verified_user_outlined,
                label: 'Safety case status',
                onTap: () => _open(context, const SafetyCaseStatusScreen()),
              ),
              const SizedBox(height: 9),
              _RestrictedAction(
                icon: Icons.support_agent_outlined,
                label: 'Safety & support',
                onTap: () => _open(
                  context,
                  HelpSupportScreen(
                    telemetrySurface: shepherd
                        ? SelahTelemetrySurface.shepherd
                        : SelahTelemetrySurface.seeker,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              _RestrictedAction(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy & data',
                onTap: () => _open(context, const PrivacyAndDataScreen()),
              ),
              const SizedBox(height: 9),
              _RestrictedAction(
                icon: Icons.manage_accounts_outlined,
                label: 'Download or delete account data',
                onTap: () => _open(context, const AccountAdvancedScreen()),
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('membership-required-sign-out'),
                onPressed: SelahAuth.signOut,
                child: Text('Sign out', style: SelahText.button(size: 13)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RestrictedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RestrictedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label, style: SelahText.button(size: 12.5)),
  );
}
