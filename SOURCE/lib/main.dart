import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'config/selah_native_identity_policy.dart';
import 'draft/selah_draft_runtime.dart';
import 'dev/selah_one_journey_concept_shell.dart';
import 'dev/selah_concept_preview_boundary.dart';
import 'dev/dev_onboarding_opening.dart';
import 'widgets/selah_onboarding_study.dart';
import 'services/selah_internal_preview_client.dart';
import 'theme/selah_colors.dart';
import 'theme/selah_text.dart';
import 'widgets/selah_keyboard_dismiss_scope.dart';
import 'widgets/selah_sanctuary_mark.dart';
import 'models/selah_shepherd_invite.dart';
import 'widgets/selah_shepherd_invite_scope.dart';
import 'screens/onboarding/selah_shepherd_invite_flow.dart';
import 'services/selah_developer_access.dart';
import 'dev/selah_dev_control_system.dart';
import 'dev/selah_request_account_session.dart';
import 'theme/selah_interaction_style.dart';
import 'models/selah_faith_profile_controller.dart';
import 'screens/onboarding/selah_faith_profile_flow.dart';

final selahNavigatorKey = GlobalKey<NavigatorState>();
final selahKeyboardDismissNavigatorObserver =
    SelahKeyboardDismissNavigatorObserver();
// Compile-preserving interface for retained service definitions. An accidental
// backend access fails closed; no authenticated client can exist in this draft.
const bool supabaseReady = false;
SupabaseClient get supabase =>
    throw StateError('Selah has no configured member backend in this draft.');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  HttpOverrides.global = SelahOfflineHttpOverrides();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  // Render the first Flutter frame immediately. Waiting for a platform-plugin
  // response here can leave iOS on the native launch storyboard until the
  // watchdog terminates the process. The private draft remains gated by the
  // compile-time delivery flag, non-release mode and the exact bundle identity
  // that the signed delivery pipeline verifies before installation.
  final admitted = SelahDraftRuntime.activate(
    bundleId: SelahNativeIdentityPolicy.productionBundleId,
  );
  if (admitted) SelahInternalPreviewClient.beginPreview();
  runApp(SelahApp(admitted: admitted));
}

class SelahApp extends StatelessWidget {
  const SelahApp({super.key, this.admitted = false});
  final bool admitted;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahText.appFontSelection,
      SelahColors.devPaletteSelection,
    ]),
    builder: (context, _) => MaterialApp(
      title: 'Selah',
      debugShowCheckedModeBanner: false,
      navigatorKey: selahNavigatorKey,
      navigatorObservers: [selahKeyboardDismissNavigatorObserver],
      scrollBehavior: const _SelahScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: SelahColors.mist,
        textTheme: SelahText.textTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: SelahColors.candleBronze,
          primary: SelahColors.actionFill,
          onPrimary: SelahColors.onAction,
          secondary: SelahColors.sanctuarySage,
          onSecondary: SelahColors.sanctuaryInk,
          surface: SelahColors.surface,
          onSurface: SelahColors.foreground,
          error: SelahColors.destructive,
        ),
        dividerColor: SelahColors.line,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: SelahColors.foreground,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: SelahColors.modalSheetSurface,
          modalBackgroundColor: SelahColors.modalSheetSurface,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            foregroundColor: SelahColors.onAction,
            backgroundColor: SelahColors.actionFill,
            side: BorderSide(color: SelahColors.lake),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SelahColors.foreground,
            side: BorderSide(color: SelahColors.surfaceEmphasisBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: SelahColors.foreground),
        ),
        cardTheme: CardThemeData(
          color: SelahColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: SelahColors.line),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: SelahColors.soft,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          labelStyle: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: SelahColors.inkColor,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            fixedSize: const Size(40, 40),
            backgroundColor: SelahColors.surface,
            foregroundColor: SelahColors.inkColor,
            side: const BorderSide(color: SelahColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: SelahColors.lake,
          linearTrackColor: SelahColors.line,
          linearMinHeight: 5,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: SelahColors.inkColor,
          contentTextStyle: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 14,
            color: SelahColors.mist,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        iconTheme: IconThemeData(color: SelahColors.foreground),
      ),
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SelahKeyboardDismissScope(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: admitted && SelahDraftRuntime.active
          ? const SelahConceptPreviewBoundary(child: SelahDraftRoot())
          : const Scaffold(
              body: SafeArea(
                child: Center(
                  child: Text(
                    'This private Selah draft is unavailable in this build.',
                  ),
                ),
              ),
            ),
    ),
  );
}

class SelahDraftRoot extends StatefulWidget {
  const SelahDraftRoot({super.key});
  @override
  State<SelahDraftRoot> createState() => _SelahDraftRootState();
}

class _SelahDraftRootState extends State<SelahDraftRoot> {
  bool _shepherd = false;
  bool _home = false;
  bool _opening = false;
  bool _signup = false;
  bool _faith = false;
  int _session = 0;
  int _profileGeneration = 0;
  late SelahRequestAccountSession _accountSession = _newAccountSession();
  late SelahFaithProfileController _faithController = _newFaithController(
    _accountSession,
  );

  SelahRequestAccountSession _newAccountSession() {
    final generation = _profileGeneration;
    return SelahRequestAccountSession(
      canAct: () =>
          mounted &&
          SelahDraftRuntime.active &&
          generation == _profileGeneration,
      palette: SelahColors.devPalette,
      hapticLevel: SelahInteractionStyle.hapticLevel,
      goldEnabled: false,
    );
  }

  SelahFaithProfileController _newFaithController(
    SelahRequestAccountSession owner,
  ) => SelahFaithProfileController(
    canAct: () => mounted && owner.current,
    read: () => owner.faithAnswers,
    save: owner.saveFaithProfile,
  );

  void _replaceProfileSession() {
    final oldSession = _accountSession;
    final oldController = _faithController;
    _profileGeneration++;
    _accountSession = _newAccountSession();
    _faithController = _newFaithController(_accountSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
      oldSession.dispose();
    });
  }

  late final _invite = SelahShepherdInviteController(
    canAct: () => mounted && SelahDraftRuntime.active,
  )..addListener(_inviteChanged);

  void _inviteChanged() {
    if (!mounted || !SelahDraftRuntime.active) return;
    if (_invite.sendState == SelahShepherdInviteSendState.sending ||
        _invite.sendState == SelahShepherdInviteSendState.failed) {
      setState(() {
        _signup = true;
        _faith = false;
        _home = false;
        _opening = false;
      });
    }
  }

  @override
  void dispose() {
    _invite.removeListener(_inviteChanged);
    _invite.dispose();
    _faithController.dispose();
    _accountSession.dispose();
    super.dispose();
  }

  void _reset() {
    _invite.reset();
    _replaceProfileSession();
    setState(() => _session++);
  }

  void _startSignup() {
    _invite.reset();
    _replaceProfileSession();
    setState(() {
      _signup = true;
      _faith = false;
      _home = false;
      _opening = false;
      _session++;
    });
  }

  Future<void> _inviteControls() async {
    if (!mounted ||
        !SelahDraftRuntime.active ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void choose(VoidCallback action) {
          if (!mounted ||
              !SelahDraftRuntime.active ||
              !SelahDeveloperAccess.canUseDeveloperTools) {
            return;
          }
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Page options', style: SelahText.heading(size: 18)),
                if (_faith) ...[
                  TextButton(
                    key: const ValueKey('faith_saving'),
                    onPressed: () => choose(_faithController.showSaving),
                    child: const Text('Faith · saving'),
                  ),
                  TextButton(
                    key: const ValueKey('faith_failed'),
                    onPressed: () => choose(_faithController.showFailure),
                    child: const Text("Faith · didn't save"),
                  ),
                ],
                TextButton(
                  key: const ValueKey('invite_sending'),
                  onPressed: () => choose(_invite.showSending),
                  child: const Text('Invite · sending'),
                ),
                TextButton(
                  key: const ValueKey('invite_failed'),
                  onPressed: () => choose(_invite.showFailure),
                  child: const Text("Invite · didn't send"),
                ),
                TextButton(
                  key: const ValueKey('invite_shepherd_accepts'),
                  onPressed: () => choose(() {
                    if (_invite.accept()) {
                      _explore(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_invite.firstName} said yes. You can ask and accept now.',
                          ),
                        ),
                      );
                    }
                  }),
                  child: const Text('Shepherd accepts'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _explore(bool shepherd) => setState(() {
    _shepherd = shepherd;
    _home = false;
    _opening = false;
    _signup = false;
    _faith = false;
    _session++;
  });
  @override
  Widget build(BuildContext context) =>
      SelahShepherdInviteScope(controller: _invite, child: _content(context));

  Widget _content(BuildContext context) {
    if (_signup || _faith) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_faith)
            SelahFaithProfileFlow(
              key: ValueKey('faith-$_session'),
              controller: _faithController,
              onSaved: () => _explore(false),
              onBack: () => setState(() {
                _faith = false;
                _signup = true;
              }),
            )
          else
            SelahShepherdInviteFlow(
              key: ValueKey('signup-$_session'),
              controller: _invite,
              onContinue: () => setState(() {
                _signup = false;
                _faith = true;
              }),
            ),
          if (SelahDraftRuntime.active &&
              SelahDeveloperAccess.canUseDeveloperTools)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: SelahDevControlRail.width,
              child: SelahDevControlRail(
                open: false,
                selected: SelahDevControlSection.actions,
                visibleSections: const [
                  SelahDevControlSection.home,
                  SelahDevControlSection.actions,
                ],
                onSelected: (section) {
                  if (!mounted ||
                      !SelahDraftRuntime.active ||
                      !SelahDeveloperAccess.canUseDeveloperTools) {
                    return;
                  }
                  if (section == SelahDevControlSection.home) {
                    setState(() {
                      _signup = false;
                      _faith = false;
                      _home = true;
                    });
                  } else {
                    _inviteControls();
                  }
                },
              ),
            ),
        ],
      );
    }
    if (_opening) {
      return DevOnboardingOpening(
        direction: selahDefaultDevOnboardingDirection,
        welcomeName: '',
        onContinue: () => _explore(_shepherd),
        onBackToProvider: () => setState(() {
          _opening = false;
          _home = true;
        }),
      );
    }
    if (_home) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const SelahSanctuaryBackdrop(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SelahWordmark(),
                    const Spacer(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SelahSanctuaryMark(size: 104),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Faith. Stillness.\nA Journey to marriage.',
                      style: SelahText.heading(size: 30),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'A Christ-centred space to meet with intention, '
                      'with trusted support beside you.',
                      style: SelahText.body(),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _startSignup,
                      child: const Text('Explore as a Seeker'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _explore(true),
                      child: const Text('Explore as a Shepherd'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _opening = true),
                      child: const Text('Welcome & onboarding'),
                    ),
                    const Spacer(),
                    Text(
                      'Private first draft · Local sample profiles',
                      textAlign: TextAlign.center,
                      style: SelahText.body(
                        size: 12,
                        color: SelahColors.ink(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SelahOneJourneyConceptShell(
      key: ValueKey('selah-draft-session-$_session'),
      canAct: () => mounted && SelahDraftRuntime.active,
      accountSession: _accountSession,
      initialShepherdRole: _shepherd,
      initialShepherdInviteReview: _shepherd && _invite.pending,
      onRoleChanged: (value) => _shepherd = value,
      onExit: _reset,
      // Draft home stays in Selah; no old-app route or real AuthGate exists.
      onDeveloperHome: () => setState(() => _home = true),
    );
  }
}

class _SelahScrollBehavior extends MaterialScrollBehavior {
  const _SelahScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
