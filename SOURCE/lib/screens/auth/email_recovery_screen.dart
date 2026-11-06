import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/selah_loading.dart';
import 'package:flutter/services.dart';

import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_session_router.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';

typedef RecoveryCodeSender = Future<SelahAuthResult> Function(String email);
typedef RecoveryCodeVerifier =
    Future<SelahAuthResult> Function({
      required String email,
      required String code,
    });

class EmailRecoveryScreen extends StatefulWidget {
  final RecoveryCodeSender? sendCode;
  final RecoveryCodeVerifier? verifyCode;
  final Future<void> Function()? onRecovered;

  const EmailRecoveryScreen({
    super.key,
    this.sendCode,
    this.verifyCode,
    this.onRecovered,
  });

  @override
  State<EmailRecoveryScreen> createState() => _EmailRecoveryScreenState();
}

class _EmailRecoveryScreenState extends State<EmailRecoveryScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String _email = '';
  int _request = 0;
  late String? _owner;
  late int _generation;
  bool _verifying = false;
  bool _concealed = false;
  StreamSubscription? _authSubscription;
  static const _connectionError =
      'Having trouble connecting. Check your connection and try again.';

  String? get _currentUserId {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      // Injected, transport-free widget fixtures need no SDK instance.
      return SelahAccountState.userId;
    }
  }

  @override
  void initState() {
    super.initState();
    _owner = _currentUserId;
    _generation = SelahAccountState.generation;
    try {
      _authSubscription = SelahAuth.authStateChanges.listen(
        (_) => _withdrawSupersededAccount(),
        onError: (Object error, StackTrace stack) {
          if (mounted && _accountCurrent) {
            setState(() => _error = _connectionError);
          }
        },
      );
    } catch (_) {
      // Fully injected, transport-free fixtures may omit SDK initialization.
      if (widget.sendCode == null || widget.verifyCode == null) rethrow;
    }
  }

  void _withdrawSupersededAccount() {
    if (!mounted || _accountCurrent) return;
    if (_verifying &&
        _owner == null &&
        !SelahAccountState.isSigningOut &&
        _currentUserId != null) {
      // Hide outgoing private inputs immediately. Only the verifier's bound
      // response can accept this potential first sign-in; its work is not
      // cancelled merely because the SDK publishes signedIn before returning.
      setState(() => _concealed = true);
      return;
    }
    _request++;
    setState(() {
      _busy = false;
      _verifying = false;
      _concealed = false;
      _email = '';
      _codeSent = false;
      _error = null;
      _emailController.clear();
      _codeController.clear();
    });
  }

  bool get _accountCurrent =>
      !SelahAccountState.isSigningOut &&
      _currentUserId == _owner &&
      SelahAccountState.generation == _generation;

  bool _requestAlive(int request) => mounted && request == _request;

  bool _acceptVerifiedPrincipal(SelahAuthResult result) {
    final verifiedUserId = result.authenticatedUserId;
    if (_accountCurrent) {
      return verifiedUserId == null || verifiedUserId == _owner;
    }
    if (_owner != null ||
        verifiedUserId == null ||
        SelahAccountState.isSigningOut ||
        _currentUserId != verifiedUserId) {
      return false;
    }
    final generation = SelahAccountState.generation;
    if (generation != _generation &&
        !(generation == _generation + 1 &&
            SelahAccountState.userId == verifiedUserId)) {
      return false;
    }
    // Synchronize invalidation is immediate; the router joins its cleanup.
    SelahAccountState.synchronize(verifiedUserId);
    _owner = verifiedUserId;
    _generation = SelahAccountState.generation;
    return _accountCurrent;
  }

  void _finishRequest(int request) {
    if (!_requestAlive(request)) return;
    setState(() {
      _busy = false;
      _verifying = false;
      _concealed = false;
      if (!_accountCurrent) {
        _email = '';
        _codeSent = false;
        _error = null;
        _emailController.clear();
        _codeController.clear();
      }
    });
  }

  RecoveryCodeSender get _send =>
      widget.sendCode ?? SelahAuth.sendRecoverySignInCode;
  RecoveryCodeVerifier get _verify =>
      widget.verifyCode ?? SelahAuth.verifyRecoverySignInCode;

  @override
  void dispose() {
    _request++;
    _authSubscription?.cancel().ignore();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!mounted || _busy || !_accountCurrent) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!SelahAuth.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final request = ++_request;
    try {
      final result = await _send(email);
      if (!_requestAlive(request) || !_accountCurrent) return;
      setState(() {
        if (result.outcome == SelahAuthOutcome.success) {
          _email = email;
          _codeSent = true;
          _codeController.clear();
        } else if (result.outcome == SelahAuthOutcome.error) {
          _error = result.errorMessage;
        }
      });
    } catch (_) {
      if (_requestAlive(request) && _accountCurrent) {
        setState(() => _error = _connectionError);
      }
    } finally {
      _finishRequest(request);
    }
  }

  Future<void> _verifyCode() async {
    if (!mounted || _busy || !_codeSent || !_accountCurrent) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _verifying = true;
      _error = null;
    });
    final request = ++_request;
    try {
      final result = await _verify(email: _email, code: code);
      if (!_requestAlive(request)) return;
      if (result.outcome == SelahAuthOutcome.error && _accountCurrent) {
        setState(() => _error = result.errorMessage);
        return;
      }
      if (result.outcome != SelahAuthOutcome.success ||
          !_acceptVerifiedPrincipal(result)) {
        return;
      }

      if (widget.onRecovered != null) {
        await widget.onRecovered!();
        return;
      }
      final home = await SelahSessionRouter.resolveHome();
      if (!mounted || !_requestAlive(request) || !_accountCurrent) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => home),
        (route) => false,
      );
    } catch (_) {
      if (_requestAlive(request) && _accountCurrent) {
        setState(() => _error = _connectionError);
      }
    } finally {
      _finishRequest(request);
    }
  }

  void _changeEmail() {
    if (!mounted || _busy || !_accountCurrent) return;
    _request++;
    setState(() {
      _codeSent = false;
      _busy = false;
      _error = null;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Account recovery', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Visibility(
            visible: !_concealed,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(25, 44, 25, 60),
              children: [
                Icon(
                  _codeSent
                      ? Icons.mark_email_read_outlined
                      : Icons.lock_open_outlined,
                  size: 38,
                  color: SelahColors.unlockText,
                ),
                SizedBox(height: 20),
                Text(
                  _codeSent ? 'Check your email.' : 'Use your recovery email.',
                  textAlign: TextAlign.center,
                  style: SelahText.heading(size: 27),
                ),
                SizedBox(height: 10),
                Text(
                  _codeSent
                      ? 'If $_email is linked to a SELAH account, a six-digit code is on its way.'
                      : 'Enter the verified recovery address you added in Settings. No password is needed.',
                  textAlign: TextAlign.center,
                  style: SelahText.body(size: 13.5),
                ),
                SizedBox(height: 30),
                if (!_codeSent)
                  _RecoveryField(
                    key: const ValueKey('recovery_signin_email'),
                    controller: _emailController,
                    label: 'Recovery email',
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _busy ? null : _sendCode(),
                  )
                else
                  _RecoveryField(
                    key: const ValueKey('recovery_signin_code'),
                    controller: _codeController,
                    label: 'Six-digit code',
                    keyboardType: TextInputType.number,
                    inputFormatters: const [_RecoverySixDigitFormatter()],
                    onSubmitted: (_) => _busy ? null : _verifyCode(),
                  ),
                if (_error != null) ...[
                  SizedBox(height: 15),
                  SelahErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                ],
                SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: ValueKey(
                      _codeSent
                          ? 'recovery_signin_verify'
                          : 'recovery_signin_send',
                    ),
                    onPressed: _busy
                        ? null
                        : (_codeSent ? _verifyCode : _sendCode),
                    child: _busy
                        ? SizedBox(width: 18, height: 18, child: SelahLoading())
                        : Text(
                            _codeSent ? 'Continue' : 'Send code',
                            style: SelahText.button(size: 14),
                          ),
                  ),
                ),
                if (_codeSent) ...[
                  SizedBox(height: 11),
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: Text(
                      'Send a new code',
                      style: SelahText.subtext(size: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _changeEmail,
                    child: Text(
                      'Use a different email',
                      style: SelahText.subtext(size: 12.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverySixDigitFormatter extends TextInputFormatter {
  const _RecoverySixDigitFormatter();

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

class _RecoveryField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  const _RecoveryField({
    super.key,
    required this.controller,
    required this.label,
    required this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
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
