// App entry gate — OA-102 session persistence. supabase_flutter itself
// persists the session locally between app restarts; this widget is
// what actually acts on that at cold start: skip Welcome/sign-in
// entirely if a session is already there, otherwise show Welcome as
// before. Without this, a signed-in user would be asked to sign in
// again every time they reopened the app, which defeats the point of
// session persistence existing at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import '../models/selah_error_state.dart';
import '../services/selah_auth.dart';
import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_session_router.dart';
import '../widgets/selah_full_screen_error.dart';
import '../widgets/selah_loading.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatefulWidget {
  /// Whether to play the full splash before handing over.
  ///
  /// TRUE at cold start — main.dart's `home:`. That is the launch the
  /// splash exists for.
  ///
  /// FALSE when re-entering the gate from inside an already-running app.
  /// Today that is Developer Access switching test accounts. Founder,
  /// 2026-08-08: "on dev button I pick user, I see the splash screen, I
  /// don't want that."
  ///
  /// ── WHY A FLAG AND NOT A DIFFERENT ROUTE. The 2026-08-07 change that
  /// sent Developer Access through AuthGate did TWO things, and only one of
  /// them was wrong. The splash was wrong. The other — deleting
  /// `preset.isMentor ? MentorHomeShell : HomeShell` so routing is decided
  /// once, by SelahSessionRouter, from the profile row rather than a
  /// hand-set flag in the dev screen — was right and must survive. So the
  /// dev screen still goes through the gate; it just does not ask for the
  /// performance.
  final bool playSplash;

  const AuthGate({super.key, this.playSplash = true});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _resolved;
  bool _didRetry = false;
  bool _exiting = false;
  bool _authRecoveryPending = false;
  String? _routeOwner;
  int _routeGeneration = 0;
  int _request = 0;
  StreamSubscription? _authSubscription;
  final Set<String> _loggedErrorReferences = {};

  /// When [AuthGate.playSplash], the splash ALWAYS plays in full —
  /// Founder, 2026-08-07: "every time I open the app I want to start with
  /// the splash screen."
  ///
  /// So there are two conditions to move on, not one: the animation must
  /// have finished AND the session must have resolved. Whichever is slower
  /// decides.
  ///
  /// On a fast launch the animation is the limit and the app waits for it —
  /// that is the deliberate cost of having one. On a slow network the fetch
  /// is the limit and the splash simply holds on its final frame, which is
  /// why that frame is composed to be calm to sit on rather than to be the
  /// end of a movement.
  ///
  /// Initialised TRUE when the splash is skipped, so the only remaining
  /// condition is the session resolving.
  late bool _animationDone = !widget.playSplash;

  @override
  void initState() {
    super.initState();
    _resolved = _resolve()..ignore();
    _authSubscription = SelahAuth.authStateChanges.listen(
      _refreshForSessionChange,
      onError: (Object error, StackTrace stack) {
        if (!mounted || _exiting) return;
        _request++;
        _routeOwner = SelahAuth.currentUser?.id;
        SelahAccountState.synchronize(_routeOwner);
        _routeGeneration = SelahAccountState.generation;
        setState(() {
          _authRecoveryPending = true;
          // Attach an error handler immediately; FutureBuilder subscribes on
          // the next frame and still renders the existing recovery design.
          _resolved = Future<Widget>.error(error)..ignore();
        });
      },
    );
  }

  @override
  void dispose() {
    _request++;
    _authSubscription?.cancel().ignore();
    super.dispose();
  }

  void _refreshForSessionChange(AuthState state) {
    if (!mounted || _exiting) return;
    final sameLifetime =
        _routeOwner == SelahAuth.currentUser?.id &&
        _routeGeneration == SelahAccountState.generation &&
        !SelahAccountState.isSigningOut;
    final recoveredSession =
        (state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.signedIn) &&
        state.session != null &&
        state.session!.user.id == _routeOwner;
    if (sameLifetime && !(_authRecoveryPending && recoveredSession)) {
      return;
    }
    setState(() {
      // Consume recovery before resolving: the resolver refreshes Auth using
      // its existing protected policy and may emit another token event.
      // Duplicate healthy events must not recursively restart that request.
      // A changed owner instead gets the normal new-lifetime route below.
      _authRecoveryPending = false;
      _request++;
      _resolved = _resolve()..ignore();
    });
  }

  Future<Widget> _resolve() async {
    _routeOwner = SelahAuth.currentUser?.id;
    SelahAccountState.synchronize(_routeOwner);
    _routeGeneration = SelahAccountState.generation;
    if (!SelahAuth.isSignedIn) return const WelcomeScreen();
    return SelahSessionRouter.resolveHome();
  }

  bool _callbackCurrent(String? owner, int generation, int request) =>
      mounted &&
      !_exiting &&
      request == _request &&
      !SelahAccountState.isSigningOut &&
      SelahAuth.currentUser?.id == owner &&
      SelahAccountState.generation == generation;

  void _retry(String? owner, int generation, int request) {
    if (!_callbackCurrent(owner, generation, request)) return;
    setState(() {
      _request++;
      _authRecoveryPending = false;
      _didRetry = true;
      _resolved = _resolve()..ignore();
    });
  }

  void _returnToWelcome(String? owner, int generation, int request) {
    if (!_callbackCurrent(owner, generation, request)) return;
    _request++;
    _showWelcome();
  }

  void _showWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _signInAgain(String? owner, int generation, int request) async {
    if (!_callbackCurrent(owner, generation, request)) return;
    _exiting = true;
    final previewBlocked = SelahDeveloperAccess.blocksMemberRouting;
    try {
      await SelahAuth.signOut(expectedUserId: owner);
    } catch (error) {
      // An expired server session can make remote sign-out fail. The member
      // still needs a usable exit instead of being trapped on this page.
      debugPrint(
        'SELAH expired-session sign-out failed (${error.runtimeType}).',
      );
      // A failed preview sign-out retains its denial latch and recovery page.
      // Do not imply that another account can now use live member data.
      if (previewBlocked && mounted) {
        setState(() {
          _request++;
          _resolved = _resolve()..ignore();
        });
        return;
      }
    } finally {
      _exiting = false;
    }
    // Sign-out deliberately invalidates this owner's generation once. Any
    // replacement/re-login is a different lifetime and owns its own routing.
    if (!mounted ||
        request != _request ||
        SelahAccountState.isSigningOut ||
        SelahAuth.currentUser != null ||
        SelahAccountState.userId != null ||
        SelahAccountState.generation != generation + 1) {
      if (mounted && request == _request) {
        setState(() {
          _request++;
          _resolved = _resolve()..ignore();
        });
      }
      return;
    }
    _request++;
    _showWelcome();
  }

  Widget _errorScreen(Object error) {
    final owner = _routeOwner;
    final generation = _routeGeneration;
    final request = _request;
    final kind = selahErrorKindFor(error);
    final reference = selahErrorReference(error);
    if (_loggedErrorReferences.add(reference)) {
      debugPrint('SELAH route failed [$reference] (${error.runtimeType}).');
    }
    return SelahFullScreenError(
      key: ValueKey('route_error_${kind.name}'),
      kind: kind,
      referenceCode: reference,
      onPrimary: kind == SelahErrorKind.sessionExpired
          ? () => _signInAgain(owner, generation, request)
          : () => _retry(owner, generation, request),
      onSecondary:
          kind == SelahErrorKind.sessionExpired ||
              kind == SelahErrorKind.previewAccess
          ? () => _signInAgain(owner, generation, request)
          : () => _returnToWelcome(owner, generation, request),
    );
  }

  /// How long brand purple takes to resolve into the member's own colour.
  ///
  /// Matches the 260ms cross-fade main.dart uses when the gendered
  /// background changes, so the app only ever has one speed for "the
  /// background colour is changing".
  static const _handoff = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolved,
      builder: (context, snapshot) {
        // SPLASH, NOT A SPINNER — 2026-08-07. This branch was a bare
        // CircularProgressIndicator on a gradient: real waiting, presented
        // as a loading indicator.
        //
        // Note the condition is no longer just `!snapshot.hasData`. The
        // splash outlives the fetch when the fetch is quick, because it now
        // always plays through — see _animationDone.
        //
        // ── THE HANDOFF IS THIS WIDGET'S JOB — 2026-08-08.
        //
        // The splash is BRAND PURPLE for its whole four seconds and is not
        // gender-matched (inherited decision 094 lists Splash Screen under GLOBAL
        // BRAND). main.dart's layer underneath IS gender-matched, so
        // swapping the splash out in one frame cuts straight from purple to
        // the member's colour — which is the "second of purple before it
        // goes pink" the Founder reported on 2026-08-07.
        //
        // That was previously "fixed" by tinting the splash itself, i.e. by
        // making it the wrong colour for four seconds to avoid being the
        // wrong colour for one frame. Reversed 2026-08-08 on Founder
        // instruction. The cut is softened here instead, where the two
        // colours actually meet.
        //
        // AnimatedSwitcher cross-fades the two. Brand purple RESOLVES INTO
        // the member's colour instead of being replaced by it.
        //
        // Stacking is the DEFAULT layoutBuilder's, deliberately not
        // overridden: previous children first, current last, so the
        // incoming screen paints ON TOP of the outgoing splash and fades
        // up over it. That is the right way round here. Whatever shows
        // through mid-fade is main.dart's gendered layer — the destination
        // colour — so the blend only ever moves toward where it is going.
        return AnimatedSwitcher(
          duration: _handoff,
          // Fade only. A slide or scale would read as navigation; this is
          // one screen becoming another, not a push.
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: !_animationDone
              ? SplashScreen(
                  key: const ValueKey('splash'),
                  onFinished: () {
                    if (mounted && !_animationDone) {
                      setState(() => _animationDone = true);
                    }
                  },
                )
              : !_callbackCurrent(_routeOwner, _routeGeneration, _request)
              ? const SelahLoading.fullScreen(key: ValueKey('loading'))
              : snapshot.connectionState != ConnectionState.done
              ? widget.playSplash && !_didRetry
                    ? SplashScreen(
                        key: const ValueKey('splash'),
                        onFinished: () {},
                      )
                    : const SelahLoading.fullScreen(key: ValueKey('loading'))
              : snapshot.hasError
              ? _errorScreen(snapshot.error!)
              : snapshot.hasData
              ? KeyedSubtree(
                  key: const ValueKey('resolved'),
                  child: snapshot.data!,
                )
              // The cold-start splash holds on its finished frame if session
              // routing takes longer than its minimum splash performance. A
              // manual retry is different: show the quiet shared loader and
              // never replay the brand entrance.
              : widget.playSplash && !_didRetry
              ? SplashScreen(key: const ValueKey('splash'), onFinished: () {})
              : const SelahLoading.fullScreen(key: ValueKey('loading')),
        );
      },
    );
  }
}
