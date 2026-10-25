// Account → Advanced. The only place Delete Account appears.
//
// NEW 2026-08-06. Founder: "Delete should never be visible in the main
// list… the goal isn't to hide it unfairly, but to avoid making such a
// destructive action one of the most visually prominent items on the page."
//
// So it is two taps down, and the two actions here are deliberately NOT
// presented as equivalent. Deactivating is reversible and is offered first,
// because for most people wanting to step away it is the thing they
// actually mean.
//
// "HIDE MY PROFILE" WAS REMOVED FROM THIS SCREEN — Founder, 2026-08-07:
// "in setting in discovery we have discovery and visibility which is the
// same thing. I'd rather leave it in the privacy section."
//
// It wrote `profiles.is_active` — the same column as Privacy's "Visible in
// Browse". The earlier attempt to live with that made them read the same
// value and said so in the copy, which reduced the confusion without
// removing it: the page still offered the same switch twice, and a page
// that does that is a page people stop trusting.
//
// Visibility is a privacy control, so it lives in Privacy. This screen is
// now the three things that change what your account IS, ordered by how
// much of it survives.
//
// If deactivation ever gains its own meaning — a grace period, a stated
// intent to leave — it gains its own column at the same time, and can come
// back here as a genuinely different thing.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_profile_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../auth_gate.dart';
import '../welcome_screen.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_glass_dialog.dart';

class AccountAdvancedScreen extends StatefulWidget {
  final bool shepherd;

  const AccountAdvancedScreen({super.key, this.shepherd = false});

  @override
  State<AccountAdvancedScreen> createState() => _AccountAdvancedScreenState();
}

class _AccountAdvancedScreenState extends State<AccountAdvancedScreen> {
  bool _busy = false;

  /// Reset profile — NEW 2026-08-07.
  ///
  /// The dialog names what survives before what goes, because the fear
  /// this button has to answer is "am I about to lose my account?" — and
  /// the answer is no. Keeping that first is the difference between this
  /// and Delete.
  Future<void> _reset() async {
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.restart_alt_rounded,
      title: 'Start fresh?',
      body:
          'You keep your account, your Shepherds, your membership and any '
          'unlocks you have paid for.\n\n'
          "You'll clear your answers, your details and your photos, and go "
          'through setup again. Everyone who passed on you, saved you or '
          'considered you starts over too, so you appear as new.\n\n'
          "Your name, date of birth and gender stay as they are. This can't "
          'be undone.',
      primaryLabel: 'Start fresh',
      secondaryLabel: 'Cancel',
      bodyTextAlign: TextAlign.left,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final res = await SelahProfileService.resetProfile();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (res.outcome) {
      case SelahResetOutcome.done:
        // Straight back through the gate. profile_complete is false now, so
        // the router lands them in onboarding — the same path a new Seeker
        // takes, rather than a second one built to imitate it.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );

      case SelahResetOutcome.blockedByJourney:
        // NOT an error. The rule is the feature: another family is in that
        // conversation, and they should not lose a Journey because someone
        // pressed a button in Settings.
        showSelahGlassNotice(
          context: context,
          icon: Icons.shield_outlined,
          title: 'You have an Active Journey',
          body: res.activeJourneys == 1
              ? 'Starting fresh would leave the person you are talking to '
                    'in a conversation with a profile that no longer exists.'
                    '\n\nEnd the Journey first — there is a proper way to do '
                    'that, and they will be told.'
              : 'You have ${res.activeJourneys} Active Journeys. Starting '
                    'fresh would leave those conversations attached to a '
                    'profile that no longer exists.\n\nEnd them first — there '
                    'is a proper way to do that, and they will be told.',
          bodyTextAlign: TextAlign.left,
        );

      case SelahResetOutcome.refused:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting fresh is for Seeker profiles.'),
          ),
        );

      case SelahResetOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "That didn't go through. Nothing was changed — please try again.",
            ),
          ),
        );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete your account?',
      body: widget.shepherd
          ? 'This permanently deletes your Shepherd account and ends your '
                'links to every Seeker you support. If you are someone’s only '
                'linked Shepherd, they will need to link a new one. This '
                'cannot be undone.'
          : 'This permanently deletes your profile, photos, Matches, messages, and '
                'Shepherd links — including your side of any shared conversation history '
                "with someone you've matched with. This cannot be undone.\n\n"
                "If you only want to stop being seen, hiding your profile does that "
                'and keeps everything.',
      primaryLabel: 'Delete Account',
      secondaryLabel: 'Cancel',
      destructivePrimary: true,
      bodyTextAlign: TextAlign.left,
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SelahLoading(),
    );
    final ok = await SelahAuth.deleteAccount();
    if (!mounted) return;
    Navigator.of(context).pop(); // spinner

    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("We couldn't delete your account. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Advanced', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
            children: [
              // Ordered by how much survives. Reset keeps the account;
              // Delete does not. Nothing here is reversible, so neither is
              // described as though it might be.
              if (!widget.shepherd) ...[
                _DangerRow(
                  label: 'Reset profile',
                  hint:
                      'Clear your answers, details and photos and set up '
                      'again. Keeps your account, Shepherds, membership and '
                      'unlocks.',
                  onTap: _busy ? null : _reset,
                ),
                const SizedBox(height: 14),
              ],
              _DangerRow(
                label: 'Delete account',
                hint: widget.shepherd
                    ? 'Permanent. Ends every Seeker link and removes your '
                          'Shepherd account.'
                    : 'Permanent. Removes your profile, photos, Journeys, '
                          'messages and Shepherd links.',
                destructive: true,
                onTap: _busy ? null : _delete,
              ),
              SizedBox(height: 20),
              Text(
                widget.shepherd
                    ? 'Deleting is irreversible and takes effect immediately. '
                          'Your linked Seekers lose your Shepherd access.'
                    : "Deleting is irreversible and takes effect immediately. If you "
                          'only want to stop being seen for a while, you can turn off '
                          'Visible in Browse under Privacy instead — that keeps '
                          'everything and you can turn it back on whenever you like.',
                style: SelahText.subtext(size: 12, color: SelahColors.ink(0.38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final String label;
  final String hint;
  final bool destructive;
  final VoidCallback? onTap;

  const _DangerRow({
    required this.label,
    required this.hint,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? SelahColors.destructive : Colors.white;
    return Material(
      color: SelahColors.foreground.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: destructive
                  ? SelahColors.destructive.withValues(alpha: 0.30)
                  : SelahColors.foreground.withValues(alpha: 0.11),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SelahText.body(size: 15, color: tint)),
              SizedBox(height: 4),
              Text(
                hint,
                style: SelahText.subtext(size: 12, color: SelahColors.ink(0.38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
