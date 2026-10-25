import 'package:flutter/material.dart';

import 'selah_code_screen.dart';

/// Compatibility route used by older profile and Journey entry points.
/// Every route now lands on the same permanent-code/request surface.
class LinkMentorScreen extends StatelessWidget {
  final bool asMentor;

  const LinkMentorScreen({super.key, required this.asMentor});

  @override
  Widget build(BuildContext context) => SelahCodeScreen(asShepherd: asMentor);
}
