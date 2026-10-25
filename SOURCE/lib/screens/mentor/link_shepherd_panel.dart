import 'package:flutter/material.dart';

import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import 'selah_code_screen.dart';

/// Seeker entry point for permanent SELAH Codes.
class LinkShepherdScreen extends StatelessWidget {
  final VoidCallback onLinked;
  final String? gender;

  const LinkShepherdScreen({super.key, required this.onLinked, this.gender});

  @override
  Widget build(BuildContext context) {
    return SelahCodeScreen(asShepherd: false, onLinked: onLinked);
  }
}

/// Compatibility wrapper for older callers that embedded the one-use-code
/// panel. It now opens the single governed SELAH Code surface.
class LinkShepherdPanel extends StatelessWidget {
  final VoidCallback onLinked;

  const LinkShepherdPanel({super.key, required this.onLinked});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SelahColors.accentBg,
          border: Border.all(color: SelahColors.accentBorder),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SelahCodeScreen(asShepherd: false, onLinked: onLinked),
              ),
            ),
            child: Center(
              child: Text('Add a Shepherd', style: SelahText.button()),
            ),
          ),
        ),
      ),
    );
  }
}
