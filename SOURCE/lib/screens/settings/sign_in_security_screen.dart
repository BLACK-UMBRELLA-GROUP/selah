import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/selah_loading.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:flutter/services.dart';

import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';

class SignInSecurityScreen extends StatefulWidget {
  const SignInSecurityScreen({super.key});

  @override
  State<SignInSecurityScreen> createState() => _SignInSecurityScreenState();
}

class _SignInSecurityScreenState extends State<SignInSecurityScreen> {
  Future<void> _openRecoveryEmail() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecoveryEmailSetupScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final providers = SelahAuth.linkedProviders;
    final hasOAuth = SelahAuth.hasLinkedOAuth;
    final recoveryEmail = SelahAuth.recoveryEmail;
    final methods = <_CurrentSignInMethod>[
      if (providers.contains('apple'))
        _CurrentSignInMethod(
          key: 'apple',
          icon: Icons.apple,
          title: 'Apple',
          detail: SelahAuth.providerEmail('apple') ?? 'Connected',
        ),
      if (providers.contains('google'))
        _CurrentSignInMethod(
          key: 'google',
          icon: Icons.g_mobiledata,
          title: 'Google',
          detail: SelahAuth.providerEmail('google') ?? 'Connected',
        ),
    ];

    // Seeded developer personas currently use an email identity. Keep that
    // existing method visible without presenting email as a public sign-up
    // choice or offering an unsupported provider-linking action.
    if (methods.isEmpty) {
      methods.add(
        _CurrentSignInMethod(
          key: 'email',
          icon: Icons.alternate_email,
          title: 'Email sign-in',
          detail: SelahAuth.currentUser?.email ?? 'Connected',
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Sign-in & security', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
            children: [
              Text('How you sign in', style: SelahText.heading(size: 24)),
              SizedBox(height: 8),
              Text(
                'These are the sign-in methods currently connected to your Selah account.',
                style: SelahText.body(size: 13.5),
              ),
              SizedBox(height: 22),
              Text(
                'CURRENT SIGN-IN METHODS',
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
              ),
              SizedBox(height: 9),
              for (var index = 0; index < methods.length; index++) ...[
                _MethodCard(
                  key: ValueKey('sign_in_method_${methods[index].key}'),
                  icon: methods[index].icon,
                  title: methods[index].title,
                  detail: methods[index].detail,
                ),
                if (index != methods.length - 1) SizedBox(height: 10),
              ],
              SizedBox(height: 25),
              Text(
                'RECOVERY EMAIL',
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
              ),
              SizedBox(height: 9),
              _RecoveryCard(
                email: recoveryEmail,
                enabled: hasOAuth,
                onTap: _openRecoveryEmail,
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: SelahColors.ink(0.38),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Selah never creates or stores a password. Recovery uses a one-time code sent only to a verified address.',
                      style: SelahText.subtext(size: 12),
                    ),
                  ),
                ],
              ),
              if (!hasOAuth) ...[
                SizedBox(height: 15),
                Text(
                  'Recovery controls become available on an Apple or Google account. This test account remains separate.',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.38),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RecoveryEmailSetupScreen extends StatefulWidget {
  const RecoveryEmailSetupScreen({super.key});

  @override
  State<RecoveryEmailSetupScreen> createState() =>
      _RecoveryEmailSetupScreenState();
}

enum _RecoverySetupStep { email, newEmailCode, currentEmailCode, complete }

class _RecoveryEmailSetupScreenState extends State<RecoveryEmailSetupScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final String _currentEmail = SelahAuth.currentUser?.email ?? '';
  _RecoverySetupStep _step = _RecoverySetupStep.email;
  bool _busy = false;
  String? _error;
  String _newEmail = '';
  late final String? _owner;
  late final int _generation;
  bool _superseded = false;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _owner = SelahAuth.currentUser?.id;
    _generation = SelahAccountState.generation;
    _authSubscription = SelahAuth.authStateChanges.listen(
      (_) => _withdrawSupersededAccount(),
      onError: (Object error, StackTrace stack) =>
          _withdrawSupersededAccount(force: true),
    );
  }

  bool get _accountCurrent =>
      !_superseded &&
      _owner != null &&
      !SelahAccountState.isSigningOut &&
      SelahAuth.currentUser?.id == _owner &&
      SelahAccountState.generation == _generation;

  bool _canAct(_RecoverySetupStep step) =>
      mounted && _accountCurrent && !_busy && _step == step;

  void _withdrawSupersededAccount({bool force = false}) {
    if (!mounted || _superseded || (!force && _accountCurrent)) return;
    setState(() {
      // Irreversible for this route, including an A → B → A replacement.
      _superseded = true;
      _busy = false;
      _newEmail = '';
      _error = null;
      _emailController.clear();
      _codeController.clear();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_canAct(_RecoverySetupStep.email)) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!SelahAuth.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await SelahAuth.requestRecoveryEmail(email);
    if (!mounted || !_accountCurrent) return;
    setState(() {
      _busy = false;
      if (result.outcome == SelahAuthOutcome.success) {
        _newEmail = email;
        _codeController.clear();
        _step = _RecoverySetupStep.newEmailCode;
      } else if (result.outcome == SelahAuthOutcome.error) {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _verifyNewEmail() async {
    final result = await _verifyCode(
      _newEmail,
      _RecoverySetupStep.newEmailCode,
    );
    if (!mounted ||
        !_accountCurrent ||
        result.outcome != SelahAuthOutcome.success) {
      return;
    }

    final complete = await SelahAuth.isRecoveryEmailVerified(_newEmail);
    if (!mounted || !_accountCurrent) return;
    setState(() {
      _busy = false;
      _codeController.clear();
      _step = complete
          ? _RecoverySetupStep.complete
          : _RecoverySetupStep.currentEmailCode;
    });
  }

  Future<void> _verifyCurrentEmail() async {
    final result = await _verifyCode(
      _currentEmail,
      _RecoverySetupStep.currentEmailCode,
    );
    if (!mounted ||
        !_accountCurrent ||
        result.outcome != SelahAuthOutcome.success) {
      return;
    }

    final complete = await SelahAuth.isRecoveryEmailVerified(_newEmail);
    if (!mounted || !_accountCurrent) return;
    setState(() {
      _busy = false;
      if (complete) {
        _step = _RecoverySetupStep.complete;
      } else {
        _error =
            "That confirmation didn't complete the change. Request new codes and try again.";
      }
    });
  }

  Future<SelahAuthResult> _verifyCode(
    String email,
    _RecoverySetupStep step,
  ) async {
    if (!_canAct(step)) return const SelahAuthResult.cancelled();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return const SelahAuthResult.error('Enter the six-digit code.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await SelahAuth.verifyRecoveryEmailCode(
      email: email,
      code: code,
    );
    if (!mounted || !_accountCurrent) return const SelahAuthResult.cancelled();
    if (result.outcome == SelahAuthOutcome.error) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _RecoverySetupStep.email => 'Add recovery email',
      _RecoverySetupStep.newEmailCode => 'Verify your recovery email',
      _RecoverySetupStep.currentEmailCode => 'Confirm it is you',
      _RecoverySetupStep.complete => 'Recovery email added',
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title, style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 70),
            children: [
              if (!_accountCurrent)
                Text(
                  'Your account changed. Return to Sign-in & security and open recovery email again.',
                  style: SelahText.body(size: 13.5),
                )
              else if (_step == _RecoverySetupStep.email) ...[
                Text('A safe way back in.', style: SelahText.heading(size: 27)),
                SizedBox(height: 9),
                Text(
                  'Use any email you control. If you lose Apple or Google access, Selah can send a one-time sign-in code here.',
                  style: SelahText.body(size: 13.5),
                ),
                SizedBox(height: 25),
                _SecurityTextField(
                  key: const ValueKey('recovery_setup_email'),
                  controller: _emailController,
                  label: 'Recovery email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _request(),
                ),
                SizedBox(height: 13),
                Text(
                  'This address is private and is not shown on your profile.',
                  style: SelahText.subtext(size: 11.5),
                ),
                SizedBox(height: 25),
                _SecurityActionButton(
                  key: const ValueKey('recovery_setup_send'),
                  label: 'Send verification code',
                  busy: _busy,
                  onTap: _request,
                ),
              ] else if (_step == _RecoverySetupStep.newEmailCode) ...[
                _CodeStep(
                  title: 'Check $_newEmail',
                  description:
                      'Enter the six-digit code sent to your new recovery email.',
                  controller: _codeController,
                  busy: _busy,
                  buttonKey: const ValueKey('recovery_setup_verify_new'),
                  onVerify: _verifyNewEmail,
                ),
              ] else if (_step == _RecoverySetupStep.currentEmailCode) ...[
                _CodeStep(
                  title: 'Now check $_currentEmail',
                  description:
                      'For security, enter the code sent to your current account email too.',
                  controller: _codeController,
                  busy: _busy,
                  buttonKey: const ValueKey('recovery_setup_verify_current'),
                  onVerify: _verifyCurrentEmail,
                ),
              ] else ...[
                Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: SelahColors.positiveGreen,
                ),
                SizedBox(height: 18),
                Text(
                  'Your backup is ready.',
                  textAlign: TextAlign.center,
                  style: SelahText.heading(size: 27),
                ),
                SizedBox(height: 9),
                Text(
                  'You can now use $_newEmail to request a one-time sign-in code. No password has been created.',
                  textAlign: TextAlign.center,
                  style: SelahText.body(size: 13.5),
                ),
                SizedBox(height: 28),
                _SecurityActionButton(
                  label: 'Done',
                  busy: false,
                  onTap: () {
                    if (_canAct(_RecoverySetupStep.complete)) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: 16),
                SelahErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _MethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return _SecurityCard(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 23),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SelahText.body(size: 14.5)),
                SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.subtext(size: 11.5),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          const _ConnectedBadge(),
        ],
      ),
    );
  }
}

class _CurrentSignInMethod {
  final String key;
  final IconData icon;
  final String title;
  final String detail;

  const _CurrentSignInMethod({
    required this.key,
    required this.icon,
    required this.title,
    required this.detail,
  });
}

class _RecoveryCard extends StatelessWidget {
  final String? email;
  final bool enabled;
  final VoidCallback onTap;

  const _RecoveryCard({
    required this.email,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SecurityCard(
      child: Row(
        children: [
          Icon(Icons.alternate_email, color: SelahColors.ink(0.70), size: 21),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email ?? 'No recovery email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.body(size: 14),
                ),
                SizedBox(height: 3),
                Text(
                  email == null ? 'One-time codes · no password' : 'Verified',
                  style: SelahText.subtext(size: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('manage_recovery_email'),
            onPressed: enabled ? onTap : null,
            child: Text(
              email == null ? 'Add' : 'Change',
              style: SelahText.button(size: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  final Widget child;

  const _SecurityCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SelahColors.iconButtonBorder),
      ),
      child: child,
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: SelahColors.positiveGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: SelahColors.positiveGreen.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        'Connected',
        style: SelahText.subtext(size: 10.5, color: const Color(0xFFBCEBD2)),
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  final String title;
  final String description;
  final TextEditingController controller;
  final bool busy;
  final Key buttonKey;
  final VoidCallback onVerify;

  const _CodeStep({
    required this.title,
    required this.description,
    required this.controller,
    required this.busy,
    required this.buttonKey,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SelahText.heading(size: 25)),
        SizedBox(height: 9),
        Text(description, style: SelahText.body(size: 13.5)),
        SizedBox(height: 25),
        _SecurityTextField(
          key: const ValueKey('recovery_setup_code'),
          controller: controller,
          label: 'Six-digit code',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: const [_SixDigitFormatter()],
          onSubmitted: (_) => busy ? null : onVerify(),
        ),
        SizedBox(height: 24),
        _SecurityActionButton(
          key: buttonKey,
          label: 'Verify code',
          busy: busy,
          onTap: onVerify,
        ),
      ],
    );
  }
}

class _SixDigitFormatter extends TextInputFormatter {
  const _SixDigitFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final value = digits.length > 6 ? digits.substring(0, 6) : digits;
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _SecurityTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  const _SecurityTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.keyboardType,
    required this.textInputAction,
    this.inputFormatters,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: onSubmitted,
      style: SelahText.body(size: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: SelahText.subtext(size: 12.5),
        filled: true,
        fillColor: SelahColors.iconButtonBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: SelahColors.iconButtonBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: SelahColors.actionFill),
        ),
      ),
    );
  }
}

class _SecurityActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _SecurityActionButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        child: busy
            ? SizedBox(width: 18, height: 18, child: SelahLoading())
            : Text(label, style: SelahText.button(size: 14)),
      ),
    );
  }
}
