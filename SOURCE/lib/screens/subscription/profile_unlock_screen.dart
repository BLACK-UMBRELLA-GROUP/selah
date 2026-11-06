// Compatibility Unlock — ONE page, two sections.
// CURRENT PRODUCT, 2026-10-11: one Compatibility Unlock includes the former
// full-detail target. New attempts use the retained Plus entitlement and stay
// held until trusted detail is available. Earlier overall-only access remains.
//
// REBUILT 2026-08-03/04. Was two swipeable tabs (Unlock / Unlock+) with a
// sliding toggle, matching the Journeys/Activity gesture.
//
// Founder: "the compatibility unlock pages... one page instead."
//
// Why the tabs were wrong, recorded so they don't come back: a swipe
// between two tabs says "these are alternatives, pick one". They are not
// alternatives — Plus is a superset of Unlock. The gesture was actively
// teaching the wrong relationship, and it hid half the offer behind a
// swipe the user had no reason to make.
//
// Stacked, the relationship states itself:
//
//   OVERALL      the headline number          Compatibility Unlock
//   THE DETAIL   what's inside that number    Compatibility Unlock+
//
// FOUNDER DECISIONS BAKED IN HERE (2026-08-03, chosen from mockups):
//
//   • An available unlock balance is shown in PLAIN WORDS, top-right of its
//     section header ("5 left" / "none left"). No balance card or subheading.
//     The held Detail offer shows neither a balance nor a spend action.
//   • Locked detail rows carry a PADLOCK EACH. The user sees the shape of
//     what they'd get — six named categories — without any of the values.
//   • The redundant padlock-open + "Unlocked" footer is removed once a
//     result is visible; the visible result is already the state.
//   • No BEST VALUE badge here. It belongs on the buy page, where there
//     is something to compare it against.
//   • "Buy more unlocks" is a quiet GLASS PILL at the foot, below the
//     available unlock action.
//
//   • ALIGNED / DISCUSS / OPPOSED is the current member language for the
//     three compatibility states. Compatibility Unlock remains the overall
//     percentage; Compatibility Unlock+ adds the detailed presentation.
//
// CURRENT DATA BOUNDARY, 2026-09-10: the overall percentage is real and comes
// from score_candidates(). That RPC still exposes no per-category totals
// (inherited upstream action 192/193(d)), so Exact Trio now renders an honest unavailable state:
// the six category names and three-column structure remain visible, no sample
// percentages appear for persisted profiles, and Unlock+ cannot spend a real credit.
// Existing Plus unlocks still retain their real Shepherd visibility.
// FOUNDER TESTING EXCEPTION, 2026-09-28: authorized sample routes alone have
// a Plus button and clearly labelled illustrative result. State/credits are
// route-local; this never opens the production fuse or writes an unlock.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../dev/selah_compatibility_demo.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../models/seeker_profile.dart';
import '../../models/selah_gender.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_shepherd_info_service.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_unlock_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_gold_action_pill.dart';

/// Exact Trio's ruled category order. Names are safe to show; values are not
/// available until the server returns real per-category totals.
const _compatibilityCategoryNames = <String>[
  'Lifestyle',
  'Work & Education',
  'Family Values',
  'Marriage Goals',
  'Personality',
  'Faith',
];

class ProfileUnlockScreen extends StatefulWidget {
  final SeekerProfile profile;

  /// THE JOURNEY DOOR — 2026-08-13 (Founder: Paused/Ended cards read
  /// "View Compatibility", never "Compatibility Unlock", "because they
  /// already unlocked"). A Journey OPENS with Compatibility Reveal: the
  /// overall figure was shown to both people as part of the Journey
  /// itself, so for a pair whose Journey began, this screen must never
  /// re-lock what the Journey already revealed — asking them to pay to
  /// see it again would be charging for a memory.
  ///
  /// True only when opened from a Journey surface for such a pair (the
  /// Paused/Ended cards, the Timeline's Compatibility entry). Affects
  /// the OVERALL section alone; the Plus detail (categories, Shepherds)
  /// stays gated exactly as before — the Journey never revealed those.
  final bool journeyRevealed;

  const ProfileUnlockScreen({
    super.key,
    required this.profile,
    this.journeyRevealed = false,
  });

  @override
  State<ProfileUnlockScreen> createState() => _ProfileUnlockScreenState();
}

class _ProfileUnlockScreenState extends State<ProfileUnlockScreen> {
  bool _busy = false;
  bool _needsRecovery = false;
  bool _accountExpired = false;
  late final String? _ownerAtOpen;
  late final int _generationAtOpen;
  late final String _profileAtOpen;
  StreamSubscription<dynamic>? _authSubscription;
  int _balanceRequest = 0;
  int _scoreRequest = 0;
  int _shepherdRequest = 0;
  int _unlockRequest = 0;
  late final bool _sampleMode;
  bool _previewAuthorizedAtOpen = false;
  ModalRoute<dynamic>? _route;
  SelahCompatibilityDevControls? _devControls;
  int _previewPlus = 1;
  // This is presentation state owned by this route, never profile_unlocks
  // or the service's unlock cache. It cannot authorize real Shepherd reads.
  bool _previewPlusUnlocked = false;

  bool get _isDeveloperPreview =>
      _sampleMode &&
      _previewAuthorizedAtOpen &&
      SelahDeveloperAccess.canUseDeveloperTools;

  /// Production balances come from `unlock_credits`; authorized non-persisted
  /// sample routes use their own local preview balances only.
  ///
  /// REPLACED the dev panel's in-memory counts 2026-08-04. Those were the
  /// only notion of a balance that existed anywhere — which is exactly why
  /// nothing could check one, and why C-1 was possible. The number on this
  /// screen is now the same number the server enforces against.
  Map<UnlockTier, int> _balance = const {};
  bool _loadingBalance = true;
  bool _balanceUnavailable = false;
  bool _balanceReadPending = false;

  /// Shepherds of the profile being viewed. Three distinct states, and the
  /// difference between them matters (Founder decision, 2026-08-05):
  ///   null       — not unlocked at Plus, or the lookup failed. Stays locked.
  ///   empty list — unlocked, and she genuinely has no Shepherd. Says so.
  ///   non-empty  — unlocked, shown in full.
  List<ShepherdInfo>? _shepherds;

  @override
  void initState() {
    super.initState();
    _ownerAtOpen = _currentOwner();
    _generationAtOpen = SelahAccountState.generation;
    _profileAtOpen = widget.profile.id;
    // Raw sample identity never falls into live balance reads after revocation.
    _sampleMode = SelahUnlockService.isSampleProfile(widget.profile.id);
    _previewAuthorizedAtOpen =
        _sampleMode && SelahDeveloperAccess.canUseDeveloperTools;
    SelahDeveloperAccess.authorizationChanges.addListener(_onAuthorityChanged);
    AppState.instance.addListener(_onAccountChanged);
    try {
      _authSubscription = SelahAuth.authStateChanges.listen(
        (_) => _onAccountChanged(),
        onError: (Object _, StackTrace _) => _expireAccount(),
      );
    } catch (_) {
      // The protected local preview intentionally needs no Supabase runtime.
    }
    _loadBalance();
    _loadShepherds();
    _loadRealScore();
  }

  static String? _currentOwner() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get _lifetimeCurrent =>
      mounted &&
      !_accountExpired &&
      !SelahAccountState.isSigningOut &&
      _generationAtOpen == SelahAccountState.generation &&
      _ownerAtOpen == _currentOwner() &&
      _profileAtOpen == widget.profile.id;

  void _onAccountChanged() {
    if (!mounted || _accountExpired || _lifetimeCurrent) return;
    _expireAccount();
  }

  void _expireAccount() {
    if (!mounted || _accountExpired) return;
    setState(() {
      _accountExpired = true;
      _busy = false;
      _balance = const {};
      _shepherds = null;
      _realScore = null;
      _previewPlusUnlocked = false;
    });
    _balanceRequest++;
    _scoreRequest++;
    _shepherdRequest++;
    _unlockRequest++;
    SelahDevSurfaceCoordinator.instance.detachCompatibility(this);
  }

  @override
  void didUpdateWidget(covariant ProfileUnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) _onAccountChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!_lifetimeCurrent || !_isDeveloperPreview) return;
    _devControls ??= SelahCompatibilityDevControls(
      profileId: widget.profile.id,
      isCurrent: () =>
          _lifetimeCurrent &&
          _isDeveloperPreview &&
          (_route?.isCurrent ?? false),
      balance: (plus) => plus ? _previewPlus : 0,
      setBalance: _setPreviewBalance,
    );
    // Route-current notifications occur during build. Notify the global
    // controls only once that frame is complete, including cover/uncover.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lifetimeCurrent || !_isDeveloperPreview) return;
      SelahDevSurfaceCoordinator.instance.attachCompatibility(
        this,
        _devControls!,
      );
    });
  }

  void _onAuthorityChanged() {
    if (!mounted || !_sampleMode) return;
    if (!_isDeveloperPreview) {
      _previewPlusUnlocked = false;
      SelahDevSurfaceCoordinator.instance.detachCompatibility(this);
    } else if (_devControls != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isDeveloperPreview) return;
        SelahDevSurfaceCoordinator.instance.attachCompatibility(
          this,
          _devControls!,
        );
      });
    }
    setState(() {});
  }

  void _setPreviewBalance(bool plus, int count) {
    if (!_lifetimeCurrent ||
        !_isDeveloperPreview ||
        !(_route?.isCurrent ?? false) ||
        !plus ||
        !const [0, 1, 5].contains(count)) {
      return;
    }
    setState(() {
      _previewPlus = count;
      _balance = {SelahUnlockService.currentTier: _previewPlus};
    });
    SelahDevSurfaceCoordinator.instance.compatibilityChanged(this);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    AppState.instance.removeListener(_onAccountChanged);
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onAuthorityChanged,
    );
    SelahDevSurfaceCoordinator.instance.detachCompatibility(this);
    super.dispose();
  }

  /// THIS SEEKER'S OWN figure for the profile on screen. Null until loaded,
  /// and null forever if they cannot be scored yet — the screen distinguishes
  /// those two states, because "still working it out" and "not enough
  /// answers between you" are different things to be told after paying.
  double? _realScore;
  bool _loadingScore = true;

  Future<void> _loadRealScore() async {
    if (!_lifetimeCurrent) return;
    final request = ++_scoreRequest;
    // Founder preview cards have no onboarding rows. Give only that isolated
    // environment a deterministic fixture score so it can exercise the real
    // locked -> unlocked presentation without contacting Supabase.
    if (_isDeveloperPreview) {
      setState(() {
        _realScore = SelahUnlockService.developerPreviewScore(
          widget.profile.id,
        );
        _loadingScore = false;
      });
      return;
    }

    // A non-authorised sample has no score and must never be passed to the
    // UUID RPC. Production Browse does not supply sample profiles.
    if (SelahUnlockService.isSampleProfile(widget.profile.id)) {
      if (mounted) setState(() => _loadingScore = false);
      return;
    }
    final s = await SelahDiscoveryService.fetchMyScoreFor(widget.profile.id);
    if (!_lifetimeCurrent || request != _scoreRequest) return;
    setState(() {
      _realScore = s;
      _loadingScore = false;
    });
  }

  Future<void> _loadBalance() async {
    if (!_lifetimeCurrent || _balanceReadPending) return;
    final request = ++_balanceRequest;
    if (_sampleMode) {
      setState(() {
        _balance = _isDeveloperPreview
            ? {SelahUnlockService.currentTier: _previewPlus}
            : const {};
        _loadingBalance = false;
        _balanceUnavailable = false;
      });
      return;
    }
    _balanceReadPending = true;
    setState(() => _loadingBalance = true);
    final b = await SelahUnlockService.readBalances();
    if (!_lifetimeCurrent || request != _balanceRequest) return;
    setState(() {
      _balanceReadPending = false;
      _balance = b.values;
      _balanceUnavailable = !b.available;
      _loadingBalance = false;
    });
    if (b.status == UnlockBalanceStatus.failed) {
      // Same existing snackbar surface; no new card, price or layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_lifetimeCurrent || request != _balanceRequest) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your unlock balance couldn’t be checked.'),
            action: SnackBarAction(
              label: 'Check again',
              onPressed: () {
                if (_lifetimeCurrent &&
                    request == _balanceRequest &&
                    !_balanceReadPending) {
                  _checkBalance(); // read-only, never a debit
                }
              },
            ),
          ),
        );
      });
    }
  }

  void _checkBalance() {
    if (!_lifetimeCurrent || _busy || !(_route?.isCurrent ?? false)) return;
    _loadBalance();
  }

  /// Only ever fetched when a Plus unlock is already held — the RPC would
  /// return nothing otherwise, and asking anyway would make "no Shepherd"
  /// and "not unlocked" indistinguishable in the logs.
  Future<void> _loadShepherds() async {
    if (!_lifetimeCurrent) return;
    final request = ++_shepherdRequest;
    if (!SelahUnlockService.isUnlocked(widget.profile.id, UnlockTier.plus)) {
      return;
    }
    if (SelahUnlockService.isSampleProfile(widget.profile.id)) return;
    final g = await SelahShepherdInfoService.fetchUnlocked(widget.profile.id);
    if (!_lifetimeCurrent || request != _shepherdRequest) return;
    setState(() => _shepherds = g);
  }

  /// Spends a credit, then rebuilds so the section swaps to the result.
  ///
  /// The outcome is no longer a bool (2026-08-04). "You have no credits"
  /// and "the network failed" used to produce the same retry message, and
  /// retrying will never fix the first one.
  Future<void> _unlock() async {
    const tier = SelahUnlockService.currentTier;
    if (!_lifetimeCurrent ||
        !(_route?.isCurrent ?? false) ||
        _busy ||
        _needsRecovery ||
        _balanceUnavailable ||
        _loadingBalance) {
      return;
    }
    if (_sampleMode &&
        (!_isDeveloperPreview ||
            !(_route?.isCurrent ?? false) ||
            (_balance[tier] ?? 0) < 1)) {
      return;
    }
    if (!SelahUnlockService.isTierAvailable(tier)) return;

    final request = ++_unlockRequest;
    // One product, one entitlement. Never downgrade to an earlier overall
    // credit if the full-detail product is held or unavailable.
    setState(() => _busy = true);
    if (_sampleMode &&
        (!_isDeveloperPreview || !(_route?.isCurrent ?? false))) {
      setState(() => _busy = false);
      return;
    }

    final outcome = await SelahUnlockService.unlock(widget.profile.id, tier);
    if (!mounted || !_lifetimeCurrent || request != _unlockRequest) return;
    setState(() => _busy = false);

    switch (outcome) {
      case UnlockOutcome.unlocked:
      case UnlockOutcome.alreadyUnlocked:
        _loadBalance(); // a credit may have gone; re-read rather than guess
        _loadShepherds(); // Plus reveals Shepherds — fetch them now it's open
      case UnlockOutcome.sampleProfile:
        // Founder preview: the local service has already recorded the unlock
        // for this session. Rebuilding reveals the deterministic test score;
        // the global preview boundary is the disclosure, so no snackbar
        // interrupts the feature itself.
        if (_isDeveloperPreview) {
          setState(() {});
          _loadBalance();
          SelahDevSurfaceCoordinator.instance.compatibilityChanged(this);
        }
        return;
      case UnlockOutcome.insufficientCredits:
        _loadBalance(); // our count was stale if we got here at all
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You don't have an unlock left for this."),
          ),
        );
      case UnlockOutcome.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Detailed compatibility isn’t available yet. No unlock was used.',
            ),
          ),
        );
      case UnlockOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This unlock could not be requested. No new access was confirmed.',
            ),
          ),
        );
      case UnlockOutcome.recoveryRequired:
        setState(() => _needsRecovery = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'We couldn’t confirm this unlock. Check access before using another credit.',
            ),
            action: SnackBarAction(
              label: 'Check access',
              onPressed: _checkUnlockAccess,
            ),
          ),
        );
    }
  }

  /// Recover a lost acknowledgement using reads only. Missing/failed evidence
  /// never authorises another spend; a confirmed permanent row restores access.
  Future<void> _checkUnlockAccess() async {
    if (!_lifetimeCurrent || _busy || !(_route?.isCurrent ?? false)) return;
    final request = ++_unlockRequest;
    setState(() => _busy = true);
    await SelahUnlockService.load();
    if (!mounted || !_lifetimeCurrent || request != _unlockRequest) return;
    final confirmed = SelahUnlockService.isUnlocked(
      widget.profile.id,
      SelahUnlockService.currentTier,
    );
    setState(() {
      _busy = false;
      _needsRecovery = !confirmed;
    });
    _loadBalance();
    if (confirmed) {
      _loadShepherds();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access hasn’t been confirmed yet. No new unlock was requested.',
          ),
        ),
      );
    }
  }

  /// Founder-authorized demonstration, not a live unlock transaction.
  /// Recheck the owner/authority at invocation, including saved callbacks.
  void _unlockPreview() {
    if (!_lifetimeCurrent ||
        !_isDeveloperPreview ||
        !(_route?.isCurrent ?? false) ||
        _previewPlusUnlocked ||
        _previewPlus < 1 ||
        _busy) {
      return;
    }
    setState(() {
      _previewPlusUnlocked = true;
      _previewPlus--;
      _balance = {SelahUnlockService.currentTier: _previewPlus};
    });
    SelahDevSurfaceCoordinator.instance.compatibilityChanged(this);
  }

  @override
  Widget build(BuildContext context) {
    if (!_lifetimeCurrent) {
      return Scaffold(
        key: const ValueKey('compatibility-account-expired'),
        appBar: AppBar(title: const Text('Compatibility')),
      );
    }
    if (_sampleMode && !_isDeveloperPreview) {
      return Scaffold(
        key: const ValueKey('compatibility-preview-denied'),
        appBar: AppBar(title: const Text('Compatibility')),
      );
    }
    final name = widget.profile.firstName;

    // Production values are straight from the ledger. The isolated sample
    // route alone reads the local balances selected in its developer toggle.
    // Previously `SelahDevScenario.instance.unlocks
    // .count` — an in-memory dev-panel enum, which meant the number on
    // screen and the number the server would enforce had no relationship
    // to each other. They are now the same number.
    //
    // SELAH One's included credits are a grant row in the same ledger
    // (reason 'selah_one_included'), not a constant added here, so the
    // count is already correct without special-casing the plan. Founder
    // rejected itemising where credits came from — that belongs on the buy
    // screen.
    final unlocksLeft = _balance[SelahUnlockService.currentTier] ?? 0;

    // Plus is a SUPERSET of Unlock, so holding Plus unlocks the overall
    // number too. Not a convenience — the spec defines Plus as "everything
    // in Compatibility Unlock, plus a category breakdown", and charging
    // again for the part they already bought would break the permanence
    // rule the unique index exists to enforce.
    final demoUnlocked = _isDeveloperPreview && _previewPlusUnlocked;
    final detailUnlocked = SelahUnlockService.isUnlocked(
      widget.profile.id,
      UnlockTier.plus,
    );
    // journeyRevealed opens the overall exactly like a standard unlock —
    // the Journey already showed both people this number (see the field's
    // doc). It spends nothing and writes nothing; the ledger is untouched.
    final overallUnlocked =
        demoUnlocked ||
        detailUnlocked ||
        widget.journeyRevealed ||
        SelahUnlockService.isUnlocked(widget.profile.id, UnlockTier.standard);

    return DecoratedBox(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          title: Text('Compatibility', style: SelahText.heading(size: 17)),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        body: Container(
          // BoxConstraints.expand for the same reason as the report screen
          // and transition_screen: the Scaffold background is now the gender
          // gradient's first stop, so a short page would show a band of flat
          // Rose Pink under the content.
          constraints: const BoxConstraints.expand(),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('You and $name', style: SelahText.heading(size: 22)),
                const SizedBox(height: 4),
                Text(
                  _isDeveloperPreview
                      ? 'Try Compatibility with a sample profile. Demo results '
                            'are not calculated from anyone’s answers.'
                      : 'Built from what you both already told Selah. Neither of you '
                            'sees the other’s answers.',
                  style: SelahText.subtext(size: 12.5),
                ),
                const SizedBox(height: 20),

                // ONE card, two sections, one divider. A card each would put
                // a gap between them and read as two unrelated offers; the
                // whole point of the single page is that the second section
                // is the inside of the first.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        label: 'OVERALL',
                        // `left: null` while the ledger is still loading.
                        // Showing 0 would render "none left" for a moment to
                        // someone who has five — the exact complaint that
                        // started this screen's rebuild, reintroduced by the
                        // move to an async balance. The corner stays empty
                        // until the real number arrives.
                        left: null,
                        unlocked: overallUnlocked,
                        busy: _busy,
                        child: overallUnlocked
                            ? _OverallResult(
                                score: _realScore,
                                loading: _loadingScore,
                                name: name,
                              )
                            : _OverallLocked(name: name),
                      ),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.14),
                        height: 1,
                        thickness: 1,
                      ),
                      _Section(
                        label: 'THE DETAIL',
                        left:
                            (_loadingBalance ||
                                _balanceUnavailable ||
                                _needsRecovery)
                            ? null
                            : unlocksLeft,
                        unlocked: demoUnlocked || detailUnlocked,
                        busy: _busy,
                        buttonLabel: 'Unlock Compatibility',
                        recoveryLabel: _needsRecovery
                            ? 'Check access'
                            : _balanceUnavailable
                            ? 'Check balance'
                            : null,
                        buttonIcon: Icons.lock_open_outlined,
                        readOnlyRecovery: _needsRecovery || _balanceUnavailable,
                        // The local fixture never calls a transaction service.
                        // Ordinary full-detail attempts retain both spend fuses.
                        onUnlock: _needsRecovery
                            ? _checkUnlockAccess
                            : _balanceUnavailable
                            ? _checkBalance
                            : _isDeveloperPreview
                            ? _unlockPreview
                            : SelahUnlockService.isTierAvailable(
                                SelahUnlockService.currentTier,
                              )
                            ? _unlock
                            : null,
                        child: _Detail(
                          unlocked: detailUnlocked,
                          developerPreview: _isDeveloperPreview,
                          demoUnlocked: demoUnlocked,
                          shepherds: _shepherds,
                          firstName: name,
                          gender: widget.profile.gender,
                        ),
                      ),
                    ],
                  ),
                ),

                // REMOVED 2026-08-06, Founder: "the text at bottom an unlock
                // never shows — remove that."
                //
                // It read: "An unlock never shows what either of you wrote,
                // or which questions caused an Aligned, Discuss or Opposed
                // result."
                //
                // The privacy promise it made is REAL and still holds — the
                // screen shows percentages and tallies, never an answer. It
                // is simply not this screen's job to keep saying so. Nothing
                // above it claims otherwise, so the sentence was defending
                // against a reading nobody was making, and it was the last
                // thing on the page.
                //
                // NOTE FOR THE SOLICITOR REVIEW: this wording exists nowhere
                // else in the product now. If the Privacy Policy or the
                // Article 9 consent text relies on the user having been told
                // this in-app, it needs a home — most likely the buy page,
                // where the promise is part of what is being sold.
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One half of the card: a header with the balance in the corner, a body,
/// and either an unlock button or the unlocked marker.
class _Section extends StatelessWidget {
  final String label;

  /// Credits remaining, or null while the ledger is still loading.
  final int? left;
  final bool unlocked;
  final String? buttonLabel;
  final String? recoveryLabel;
  final IconData? buttonIcon;
  final bool busy;
  final bool readOnlyRecovery;
  final VoidCallback? onUnlock;
  final Widget child;

  const _Section({
    required this.label,
    required this.left,
    required this.unlocked,
    this.buttonLabel,
    this.recoveryLabel,
    this.buttonIcon,
    required this.busy,
    this.readOnlyRecovery = false,
    this.onUnlock,
    required this.child,
  }) : assert(onUnlock == null || (buttonLabel != null && buttonIcon != null));

  String? get _actionLabel => recoveryLabel ?? buttonLabel;

  /// Plain words, Founder's choice. "none left" rather than "0 left"
  /// because a zero in a corner reads as a score, not a stock level.
  ///
  /// null renders NOTHING, not "none left" — the balance is still loading
  /// and claiming zero would be a lie the user has already caught once.
  String? get _balance => switch (left) {
    null => null,
    0 => 'none left',
    1 => '1 left',
    final n => '$n left',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: SelahText.chapterLabel(color: Colors.white),
                ),
              ),
              // The count disappears once unlocked. It answers "can I
              // afford this", and there is nothing left to afford.
              if (!unlocked &&
                  !readOnlyRecovery &&
                  onUnlock != null &&
                  _balance != null)
                Text(
                  _balance!,
                  style: SelahText.subtext(
                    size: 11.5,
                    color: Colors.white.withValues(
                      alpha: left == 0 ? 0.40 : 0.75,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (!unlocked && onUnlock != null) ...[
            const SizedBox(height: 14),
            SelahGoldActionPill(
              // Disabled at zero rather than relabelled. The corner already
              // says why, and the foot link says what to do — swapping this
              // to a buy button would put the same offer on screen twice.
              // `left == null` means the balance has not arrived yet.
              // Disabled until it does — an enabled button whose result we
              // cannot predict is worse than a brief dim one.
              key: ValueKey<String>('compatibility-unlock-$_actionLabel'),
              label: _actionLabel!,
              icon: readOnlyRecovery ? Icons.refresh_rounded : buttonIcon!,
              busy: busy,
              onPressed:
                  (busy || (!readOnlyRecovery && (left == null || left == 0)))
                  ? null
                  : onUnlock,
            ),
          ],
        ],
      ),
    );
  }
}

/// Locked overall — the shape of the answer, with the number withheld.
///
/// REPLACES a widget that hardcoded "You have none left" regardless of
/// balance, which is how the Founder saw that sentence while the dev panel
/// held five credits. The balance is now stated once, in the section
/// header, by the code that actually knows it. This widget says nothing
/// about stock at all — that is why it cannot be wrong about it again.
class _OverallLocked extends StatelessWidget {
  final String name;
  const _OverallLocked({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.lock_outline,
          size: 20,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your overall compatibility with $name.',
            style: SelahText.body(size: 14, color: Colors.white),
          ),
        ),
        Text('__%', style: SelahText.heading(size: 26, color: Colors.white24)),
      ],
    );
  }
}

/// Unlocked overall — the percentage, and nothing else.
///
/// Aligned/Discuss/Opposed detail lives in Plus so that
/// Plus has more to sell. Compatibility Unlock is now exactly one number,
/// which is also the easiest thing in the app to explain.
class _OverallResult extends StatelessWidget {
  /// THE REAL FIGURE, at last — inherited upstream action 192, unblocked by inherited upstream action 193 on
  /// 2026-08-11. This showed `_Sample.overall` — a constant 81% — to every
  /// Seeker for every profile, while taking a real credit for it. The
  /// transaction was real and the number was not.
  ///
  /// It is the SIGNED-IN Seeker's own figure, per decision (a2): how well
  /// this person's answers fit what you said you were looking for. The other
  /// person has their own, and it is not yours to see.
  final double? score;
  final bool loading;
  final String name;

  const _OverallResult({
    required this.score,
    required this.loading,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text('Working it out…', style: SelahText.subtext(size: 13));
    }

    // NO NUMBER RATHER THAN A MADE-UP ONE. Reachable today because the
    // onboarding completeness gate (inherited upstream action 193c) is decided but unbuilt, so
    // a half-finished profile can still be looked at. When that gate exists
    // this branch becomes unreachable — and it should STILL be here, because
    // the alternative is inventing a figure the moment it is.
    if (score == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('—', style: SelahText.heading(size: 44, color: Colors.white38)),
          const SizedBox(height: 6),
          Text(
            'Not enough answers between you yet. This fills in as you and '
            '$name both cover more ground.',
            style: SelahText.subtext(size: 12.5),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${score!.round()}%', style: SelahText.heading(size: 44)),
        const SizedBox(width: 12),
        Text('aligned', style: SelahText.subtext(size: 13)),
      ],
    );
  }
}

/// The lower section, locked or not.
///
/// The ruled Exact Trio structure remains visible, but no category value is
/// rendered for a persisted profile until real server totals exist. The
/// explicitly marked developer sample is separate presentation state.
/// `unlocked` governs only already-real Shepherd disclosure below it.
class _Detail extends StatelessWidget {
  final bool unlocked;
  final bool developerPreview;
  final bool demoUnlocked;

  /// Shepherds of the profile being viewed, or null while locked/unknown.
  /// An empty list is a real answer — "No Shepherd linked" — not a gap.
  final List<ShepherdInfo>? shepherds;

  /// Whose Shepherds these are, for the section copy.
  final String firstName;

  /// Their gender, so the copy says his/her rather than always "her".
  final String? gender;

  const _Detail({
    required this.unlocked,
    this.developerPreview = false,
    this.demoUnlocked = false,
    required this.shepherds,
    required this.firstName,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (developerPreview) ...[
          const _DemoNotice(),
          const SizedBox(height: 14),
        ],
        _ExactTrioBreakdown(
          developerPreview: developerPreview,
          demoUnlocked: demoUnlocked,
        ),
        if (demoUnlocked)
          const _DemoShepherd()
        else
          _ShepherdSection(
            unlocked: unlocked,
            shepherds: shepherds,
            firstName: firstName,
            gender: gender,
          ),
      ],
    );
  }
}

abstract final class _BreakdownPalette {
  static const aligned = Color(0xFF6FBF8A);
  static const discuss = Color(0xFFE0C070);
  static const opposed = SelahColors.destructive;
}

class _ExactTrioBreakdown extends StatelessWidget {
  final bool developerPreview;
  final bool demoUnlocked;
  const _ExactTrioBreakdown({
    this.developerPreview = false,
    this.demoUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget value(Color colour, int? percentage) => SizedBox(
      width: 51,
      child: Text(
        percentage == null ? '—' : '$percentage%',
        textAlign: TextAlign.center,
        style: SelahText.body(
          size: 11.5,
          color: colour.withValues(alpha: percentage == null ? 0.55 : 1),
        ),
      ),
    );
    Widget heading(String label) => SizedBox(
      width: 51,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 9.5),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!demoUnlocked)
          Text(
            developerPreview
                ? 'Unlock Compatibility to reveal the sample result.'
                : 'Detailed compatibility isn’t available yet.',
            key: const ValueKey('compatibility-detail-unavailable'),
            style: SelahText.subtext(size: 12.5),
          )
        else
          Text(
            'Sample category percentages',
            key: const ValueKey('compatibility-demo-result'),
            style: SelahText.subtext(size: 12.5),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            heading('Aligned'),
            heading('Discuss'),
            heading('Opposed'),
          ],
        ),
        const SizedBox(height: 4),
        for (var index = 0; index < _compatibilityCategoryNames.length; index++)
          Semantics(
            label: demoUnlocked
                ? '${_compatibilityCategoryNames[index]}, developer demo: '
                      '${SelahCompatibilityDemo.categories[index].aligned}% aligned, '
                      '${SelahCompatibilityDemo.categories[index].discuss}% discuss, '
                      '${SelahCompatibilityDemo.categories[index].opposed}% opposed'
                : '${_compatibilityCategoryNames[index]}, detailed compatibility not available',
            excludeSemantics: true,
            child: Container(
              key: ValueKey<String>(
                'compatibility-exact-row-${_compatibilityCategoryNames[index]}',
              ),
              constraints: const BoxConstraints(minHeight: 41),
              decoration: index < _compatibilityCategoryNames.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _compatibilityCategoryNames[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SelahText.body(size: 11.5),
                    ),
                  ),
                  value(
                    _BreakdownPalette.aligned,
                    demoUnlocked
                        ? SelahCompatibilityDemo.categories[index].aligned
                        : null,
                  ),
                  value(
                    _BreakdownPalette.discuss,
                    demoUnlocked
                        ? SelahCompatibilityDemo.categories[index].discuss
                        : null,
                  ),
                  value(
                    _BreakdownPalette.opposed,
                    demoUnlocked
                        ? SelahCompatibilityDemo.categories[index].opposed
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Narrow seam for rendering the truthful Compatibility Unlock+ unavailable
/// state in widget tests without loading credits, Supabase or a profile route.
@visibleForTesting
Widget buildSelahCompatibilityBreakdownTestSurface({
  bool unlocked = true,
  bool demoUnlocked = false,
}) => _Detail(
  unlocked: unlocked,
  developerPreview: demoUnlocked,
  demoUnlocked: demoUnlocked,
  shepherds: [],
  firstName: 'Ruth',
  gender: 'female',
);

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('compatibility-demo-notice'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: SelahColors.journeyGold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Developer demo',
          style: SelahText.body(size: 12, color: SelahColors.journeyGold),
        ),
        const SizedBox(height: 4),
        Text(
          'Sample values, not calculated from answers or the final scoring '
          'rules. No real unlocks are used.',
          style: SelahText.subtext(size: 11.5),
        ),
      ],
    ),
  );
}

class _DemoShepherd extends StatelessWidget {
  const _DemoShepherd();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('compatibility-demo-shepherd'),
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
        const SizedBox(height: 14),
        Text('SHEPHERD EXAMPLE', style: SelahText.chapterLabel()),
        const SizedBox(height: 10),
        Text('Demo Shepherd · Father', style: SelahText.body(size: 13)),
        const SizedBox(height: 4),
        Text(
          'Main Shepherd · Fictional example',
          style: SelahText.subtext(size: 11.5),
        ),
      ],
    ),
  );
}

/// Shepherd visibility — Founder decision, 2026-08-05: "I want the Shepherd
/// to be visible. Show the Shepherd's details, not just the relationship…
/// if no Shepherd is linked, I want that shown honestly rather than hiding
/// the row. I don't want the UI to obscure or infer this information."
///
/// Consent is taken at onboarding and the Privacy Policy / Terms name
/// exactly what an unlock reveals, with solicitor review before launch.
///
/// Plus tier only, matching `shepherds_for_unlocked()`, which will return
/// nothing for a standard unlock however this widget is called. Locked, it
/// keeps the same padlock treatment as every row above it. Previously held
/// Plus rows retain this real disclosure while new Plus spending is fused.
class _ShepherdSection extends StatelessWidget {
  final bool unlocked;
  final List<ShepherdInfo>? shepherds;
  final String firstName;

  /// The viewed profile's gender — 'male' | 'female' | null.
  ///
  /// ADDED 2026-08-06. The sentence below said "her Journey" for everyone,
  /// so viewing Tariq read "Tariq has 2 Shepherds involved in her Journey."
  /// Founder: "Tariq would be a man, so make sure the app knows the wording
  /// to differentiate between man and woman."
  ///
  /// Worth noting WHY it was hardcoded: this screen only ever shows the
  /// opposite gender to the viewer, so on a female Seeker's device every
  /// profile is male and on a male Seeker's every profile is female. It
  /// reads correctly for exactly half the users and wrongly for the other
  /// half — the kind of bug that survives testing on one account.
  final String? gender;

  const _ShepherdSection({
    required this.unlocked,
    required this.shepherds,
    required this.firstName,
    required this.gender,
  });

  /// his / her / their. Falls back to "their" rather than guessing — an
  /// unknown gender is not a reason to misgender someone.
  String get _possessive => SelahGender.possessive(gender);

  @override
  Widget build(BuildContext context) {
    final list = shepherds;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          const SizedBox(height: 14),
          Text(
            'SHEPHERD',
            style: SelahText.chapterLabel(color: Colors.white54),
          ),
          const SizedBox(height: 10),

          if (!unlocked || list == null)
            // Same visual language as the locked category rows above.
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            )
          else if (list.isEmpty)
            // Stated plainly, per the decision above. Not softened, not
            // hidden, and not inferred from silence.
            Text(
              'No Shepherd linked.',
              style: SelahText.body(
                size: 14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            )
          else ...[
            for (final g in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.displayLine,
                        style: SelahText.body(size: 14, color: Colors.white),
                      ),
                    ),
                    if (g.isMain)
                      Text('Main', style: SelahText.subtext(size: 11.5)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              list.length == 1
                  ? '$firstName has a Shepherd involved in $_possessive Journey.'
                  : '$firstName has ${list.length} Shepherds involved in $_possessive Journey.',
              style: SelahText.subtext(size: 12),
            ),
          ],
        ],
      ),
    );
  }
}
