// Browse — BROWSE_UX_SPEC_CURRENT_VERSION_V3.md + PROFILE DECISION
// SYSTEM/Summary.md. Current terminology (inherited decision 099, 2026-07-25):
// 🔴 Pass (was: Decline — no record, no notification), 🟡 Save
// (private bookmark), 🟢 Consider (was: Like — Outgoing Potential;
// mutual Consider = Match event = Potential Journey created).
//
// Visual treatment (2026-07-18) adapted from the founder's old Lovable
// prototype (src/routes/home.tsx + AppShell.tsx GLASS_BTN) after his
// review request: full-bleed edge-to-edge photo (no card padding/
// rounding), tap left/right half to cycle multiple photos, a vertical
// dot indicator on the LEFT side that fades while holding the photo
// (matches their actual code — he recalled it as the right side, but
// their source has it on the left; went with the source), and real
// glassmorphism (backdrop blur, not just a flat tint) on a brief
// tinted glass "flash" confirmation on each decision.
//
// 2026-07-25, inherited decision 099 (Founder decision, direct quote: "we will
// stick with swiping actions for cleaner UI"): the floating action
// button row is REMOVED. Primary actions are now swipe gestures on
// the card itself — swipe left = Consider, swipe right = Pass, swipe
// down = Save — with the card following the finger and flying off in
// the swipe direction on release past threshold, snapping back
// otherwise. Terminology renamed Decline→Pass, Like→Consider
// throughout this file's UI layer (enum, handler names, comments).
//
// 2026-07-26 (Founder feedback: "the current swiping action is not
// nice... I kinda want the traffic light colour implements. Green if
// u swipe positive. Yellow if u save and red if u skip"): added live
// drag-direction feedback — _dragDecision/_dragStrength compute the
// same inherited decision 099 direction mapping continuously while dragging, and
// the card shows an abstract treatment in the matching traffic-light
// colour, growing in intensity as the drag approaches the commit
// threshold. The current developer lab keeps Full Aura as the default and
// offers ten Founder-selected 3D profile-motion comparisons. None uses visible
// action buttons, ticks or thumbs. Full Aura reuses the hue family
// established by the post-commit tint colours (🔴🟡🟢) for
// visual consistency, just at full opacity with the pill/border
// applying their own transparency. Approved via an interactive
// mockup shown to the Founder before this was built (not a first
// guess coded blind).
//
// NOT renamed: AppState's underlying `decline()`/`declined`/`like()`/
// `outgoingLikes` API — those are internal method/field names used
// elsewhere (e.g. profile_screen.dart's Connections counts) and were
// judged out of scope for tonight's UI-layer change; flagged in
// SEEKER NAVIGATION/Summary.md and inherited upstream action 138 as a known, not-yet-
// closed doc/code terminology gap. This file calls the old method
// names (`AppState.instance.decline(...)`, `.like(...)`) from the new
// `_onPass`/`_onConsider` handlers.
//
// 2026-07-27 (Founder: "im thinking of removing the 3 [dot] button and
// having it [so] if the user presses and holds down on centre without
// swiping and there's a time delay between 3-5 seconds then it opens up
// the 3 buttons which shows up as a placecard in middle screen... again
// being removed if u click anywhere else on screen"). Asked to choose
// between that and a bottom-sheet variant, the Founder picked "remove
// icon, centre placecard" over keeping the "..." icon as a discoverable
// fallback — a deliberate trade-off, not an oversight: the Help/Report
// menu now has NO visible on-screen affordance at all. The "..." icon
// (home_shell.dart) is gone; holding a finger still in roughly the
// middle 76% of the photo's width for ~0.8s TOTAL from finger-down —
// which is Flutter's own 500ms long-press deadline plus
// _centreHoldDuration, NOT _centreHoldDuration alone; see that constant
// for why that distinction caused three failed tuning passes — opens
// HelpReportCard
// (widgets/help_report_sheet.dart) — originally centred via showDialog,
// changed to a bottom sheet in a later pass the same day (see the
// _openHelpReportSheet's own comment below for that change). Dismissed
// by tapping anywhere else either way (showDialog/showModalBottomSheet
// both default to dismissible). Implemented as a timer started in the
// EXISTING onLongPressStart (which
// already drives `_interacting`'s photo-dimming feedback — kept as the
// only in-progress feedback during the hold, per the Founder's chosen
// option) and cancelled on release or on drifting outside a small
// stillness tolerance (onLongPressMoveUpdate) — "without swiping" is
// taken literally: a hold that turns into a drag does not open the menu.
// See _onCentreLongPressStart / _onCentreLongPressMoveUpdate /
// _onCentreLongPressEnd / _openHelpReportCentred below.
//
// ALL OF THE ABOVE RETIRED 2026-08-13 (inherited decision 150). The hidden hold
// never earned its invisibility; with the Bell gone to the nav bar
// (inherited decision 149) the top-right corner was free again, and the Founder
// put a visible ⋮ there. Tapping it asks HomeShell to transform the nav
// bar into the two action pills (Report Profile / Help & Support) —
// see the ⋮ overlay in this build and _ActionModeBar in home_shell.dart.
// Long-press keeps only the photo-dim feedback; the paragraphs above
// stay as the history of how this corner earned its button back.

import 'dart:async';
import '../../widgets/selah_profile_image.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../models/seeker_profile.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_shepherd_suggestion_service.dart';
import '../../services/selah_hidden_profile_store.dart';
import '../../services/selah_report_service.dart';
import '../../services/selah_seeker_basic_usage_store.dart';
import '../../data/selah_seeker_basic_policy.dart';
import '../../data/selah_seeker_plan_limits.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_interaction_style.dart';
import '../../theme/selah_text.dart';
import '../subscription/profile_unlock_screen.dart';
import '../../widgets/selah_profile_name_block.dart';
import '../../widgets/report_profile_sheet.dart';
import '../../widgets/selah_glass_dialog.dart';
import 'match_notification_screen.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_write_feedback.dart';
import '../../widgets/selah_state_widgets.dart';
import 'browse_swipe_policy.dart';
// inherited decision 169 Phase 1 (2026-08-15): the precache pass and the block path
// both talk to the shared disk image cache now.
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/selah_image_cache.dart';

/// SELAH One has unlimited browsing; Seeker Basic has a four-hour allowance.
bool selahBrowseLimitReached({required SelahPlan plan, required int viewed}) =>
    plan != SelahPlan.one && SelahSeekerBasicPolicy.swipeLimitReached(viewed);

// Swipe distance (px) past which a release commits to the action,
// rather than snapping back. Kept generous so accidental drags while
// viewing a photo don't misfire.
const double _swipeCommitThreshold = SelahBrowseSwipePolicy.commitThreshold;

// Legacy identifiers remain for existing callers and account contracts.
// These restrictions do not advertise or offer a retired free plan.
const int selahBasicSaveLimit = SelahSeekerBasicPolicy.totalSaveLimit;
const int selahBasicConsiderLimit = SelahSeekerBasicPolicy.totalConsiderLimit;
const int selahOneSaveLimit = SelahSeekerPlanLimits.oneSavedProfiles;
// No _oneConsiderLimit constant — "like is unlimited" for SELAH One, so
// the Consider cap check is skipped entirely for that plan (see _onConsider).

/// Shadows for white text sitting directly on a photograph.
///
/// ADDED 2026-08-07 (Founder: "if a person uploads a photo and it happens
/// to be in the same section as the name is white, would it then not hide
/// the name, age etc — check for me").
///
/// It does, and by more than it looks. MEASURED against the bottom scrim as
/// it was: the name sat on only 17% black, giving **1.48:1** against a white
/// photo where WCAG asks 3:1 for text that size. The surname managed 1.78:1
/// and the age/city line 2.22:1, both needing 4.5:1. A mid-grey photo failed
/// too — this was never only about pure white.
///
/// ── WHY THE SCRIM IS NOT THE LEVER, which is the part worth recording.
/// Reaching 3:1 on the name by darkening alone needs **42% black at the
/// name's height**, and the name sits two-thirds of the way UP the gradient
/// band. Getting 42% there means dragging the whole band up with it, so
/// every photo — including the many that were perfectly legible — loses its
/// bottom third to a grey wash. On a product whose entire card IS the
/// photograph, that trades a real problem for a worse one.
///
/// ── WHAT A SHADOW DOES INSTEAD. It creates contrast at the glyph EDGE,
/// from the text's own halo, so it does not care what is behind it: white
/// text against its own 80%-black halo is **12.6:1** whether the photo is a
/// snowfield or a night sky. The photo is not dimmed at all.
///
/// Two shadows, doing different jobs:
///   TIGHT   3px, near-opaque — the hard edge that separates letter from
///           background. This is what carries a white photo.
///   WIDE    14px, softer — lifts the block off a BUSY photo, where the
///           problem is not brightness but detail competing with letterforms.
///
/// The scrim still moved (see the bottom gradient), just modestly: 17% → 32%
/// at the name, which is real improvement without the wash. Belt and braces,
/// with the braces doing most of the work.
// _onPhotoTextShadows MOVED 2026-08-13 (inherited decision 163) to
// widgets/selah_profile_name_block.dart, as kSelahOnPhotoTextShadows. It
// was private here, so every other screen drawing text on a photo did
// without it — which is why the Connections heroes read flatter than
// this one.
//
// It was briefly left behind as an alias, on a note claiming "~20 call
// sites in this file". That number was written without counting: the
// name block was the ONLY consumer, and it moved out with the shadow.
// Alias deleted.

enum _Decision { pass, save, consider }

_Decision? _decisionFromPolicy(SelahBrowseSwipeDecision? decision) =>
    switch (decision) {
      null => null,
      SelahBrowseSwipeDecision.pass => _Decision.pass,
      SelahBrowseSwipeDecision.save => _Decision.save,
      SelahBrowseSwipeDecision.consider => _Decision.consider,
    };

SelahBrowseSwipeDecision _policyDecisionFrom(_Decision decision) =>
    switch (decision) {
      _Decision.pass => SelahBrowseSwipeDecision.pass,
      _Decision.save => SelahBrowseSwipeDecision.save,
      _Decision.consider => SelahBrowseSwipeDecision.consider,
    };

class BrowseScreen extends StatefulWidget {
  // Renamed from onNavigateToMatches 2026-07-26 (nav bar fix) — the
  // tab it jumps to is now Connections, not a standalone Matches tab.
  final VoidCallback? onNavigateToConnections;

  /// Hides shell chrome during the Seeker Basic advert interstitial.
  final ValueChanged<bool>? onFullScreenTakeover;
  final Future<SelahSourceResult<List<SeekerProfile>>> Function()?
  loadCandidates;

  /// THE ⋮'S DOOR — 2026-08-13 (inherited decision 150): tapping the three dots
  /// asks the SHELL to enter action mode (the nav bar becomes the
  /// Report Profile / Help & Support pills), handing it what Report
  /// should do — report whoever is on the card right now. The shell
  /// owns the bar; this screen owns the person. Null in contexts with
  /// no shell (none today).
  /// CARRIES TWO ACTIONS SINCE 2026-08-13 (inherited decision 155). Hide Profile
  /// left the report sheet and became its own option on the bar, so the
  /// card hands over both things the bar can do to whoever is on it.
  /// The shell owns the bar; this screen owns the person.
  final void Function(
    ({
      VoidCallback report,
      VoidCallback hide,
      String hideWarning,
      VoidCallback compatibility,
    })
    actions,
  )?
  onOpenActions;

  const BrowseScreen({
    super.key,
    this.onNavigateToConnections,
    this.onFullScreenTakeover,
    this.onOpenActions,
    this.loadCandidates,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _accountGeneration = SelahAccountState.generation;
  final _accountOwner = SelahAccountState.userId;
  bool get _accountCurrent =>
      !SelahAccountState.isSigningOut &&
      _accountGeneration == SelahAccountState.generation &&
      _accountOwner == SelahAccountState.userId;
  int _index = 0;
  int _viewed = 0;
  late SelahSeekerBasicUsage _basicUsage;
  bool _basicUsageReady = false;
  bool _basicModalShowing = false;
  bool _claimingConsider = false;
  int _photoIndex = 0;
  bool _interacting = false;
  // 2026-07-26 (Founder: "if swiped maybe the dots have a little
  // burst... small firework burst or something"). Deliberately a
  // separate flag from `_dragDecision` (which depends on `_dragOffset`
  // and lives inside the swappable per-profile card) — `_advance()`
  // switches `_index` ~280ms into a commit, which would tear down/
  // rebuild anything nested inside that card mid-animation. Being
  // independent of `_index` is what makes this survive that switch.
  //
  // (This comment used to cite `_flash` as the pattern it mirrors.
  // `_flash` was deleted 2026-08-01 — see _onPass's note.)
  _Decision? _burstDecision;

  // The centre-hold machinery (2026-07-27 -> 2026-08-13) is GONE:
  // timer, origin, fraction/stillness constants, the three handlers and
  // _openHelpReportSheet all retired with inherited decision 150 — the ⋮ top-right
  // is Help/Report's visible door now, and the shell's action bar is
  // its surface. Long-press keeps only the photo-dim feedback.

  // Swipe-gesture state (inherited decision 099). _dragOffset is the card's live
  // visual offset while a finger is down; _dragStartGlobal anchors the
  // gesture so onPanUpdate can compute delta without accumulating
  // floating-point drift.
  Offset _dragOffset = Offset.zero;
  Offset? _dragStartGlobal;
  SelahBrowseSwipeAxis? _dragAxis;
  bool _dragCommitted = false;
  bool _dragInProgress = false;

  /// Whether the completeness gate is what is keeping this deck empty
  /// (inherited upstream action 193c). Server-answered — see
  /// SelahProfileService.fetchOnboardingProgress.
  bool _gated = false;

  Future<void> _loadGateState() async {
    final p = await SelahProfileService.fetchOnboardingProgress();
    if (!mounted || !_accountCurrent || p == null) return;
    setState(() => _gated = !p.complete);
    if (!p.complete) {
      // The setup reminder now belongs on Dashboard. Browse remains a
      // visual discovery surface and must not turn into a second onboarding
      // explanation. Also clear any decision snackbar left over from the
      // card that disappeared when the server gate resolved.
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  // Starts EMPTY with a loading flag, and stays empty if there is nothing
  // real to show.
  //
  // 2026-08-04: the mock fallback inside SelahDiscoveryService is gone
  // (independent review, H-6), so an empty deck now genuinely means "no
  // candidates" rather than "something failed and you are looking at
  // fabricated people". The comment below described that fallback as
  // intentional and correct; it was neither, and it is what let the
  // profile_complete bug hide for a month.
  //
  // FIXED 2026-07-27 (Founder, dev-mode report: "when on dev i click
  // home and change profiles a old picture shows up before it changes
  // to the profile photos... it lasts for a second"). Root cause:
  // _allProfiles used to default to `mockProfiles` synchronously
  // (painted on the very first frame, before initState's fetch below
  // even starts), only replaced once fetchCandidates()'s real network
  // round trip resolved a moment later — so every fresh BrowseScreen
  // (first launch, or any full HomeShell rebuild, e.g. Developer
  // Access's account switcher, or — see home_shell.dart's own fix this
  // same pass — every tab switch back to Browse) always flashed
  // mockProfiles' hardcoded first entry ("Maryam", surnameLine
  // "Hussain" — a stale leftover; the real, migrated Supabase row for
  // Maryam uses "Begum") with a random Picsum stock photo, before
  // swapping to the real fetch result. Now starts empty with a genuine
  // loading flag instead, so nothing paints until fetchCandidates()
  // actually resolves — including its own internal mockProfiles
  // fallback for cases where that's the correct, intentional result
  // (signed out, no real candidates yet, etc.), which this fix doesn't
  // change at all.
  List<SeekerProfile> _allProfiles = [];
  bool _loadingCandidates = true;
  bool _candidatesUnavailable = false;
  int _candidateLoadGeneration = 0;

  // #21 (Search = Browse's filter controls, per APP/Search/SUMMARY.md's
  // resolved scope) — age range is a pure client-side filter over the
  // already-fetched candidate list (age is already known per-candidate
  // via ages_for(), no new schema/query needed). Null = no filter set.
  int? _minAge;
  int? _maxAge;

  /// ADDED 2026-08-01 (Founder, screenshot: Usman, 35 under CONSIDERED
  /// *and* SAVED). Drops anyone already decided on from a freshly fetched
  /// deck.
  ///
  /// This is where the duplicate actually came from. `_current` returns
  /// null past the end of the list, so Browse does not wrap — but every
  /// refetch reassigned `_allProfiles` wholesale and reset the cursor to
  /// 0, handing back the same seven mock profiles including the ones just
  /// acted on. Decide again, land in a second list.
  ///
  /// Filtered HERE and not in the `_profiles` getter on purpose. `_index`
  /// is a positional cursor into that list, so a reactive filter would
  /// remove the current profile the instant a decision is recorded,
  /// shifting everything left, and then `_advance()`'s `_index++` 280ms
  /// later would skip the next person entirely. Filtering at load keeps
  /// the cursor stable for the whole session.
  ///
  /// Saved is NOT filtered — a bookmark is not a decision (see
  /// AppState's two-axes note). A Saved-but-undecided profile stays
  /// browsable and wears a badge so its reappearance is never confusing.
  List<SeekerProfile> _withoutDecided(List<SeekerProfile> list) {
    final decided = AppState.instance.decidedProfileIds;
    if (decided.isEmpty) return list;
    return list.where((p) => !decided.contains(p.id)).toList();
  }

  /// Last `AppState.deckVersion` this deck was built from. A change means
  /// the account was reset and the deck must be re-fetched, not re-filtered.
  int _deckVersion = AppState.instance.deckVersion;

  @override
  void initState() {
    super.initState();
    _basicUsage = SelahSeekerBasicUsage.fresh(DateTime.now());
    _loadBasicUsage();
    _loadGateState();
    // The 200-profile colour deck short-circuit was removed 2026-08-04 at
    // the Founder's request. The 24 seeded profiles now carry real Chapter 2
    // data, which the synthetic deck never did, so Browse always goes to the
    // real fetch.
    _loadDeck();
    AppState.instance.addListener(_onAppStateChanged);
    SelahDevScenario.instance.addListener(_onDevPopupRequested);
    // Shepherd Suggestions are published app-wide by Connections, but Browse
    // is the first tab and may never have been visited — without this, a
    // suggested profile met in the deck would carry no badge until the user
    // happened to open Connections. Cheap: one indexed read, and the result
    // is what the badge above the name is drawn from.
    _loadSuggestedMarks();
  }

  Future<void> _loadBasicUsage() async {
    if (AppState.instance.plan == SelahPlan.one) {
      _basicUsageReady = true;
      return;
    }
    final usage = await SelahSeekerBasicUsageStore.load();
    if (!mounted || AppState.instance.plan == SelahPlan.one) return;
    setState(() {
      _basicUsage = usage;
      _viewed = usage.swipes;
      _basicUsageReady = true;
    });
  }

  Future<void> _loadSuggestedMarks() async {
    if (AppState.instance.shepherdSuggestedBy.isNotEmpty) return;
    final s = await SelahShepherdSuggestionService.fetchPending();
    if (!mounted || !_accountCurrent || s.isEmpty) return;
    AppState.instance.setShepherdSuggestedBy({
      for (final x in s) x.profile.id: x.suggestedBy,
    });
  }

  /// ADDED 2026-08-05 (Fable). Browse used to fetch exactly once, in
  /// initState, so a dev-panel reset emptied Connections but left this deck
  /// untouched — the profiles only reappeared after an app restart, which is
  /// what the reset snackbar had to tell people to do. Now a reset bumps
  /// `deckVersion`, this hears it, and the deck comes straight back.
  void _onAppStateChanged() {
    if (!mounted) return;
    if (!_accountCurrent) {
      setState(() {
        _allProfiles = [];
        _loadingCandidates = false;
        _candidatesUnavailable = true;
      });
      return;
    }

    // "View profile" on a Shepherd Suggestion (Founder, 2026-08-05) parks a
    // profile here and switches to this tab. Jump to it, inserting it at the
    // front if it isn't in the deck — a suggestion is usually someone you
    // have not reached yet, and possibly someone already decided on, so it
    // cannot be assumed present.
    final pending = AppState.instance.takePendingBrowseProfile();
    if (pending != null) {
      setState(() {
        final at = _allProfiles.indexWhere((p) => p.id == pending.id);
        if (at == -1) {
          _allProfiles = [pending, ..._allProfiles];
          _index = 0;
        } else {
          _index = at;
        }
        // Arriving on a new person must start at their first photo. Without
        // this, _photoIndex carries over from whoever was on screen when the
        // user left for Connections.
        _photoIndex = 0;
        _loadingCandidates = false;
      });
      _precacheAround(_index);
      return;
    }

    final v = AppState.instance.deckVersion;
    if (v == _deckVersion) return;
    _deckVersion = v;
    setState(() {
      _index = 0;
      _loadingCandidates = true;
    });
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    if (!_accountCurrent) return;
    final generation = ++_candidateLoadGeneration;
    setState(() {
      _loadingCandidates = true;
      _candidatesUnavailable = false;
    });
    SelahSourceResult<List<SeekerProfile>> result;
    try {
      result =
          await (widget.loadCandidates ??
              SelahDiscoveryService.fetchCandidatesResult)();
    } catch (error) {
      debugPrint('SELAH: Browse load failed (${error.runtimeType}).');
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!mounted ||
        !_accountCurrent ||
        generation != _candidateLoadGeneration) {
      return;
    }
    // A developer preview may deliberately use an empty local scenario;
    // ordinary members must never see a failed query as an empty success.
    if (result.isUnavailable && !SelahDeveloperAccess.canUseDeveloperTools) {
      setState(() {
        _loadingCandidates = false;
        _candidatesUnavailable = true;
      });
      return;
    }
    final list = result.valueOr(const []);
    final localHiddenIds = await SelahHiddenProfileStore.hiddenIds();
    if (!mounted ||
        !_accountCurrent ||
        generation != _candidateLoadGeneration) {
      return;
    }
    final deck = SelahDeveloperAccess.canUseDeveloperTools
        ? SelahDevScenario.composeBrowsePreviewProfiles(
            real: list,
            viewerGender: AppState.instance.gender,
          )
        : list;
    setState(() {
      _allProfiles = _withoutDecided([
        for (final profile in deck)
          // Real visibility is always server/RLS-owned. Only non-UUID demo
          // profiles use this local boundary, so a fake id can never reach
          // Supabase and a stale cache can never overrule a real unblock.
          if (SelahReportService.isPersistableId(profile.id) ||
              !localHiddenIds.contains(profile.id))
            profile,
      ]);
      _loadingCandidates = false;
      _candidatesUnavailable = false;
    });
    _precacheAround(_index);
  }

  /// Shows a popup the dev panel asked for — using THE APP'S OWN modals,
  /// not copies (Founder, 2026-08-05: "please include the pop-ups that are
  /// on file, not create random ones").
  ///
  /// Read-and-clear, so one press produces exactly one showing. The old
  /// design set a sticky flag that made every subsequent Save hit the cap
  /// branch for the rest of the session.
  void _onDevPopupRequested() {
    final popup = SelahDevScenario.instance.takePendingPopup();
    if (popup == null || !mounted) return;

    switch (popup) {
      case DevPopup.saveLimit:
        _showCapReachedModal(
          action: 'Save',
          limit: AppState.instance.plan == SelahPlan.one
              ? selahOneSaveLimit
              : selahBasicSaveLimit,
        );
      case DevPopup.considerLimit:
        if (AppState.instance.plan != SelahPlan.one) {
          _showCapReachedModal(
            action: 'Consider',
            limit: selahBasicConsiderLimit,
          );
        }
      case DevPopup.dailyLimit:
        if (AppState.instance.plan != SelahPlan.one) {
          _showLimitReachedModal();
        }
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    SelahDevScenario.instance.removeListener(_onDevPopupRequested);
    super.dispose();
  }

  // FIXED 2026-07-26 (photo preloading pass — see CHATGPT_REPLY_NAVBAR_
  // PHOTO_MENU_2026-07-26.md §2). The ~1s tap-to-next-photo stall was
  // traced to zero image caching anywhere — Image.network() fetches +
  // decodes cold the first time any given URL is shown, and Flutter's
  // ImageCache only makes the *second* view of a URL instant.
  // precacheImage() is Flutter's own built-in mechanism for "fetch and
  // decode now, park it in the cache" — this warms the CURRENT
  // candidate's full photo set (covers in-profile tap-to-next-photo,
  // since all of that candidate's photos are already decoded by the
  // time any of them is tapped) plus the NEXT candidate's first photo
  // only (covers swipe-to-next-profile, without wastefully prefetching
  // photos 2+ of a candidate the user may Pass before ever opening).
  // SWITCHED to the shared cached provider 2026-08-15 (inherited decision 169
  // Phase 1). NetworkImage warmed only the RAM cache, and by URL — so a
  // re-signed URL missed, and nothing survived an app close. The same
  // provider SelahProfileImage renders with (same manager, same
  // URL-sans-token key) means this prefetch now warms disk AND RAM, and
  // warms the exact entries the render will look up.
  void _precacheAround(int index) {
    final profiles = _profiles;
    if (index >= 0 && index < profiles.length) {
      for (final url in profiles[index].photos) {
        precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheKey: SelahImageCache.keyFor(url),
            cacheManager: SelahImageCache.manager,
          ),
          context,
        );
      }
    }
    if (index + 1 < profiles.length) {
      final nextPhotos = profiles[index + 1].photos;
      if (nextPhotos.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(
            nextPhotos.first,
            cacheKey: SelahImageCache.keyFor(nextPhotos.first),
            cacheManager: SelahImageCache.manager,
          ),
          context,
        );
      }
    }
  }

  List<SeekerProfile> get _profiles {
    if (_minAge == null && _maxAge == null) return _allProfiles;
    final lo = _minAge ?? 18;
    final hi = _maxAge ?? 120;
    return _allProfiles.where((p) => p.age >= lo && p.age <= hi).toList();
  }

  bool get _filterActive => _minAge != null || _maxAge != null;

  // No longer called anywhere — its only entry point (the top-left tune
  // icon) was removed 2026-07-26. Kept, not deleted; see the removal
  // note further down in build(). Suppressed rather than deleted so
  // `flutter analyze` stays clean without losing this logic.
  // ignore: unused_element
  Future<void> _openFilterSheet() async {
    int lo = _minAge ?? 18;
    int hi = _maxAge ?? 65;
    final result = await showModalBottomSheet<({int? lo, int? hi})>(
      context: context,
      backgroundColor: SelahColors.modalSheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Age range', style: SelahText.heading(size: 17)),
                const SizedBox(height: 4),
                Text(
                  'Only affects who appears in Browse for you.',
                  style: SelahText.subtext(size: 12.5),
                ),
                const SizedBox(height: 8),
                Text(
                  '$lo – $hi',
                  style: SelahText.body(size: 15, color: Colors.white),
                ),
                RangeSlider(
                  values: RangeValues(lo.toDouble(), hi.toDouble()),
                  min: 18,
                  max: 70,
                  divisions: 52,
                  activeColor: SelahColors.accentBorder,
                  inactiveColor: SelahColors.iconButtonBg,
                  labels: RangeLabels('$lo', '$hi'),
                  onChanged: (v) => setSheetState(() {
                    lo = v.start.round();
                    hi = v.end.round();
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop((lo: null, hi: null)),
                        child: Text('Clear', style: SelahText.button(size: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop((lo: lo, hi: hi)),
                        child: Text('Apply', style: SelahText.button(size: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _minAge = result.lo;
      _maxAge = result.hi;
      // Start over within the newly-filtered set — _viewed (the daily
      // limit counter) deliberately does NOT reset; changing a filter
      // isn't a new day.
      _index = 0;
      _photoIndex = 0;
    });
    _precacheAround(0);
  }

  SeekerProfile? get _current =>
      _index < _profiles.length ? _profiles[_index] : null;

  SeekerProfile? get _nextProfile =>
      _index + 1 < _profiles.length ? _profiles[_index + 1] : null;

  bool get _limitReached =>
      AppState.instance.plan == SelahPlan.basic &&
      (!_basicUsageReady ||
          selahBrowseLimitReached(
            plan: AppState.instance.plan,
            viewed: _viewed,
          ));

  Future<void> _advance() async {
    final wasLimited = _limitReached;
    var advertDue = false;
    if (AppState.instance.plan == SelahPlan.basic) {
      try {
        final usage = await SelahSeekerBasicUsageStore.recordSwipe();
        if (!mounted) return;
        _basicUsage = usage;
        _viewed = usage.swipes;
        advertDue = usage.advertDue;
      } catch (_) {
        // Keep the allowance fail-closed for this session if local storage is
        // unavailable. Production authority will move to the server.
        _viewed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _photoIndex = 0;
    });
    _precacheAround(_index);
    if (advertDue) await _showBasicAdvert();
    if (!wasLimited && _limitReached) {
      await _showLimitReachedModal();
    }
  }

  Future<void> _showLimitReachedModal() async {
    if (!mounted || AppState.instance.plan == SelahPlan.one) return;
    if (!_basicUsageReady) {
      await _showBrowseRefusal(
        title: 'Checking your allowance',
        message:
            'Your current swipe allowance is still loading. Try again in a moment.',
        icon: Icons.hourglass_top,
      );
      return;
    }
    await _showBrowseRefusal(
      title: 'Browsing limit reached',
      message:
          'Your current allowance is ${SelahSeekerBasicPolicy.swipeLimit} profile '
          'swipes every 4 hours. Your next allowance begins in '
          '${_remainingSwipeWindowLabel()}. Your Saves and Connections remain available.',
      icon: Icons.hourglass_bottom,
    );
  }

  String _remainingSwipeWindowLabel() {
    final remaining = _basicUsage.remainingInSwipeWindow(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes.clamp(1, 59)}m';
  }

  Future<void> _showBasicAdvert() async {
    if (!mounted ||
        _basicModalShowing ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    _basicModalShowing = true;
    widget.onFullScreenTakeover?.call(true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (dialogContext) => SelahGlassCard(
          key: const ValueKey('seeker-basic-advert-preview'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ADVERTISEMENT', style: SelahText.chapterLabel()),
              const SizedBox(height: 16),
              Icon(
                Icons.campaign_outlined,
                color: SelahColors.accentOnCanvas,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                'Advert preview',
                style: SelahText.heading(size: 21),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Retired-plan developer example only. '
                'This advert is never shown to ordinary members.',
                style: SelahText.subtext(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('seeker-basic-advert-continue'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      _basicModalShowing = false;
      widget.onFullScreenTakeover?.call(false);
    }
  }

  Future<void> _showCapReachedModal({
    required String action,
    required int limit,
  }) => _showBrowseRefusal(
    title: 'Your $action list is full',
    message: action == 'Save'
        ? 'To keep this profile, make space by removing a Save in Connections.'
        : 'Your current account access allows up to $limit outgoing Considers. '
              'Your existing Connections are still available.',
    icon: action == 'Save'
        ? Icons.bookmark_outline
        : Icons.person_add_alt_1_outlined,
  );

  Future<void> _showBrowseRefusal({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => SelahGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 14),
            Text(
              title,
              style: SelahText.heading(size: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK', style: SelahText.subtext()),
            ),
          ],
        ),
      ),
    );
  }

  // 2026-07-27 (Founder: "the orange line goes around the screen but
  // can u make it per model for example apple and samsung or google
  // phones where it wraps around the whole screen, u can see the edges
  // of the screen cut out the colour"). Honest limitation: Flutter (and
  // iOS/Android themselves) expose no API that returns a device's true
  // physical corner radius — there is no supported way to ask "is this
  // an iPhone 16 Pro or a Samsung S24" and look up its exact curvature.
  // Genuine per-model precision would need a hardcoded table of
  // hundreds of device models, which isn't standard practice and would
  // go stale with every new phone released. What IS achievable: a
  // platform + safe-area-inset heuristic — the size of the top inset is
  // a reasonable proxy for which "generation" of hardware shape a
  // device has (Dynamic Island vs notch vs neither), which loosely
  // tracks how aggressively rounded that generation's corners are. This
  // rounds the drag-glow border to approximate that, so it curves into
  // the physical corner instead of stopping in a hard 90° corner that
  // gets visually clipped by the real rounded glass — a closer wrap,
  // not an exact one.
  double _deviceCornerRadiusGuess(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        if (topInset >= 55) return 55; // Dynamic Island generation
        if (topInset >= 40) return 47; // notch generation
        return 20; // no notch/island (e.g. Touch ID iPhones) — squarer
      case TargetPlatform.android:
        // Varies more by individual model than iOS does, with no finer
        // signal available cross-platform than this — a reasonable
        // mid-range value across current flagship shapes.
        return 34;
      default:
        return 24;
    }
  }

  // Same hue family as the post-commit tint colours (inherited decision 099's
  // 🔴🟡🟢 palette) — full opacity here since callers apply their own
  // .withValues(alpha: ) on top for the border-glow/pill intensity.
  Color _dragColor(_Decision d) => switch (d) {
    _Decision.pass => const Color(0xFFF47272),
    _Decision.save => const Color(0xFFEED26C),
    _Decision.consider => const Color(0xFF84C88E),
  };

  // DELETED 2026-08-01: _dragIcon(). It supplied the icon for the centred
  // decision badge, which the Founder removed ("I don't want the green
  // tick in the middle, that goes for save and decline also"). Nothing
  // has referenced it since. The no-heart-icons rule it encoded still
  // stands and is recorded in the UX docs, not here.

  String _dragLabel(_Decision d) => switch (d) {
    _Decision.pass => 'Pass',
    _Decision.save => 'Save',
    _Decision.consider => 'Consider',
  };

  // DELETED 2026-08-01: _showFlash() and the _flash field it drove.
  //
  // Once the centred decision badge was removed, nothing READ `_flash`.
  // The setter survived and kept running: two setState() rebuilds of the
  // whole Browse screen plus a 380ms Timer on every single pass, save and
  // consider — the three hottest interactions in the app — to update a
  // field no widget consulted. The note left at the badge's removal said
  // to delete it if nothing else ever consumed it. Nothing did.
  //
  // Post-commit feedback is unaffected: it comes from _BorderFlash via
  // `_burstDecision`, which is separate and still wired.

  // 2026-07-26 (Founder: swipe-dot "burst" on commit) — see
  // `_burstDecision`'s doc comment above for why this is separate from
  // the deleted `_showFlash`. 460ms rather than that flash's old 380ms so the burst ring
  // has time to fully expand and fade rather than being cut off.
  void _triggerBurst(_Decision d) {
    setState(() => _burstDecision = d);
    Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _burstDecision = null);
    });
  }

  /// Reports/blocks whoever is currently on the card. Advances past them
  /// on success — having just reported someone, seeing them still sitting
  /// there would be its own small failure.
  Future<void> _reportCurrentProfile() async {
    final profile = _current;
    if (profile == null) return;
    final simulateOnly = !SelahReportService.isPersistableId(profile.id);

    final handled = await showReportProfileSheet(
      context,
      profileId: profile.id,
      firstName: profile.firstName,
      source: SelahReportSource.browse,
      profileSnapshot: profile,
      simulateOnly: simulateOnly,
    );
    if (handled != true || !mounted) return;

    // Drop them from the in-memory deck immediately. The RLS block means
    // they will not come back on the next fetch either, but the user
    // should not have to wait for a refetch to stop seeing them.
    setState(() {
      _allProfiles = _allProfiles.where((p) => p.id != profile.id).toList();
      if (_index >= _profiles.length) _index = _profiles.length;
      _photoIndex = 0;
    });
  }

  /// Hides whoever is on the card after HomeShell's nav confirmation.
  ///
  /// ITS OWN ACTION SINCE 2026-08-13 (inherited decision 155, Founder): it used to
  /// be a row at the bottom of the report sheet, which meant reaching a
  /// privacy preference by opening an accusation. "Keep the difference
  /// clear: Report Profile — safety/reporting concerns. Hide Profile —
  /// privacy/discovery preference."
  ///
  /// THE CONFIRMATION SAYS WHAT IT ACTUALLY DOES, and this is the part
  /// worth reading. The underlying call is SelahReportService.block(),
  /// which is MUTUAL: it hides the two of you from each
  /// other everywhere, enforced in profiles_select's RLS. The sheet row
  /// it replaces said so — "hides you both" — and dropping that line
  /// while promoting the action to a top-level button would quietly
  /// turn a two-way block into something that reads like
  /// "don't show me this one". Whether a genuine one-way hide should
  /// exist is a real question and a schema change; raised as
  /// inherited upstream action 217 rather than guessed at here.
  Future<void> _hideProfile(SeekerProfile profile) async {
    final simulateOnly = !SelahReportService.isPersistableId(profile.id);

    final ok = simulateOnly ? true : await SelahReportService.block(profile.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That didn't go through — try again.")),
      );
      return;
    }

    await SelahHiddenProfileStore.remember(profile);
    if (!mounted) return;
    AppState.instance.removeHiddenProfileFromSession(profile.id);

    // Out of the deck now, not on the next fetch. The RLS block means
    // they will not return either, but waiting for a refetch to stop
    // seeing someone you just hid is its own small failure.
    setState(() {
      _allProfiles = _allProfiles.where((p) => p.id != profile.id).toList();
      if (_index >= _profiles.length) _index = _profiles.length;
      _photoIndex = 0;
    });
    // And out of the disk cache (inherited decision 169): the server stops signing
    // their URLs from this moment; the cached bytes die with the
    // relationship instead of with the 7-day TTL. Fire-and-forget — an
    // eviction miss costs nothing a TTL doesn't already bound.
    SelahImageCache.evictUrls(profile.photos);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          simulateOnly
              ? 'Preview profile hidden locally. No server data was sent.'
              : 'Hidden. Manage hidden profiles in Settings.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Opens the Compatibility Unlock page for whoever is on the card.
  ///
  /// ADDED 2026-08-13 (inherited decision 156). NOTHING NEW WAS DESIGNED: this is a
  /// door onto ProfileUnlockScreen, the same screen the Connections
  /// cards have always pushed, with the same profile argument. The
  /// screen already knows how to be both halves of itself — it reads
  /// profile_unlocks and shows what is held, so a profile already
  /// unlocked opens straight to the compatibility rather than to a
  /// price, and selah_unlock_profile() refuses to charge twice
  /// regardless (it checks profile_unlocks BEFORE the credit balance).
  /// A second purchase surface here would have been a second thing to
  /// keep in step with the ledger, for no gain.
  ///
  /// `journeyRevealed` is deliberately left false. It is true only for
  /// a pair whose Journey already revealed the overall figure, which by
  /// definition cannot be someone still sitting in Browse.
  Future<void> _openCompatibilityForCurrent() async {
    final profile = _current;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileUnlockScreen(profile: profile)),
    );
  }

  /// BUG-02 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15): the
  /// three decision writes below were fire-and-forget, so a failed
  /// insert meant the card advanced, the UI said done, and the decision
  /// was gone on next launch — a failed Like could silently prevent a
  /// match. The advance STAYS optimistic (yanking a card back
  /// mid-swipe would be worse than the failure); what changes is that
  /// a failure now says so and offers a retry, which is safe because
  /// all three writes are idempotent upserts.
  ///
  /// Demo and dev-scenario profiles never had a row to write and never
  /// will — the isPersistableId guard at each call site keeps them off
  /// this path entirely, exactly as the report/hide/unlock paths
  /// already do, so a stand-in can never trigger a real-looking error.
  void _decisionSaveFailed(String what, Future<bool> Function() retry) {
    if (!mounted) return;
    showSelahDecisionWriteFailure(context, decision: what, retry: retry);
  }

  void _onPass() {
    if (_limitReached) {
      _showLimitReachedModal();
      return;
    }
    final profile = _current;
    if (profile != null) {
      AppState.instance.decline(profile);
      // ADDED 2026-08-01. Pass was the only decision that persisted
      // NOTHING — recordSave and recordLike both existed, this did not,
      // because there was no `passes` table to write to. So a decline
      // survived exactly as long as the app stayed open, and everyone
      // passed on came back on the next launch.
      if (SelahReportService.isPersistableId(profile.id)) {
        SelahDiscoveryService.recordPass(profile.id).then((ok) {
          if (!ok) {
            _decisionSaveFailed(
              'Pass',
              () => SelahDiscoveryService.recordPass(profile.id),
            );
          }
        });
      }
    }
    Timer(const Duration(milliseconds: 280), () {
      if (mounted) _advance();
    });
  }

  void _onSave() {
    if (_limitReached) {
      _showLimitReachedModal();
      return;
    }
    // 2026-07-27 — Save cap by plan. Checked against the CURRENT saved
    // count before adding — AppState.save() itself is a no-op if the
    // profile's already saved, so this only ever blocks genuinely new
    // saves once at the cap, not re-saves.
    final saveLimit = AppState.instance.plan == SelahPlan.one
        ? selahOneSaveLimit
        : selahBasicSaveLimit;
    // The dev panel no longer forces this branch — it requests the modal
    // directly (see _onDevPopupRequested). A sticky force flag here meant
    // every Save for the rest of the session hit the cap.
    if (AppState.instance.saved.length >= saveLimit) {
      _showCapReachedModal(action: 'Save', limit: saveLimit);
      return;
    }
    final profile = _current;
    if (profile != null) {
      AppState.instance.save(profile);
      // BUG-02: failure surfaces with a retry — see _decisionSaveFailed.
      if (SelahReportService.isPersistableId(profile.id)) {
        SelahDiscoveryService.recordSave(profile.id).then((ok) {
          if (!ok) {
            _decisionSaveFailed(
              'Save',
              () => SelahDiscoveryService.recordSave(profile.id),
            );
          }
        });
      }
    }
    // REMOVED 2026-07-27 (Founder screenshot: "when we do the save action
    // a message at bottom appears which does not need to be there") — the
    // yellow glass circle above already confirmed the Save (that circle
    // has since been removed too; the border flash now does the job)
    // action; this SnackBar was a redundant second confirmation.
    Timer(const Duration(milliseconds: 280), () {
      if (mounted) _advance();
    });
  }

  Future<void> _onConsider() async {
    if (_claimingConsider) return;
    if (_limitReached) {
      _showLimitReachedModal();
      return;
    }
    // 2026-07-27 — Consider ("like") cap by plan. SELAH One is
    // unlimited (Founder: "like is unlimited") — skipped entirely for
    // that plan rather than checked against a very large number.
    if (AppState.instance.plan == SelahPlan.basic &&
        AppState.instance.outgoingLikes.length >= selahBasicConsiderLimit) {
      _showCapReachedModal(action: 'Consider', limit: selahBasicConsiderLimit);
      return;
    }
    final profile = _current;
    if (profile == null) {
      return;
    }
    if (AppState.instance.plan == SelahPlan.basic &&
        !AppState.instance.outgoingLikes.any((p) => p.id == profile.id)) {
      _claimingConsider = true;
      try {
        final usage = await SelahSeekerBasicUsageStore.tryRecordConsider();
        if (!mounted) return;
        if (usage == null) {
          _showBrowseRefusal(
            title: 'Daily Consider limit reached',
            message:
                'Your current allowance is ${SelahSeekerBasicPolicy.dailyConsiderLimit} '
                'Considers each day. You can still Pass or Save profiles today.',
            icon: Icons.today_outlined,
          );
          return;
        }
        _basicUsage = usage;
      } catch (_) {
        if (!mounted) return;
        _showBrowseRefusal(
          title: 'Couldn’t record your allowance',
          message: 'Your profile decision is unchanged. Please try again.',
          icon: Icons.info_outline,
        );
        return;
      } finally {
        _claimingConsider = false;
      }
    }
    final isMatch = AppState.instance.like(profile);
    // BUG-02: this is the write that makes matches exist —
    // create_match_on_mutual_like only fires off a row that lands. A
    // failure surfaces with a retry; see _decisionSaveFailed.
    if (SelahReportService.isPersistableId(profile.id)) {
      SelahDiscoveryService.recordLike(profile.id).then((ok) {
        if (!ok) {
          _decisionSaveFailed(
            'Consider',
            () => SelahDiscoveryService.recordLike(profile.id),
          );
        }
      });
    }
    Timer(const Duration(milliseconds: 280), () async {
      // 2026-08-12: this one-shot outlives the screen if the user leaves
      // Browse inside the 280ms window; pushing from a dead context threw.
      if (!mounted) return;
      if (isMatch) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchNotificationScreen(
              matchedWith: profile,
              onViewMatch: () {
                Navigator.of(context).pop();
                widget.onNavigateToConnections?.call();
              },
            ),
          ),
        );
      }
      await _advance();
    });
  }

  void _tapPhoto(TapUpDetails details, double width) {
    final profile = _current;
    if (profile == null || profile.photos.length <= 1) return;
    final goRight = details.localPosition.dx > width / 2;
    setState(() {
      if (goRight) {
        _photoIndex = _photoIndex >= profile.photos.length - 1
            ? 0
            : _photoIndex + 1;
      } else {
        _photoIndex = _photoIndex <= 0 ? 0 : _photoIndex - 1;
      }
    });
  }

  // --- Swipe gesture handling (inherited decision 099) ---------------------------

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragStartGlobal = details.globalPosition;
      _dragAxis = null;
      _dragCommitted = false;
      _dragInProgress = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartGlobal == null) return;
    setState(() {
      _dragOffset += details.delta;
      _dragAxis ??= SelahBrowseSwipePolicy.previewAxis(_dragOffset);
    });
  }

  // --- Live drag-direction preview (2026-07-26 swipe redesign) --------
  //
  // Founder feedback: "the current swiping action is not nice... I kinda
  // want the traffic light colour implements. Green if u swipe positive.
  // Yellow if u save and red if u skip." Previously the only feedback
  // during a drag was the card itself moving — the traffic-light colour
  // only appeared as a brief post-commit flash (_showFlash). This
  // computes the same _Decision + an intensity (0-1, capped at the
  // commit threshold) continuously while dragging, so the card can show
  // a live colour wash + label as the finger moves, the same real-time
  // feedback pattern the Founder's own mockup reaction approved.
  //
  // Final Founder mapping, confirmed 2026-08-27: left=Consider (green),
  // right=Pass (red), down=Save (yellow). The Save treatment is drawn from
  // the top edge, as though the downward gesture reveals it behind the card.
  _Decision? get _dragDecision => _decisionFromPolicy(
    SelahBrowseSwipePolicy.previewDecision(_dragOffset, lockedAxis: _dragAxis),
  );

  double get _dragStrength {
    final decision = _dragDecision;
    if (decision == null) return 0;
    final distance = decision == _Decision.save
        ? _dragOffset.dy
        : _dragOffset.dx.abs();
    return (distance / _swipeCommitThreshold).clamp(0.0, 1.0);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStartGlobal = null;
    final dragAxis = _dragAxis;
    _dragAxis = null;
    final decision = _decisionFromPolicy(
      SelahBrowseSwipePolicy.committedDecision(
        _dragOffset,
        lockedAxis: dragAxis,
      ),
    );
    if (decision != null) {
      _dragInProgress = false;
      _commitSwipe(decision);
    } else {
      // Below threshold — motion options settle back; fixed options simply
      // clear their live treatment.
      setState(() {
        _dragInProgress = false;
        _dragOffset = Offset.zero;
      });
    }
  }

  void _onPanCancel() {
    _dragStartGlobal = null;
    _dragAxis = null;
    setState(() {
      _dragInProgress = false;
      _dragOffset = Offset.zero;
    });
  }

  void _commitSwipe(_Decision decision) {
    if (_dragCommitted) return;
    _dragCommitted = true;
    _triggerBurst(decision);
    // Fling the card the rest of the way off-screen in the swipe
    // direction, then run the matching action exactly as the old
    // button handlers did.
    final flingTarget = SelahBrowseSwipePolicy.flingTarget(
      _policyDecisionFrom(decision),
    );
    setState(() => _dragOffset = flingTarget);
    switch (decision) {
      case _Decision.pass:
        _onPass();
      case _Decision.save:
        _onSave();
      case _Decision.consider:
        _onConsider();
    }
    // Reset the drag offset once _advance() (called by the handlers
    // above, after their own short delay) has moved on to the next
    // profile, so the new card doesn't inherit the old one's fling
    // position.
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _dragOffset = Offset.zero);
    });
  }

  Matrix4 _photoSwipeTransform(SelahBrowseSwipeFeedbackStyle style) {
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    final progress = _dragStrength;
    switch (style) {
      case SelahBrowseSwipeFeedbackStyle.fullAura:
        return Matrix4.identity();
      case SelahBrowseSwipeFeedbackStyle.layeredParallax:
        return Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..setTranslationRaw(dx * 0.70, dy * 0.70, progress * 72)
          ..rotateY(-dx / 1050)
          ..rotateX(dy / 1300)
          ..rotateZ(dx / 3600);
      case SelahBrowseSwipeFeedbackStyle.edgePeek:
        return Matrix4.translationValues(dx * 0.90, dy * 0.90, 0)
          ..rotateZ(dx / 4200);
      case SelahBrowseSwipeFeedbackStyle.floatingDeck:
        final scale = 1 - progress * 0.025;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0012)
          ..setTranslationRaw(dx * 0.64, dy * 0.64, progress * 105)
          ..rotateY(-dx / 1450)
          ..rotateX(dy / 1700)
          ..rotateZ(dx / 3800);
      case SelahBrowseSwipeFeedbackStyle.carousel3d:
        return Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..setTranslationRaw(dx * 0.52, dy * 0.52, progress * 55)
          ..rotateY(-dx / 430)
          ..rotateX(dy / 520);
      case SelahBrowseSwipeFeedbackStyle.doorHinge:
        return Matrix4.identity()
          ..setEntry(3, 2, 0.0017)
          ..setTranslationRaw(dx * 0.38, dy * 0.42, progress * 46)
          ..rotateY(-dx / 290)
          ..rotateX(dy / 360);
      case SelahBrowseSwipeFeedbackStyle.pageCurl:
        final scale = 1 - progress * 0.035;
        return Matrix4.diagonal3Values(scale, 1, 1)
          ..setEntry(3, 2, 0.0015)
          ..setTranslationRaw(dx * 0.56, dy * 0.56, progress * 70)
          ..rotateY(-dx / 520)
          ..rotateX(dy / 620)
          ..rotateZ(dx / 5200);
      case SelahBrowseSwipeFeedbackStyle.depthTunnel:
        final scale = 1 - progress * 0.18;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0013)
          ..setTranslationRaw(dx * 0.30, dy * 0.30, -progress * 170)
          ..rotateY(-dx / 1700)
          ..rotateX(dy / 1900);
      case SelahBrowseSwipeFeedbackStyle.subjectSplit:
        return Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..setTranslationRaw(dx * 0.58, dy * 0.58, progress * 66)
          ..rotateY(-dx / 1200)
          ..rotateX(dy / 1450);
      case SelahBrowseSwipeFeedbackStyle.magneticTilt:
        return Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..setTranslationRaw(dx * 0.67, dy * 0.67, progress * 98)
          ..rotateY(-dx / 390)
          ..rotateX(dy / 470)
          ..rotateZ(dx / 3100);
      case SelahBrowseSwipeFeedbackStyle.horizonLift:
        final scale = 1 - progress * 0.018;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0014)
          ..setTranslationRaw(
            dx * 0.56,
            dy * 0.56 - progress * 22,
            progress * 128,
          )
          ..rotateY(-dx / 1350)
          ..rotateX(dy / 760)
          ..rotateZ(dx / 4200);
    }
  }

  Matrix4 _nextProfileSwipeTransform(SelahBrowseSwipeFeedbackStyle style) {
    final progress = _dragStrength;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    final horizontal = dx.abs() > dy.abs();
    final direction = horizontal && dx != 0 ? dx.sign : 0.0;
    final incomingX = -direction * 46 * (1 - progress);
    final incomingY = horizontal ? 12 * (1 - progress) : -46 * (1 - progress);

    switch (style) {
      case SelahBrowseSwipeFeedbackStyle.fullAura:
        return Matrix4.identity();
      case SelahBrowseSwipeFeedbackStyle.layeredParallax:
        final scale = 0.92 + progress * 0.08;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setTranslationRaw(-dx * 0.12, incomingY, -70 + progress * 70);
      case SelahBrowseSwipeFeedbackStyle.edgePeek:
        final scale = 0.97 + progress * 0.03;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setTranslationRaw(incomingX * 0.34, incomingY * 0.34, 0);
      case SelahBrowseSwipeFeedbackStyle.floatingDeck:
        final scale = 0.90 + progress * 0.10;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0011)
          ..setTranslationRaw(-dx * 0.10, incomingY, -78 + progress * 78);
      case SelahBrowseSwipeFeedbackStyle.carousel3d:
        final scale = 0.95 + progress * 0.05;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0015)
          ..setTranslationRaw(incomingX, incomingY * 0.52, -48 + progress * 48)
          ..rotateY(direction * (1 - progress) * 0.76)
          ..rotateX(horizontal ? 0 : -(1 - progress) * 0.58);
      case SelahBrowseSwipeFeedbackStyle.doorHinge:
        final scale = 0.93 + progress * 0.07;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0014)
          ..setTranslationRaw(
            incomingX * 0.32,
            incomingY * 0.32,
            -64 + progress * 64,
          );
      case SelahBrowseSwipeFeedbackStyle.pageCurl:
        final scale = 0.93 + progress * 0.07;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0014)
          ..setTranslationRaw(
            incomingX * 0.25,
            incomingY * 0.25,
            -60 + progress * 60,
          )
          ..rotateY(direction * (1 - progress) * 0.34);
      case SelahBrowseSwipeFeedbackStyle.depthTunnel:
        final scale = 0.78 + progress * 0.22;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0015)
          ..setTranslationRaw(
            incomingX * 0.12,
            incomingY * 0.12,
            -175 + progress * 175,
          );
      case SelahBrowseSwipeFeedbackStyle.subjectSplit:
        final scale = 0.92 + progress * 0.08;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setTranslationRaw(-dx * 0.18, -dy * 0.10, -66 + progress * 66);
      case SelahBrowseSwipeFeedbackStyle.magneticTilt:
        final scale = 0.93 + progress * 0.07;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0015)
          ..setTranslationRaw(-dx * 0.19, -dy * 0.12, -68 + progress * 68)
          ..rotateY(direction * (1 - progress) * 0.30);
      case SelahBrowseSwipeFeedbackStyle.horizonLift:
        final scale = 0.88 + progress * 0.12;
        return Matrix4.diagonal3Values(scale, scale, 1)
          ..setEntry(3, 2, 0.0013)
          ..setTranslationRaw(
            -dx * 0.08,
            -34 * (1 - progress),
            -84 + progress * 84,
          );
    }
  }

  Alignment _photoSwipeAlignment(SelahBrowseSwipeFeedbackStyle style) {
    if (style != SelahBrowseSwipeFeedbackStyle.doorHinge &&
        style != SelahBrowseSwipeFeedbackStyle.pageCurl) {
      return Alignment.center;
    }
    if (_dragOffset.dy > _dragOffset.dx.abs()) return Alignment.topCenter;
    if (_dragOffset.dx < 0) return Alignment.centerRight;
    if (_dragOffset.dx > 0) return Alignment.centerLeft;
    return Alignment.center;
  }

  Matrix4 _profileCopySwipeTransform(SelahBrowseSwipeFeedbackStyle style) {
    if (style != SelahBrowseSwipeFeedbackStyle.subjectSplit) {
      return Matrix4.identity();
    }
    return Matrix4.translationValues(
      _dragOffset.dx * 0.18,
      _dragOffset.dy * 0.14,
      _dragStrength * 34,
    );
  }

  Widget _buildNextProfilePreview(SeekerProfile profile) => Stack(
    fit: StackFit.expand,
    children: [
      SelahProfileImage(
        profile.photos.isEmpty ? '' : profile.photos.first,
        showLoader: false,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xB3000000)],
            stops: [0.50, 1.0],
          ),
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 130,
        child: SelahProfileNameBlock(profile: profile),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // 2026-07-27 — see _allProfiles/_loadingCandidates doc comment
    // above. Real candidates (or fetchCandidates()'s own mockProfiles
    // fallback, when that's genuinely the correct result) only ever
    // render once this is false, so a stale hardcoded profile is never
    // shown mid-fetch.
    if (_loadingCandidates) {
      return Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: const SelahLoading.browse(),
      );
    }
    if (_candidatesUnavailable) {
      return Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SelahLoadFailure(contentName: 'Profiles', onRetry: _loadDeck),
      );
    }
    final profile = _current;
    final nextProfile = _nextProfile;
    final swipeFeedbackStyle =
        SelahDevScenario.instance.browseSwipeFeedbackStyle;
    // 2026-07-25, inherited decision 101 audit item 1 (Founder decision: "switch
    // to gradient"): gender-matched gradient, not flat — Browse is
    // only ever reached by a signed-in, onboarded Seeker, so gender is
    // always known here, same as every other profile-context screen
    // fixed under inherited decision 101 (SelahColors.genderGradient()).
    return Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed photo, edge to edge — no outer padding, no rounding.
          if (profile == null && _gated)
            const SizedBox.shrink()
          else if (profile == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _filterActive
                          ? Icons.filter_alt_off_outlined
                          : Icons.check_circle_outline,
                      color: Colors.white38,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _filterActive
                          ? 'No one matches your age filter'
                          : 'You\'re all caught up',
                      style: SelahText.heading(size: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _filterActive
                          ? 'Try widening the range, or clear it to see everyone again.'
                          : 'More profiles will appear as new members join.',
                      style: SelahText.subtext(),
                      textAlign: TextAlign.center,
                    ),
                    if (_filterActive) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _minAge = null;
                          _maxAge = null;
                          _index = 0;
                          _photoIndex = 0;
                        }),
                        child: Text(
                          'Clear filter',
                          style: SelahText.button(size: 13),
                        ),
                      ),
                    ] else ...[
                      // 2026-07-27 (Founder: "when it says your all
                      // caught up. there should be a button to say reset
                      // search whihc thenm takes them back to browser
                      // and shows all profiles they either skipped or
                      // saved"). Reaching this empty state means _index
                      // has already advanced past every candidate in
                      // _profiles — nothing is filtered OUT of that list
                      // today (Pass/Save/Consider only move _index
                      // forward, they don't remove anyone from
                      // _allProfiles), so restarting from 0 naturally
                      // re-shows exactly that same full set, everyone in
                      // it having already been Passed, Saved, or
                      // Considered. Deliberately does NOT reset _viewed
                      // (the daily limit counter) — re-browsing already-
                      // seen profiles isn't new content for that purpose.
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _index = 0;
                          _photoIndex = 0;
                        }),
                        child: Text(
                          'Reset search',
                          style: SelahText.button(size: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapUp: (d) => _tapPhoto(d, constraints.maxWidth),
                // Long-press keeps ONLY the photo-dim feedback since
                // 2026-08-13 (inherited decision 150): the centre-hold menu it
                // used to open retired with the ⋮ — a visible button
                // beat a hidden 800ms gesture, the Founder's call.
                onLongPressStart: (_) => setState(() => _interacting = true),
                onLongPressEnd: (_) => setState(() => _interacting = false),
                // Swipe gestures — left = Consider, right = Pass, down =
                // Save. Coexists with the tap/long-press
                // recognisers above: a plain tap has no meaningful pan
                // delta, so onPanEnd's threshold check below simply does
                // nothing and the tap fires normally.
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanCancel,
                // Full aura preserves the current fixed-photo response. The
                // other ten options animate the live card and reveal the next
                // real profile beneath it. Both layers follow the same drag
                // state, so a rejected gesture settles together and a commit
                // hands off without a blank frame.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (swipeFeedbackStyle.previewsNextProfile &&
                        nextProfile != null)
                      IgnorePointer(
                        child: AnimatedOpacity(
                          duration: _dragInProgress
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          opacity: 0.34 + (_dragStrength * 0.66),
                          child: AnimatedContainer(
                            duration: _dragInProgress
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            transform: _nextProfileSwipeTransform(
                              swipeFeedbackStyle,
                            ),
                            transformAlignment: Alignment.center,
                            child: _buildNextProfilePreview(nextProfile),
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: _dragInProgress
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      transform: _photoSwipeTransform(swipeFeedbackStyle),
                      transformAlignment: _photoSwipeAlignment(
                        swipeFeedbackStyle,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 2026-07-26 (Founder: "the pictures load a lot
                          // better now but sometimes there's a slight delay so
                          // I see the blue/purple background... maybe add a
                          // loading message/icon/animation"). The spinner moved
                          // into SelahProfileImage 2026-08-03 behind
                          // `showLoader`, unchanged in appearance — but it now
                          // only runs for network photos. A dev colour block
                          // paints instantly and would otherwise flash a
                          // spinner on every single card.
                          // FIXED 2026-08-05 (Founder: "when I click view profile
                          // for family suggestions it goes to Browse and it's just
                          // a white page").
                          //
                          // This was a bare `profile.photos[_photoIndex]`. Two ways
                          // it threw a RangeError, and a RangeError inside build()
                          // paints nothing — hence a white screen rather than an
                          // error:
                          //
                          //   1. photos was EMPTY. Shepherd Suggestions build their
                          //      SeekerProfile from whatever photos signed, and
                          //      before today's storage-policy fix that could be
                          //      none. "View profile" then pushed a photoless
                          //      person straight into this card.
                          //   2. _photoIndex was left over from the PREVIOUS
                          //      profile. Jumping to a suggestion while parked on
                          //      photo 4 of someone with five photos lands on a
                          //      person who has two.
                          //
                          // The policy fix addresses the cause of (1); this
                          // addresses the consequence of both, permanently. A
                          // missing photo is a placeholder, never a blank screen.
                          SelahProfileImage(
                            profile.photos.isEmpty
                                ? ''
                                : profile.photos[_photoIndex <
                                          profile.photos.length
                                      ? _photoIndex
                                      : 0],
                            showLoader: true,
                          ),
                          // Top gradient — status bar / glass button legibility.
                          Container(
                            alignment: Alignment.topCenter,
                            height: 130,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x66000000), Colors.transparent],
                              ),
                            ),
                          ),
                          // Bottom gradient — identity block legibility.
                          //
                          // STRENGTHENED 2026-08-07, modestly and on purpose. The
                          // identity block sits 130px up, so at the old 300px /
                          // 0x40-at-0.4 the NAME was landing on 17% black: 1.48:1
                          // against a white photo. Now 340px tall with the mid
                          // stop moved up and darkened, which puts the name on 32%
                          // — 2.24:1.
                          //
                          // That still does not reach 3:1, and it is not meant to.
                          // Getting there by scrim alone needs 42% black at the
                          // name's height and washes out the bottom third of every
                          // photo on the platform. The shadows carry the rest —
                          // see kSelahOnPhotoTextShadows for the measurements and
                          // reasoning. This half just stops the small text having
                          // to do it alone.
                          //
                          // Still fully transparent at the top of the band, so
                          // nothing above the identity block is dimmed at all.
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 340,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x4D000000),
                                    Color(0xB3000000),
                                  ],
                                  stops: [0.0, 0.32, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Live drag-direction feedback. The Founder-facing
                          // Browse Actions lab compares the current Full aura with
                          // ten 3D photo-motion responses while preserving the same
                          // threshold and decision writes. None places visible
                          // words, ticks or thumbs over a person's photo.
                          // Semantics retains the spoken decision for accessibility.
                          if (_dragDecision != null)
                            Semantics(
                              label: _dragLabel(_dragDecision!),
                              child: IgnorePointer(
                                child: _SwipeFeedbackLayer(
                                  style: swipeFeedbackStyle,
                                  decision: _dragDecision!,
                                  strength: _dragStrength,
                                  color: _dragColor(_dragDecision!),
                                  borderRadius: _deviceCornerRadiusGuess(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                          // REMOVED 2026-07-27 (3rd pass, Founder: "i like how
                          // the colour now wraps around the whole frame
                          // meaning i think we get rid of the dots and the
                          // animation happens on the outer rim when thumb is
                          // removed for execution"). The 3 fixed-position dot
                          // clusters that lived here through 3 prior passes
                          // (text pill → single growing dot → 4-dot cluster,
                          // see git history / prior comments for that lineage)
                          // are gone outright — the selected visual above is now
                          // the only live drag feedback, and the commit
                          // animation (_burstDecision, below in this file) is
                          // now _BorderFlash — a flash on that same border
                          // rim, not a ring at a fixed x/y spot. _SwipeDots
                          // class removed with it; _dragLabel/_dragColor are
                          // untouched (still used above and by _BorderFlash).
                          // Left-side vertical photo dots (matches source: left, not right).
                          if (profile.photos.length > 1)
                            Positioned(
                              left: 16,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: AnimatedOpacity(
                                  opacity: _interacting ? 0.35 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(profile.photos.length, (
                                      i,
                                    ) {
                                      final active = i == _photoIndex;
                                      // 2026-07-27 (Founder: "selah one account
                                      // users can upload a video... on the left
                                      // side dots area which shows number of
                                      // photos for a video its a play button
                                      // like the right face triangle") — mockup
                                      // only, see SeekerProfile.videoPhotoIndex's
                                      // doc comment. Slightly larger than a
                                      // plain dot (9px vs 7px) so the triangle
                                      // has room to read; icon colour inverts
                                      // against the fill the same way the dot's
                                      // own fill/backdrop contrast already
                                      // works (dark glyph on the white active
                                      // fill, light glyph on the dim inactive
                                      // fill) so it stays legible in both states.
                                      if (profile.videoPhotoIndex == i) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 3,
                                          ),
                                          width: 9,
                                          height: 9,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 0.5,
                                            ),
                                            color: active
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.32,
                                                  ),
                                          ),
                                          child: Icon(
                                            Icons.play_arrow,
                                            size: 7,
                                            color: active
                                                ? SelahColors.luxuryDarkPurple
                                                : Colors.white,
                                          ),
                                        );
                                      }
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 0.5,
                                          ),
                                          color: active
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.32,
                                                ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          // Identity block — bottom-left, large name/age/location.
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 130,
                            child: AnimatedContainer(
                              duration: _dragInProgress
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              transform: _profileCopySwipeTransform(
                                swipeFeedbackStyle,
                              ),
                              transformAlignment: Alignment.center,
                              child: AnimatedOpacity(
                                opacity: _interacting ? 0.35 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // SAVED BADGE REMOVED 2026-08-03.
                                    //
                                    // It existed because a saved profile stayed
                                    // in the Browse deck under the two-axis
                                    // model — a bookmark was not a decision, so
                                    // you could meet them again and the badge
                                    // explained why.
                                    //
                                    // With one state per profile, saving IS
                                    // acting on someone: they leave the deck
                                    // like a Consider or a Pass. This branch
                                    // became unreachable, so it goes rather than
                                    // sitting here looking load-bearing.
                                    // SHEPHERD SUGGESTION BADGE — 2026-08-05
                                    // (Founder: "a shepherd suggested a person but
                                    // a person was browsing anyway and saw a person
                                    // shepherd suggested, or they clicked the link
                                    // the shepherd suggested for that profile — I
                                    // need somewhere in Browse, maybe above the
                                    // navigation bar, the words shepherd
                                    // suggestion").
                                    //
                                    // Shown whichever way you arrived: tapping
                                    // through from Connections, or simply reaching
                                    // them in the deck. The fact belongs to the
                                    // person, not to the route — meeting someone
                                    // your Shepherd put forward should feel the
                                    // same either way.
                                    //
                                    // Sits directly above the name rather than
                                    // floating over the photo, so it reads as part
                                    // of who they are rather than an alert.
                                    if (AppState.instance.suggestedBy(
                                          profile.id,
                                        ) !=
                                        null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.28,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.22,
                                            ),
                                            width: 0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.shield_outlined,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Suggested by ${AppState.instance.suggestedBy(profile.id)}',
                                              style: SelahText.subtext(
                                                size: 11.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    // THE SHARED BLOCK — inherited decision 163. Browse
                                    // is where this design was decided
                                    // (inherited decision 162, option C of five), and it is
                                    // now one widget so the three Connections
                                    // surfaces draw the same thing rather than
                                    // three approximations of it.
                                    SelahProfileNameBlock(profile: profile),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // inherited upstream action 125 §5: the "X/50 profiles" counter chip that used to
          // sit here permanently is removed. The limit now only ever
          // surfaces as the modal in _showLimitReachedModal(), triggered
          // right when the limit is hit — see _advance() and the
          // _limitReached guards in _onPass/_onSave/_onConsider.

          // REMOVED 2026-08-01 (Founder: "I don't want the green tick in
          // the middle, that goes for save and decline also"). The centred
          // GlassFlashCircle covered the person's face at the exact moment
          // the user was deciding about them, and duplicated feedback the
          // edge flash below already confirms the action without covering
          // the photo. Two confirmations for one
          // action, one of them landing on top of the face.
          //
          // _flash / _showFlash were deleted 2026-08-01 — once the badge
          // went, nothing read them. See their note further up.

          // 2026-07-27 (3rd pass, Founder, screenshot-driven: "i like
          // how the colour now wraps around the whole frame meaning i
          // think we get rid of the dots and the animation happens on
          // the outer rim when thumb is removed for execution"). Was 3
          // fixed-position expanding rings (_SwipeBurst). Replaced by one
          // _BorderFlash painter that resolves its right/left/top edge from
          // `_burstDecision` and stays colour-coded via `_dragColor`. Kept at
          // this same top
          // level, sibling to the decision flash above, for the same
          // reason the old burst was: driven by `_burstDecision` rather
          // than `_dragDecision` so it survives `_advance()` switching
          // profiles partway through the animation, which nesting it
          // inside the swappable card would cut short.
          if (_burstDecision != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _BorderFlash(
                  color: _dragColor(_burstDecision!),
                  decision: _burstDecision!,
                  borderRadius: _deviceCornerRadiusGuess(context),
                ),
              ),
            ),

          // 2026-07-25, inherited decision 099: the floating glass action-button row
          // (Pass/Save/Consider buttons) is removed here per the Founder's
          // explicit "stick with swiping actions for cleaner UI" decision.
          // All three actions are now reachable only via the swipe
          // gestures wired into the GestureDetector above (_onPanEnd /
          // _commitSwipe) — see this file's header comment for the
          // full inherited decision 099 rationale.

          // REMOVED 2026-07-26 (Founder, reviewing this page: "that's
          // not needed cos they can change that in setting/onboarding").
          // Checked first, per standing process, rather than removing on
          // request alone: grepped onboarding/ and settings/ for any
          // existing age-range control — there isn't one anywhere else
          // in the app today. This icon was the ONLY way to set an age
          // range, so the capability is gone until it's rebuilt somewhere
          // (Settings, most likely) — flagged back to the Founder rather
          // than silently dropping it. _openFilterSheet/_minAge/_maxAge/
          // _filterActive deliberately left in the class, unused, rather
          // than deleted — cheap to wire to a new entry point later,
          // expensive to rebuild from nothing.
          //
          // Bell + Help/Report menu both now live at HomeShell level,
          // stacked top-right as anchored cards (see home_shell.dart,
          // widgets/notification_bell.dart) — not in this top-left slot
          // any more as of the 2026-07-26 Bell/3-dot reposition pass.
          // THE ⋮ — 2026-08-13 (inherited decision 150, Founder: "put 3 dots on
          // top right. if click the nav bar changes… becomes 2 pills").
          // The visible door that replaced the centre-hold: it hands
          // the shell what Report should mean right now — whoever is
          // on the card — and the shell's action bar does the rest.
          // Last child on purpose: it must sit above every layer of card
          // chrome.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                // NO GLASS CIRCLE — 2026-08-13 (inherited decision 153, Founder:
                // "you see in Browse we have 3 dots with outer circle,
                // remove the outer circle"). GlassIconButton is left
                // alone: it is the shared component behind the Bell and
                // the Shepherd's buttons, and removing its circle there
                // would strip three controls to answer a note about one.
                //
                // THE SHADOW IS NOT DECORATION. The circle was doing a
                // second job nobody asked it to — it carried its own
                // contrast, so the glyph stayed legible over a bright
                // photo. Bare white dots on a pale headshot disappear.
                // A soft dark drop shadow buys that contrast back at a
                // fraction of the visual weight.
                //
                // Sized to a 40pt box, matching what GlassIconButton
                // occupied, so the tap target does not shrink with the
                // circle — the icon is 24pt inside it.
                child: SelahBrowseMoreActionsButton(
                  onPressed: () {
                    final profile = _current;
                    if (profile == null) return;
                    widget.onOpenActions?.call((
                      report: _reportCurrentProfile,
                      // Bind the person at menu-open time so the warning and
                      // the confirmed destructive action can never drift onto
                      // different cards while the second step is visible.
                      hide: () => unawaited(_hideProfile(profile)),
                      hideWarning:
                          "You and ${profile.firstName} won't see each other "
                          'in SELAH. Any live Journey together will end. '
                          'Nothing is reported and nobody is told. You can '
                          'unhide them later in Settings, but an ended '
                          'Journey will not be restored.',
                      compatibility: _openCompatibilityForCurrent,
                    ));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Browse's visible three-dot action door.
///
/// Kept as a small component so its native haptic can be regression-tested
/// without booting discovery, authentication or a candidate deck. The
/// selected member haptic preference remains authoritative, including Off.
class SelahBrowseMoreActionsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SelahBrowseMoreActionsButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('browse-more-actions'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(SelahInteractionStyle.emitSelectionHaptic());
        onPressed();
      },
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.more_horiz,
          size: 24,
          color: Colors.white,
          shadows: [Shadow(color: Color(0x8C000000), blurRadius: 6)],
        ),
      ),
    );
  }
}

/// Visual-only response painted while the Browse gesture is in progress.
///
/// One painter keeps the ten fixed-photo options cheap: there are no
/// controllers, timers or rebuilding subtrees. The other five options move the
/// parent card and intentionally paint nothing over the profile.
class _SwipeFeedbackLayer extends StatelessWidget {
  final SelahBrowseSwipeFeedbackStyle style;
  final _Decision decision;
  final double strength;
  final Color color;
  final double borderRadius;

  const _SwipeFeedbackLayer({
    required this.style,
    required this.decision,
    required this.strength,
    required this.color,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _SwipeFeedbackPainter(
        style: style,
        decision: decision,
        strength: strength,
        color: color,
        borderRadius: borderRadius,
      ),
      size: Size.infinite,
    ),
  );
}

class _SwipeFeedbackPainter extends CustomPainter {
  final SelahBrowseSwipeFeedbackStyle style;
  final _Decision decision;
  final double strength;
  final Color color;
  final double borderRadius;

  const _SwipeFeedbackPainter({
    required this.style,
    required this.decision,
    required this.strength,
    required this.color,
    required this.borderRadius,
  });

  SelahBrowseSwipeCueEdge get _cueEdge =>
      SelahBrowseSwipePolicy.cueEdge(_policyDecisionFrom(decision));
  bool get _isLeft => _cueEdge == SelahBrowseSwipeCueEdge.left;
  bool get _isRight => _cueEdge == SelahBrowseSwipeCueEdge.right;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = strength.clamp(0.0, 1.0);
    switch (style) {
      case SelahBrowseSwipeFeedbackStyle.fullAura:
        _paintFullAura(canvas, size, progress);
      case SelahBrowseSwipeFeedbackStyle.layeredParallax ||
          SelahBrowseSwipeFeedbackStyle.edgePeek ||
          SelahBrowseSwipeFeedbackStyle.floatingDeck ||
          SelahBrowseSwipeFeedbackStyle.carousel3d ||
          SelahBrowseSwipeFeedbackStyle.doorHinge ||
          SelahBrowseSwipeFeedbackStyle.pageCurl ||
          SelahBrowseSwipeFeedbackStyle.depthTunnel ||
          SelahBrowseSwipeFeedbackStyle.subjectSplit ||
          SelahBrowseSwipeFeedbackStyle.magneticTilt ||
          SelahBrowseSwipeFeedbackStyle.horizonLift:
        break;
    }
  }

  void _paintFullAura(Canvas canvas, Size size, double progress) {
    final inset = 3.0 + progress;
    final rect = Offset.zero & size;
    final rim = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular((borderRadius - inset).clamp(0.0, borderRadius)),
    );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 + progress * 5
      ..color = color.withValues(alpha: 0.10 + progress * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + progress * 3
      ..color = color.withValues(alpha: 0.28 + progress * 0.55);
    canvas.drawRRect(rim, glow);
    canvas.drawRRect(rim, line);
    _paintEdgeLine(canvas, size, progress, color, width: 4 + progress * 4);
  }

  void _paintEdgeLine(
    Canvas canvas,
    Size size,
    double progress,
    Color lineColor, {
    required double width,
    double? lengthFactor,
  }) {
    final factor = lengthFactor ?? (0.22 + progress * 0.58);
    final axis = decision == _Decision.save ? size.width : size.height;
    final length = axis * factor;
    late Offset start;
    late Offset end;
    if (_isLeft || _isRight) {
      final x = _isLeft ? 6.0 : size.width - 6;
      start = Offset(x, (size.height - length) / 2);
      end = Offset(x, (size.height + length) / 2);
    } else {
      final y = 6.0;
      start = Offset((size.width - length) / 2, y);
      end = Offset((size.width + length) / 2, y);
    }
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width + 9
      ..color = lineColor.withValues(alpha: 0.08 + progress * 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = lineColor.withValues(alpha: 0.30 + progress * 0.62);
    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, line);
  }

  @override
  bool shouldRepaint(covariant _SwipeFeedbackPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.decision != decision ||
      oldDelegate.strength != strength ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}

/// One-shot edge flash when a swipe is released.
///
/// 2026-07-27 (3rd pass, Founder, screenshot-driven: "i like how the
/// colour now wraps around the whole frame meaning i think we get rid
/// of the dots and the animation happens on the outer rim when thumb is
/// removed for execution"). Replaces the old _SwipeDots (live drag
/// preview) + _SwipeBurst (commit-time ring at one of 3 fixed dot
/// positions) pair entirely. The live-drag treatment is now selectable;
/// this remains the one commit-time animation. The horizontal cue deliberately
/// counterbalances the card: red rises on the left during Pass, green on the
/// right during Consider, and yellow remains at the top for Save.
///
/// A fresh instance is only ever mounted while `_burstDecision` is
/// non-null (see that field's own doc comment + the single call site
/// above), so `TweenAnimationBuilder` naturally plays once from 0→1 and
/// is removed when `_burstDecision` resets — no AnimationController/
/// ticker bookkeeping needed, same pattern _SwipeBurst used.
class _BorderFlash extends StatelessWidget {
  final Color color;
  final _Decision decision;
  final double borderRadius;
  const _BorderFlash({
    required this.color,
    required this.decision,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, v, child) {
        return CustomPaint(
          painter: _CommitEdgeFlashPainter(
            color: color,
            decision: decision,
            progress: v,
            borderRadius: borderRadius,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CommitEdgeFlashPainter extends CustomPainter {
  final Color color;
  final _Decision decision;
  final double progress;
  final double borderRadius;

  const _CommitEdgeFlashPainter({
    required this.color,
    required this.decision,
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fade = (1 - progress).clamp(0.0, 1.0);
    final cueEdge = SelahBrowseSwipePolicy.cueEdge(
      _policyDecisionFrom(decision),
    );
    final horizontalEdge = cueEdge == SelahBrowseSwipeCueEdge.top;
    final axis = horizontalEdge ? size.width : size.height;
    final length = axis * (0.42 + progress * 0.42);
    final inset = (borderRadius / 9).clamp(5.0, 9.0);
    late Offset start;
    late Offset end;
    if (cueEdge == SelahBrowseSwipeCueEdge.left) {
      start = Offset(inset, (size.height - length) / 2);
      end = Offset(inset, (size.height + length) / 2);
    } else if (cueEdge == SelahBrowseSwipeCueEdge.right) {
      start = Offset(size.width - inset, (size.height - length) / 2);
      end = Offset(size.width - inset, (size.height + length) / 2);
    } else {
      start = Offset((size.width - length) / 2, inset);
      end = Offset((size.width + length) / 2, inset);
    }
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16 - progress * 8
        ..color = color.withValues(alpha: fade * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8 - progress * 5
        ..color = color.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(covariant _CommitEdgeFlashPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.decision != decision ||
      oldDelegate.progress != progress ||
      oldDelegate.borderRadius != borderRadius;
}
