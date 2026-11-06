// The App Lock gate — wraps the entire app, above the navigator.
//
// NEW 2026-08-07. Placed in main.dart's `builder:`, which sits above every
// route, so it covers pushed screens, dialogs and sheets without any screen
// having to know it exists. Fixing this in one place is the same lesson as
// the scroll-line fix: a behaviour that must be true everywhere belongs
// above everything, not repeated on each screen.
//
// Three states, and the middle one is easy to miss:
//
//   locked    full screen, content not built at all, authentication required
//   obscured  content still mounted but covered — the app switcher, the
//             notification shade, a system prompt. No re-authentication.
//   open      the app
//
// The obscured state is what stops iOS's app-switcher snapshot from
// showing someone's Connections list to whoever swipes up next. It is
// arguably the moment this feature earns its keep, and it is invisible in
// normal use, so it is easy to remove by accident later. Please don't.

import 'package:flutter/material.dart';

import '../services/selah_app_lock.dart';
import '../services/selah_auth.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

class SelahAppLockGate extends StatefulWidget {
  final Widget child;
  const SelahAppLockGate({super.key, required this.child});

  @override
  State<SelahAppLockGate> createState() => _SelahAppLockGateState();
}

class _SelahAppLockGateState extends State<SelahAppLockGate>
    with WidgetsBindingObserver {
  final _lock = SelahAppLock.instance;
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold launch into a locked app: prompt immediately rather than making
    // the user tap a button to be asked something they already expect.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lock.handleLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      _prompted = false;
      _promptIfNeeded();
    }
  }

  /// Guarded by `_prompted` so a rebuild cannot re-fire the OS sheet while
  /// one is already up — which on Android cancels the first attempt and
  /// reads to the user as the unlock simply not working.
  Future<void> _promptIfNeeded() async {
    if (!mounted || !_lock.isLocked || _prompted) return;
    _prompted = true;
    await _lock.unlock();
  }

  /// SelahAuth.signOut() takes the lock down itself (it calls
  /// clearForSignOut), so there is deliberately nothing to undo here.
  Future<void> _signOut() => SelahAuth.signOut();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _lock,
      builder: (context, _) {
        if (_lock.isLocked) {
          return _LockScreen(
            onUnlock: () {
              _prompted = false;
              _promptIfNeeded();
            },
            onSignOut: _signOut,
          );
        }
        return Stack(
          children: [
            widget.child,
            // Content stays mounted underneath — this is a cover, not a
            // teardown. Rebuilding the whole tree on every trip to the app
            // switcher would lose scroll positions and in-progress text.
            if (_lock.isObscured) const Positioned.fill(child: _ObscureVeil()),
          ],
        );
      },
    );
  }
}

class _ObscureVeil extends StatelessWidget {
  const _ObscureVeil();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      decoration: BoxDecoration(gradient: SelahColors.brandGradient),
      alignment: Alignment.center,
      child: Text('Selah', style: SelahText.wordmark(size: 26)),
    ),
  );
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  final Future<void> Function() onSignOut;

  const _LockScreen({required this.onUnlock, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    // Neutral brand gradient, NOT the gender gradient. The lock screen is
    // visible to whoever is holding the phone, and the gendered colour is
    // itself a disclosure — it would tell the person looking whether the
    // account belongs to a man or a woman before they have authenticated.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Selah', style: SelahText.wordmark(size: 30)),
                  SizedBox(height: 10),
                  Text(
                    'Locked',
                    style: SelahText.subtext(
                      size: 14,
                      color: SelahColors.ink(0.54),
                    ),
                  ),
                  SizedBox(height: 40),
                  _UnlockButton(onTap: onUnlock),
                  SizedBox(height: 28),
                  // Always present. See selah_app_lock.dart — a lock you
                  // cannot escape is a bug, and nothing is lost by signing
                  // out, because the account lives on the server.
                  TextButton(
                    onPressed: onSignOut,
                    child: Text(
                      'Sign out instead',
                      style: SelahText.subtext(
                        size: 13,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UnlockButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(
        color: SelahColors.accentBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: SelahColors.accentBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 17, color: SelahColors.ink(0.70)),
          SizedBox(width: 9),
          Text('Unlock', style: SelahText.body(size: 15, color: Colors.white)),
        ],
      ),
    ),
  );
}
