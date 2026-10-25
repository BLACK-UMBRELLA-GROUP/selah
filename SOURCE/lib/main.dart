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
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: SelahText.textTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: SelahColors.candleBronze,
          primary: SelahColors.actionFill,
          onPrimary: SelahColors.onAction,
          secondary: SelahColors.sanctuarySage,
          onSecondary: SelahColors.sanctuaryInk,
          surface: SelahColors.sanctuaryInk,
          onSurface: SelahColors.foreground,
          error: SelahColors.destructive,
        ),
        dividerColor: SelahColors.candleBronze.withValues(alpha: 0.18),
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            foregroundColor: SelahColors.onAction,
            backgroundColor: SelahColors.actionFill,
            side: BorderSide(
              color: SelahColors.warmIvory.withValues(alpha: 0.14),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SelahColors.foreground,
            side: BorderSide(color: SelahColors.surfaceEmphasisBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: SelahColors.foreground),
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
  int _session = 0;
  void _reset() => setState(() => _session++);
  void _explore(bool shepherd) => setState(() {
    _shepherd = shepherd;
    _home = false;
    _opening = false;
    _session++;
  });
  @override
  Widget build(BuildContext context) {
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
                    Text('SELAH', style: SelahText.wordmark(size: 26)),
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
                      onPressed: () => _explore(false),
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
      initialShepherdRole: _shepherd,
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
