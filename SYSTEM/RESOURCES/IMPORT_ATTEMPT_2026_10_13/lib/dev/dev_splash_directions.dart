// Founder-requested Mobbin study, 2026-09-27. Preview only: the real
// Quiet Horizon is now the main splash; previews never replace the route stack.
import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_splash_motion.dart';
import '../widgets/selah_splash_artwork.dart';

export '../widgets/selah_splash_artwork.dart'
    show SelahSplashDirection, SelahSplashStudy;

/// Shared by both roles and the global Home door. Selecting opens a study,
/// never changes a launch preference or signs the Founder out.
class DevSplashDirectionPicker extends StatelessWidget {
  const DevSplashDirectionPicker({
    super.key,
    this.enabled = true,
    this.onBeforeOpen,
  });
  final bool enabled;
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Splash directions', style: SelahText.body(size: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final direction in SelahSplashDirection.values)
              ActionChip(
                key: ValueKey('dev_splash_${direction.name}'),
                label: Text(direction.label, style: SelahText.body(size: 11)),
                onPressed: !enabled
                    ? null
                    : () {
                        onBeforeOpen?.call();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DevSplashDirectionsScreen(
                              initialDirection: direction,
                            ),
                          ),
                        );
                      },
              ),
          ],
        ),
      ],
    );
  }
}

class DevSplashDirectionsScreen extends StatefulWidget {
  const DevSplashDirectionsScreen({
    super.key,
    this.initialDirection = SelahSplashDirection.current,
  });
  final SelahSplashDirection initialDirection;

  @override
  State<DevSplashDirectionsScreen> createState() =>
      _DevSplashDirectionsScreenState();
}

class _DevSplashDirectionsScreenState extends State<DevSplashDirectionsScreen> {
  late SelahSplashDirection _direction = widget.initialDirection;
  int _run = 0;

  void _select(SelahSplashDirection direction) => setState(() {
    _direction = direction;
    _run++;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) => _buildPreview(context),
  );

  // Static brand artwork only: use the already-established capability and
  // listen for revocation, but never refresh Auth or replace the route stack.
  // Real developer operations still use their fresh authorization gates.
  Widget _buildPreview(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return Scaffold(
        key: const ValueKey('dev_splash_directions_denied'),
        body: SafeArea(
          child: IconButton(
            tooltip: 'Close splash preview',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_direction == SelahSplashDirection.current)
            SplashScreen(
              key: ValueKey('current_$_run'),
              motion: SelahSplashMotion.bloomDraw,
            )
          else
            SelahSplashStudy(
              key: ValueKey('${_direction.name}_$_run'),
              direction: _direction,
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Close splash preview',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _direction.label,
                      style: SelahText.subtext(size: 11, color: Colors.white70),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous direction',
                          onPressed: () => _select(
                            SelahSplashDirection.values[(_direction.index - 1) %
                                SelahSplashDirection.values.length],
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _run++),
                          icon: const Icon(Icons.replay_rounded, size: 17),
                          label: Text(
                            'Replay',
                            style: SelahText.button(size: 12),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next direction',
                          onPressed: () => _select(
                            SelahSplashDirection.values[(_direction.index + 1) %
                                SelahSplashDirection.values.length],
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
