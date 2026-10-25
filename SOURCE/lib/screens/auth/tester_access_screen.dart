import 'package:flutter/material.dart';

import '../../config/selah_external_tester_policy.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../services/selah_developer_access.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';

/// Private TestFlight entry for invited external testers. This never appears
/// in ordinary builds and does not create an account or bypass real auth.
class TesterAccessScreen extends StatefulWidget {
  const TesterAccessScreen({super.key});

  @override
  State<TesterAccessScreen> createState() => _TesterAccessScreenState();
}

class _TesterAccessScreenState extends State<TesterAccessScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _verified = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _verify() {
    final accepted = SelahDeveloperAccess.authorizeExternalTester(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    setState(() {
      _verified = accepted;
      _error = accepted ? null : 'Those review details are not recognised.';
    });
  }

  Future<void> _openPreview({required bool shepherd}) {
    return SelahDevLocalPreview.open(context, isMentor: shepherd, premium: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
              ),
              const SizedBox(height: 20),
              Text('Review access', style: SelahText.heading(size: 30)),
              const SizedBox(height: 8),
              Text(
                'Use the demo details supplied with your invitation to review every main app area.',
                style: SelahText.subtext(size: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('tester_username_field'),
                controller: _usernameController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'User name',
                  hintText: 'Enter the supplied user name',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('tester_password_field'),
                controller: _passwordController,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter the supplied password',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.amber)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('tester_verify_button'),
                  onPressed: _verify,
                  child: const Text('Open review mode'),
                ),
              ),
              if (_verified) ...[
                const SizedBox(height: 34),
                Text('Choose an experience', style: SelahText.heading(size: 22)),
                const SizedBox(height: 8),
                Text(
                  'Review mode uses local sample data and does not change a live member account.',
                  style: SelahText.subtext(size: 13),
                ),
                const SizedBox(height: 18),
                _PreviewButton(
                  label: 'Seeker',
                  onPressed: () => _openPreview(shepherd: false),
                ),
                _PreviewButton(
                  label: 'Shepherd',
                  onPressed: () => _openPreview(shepherd: true),
                ),
              ],
              if (!SelahExternalTesterPolicy.enabled)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text('Tester access is not enabled in this build.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PreviewButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}
