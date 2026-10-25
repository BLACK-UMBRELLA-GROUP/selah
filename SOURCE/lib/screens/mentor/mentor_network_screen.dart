// GN DRAFT 3.1 — D14-RATIFIED interaction model (2026-08-23). Built to
// SELAH_GN_BUILD_CONTRACT_CURRENT_VERSION_V1.md (Rules 1-44, as amended
// for Draft 3 — see mentor_gn_shared.dart's header).
//
// Founder directive, 2026-08-23, the Dashboard/Network restructure:
//   · The CONNECTIONS context moved to the Mentor Dashboard
//     (GNConnectionsPanel in mentor_gn_shared.dart). This page is now
//     DISCOVER only — the one place families are served.
//   · The top slider is the Shepherd's SEEKERS BY NAME (GNSeekerSlider),
//     the same slider the Dashboard shows. Selection is shared through
//     GNContext: slide to a Seeker on either page and the other page is
//     already on them.
//   · The merge card's "Review request" no longer switches pages — it
//     opens the incoming request in place (showGNIncomingSheet); the
//     same request also sits in the Dashboard's Connections section.
//
// Draft 3.1 (Founder phone feedback, 2026-08-23), four changes:
//   1. The no-Seeker state copies the Seeker-side blank pages and the
//      Dashboard: message + "Invite your Seeker" button — no dev-speak.
//   2. The Seeker slider is the Seeker Connections page's exact pill
//      (SelahSegmentedToggle) and the SCREEN SWIPES: the body is a
//      PageView, one Discover per Seeker, fill travelling with the
//      finger; swiping writes the shared selection.
//   3. REVERSED same day (Draft 3.2, from screenshots): no Seeker → NO
//      bar at all. The blank page copies the Shepherds page exactly —
//      the large + and one short line (SelahAddCircle); the slider first
//      appears with the first Seeker.
//   4. The served family card FILLS the screen (no dead area below):
//      the page lays out to full height, the card stretches and spaces
//      its content, scrolling only when a small screen truly needs it.
//
// Draft 2.x history kept in git and in OVERNIGHT_GN_2026-08-23/. All
// mock data remains PROVISIONAL and developer-preview only (Rule 44);
// the production path renders the entitlement gate + empty states;
// flutter analyze gated.

import 'package:flutter/material.dart';
import '../../data/selah_membership_catalog.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../services/selah_entitlement_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_product_telemetry.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_card_metrics.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_segmented_toggle.dart';
import '../../widgets/selah_state_widgets.dart';
import '../subscription/upgrade_screen.dart';
import 'mentor_gn_shared.dart';
import 'mentor_invite_seeker_screen.dart';

class MentorNetworkScreen extends StatefulWidget {
  const MentorNetworkScreen({super.key});

  @override
  State<MentorNetworkScreen> createState() => _MentorNetworkScreenState();
}

class _MentorNetworkScreenState extends State<MentorNetworkScreen> {
  bool _loading = true;
  bool _hasExtended = false;
  bool _hasLinkedSeeker = false;

  final PageController _modePager = PageController();
  double _modePosition = 0;

  void _onModeScroll() {
    if (!_modePager.hasClients || _modePager.page == null) return;
    final next = _modePager.page!;
    if ((next - _modePosition).abs() < 0.001) return;
    setState(() => _modePosition = next);
  }

  @override
  void initState() {
    super.initState();
    _modePager.addListener(_onModeScroll);
    AppState.instance.addListener(_onChange);
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      _loading = false;
      // Founder fix 2026-08-23: rebuild when the dev-scenario store changes
      // (seeker composition edited in the side panel).
      SelahDevScenario.instance.addListener(_onChange);
      // Draft 3: the shared GN state — seeker selection, stages, scenes —
      // lives in GNContext so this page and the Dashboard stay in step.
      GNContext.instance.addListener(_onChange);
      SelahPromotionEngine.instance.addListener(_onChange);
    } else {
      _loadAccess();
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    // UNGATED removes — inherited upstream action 250 (2026-08-23). The gated pair here is
    // exactly what crashed Draft 2.x live: switch accounts through the
    // dev panel and canUseDeveloperTools flips before dispose runs, so
    // the SelahDevScenario listener outlived this State and the next
    // notify (Seeker-side setCurrentPage) called setState on a defunct
    // element. removeListener on a never-registered listener is a
    // documented no-op — remove without gates, in every build.
    SelahDevScenario.instance.removeListener(_onChange);
    GNContext.instance.removeListener(_onChange);
    SelahPromotionEngine.instance.removeListener(_onChange);
    _modePager.removeListener(_onModeScroll);
    _modePager.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccess() async {
    final results = await Future.wait<dynamic>([
      SelahEntitlementService.hasMentorOne(),
      SelahMentorLinkService.fetchLinkedPeople(asMentor: true),
    ]);
    if (mounted) {
      setState(() {
        _hasExtended = results[0] as bool;
        _hasLinkedSeeker = (results[1] as List<MentorLinkedPerson>).isNotEmpty;
        _loading = false;
      });
    }
  }

  // ── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      switch (SelahPromotionEngine.instance.developerShepherdNetworkState) {
        case SelahDeveloperShepherdNetworkState.d14Preview:
          return _buildD14Preview(context);
        case SelahDeveloperShepherdNetworkState.unlinkedBasic:
          return _buildAccessView(
            hasEntitlement: false,
            hasLinkedSeeker: false,
          );
        case SelahDeveloperShepherdNetworkState.linkedBasic:
          return _buildAccessView(hasEntitlement: false, hasLinkedSeeker: true);
        case SelahDeveloperShepherdNetworkState.unlinkedEntitled:
          return _buildAccessView(hasEntitlement: true, hasLinkedSeeker: false);
        case SelahDeveloperShepherdNetworkState.linkedEntitledUnavailable:
          return _buildAccessView(hasEntitlement: true, hasLinkedSeeker: true);
      }
    }

    return _buildAccessView(
      hasEntitlement: _hasExtended,
      hasLinkedSeeker: _hasLinkedSeeker,
      loading: _loading,
    );
  }

  // ── production access matrix (inherited decision 213) ──────────────────────────────
  Widget _buildAccessView({
    required bool hasEntitlement,
    required bool hasLinkedSeeker,
    bool loading = false,
  }) {
    return Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Network', style: SelahText.heading(size: 26)),
            ),
            if (loading)
              const Expanded(child: SelahLoading())
            else
              Expanded(
                child: ShepherdNetworkAccessView(
                  hasEntitlement: hasEntitlement,
                  hasLinkedSeeker: hasLinkedSeeker,
                  onLinkSeeker: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MentorInviteSeekerScreen(),
                    ),
                  ),
                  onMembership: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UpgradeScreen(
                        telemetrySurface: SelahTelemetrySurface.shepherd,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── D14 preview (developer tools only) ──────────────────────────────────
  Widget _buildD14Preview(BuildContext context) {
    final ctx = GNContext.instance;
    final wards = SelahDevScenario.composeMentorWards(
      real: AppState.instance.mentorRealLinkedSeekers,
    );
    final selected = ctx.effectiveSelected(wards);
    final families = selected == null
        ? const <GNFamily>[]
        : ctx.familiesFor(wards, selected);
    final sent = selected == null
        ? 0
        : ctx.previewCountFor(GNNetworkPreviewArea.sent) ??
              ctx.sentCount(selected, families);
    final received = selected == null
        ? 0
        : ctx.previewCountFor(GNNetworkPreviewArea.received) ??
              ctx.incomingCount(selected, families);

    return Container(
      key: const Key('shepherd-network-preview'),
      decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                key: const Key('gn-network-title-row'),
                children: [
                  Text('Network', style: SelahText.heading(size: 26)),
                  const Spacer(),
                  if (selected != null)
                    _NetworkSeekerDropdown(wards: wards, selected: selected),
                ],
              ),
            ),
            if (selected != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: SelahSegmentedToggle(
                  labels: const ['Browser', 'Sent requests', 'Received'],
                  position: _modePosition.clamp(0.0, 2.0),
                  badges: [0, sent, received],
                  labelSize: 10.5,
                  segmentKeys: const [
                    Key('gn-mode-browser'),
                    Key('gn-mode-sent'),
                    Key('gn-mode-received'),
                  ],
                  onChanged: (i) =>
                      SelahSegmentedMotion.animateToPage(_modePager, i),
                ),
              ),
              // Keep a visible boundary even when the card list scrolls;
              // this is shared by Browser, Sent and Received and all five
              // card treatments. Expanded body/cards shorten by the same
              // amount, preserving the existing bottom navigation clearance.
              const SizedBox(height: 16),
            ],
            Expanded(
              child: selected == null
                  ? _buildNoSeeker(context)
                  : PageView(
                      key: const Key('gn-mode-page-view'),
                      controller: _modePager,
                      physics: SelahSegmentedMotion.pagePhysics,
                      children: [
                        _buildDiscover(context, wards, selected),
                        _buildRequests(
                          context,
                          wards: wards,
                          ward: selected,
                          kind: GNNetworkRequestKind.sent,
                        ),
                        _buildRequests(
                          context,
                          wards: wards,
                          ward: selected,
                          kind: GNNetworkRequestKind.received,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── the no-Seeker state (Draft 3.2: the picture-1 pattern, exactly) ─────
  Widget _buildNoSeeker(BuildContext context) {
    // Founder, from screenshots 2026-08-23: copy the Shepherds page's
    // blank state — the large + and one short line. Founder follow-up:
    // centre it in the usable page, above the floating navigation. No bar
    // above it, no paragraph, no pill button.
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: Center(
        child: SelahAddCircle(
          label: 'Invite your Seeker',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MentorInviteSeekerScreen()),
          ),
        ),
      ),
    );
  }

  // ── Discover (Rung 0, Rules 22-24) — one full-height page per Seeker ────
  Widget _buildDiscover(
    BuildContext context,
    List<MentorLinkedPerson> wards,
    MentorLinkedPerson ward,
  ) {
    final ctx = GNContext.instance;
    if (ctx.scene == GNScene.loading || ctx.choosing) {
      return Center(
        child: SelahLoading(label: 'SELAH is choosing the next family…'),
      );
    }
    if (ctx.scene == GNScene.error) {
      return Center(
        child: SizedBox(
          height: 330,
          child: SelahUnknownErrorState(
            onRetry: () => ctx.setScene(GNScene.standard),
          ),
        ),
      );
    }

    final fams = ctx.familiesFor(wards, ward);
    final live = ctx.liveCount(ward, fams);
    final capped = ctx.scene == GNScene.capReached || live >= 3;
    final countOverride = ctx.previewCountFor(GNNetworkPreviewArea.browser);
    final nextFamily = ctx.servedFamily(ward, fams);
    final served = ctx.scene == GNScene.empty
        ? const <GNFamily>[]
        : countOverride == null
        ? nextFamily == null
              ? const <GNFamily>[]
              : <GNFamily>[nextFamily]
        : fams.take(countOverride).toList();
    if (capped) {
      return _buildNetworkState(
        ward: ward,
        child: Center(child: _CapReachedCard(live: live)),
      );
    }
    if (served.isEmpty) {
      return _buildNetworkState(
        ward: ward,
        child: Center(
          child: SelahEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No suitable families right now',
            message:
                'Nothing currently fits this Seeker\'s requirements and availability. SELAH keeps looking without widening their choices.',
          ),
        ),
      );
    }

    return _buildNetworkFamilyList(
      ward: ward,
      families: served,
      mode: _NetworkCardMode.browser,
      cardBuilder: (family) => _NetworkFamilyCard(
        family: family,
        mode: _NetworkCardMode.browser,
        isMainMentor: ctx.isMainMentor,
        design: ctx.networkCardDesign,
        actionLayout: ctx.networkActionLayout,
        onViewProfile: () {
          ctx.track('card_viewed', family.id);
          showGNProfileSheet(context, family, rung2: false);
        },
        onNext: () {
          ctx.track('family_next', family.id);
          ctx.setStage(ward, family, GNStage.setAside);
          ctx.advance();
        },
        onRequest: () => _showRequestSheet(context, ward, family),
      ),
    );
  }

  Widget _buildRequests(
    BuildContext context, {
    required List<MentorLinkedPerson> wards,
    required MentorLinkedPerson ward,
    required GNNetworkRequestKind kind,
  }) {
    final ctx = GNContext.instance;
    final all = ctx.familiesFor(wards, ward);
    final area = kind == GNNetworkRequestKind.sent
        ? GNNetworkPreviewArea.sent
        : GNNetworkPreviewArea.received;
    final countOverride = ctx.previewCountFor(area);
    final requests = countOverride == null
        ? all.where((family) {
            final stage = ctx.stageOf(ward, family);
            return kind == GNNetworkRequestKind.sent
                ? stage == GNStage.sent
                : stage == GNStage.incoming;
          }).toList()
        : all.take(countOverride).toList();

    if (!ctx.isMainMentor) {
      return _buildNetworkState(
        ward: ward,
        storageSuffix: kind.name,
        child: Center(
          child: GNQuietNotice(
            icon: Icons.shield_outlined,
            title: 'Handled by the Main Shepherd',
            message:
                'Only the Main Shepherd manages requests for ${ward.firstName}.',
          ),
        ),
      );
    }
    if (requests.isEmpty) {
      return _buildNetworkState(
        ward: ward,
        storageSuffix: kind.name,
        child: Center(
          child: SelahEmptyState(
            icon: kind == GNNetworkRequestKind.sent
                ? Icons.outbox_outlined
                : Icons.mark_email_unread_outlined,
            title: kind == GNNetworkRequestKind.sent
                ? 'No sent requests'
                : 'No received requests',
            message: kind == GNNetworkRequestKind.sent
                ? 'Requests you send for ${ward.firstName} will appear here.'
                : 'Requests another family sends for ${ward.firstName} will appear here.',
          ),
        ),
      );
    }

    final mode = kind == GNNetworkRequestKind.sent
        ? _NetworkCardMode.sent
        : _NetworkCardMode.received;
    final capped = ctx.liveCount(ward, all) >= 3;
    return _buildNetworkFamilyList(
      ward: ward,
      families: requests,
      mode: mode,
      cardBuilder: (family) => _NetworkFamilyCard(
        family: family,
        mode: mode,
        isMainMentor: true,
        connectionCapped: capped,
        design: ctx.networkCardDesign,
        onViewProfile: () {
          ctx.track('card_viewed', family.id);
          showGNProfileSheet(context, family, rung2: false);
        },
        onWithdraw: () {
          ctx.track('request_withdrawn', family.id);
          ctx.setStage(ward, family, GNStage.closed);
        },
        onShepherd: () {
          ctx.track('shepherd_viewed', family.id);
          showGNShepherdSheet(context, family);
        },
        onConnect: () {
          if (capped) return;
          ctx.track('connected', family.id);
          ctx.setStage(ward, family, GNStage.connected);
        },
        onNotForUs: () {
          ctx.track('not_for_us', family.id);
          ctx.setStage(ward, family, GNStage.closed);
        },
      ),
    );
  }

  Widget _buildNetworkState({
    required MentorLinkedPerson ward,
    required Widget child,
    String storageSuffix = 'discover',
  }) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: PageStorageKey('shepherd-network-$storageSuffix-${ward.id}'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 88)
              .clamp(0.0, double.infinity)
              .toDouble(),
        ),
        child: child,
      ),
    ),
  );

  Widget _buildNetworkFamilyList({
    required MentorLinkedPerson ward,
    required List<GNFamily> families,
    required _NetworkCardMode mode,
    required Widget Function(GNFamily family) cardBuilder,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final cardHeight = (constraints.maxHeight - 88)
          .clamp(510.0, 720.0)
          .toDouble();
      return SingleChildScrollView(
        key: PageStorageKey('shepherd-network-${mode.name}-${ward.id}'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < families.length; index++) ...[
              SizedBox(height: cardHeight, child: cardBuilder(families[index])),
              if (index != families.length - 1) const SizedBox(height: 24),
            ],
          ],
        ),
      );
    },
  );

  // ── page-local request surface (Rung 1) ──────────────────────────────────
  void _showRequestSheet(
    BuildContext context,
    MentorLinkedPerson ward,
    GNFamily family,
  ) {
    final ctx = GNContext.instance;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ShepherdRequestPage(
          family: family,
          onSend: () {
            ctx.track('request_sent', family.id);
            ctx.setStage(ward, family, GNStage.sent);
            ctx.advance();
          },
        ),
      ),
    );
  }
}

class _NetworkSeekerDropdown extends StatelessWidget {
  const _NetworkSeekerDropdown({required this.wards, required this.selected});

  final List<MentorLinkedPerson> wards;
  final MentorLinkedPerson selected;

  Future<void> _showPicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final availableHeight =
            (MediaQuery.sizeOf(sheetContext).height * 0.46 - 90)
                .clamp(112.0, 420.0)
                .toDouble();
        final listHeight = (wards.length * 80.0)
            .clamp(112.0, availableHeight)
            .toDouble();
        return GNSheetShell(
          title: 'CHOOSE SEEKER',
          child: SizedBox(
            key: const Key('gn-seeker-picker-sheet'),
            height: listHeight,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: wards.length,
              separatorBuilder: (_, index) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final ward = wards[index];
                final isSelected = ward.id == selected.id;
                return Material(
                  color: isSelected
                      ? gnGold.withValues(alpha: 0.12)
                      : SelahColors.surfaceFill,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    key: Key('gn-seeker-dropdown-${ward.id}'),
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => Navigator.of(sheetContext).pop(ward.id),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? gnGold.withValues(alpha: 0.42)
                              : SelahColors.surfaceBorder,
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SelahColors.iconButtonBg,
                              border: Border.all(
                                color: isSelected
                                    ? gnGold.withValues(alpha: 0.55)
                                    : SelahColors.iconButtonBorder,
                              ),
                            ),
                            child: Text(
                              ward.firstName.isEmpty
                                  ? '?'
                                  : ward.firstName.characters.first,
                              style: SelahText.body(
                                size: 13,
                                color: SelahColors.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(child: GNSeekerPickerIdentity(person: ward)),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              size: 19,
                              color: gnGold,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (chosen != null) GNContext.instance.selectSeeker(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('gn-seeker-dropdown'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPicker(context),
      child: Container(
        key: const Key('gn-seeker-header-control'),
        padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.firstName,
              style: SelahText.body(size: 14.5, color: SelahColors.foreground),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: SelahColors.foregroundSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShepherdRequestPage extends StatefulWidget {
  const _ShepherdRequestPage({required this.family, required this.onSend});

  final GNFamily family;
  final VoidCallback onSend;

  @override
  State<_ShepherdRequestPage> createState() => _ShepherdRequestPageState();
}

class _ShepherdRequestPageState extends State<_ShepherdRequestPage> {
  static const double _dismissVelocity = 650;

  double _dismissOffset = 0;
  bool _dragging = false;

  void _updateDismiss(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _dismissOffset = (_dismissOffset + details.delta.dy)
          .clamp(0.0, double.infinity)
          .toDouble();
    });
  }

  void _endDismiss(DragEndDetails details, double height) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dismissOffset >= height * 0.14 || velocity >= _dismissVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dismissOffset = 0;
    });
  }

  void _cancelDismiss() {
    setState(() {
      _dragging = false;
      _dismissOffset = 0;
    });
  }

  void _sendRequest() {
    widget.onSend();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dismissing the request page reveals the same live canvas family,
      // never an unrelated black strip behind the moving surface.
      backgroundColor: SelahColors.brandGradient.colors.last,
      body: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: const Key('gn-request-page-swipe-surface'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _updateDismiss,
          onVerticalDragEnd: (details) =>
              _endDismiss(details, constraints.maxHeight),
          onVerticalDragCancel: _cancelDismiss,
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _dismissOffset, 0),
            decoration: SelahAppGoldDecoration(
              gradient: SelahColors.genderGradient(AppState.instance.gender),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 62,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('gn-request-page-close'),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              size: 25,
                              color: SelahColors.foreground,
                            ),
                          ),
                        ),
                        Text(
                          'Speak to Shepherd',
                          style: SelahText.heading(size: 18),
                        ),
                        Positioned(
                          top: 7,
                          child: Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              color: SelahColors.foreground.withValues(
                                alpha: 0.42,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: gnGold.withValues(alpha: 0.10),
                              border: Border.all(
                                color: gnGold.withValues(alpha: 0.38),
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              size: 34,
                              color: gnGold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.family.shepherdLabel,
                            textAlign: TextAlign.center,
                            style: SelahText.heading(size: 21),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Send a request to their Main Shepherd?',
                            textAlign: TextAlign.center,
                            style: SelahText.body(
                              size: 14,
                              color: SelahColors.foregroundSecondary,
                            ),
                          ),
                          const Spacer(flex: 3),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              key: const Key('gn-request-page-send'),
                              onPressed: _sendRequest,
                              child: Text(
                                'Send request',
                                style: SelahText.button(size: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Not yet',
                              style: SelahText.subtext(
                                size: 12,
                                color: SelahColors.foregroundMuted,
                              ),
                            ),
                          ),
                        ],
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

/// Privacy-safe Shepherd Network access matrix. This widget receives already
/// resolved link/entitlement truth and never performs either lookup itself,
/// which keeps the four product states deterministic and widget-testable.
class ShepherdNetworkAccessView extends StatelessWidget {
  final bool hasEntitlement;
  final bool hasLinkedSeeker;
  final VoidCallback onLinkSeeker;
  final VoidCallback onMembership;

  const ShepherdNetworkAccessView({
    super.key,
    required this.hasEntitlement,
    required this.hasLinkedSeeker,
    required this.onLinkSeeker,
    required this.onMembership,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('shepherd-network-access-state'),
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 112),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 130)
                .clamp(0, double.infinity)
                .toDouble(),
          ),
          child: Center(child: _content()),
        ),
      ),
    );
  }

  Widget _content() {
    if (!hasEntitlement) {
      return Column(
        key: Key(
          hasLinkedSeeker
              ? 'shepherd-network-basic-linked'
              : 'shepherd-network-basic-unlinked',
        ),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_rounded,
            key: const Key('shepherd-network-content-lock'),
            color: SelahColors.journeyGold,
            size: 32,
          ),
          SizedBox(height: 16),
          Text(
            'Network is part of ${SelahMembershipCatalog.shepherdOneTitle}',
            style: SelahText.heading(size: 22),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 9),
          Text(
            'Shepherd Network is not available in this build. You can view ${SelahMembershipCatalog.shepherdOneTitle} membership details below.',
            style: SelahText.subtext(size: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22),
          _AccessButton(
            label: 'View ${SelahMembershipCatalog.shepherdOneTitle}',
            onTap: onMembership,
            icon: Icons.workspace_premium_outlined,
          ),
        ],
      );
    }

    if (!hasLinkedSeeker) {
      return Column(
        key: const Key('shepherd-network-entitled-unlinked'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StatusPill(label: SelahMembershipCatalog.shepherdOneTitle),
          SizedBox(height: 18),
          Icon(
            Icons.person_add_alt_1_outlined,
            color: SelahColors.ink(0.54),
            size: 32,
          ),
          SizedBox(height: 14),
          Text(
            'Link a Seeker first',
            style: SelahText.heading(size: 21),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 9),
          Text(
            'Your ${SelahMembershipCatalog.shepherdOneTitle} access is active. Link the Seeker you support. Shepherd Network is not available in this build.',
            style: SelahText.subtext(size: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22),
          _AccessButton(label: 'Link a Seeker', onTap: onLinkSeeker),
        ],
      );
    }

    if (hasEntitlement) {
      return Column(
        key: const Key('shepherd-network-entitled-linked-unavailable'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StatusPill(label: SelahMembershipCatalog.shepherdOneTitle),
          SizedBox(height: 18),
          Icon(
            Icons.hourglass_top_rounded,
            color: SelahColors.ink(0.54),
            size: 30,
          ),
          SizedBox(height: 14),
          Text(
            'Shepherd Network is not available yet',
            style: SelahText.heading(size: 20),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 9),
          Text(
            'Your access remains active. We will let you know when trusted family discovery is ready here.',
            style: SelahText.subtext(size: 13),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    throw StateError('Unreachable Shepherd Network access state');
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: SelahColors.accentBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: SelahColors.accentBorder),
    ),
    child: Text(label, style: SelahText.chapterLabel(color: gnGold)),
  );
}

class _AccessButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const _AccessButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
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
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: SelahColors.journeyGold),
                  const SizedBox(width: 8),
                ],
                Text(label, style: SelahText.button(size: 13)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── One visual card system across Browser, Sent and Received ────────────────

enum _NetworkCardMode { browser, sent, received }

class _NetworkFamilyCard extends StatelessWidget {
  const _NetworkFamilyCard({
    required this.family,
    required this.mode,
    required this.isMainMentor,
    required this.design,
    required this.onViewProfile,
    this.actionLayout = GNNetworkActionLayout.current,
    this.connectionCapped = false,
    this.onNext,
    this.onRequest,
    this.onWithdraw,
    this.onShepherd,
    this.onConnect,
    this.onNotForUs,
  });
  final GNFamily family;
  final _NetworkCardMode mode;
  final bool isMainMentor;
  final GNNetworkCardDesign design;
  final GNNetworkActionLayout actionLayout;
  final bool connectionCapped;
  final VoidCallback onViewProfile;
  final VoidCallback? onNext;
  final VoidCallback? onRequest;
  final VoidCallback? onWithdraw;
  final VoidCallback? onShepherd;
  final VoidCallback? onConnect;
  final VoidCallback? onNotForUs;

  @override
  Widget build(BuildContext context) => Container(
    key: Key(switch (mode) {
      _NetworkCardMode.browser => 'gn-served-${family.id}',
      _NetworkCardMode.sent => 'gn-sent-${family.id}',
      _NetworkCardMode.received => 'gn-incoming-${family.id}',
    }),
    child: switch (design) {
      GNNetworkCardDesign.openCanvas => _openCanvas(),
      GNNetworkCardDesign.cinematic => _cinematic(),
      GNNetworkCardDesign.editorial => _editorial(),
      GNNetworkCardDesign.portraitFocus => _portraitFocus(),
      GNNetworkCardDesign.actionRail => _actionRail(),
    },
  );

  Widget _openCanvas() => Column(
    key: const Key('gn-card-design-openCanvas'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Semantics(
          button: true,
          label: 'View ${family.display} profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewProfile,
            child: _NetworkFamilyPortrait(family: family),
          ),
        ),
      ),
      const SizedBox(height: 13),
      _shepherdLine(),
      if (mode != _NetworkCardMode.browser) ...[
        const SizedBox(height: 8),
        _requestContext(),
      ],
      const SizedBox(height: 13),
      _actionArea(gap: 8),
    ],
  );

  Widget _cinematic() => ClipRRect(
    key: const Key('gn-card-design-cinematic'),
    borderRadius: BorderRadius.circular(28),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          button: true,
          label: 'View ${family.display} profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewProfile,
            child: _NetworkFamilyPortrait(family: family, detailsBottom: 178),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
            decoration: BoxDecoration(
              color: SelahColors.luxuryDarkPurple.withValues(alpha: 181 / 255),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shepherdLine(),
                if (mode != _NetworkCardMode.browser) ...[
                  const SizedBox(height: 7),
                  _requestContext(compact: true),
                ],
                const SizedBox(height: 10),
                _actionArea(gap: 5, compact: true),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _editorial() => Column(
    key: const Key('gn-card-design-editorial'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(family.display, style: SelahText.heading(size: 25)),
                const SizedBox(height: 2),
                Text(family.region, style: SelahText.subtext(size: 11.75)),
              ],
            ),
          ),
          const GNVerifiedBadge(),
        ],
      ),
      const SizedBox(height: 11),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onViewProfile,
          child: _NetworkFamilyPortrait(family: family, showIdentity: false),
        ),
      ),
      const SizedBox(height: 11),
      _shepherdLine(showVerified: false),
      if (mode != _NetworkCardMode.browser) ...[
        const SizedBox(height: 8),
        _requestContext(),
      ],
      const SizedBox(height: 12),
      _actionArea(),
    ],
  );

  Widget _portraitFocus() => Column(
    key: const Key('gn-card-design-portraitFocus'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewProfile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(42),
              child: _NetworkFamilyPortrait(
                family: family,
                showIdentity: false,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        family.display,
        textAlign: TextAlign.center,
        style: SelahText.heading(size: 25),
      ),
      const SizedBox(height: 2),
      Text(
        family.region,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 11.75),
      ),
      const SizedBox(height: 11),
      _shepherdLine(centered: true),
      if (mode != _NetworkCardMode.browser) ...[
        const SizedBox(height: 8),
        _requestContext(centered: true),
      ],
      const SizedBox(height: 12),
      _actionArea(),
    ],
  );

  Widget _actionRail() => Column(
    key: const Key('gn-card-design-actionRail'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onViewProfile,
          child: _NetworkFamilyPortrait(family: family),
        ),
      ),
      const SizedBox(height: 12),
      _shepherdLine(),
      if (mode != _NetworkCardMode.browser) ...[
        const SizedBox(height: 8),
        _requestContext(),
      ],
      const SizedBox(height: 12),
      _actionArea(),
    ],
  );

  Widget _shepherdLine({bool showVerified = true, bool centered = false}) {
    final content = <Widget>[
      Icon(
        Icons.shield_outlined,
        size: 19,
        color: gnGold.withValues(alpha: 0.88),
      ),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          family.shepherdLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SelahText.body(size: 13.25),
        ),
      ),
      if (showVerified) ...[const SizedBox(width: 8), const GNVerifiedBadge()],
    ];
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: content,
    );
  }

  Widget _requestContext({bool compact = false, bool centered = false}) {
    final sent = mode == _NetworkCardMode.sent;
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(
          sent ? Icons.schedule_outlined : Icons.mark_email_unread_outlined,
          size: compact ? 14 : 16,
          color: gnGold.withValues(alpha: 0.82),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            sent
                ? 'Request sent · Awaiting their Main Shepherd'
                : 'Request received · Their Main Shepherd is waiting',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SelahText.subtext(size: compact ? 9.5 : 10.5),
          ),
        ),
      ],
    );
  }

  // Layout comparisons apply only to Browser. Sent and Received keep their
  // request actions and their existing order; Next still sets a family aside.
  Widget _actionArea({double gap = 7, bool compact = false}) {
    if (mode != _NetworkCardMode.browser ||
        actionLayout == GNNetworkActionLayout.current) {
      return Column(
        key: mode == _NetworkCardMode.browser
            ? const Key('gn-browser-actions-current')
            : null,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionPair(),
          SizedBox(height: gap),
          _footerAction(compact: compact),
        ],
      );
    }

    return Column(
      key: Key('gn-browser-actions-${actionLayout.name}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (actionLayout) {
        GNNetworkActionLayout.quietNext => [
          _actionPair(),
          SizedBox(height: gap),
          Align(alignment: Alignment.centerRight, child: _quietNextAction()),
        ],
        GNNetworkActionLayout.speakFirst => [
          SizedBox(height: 44, child: _speakAction()),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: SizedBox(height: 44, child: _profileAction())),
              const SizedBox(width: 8),
              _quietNextAction(),
            ],
          ),
        ],
        GNNetworkActionLayout.profileFirst => [
          SizedBox(height: 44, child: _profileAction()),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: SizedBox(height: 44, child: _speakAction())),
              const SizedBox(width: 8),
              _quietNextAction(),
            ],
          ),
        ],
        GNNetworkActionLayout.current => throw StateError(
          'Current actions are built with the request-compatible layout.',
        ),
      },
    );
  }

  Widget _profileAction() => GNActionPill(
    key: const Key('gn-view-profile-action'),
    label: 'View profile',
    onTap: onViewProfile,
  );

  Widget _speakAction() => GNActionPill(
    key: const Key('gn-speak-action'),
    label: isMainMentor ? 'Speak to Shepherd' : 'Ask Main Shepherd',
    goldAccent: true,
    enabled: isMainMentor,
    onTap: onRequest ?? () {},
  );

  Widget _quietNextAction() => SizedBox(
    width: 88,
    height: 44,
    child: TextButton.icon(
      key: const Key('gn-next-action'),
      onPressed: onNext,
      style: TextButton.styleFrom(
        foregroundColor: SelahColors.foreground.withValues(alpha: 0.72),
        textStyle: SelahText.button(size: 11.5),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      label: const Text('Next'),
      icon: const Icon(Icons.chevron_right_rounded, size: 16),
      iconAlignment: IconAlignment.end,
    ),
  );

  Widget _actionPair() {
    final second = switch (mode) {
      _NetworkCardMode.browser => _speakAction(),
      _NetworkCardMode.sent => GNActionPill(
        key: Key('gn-withdraw-${family.id}'),
        label: 'Withdraw request',
        onTap: onWithdraw ?? () {},
      ),
      _NetworkCardMode.received => GNActionPill(
        key: Key('gn-view-shepherd-${family.id}'),
        label: 'View Shepherd',
        goldAccent: true,
        onTap: onShepherd ?? () {},
      ),
    };
    return Row(
      children: [
        Expanded(
          child: mode == _NetworkCardMode.browser
              ? SizedBox(height: 44, child: _profileAction())
              : _profileAction(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: mode == _NetworkCardMode.browser
              ? SizedBox(height: 44, child: second)
              : second,
        ),
      ],
    );
  }

  Widget _footerAction({bool compact = false}) {
    final height = compact ? 38.0 : 44.0;
    return switch (mode) {
      _NetworkCardMode.browser => SizedBox(
        height: 44,
        child: GNActionPill(
          key: const Key('gn-next-action'),
          label: 'Next',
          borderless: true,
          onTap: onNext ?? () {},
        ),
      ),
      _NetworkCardMode.sent => SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Waiting for their family to respond',
            style: SelahText.subtext(size: compact ? 10 : 11),
          ),
        ),
      ),
      _NetworkCardMode.received => SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: GNActionPill(
                key: Key('gn-not-for-us-${family.id}'),
                label: 'Not for us',
                borderless: true,
                onTap: onNotForUs ?? () {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: GNActionPill(
                key: const Key('gn-connect-family-action'),
                label: connectionCapped ? 'Request limit reached' : 'Connect',
                goldAccent: true,
                enabled: !connectionCapped,
                onTap: onConnect ?? () {},
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _NetworkFamilyPortrait extends StatelessWidget {
  const _NetworkFamilyPortrait({
    required this.family,
    this.showIdentity = true,
    this.detailsBottom = 16,
  });

  final GNFamily family;
  final bool showIdentity;
  final double detailsBottom;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('gn-family-photo'),
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius + 2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SelahProfileImage(family.photoUrl),
          if (family.photoUrl.isEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SelahColors.royalPurple.withValues(alpha: 0.38),
                    SelahColors.luxuryDarkPurple.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  family.initial,
                  style: SelahText.heading(
                    size: 82,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  SelahColors.luxuryDarkPurple.withValues(alpha: 217 / 255),
                ],
                stops: [0.45, 1],
              ),
            ),
          ),
          if (showIdentity)
            Positioned(
              left: 18,
              right: 18,
              bottom: detailsBottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.display,
                    style: SelahText.heading(size: 27, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    family.region,
                    style: SelahText.subtext(
                      size: 12.5,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CapReachedCard extends StatelessWidget {
  const _CapReachedCard({required this.live});
  final int live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        border: Border.all(
          color: Color.alphaBlend(
            gnGold.withValues(alpha: 0.34),
            SelahColors.surfaceBorder,
          ),
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_top_outlined,
            size: 26,
            color: SelahColors.ink(0.54),
          ),
          SizedBox(height: 8),
          Text('$live of 3 live processes', style: SelahText.heading(size: 16)),
          SizedBox(height: 5),
          Text(
            'Each family deserves proper attention. Close or complete one of your live processes before starting another — the cap is the same on every plan.',
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 11.5),
          ),
          SizedBox(height: 10),
          Text(
            'Manage them from your Dashboard — everything about your Seekers lives there.',
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 10.5, color: gnGold),
          ),
        ],
      ),
    );
  }
}
