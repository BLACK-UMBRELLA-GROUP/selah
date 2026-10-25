import 'package:flutter/material.dart';

import '../../models/selah_initial_signup_draft.dart';
import 'selah_code_screen.dart';

/// Shepherd entry point for their permanent code and Seeker requests.
class MentorInviteSeekerScreen extends StatelessWidget {
  /// Requested rehearsal mode is never reinterpreted as live on revocation.
  final bool signupPreview;
  final SelahInitialSignupDraft? signupPreviewIdentity;

  const MentorInviteSeekerScreen({
    super.key,
    this.signupPreview = false,
    this.signupPreviewIdentity,
  });

  @override
  Widget build(BuildContext context) => SelahCodeScreen(
    asShepherd: true,
    signupPreview: signupPreview,
    signupPreviewIdentity: signupPreviewIdentity,
  );
}
