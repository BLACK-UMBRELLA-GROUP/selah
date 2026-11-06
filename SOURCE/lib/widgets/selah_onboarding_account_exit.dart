import 'package:flutter/material.dart';

import '../screens/welcome_screen.dart';
import '../services/selah_auth.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_glass_dialog.dart';

/// A safe escape from first-time setup when the wrong account was used.
///
/// This deliberately calls [SelahAuth.signOut] rather than Supabase directly,
/// so the account-scoped signup draft and the rest of SELAH's local account
/// state are cleared before the session is released.
class SelahOnboardingAccountExit extends StatefulWidget {
  final String expectedUserId;

  const SelahOnboardingAccountExit({super.key, required this.expectedUserId});

  @override
  State<SelahOnboardingAccountExit> createState() =>
      _SelahOnboardingAccountExitState();
}

class _SelahOnboardingAccountExitState extends State<SelahOnboardingAccountExit> {
  bool _busy = false;
  String? _error;

  bool _guardPrincipal() {
    if (SelahAuth.currentUser?.id == widget.expectedUserId) return true;
    if (mounted) {
      setState(() {
        _busy = false;
        _error = 'Your account changed. Close and reopen Selah.';
      });
    }
    return false;
  }

  Future<void> _confirmAndLeave() async {
    if (_busy || !_guardPrincipal()) return;
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.switch_account_outlined,
      title: 'Use a different account?',
      body:
          'This will clear setup saved on this device and return to sign in. '
          'Your account will not be deleted.',
      primaryLabel: 'Switch account',
      secondaryLabel: 'Cancel',
      primaryKey: const ValueKey('onboarding_account_exit_confirm'),
      secondaryKey: const ValueKey('onboarding_account_exit_cancel'),
    );
    if (confirmed != true || !mounted || !_guardPrincipal()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SelahAuth.signOut(expectedUserId: widget.expectedUserId);
      if (!mounted) return;
      if (SelahAuth.currentUser != null) {
        setState(() {
          _error =
              'Your account changed while signing out. Close and reopen Selah.';
        });
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      debugPrint(
        'SELAH: onboarding account switch failed (${error.runtimeType}).',
      );
      if (!mounted) return;
      // GoTrue can clear the device session before a best-effort server
      // logout request reports a network error. The security postcondition,
      // not the exception alone, decides whether it is safe to show Welcome.
      if (SelahAuth.currentUser == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      } else {
        setState(() {
          _error = "We couldn't sign you out. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: const ValueKey('onboarding_account_exit'),
          onPressed: _busy ? null : _confirmAndLeave,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
          child: _busy
              ? Text(
                  'Signing out…',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.54),
                  ),
                )
              : Text(
                  'Use a different account',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.70),
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: SelahText.subtext(size: 10.5),
            ),
          ),
      ],
    );
  }
}
