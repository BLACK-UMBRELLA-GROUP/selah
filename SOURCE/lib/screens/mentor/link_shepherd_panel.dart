import 'package:flutter/material.dart';

import '../../draft/selah_draft_runtime.dart';
import '../../models/selah_shepherd_invite.dart';
import '../../services/selah_account_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_shepherd_invite_scope.dart';
import '../onboarding/selah_shepherd_invite_flow.dart';

/// The Seeker links through the locked local invitation; other code routes
/// still own SelahCodeScreen and are unchanged.
class LinkShepherdScreen extends StatefulWidget {
  const LinkShepherdScreen({
    super.key,
    required this.onLinked,
    this.gender,
    this.controller,
  });
  final VoidCallback onLinked;
  final String? gender;
  final SelahShepherdInviteController? controller;

  @override
  State<LinkShepherdScreen> createState() => _LinkShepherdScreenState();
}

class _LinkShepherdScreenState extends State<LinkShepherdScreen> {
  SelahShepherdInviteController? _owned;
  final _ownerGeneration = SelahAccountState.generation;

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ??
        SelahShepherdInviteScope.maybeOf(context) ??
        (_owned ??= SelahShepherdInviteController(
          canAct: () =>
              mounted &&
              SelahDraftRuntime.active &&
              SelahAccountState.generation == _ownerGeneration,
        ));
    return SelahShepherdInviteFlow(
      controller: controller,
      initialStep: SelahShepherdInviteStep.invite,
      onContinue: () {
        // The retained callback refreshes its caller; no real link is granted
        // here, and the session owner can still report the invite as pending.
        widget.onLinked();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

class LinkShepherdPanel extends StatelessWidget {
  const LinkShepherdPanel({super.key, required this.onLinked});
  final VoidCallback onLinked;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: SelahColors.inkColor,
        side: const BorderSide(color: SelahColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LinkShepherdScreen(onLinked: onLinked),
        ),
      ),
      child: Text('Add a Shepherd', style: SelahText.button()),
    ),
  );
}
