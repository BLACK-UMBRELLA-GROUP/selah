import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/selah_membership_catalog.dart';
import '../../data/selah_reference_data.dart';
import '../../data/selah_shepherd_capacity.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../dev/selah_dev_personal_code_fixtures.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../models/selah_initial_signup_draft.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_product_telemetry.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_interaction_style.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_shepherd_capacity_notice.dart';
import '../../widgets/selah_glass_dialog.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import 'accept_mentor_invite_screen.dart';
import 'mentor_home_shell.dart';

/// One role-neutral surface for the Founder-approved permanent SELAH Code.
///
/// The code is only a discovery handle. Every successful entry creates a
/// request and the owner must accept it before a Shepherd link exists.
class SelahCodeScreen extends StatefulWidget {
  final bool asShepherd;
  final VoidCallback? onLinked;

  /// Read-only dependencies for ordinary caller lifetime tests. Production
  /// routes omit them and keep the authenticated service readiness boundary.
  final Future<SelahSourceResult<SelahPersonalCode>> Function({
    String? roleContext,
  })?
  loadPersonalCode;
  final Future<SelahSourceResult<List<SelahShepherdLinkRequest>>> Function()?
  loadShepherdRequests;

  /// Bounded first-use rehearsal: fictional code and local information only.
  /// Keep the requested mode isolated even when developer access is revoked.
  final bool signupPreview;
  final SelahInitialSignupDraft? signupPreviewIdentity;

  const SelahCodeScreen({
    super.key,
    required this.asShepherd,
    this.onLinked,
    this.loadPersonalCode,
    this.loadShepherdRequests,
    this.signupPreview = false,
    this.signupPreviewIdentity,
  });

  @override
  State<SelahCodeScreen> createState() => _SelahCodeScreenState();
}

class _SelahCodeScreenState extends State<SelahCodeScreen> {
  SelahPersonalCode? _code;
  List<SelahShepherdLinkRequest> _requests = const [];
  bool _loading = true;
  bool _available = true;
  bool _showQr = false;
  bool _copied = false;
  bool _copyPulseActive = false;
  int _copyPulseRevision = 0;
  bool _shareSelected = false;
  bool _showEnterCode = false;
  String? _initialEnteredCode;
  Timer? _copyPulseTimer;
  Timer? _shareResetTimer;
  Timer? _entryRevealTimer;
  final GlobalKey _entryRevealKey = GlobalKey();
  final GlobalKey _entryActionRevealKey = GlobalKey();
  final ScrollController _screenScrollController = ScrollController();
  String? _error;
  String? _busyRequest;
  int _readRevision = 0;
  String? _rowsOwnerId;
  int _rowsOwnerGeneration = -1;
  bool _requestMutationInFlight = false;
  String? _signupPreviewNotice;
  bool _enteringShepherdPreview = false;

  String get _other => widget.asShepherd ? 'Seeker' : 'Shepherd';
  bool get _signupPreviewAllowed =>
      mounted && SelahDeveloperAccess.canUseDeveloperTools;
  bool get _isFounderDemoPreview =>
      widget.signupPreview ||
      SelahInternalPreviewClient.isActive &&
          SelahDeveloperAccess.isMainAppFounderPreview;

  @override
  void initState() {
    super.initState();
    if (widget.signupPreview) {
      SelahDeveloperAccess.authorizationChanges.addListener(
        _signupAuthorizationChanged,
      );
    } else {
      SelahMentorLinkService.invitationRevision.addListener(_reload);
    }
    _load();
  }

  @override
  void dispose() {
    if (widget.signupPreview) {
      SelahDeveloperAccess.authorizationChanges.removeListener(
        _signupAuthorizationChanged,
      );
    } else {
      SelahMentorLinkService.invitationRevision.removeListener(_reload);
    }
    _copyPulseTimer?.cancel();
    _shareResetTimer?.cancel();
    _entryRevealTimer?.cancel();
    _screenScrollController.dispose();
    super.dispose();
  }

  void _reload() => _load(keepRows: true);

  void _signupAuthorizationChanged() {
    if (!mounted) return;
    if (_signupPreviewAllowed) {
      _load();
    } else {
      setState(() {
        _code = null;
        _requests = const [];
        _showQr = false;
        _signupPreviewNotice = null;
      });
    }
  }

  void _signupInformation(String message) {
    if (!_signupPreviewAllowed) return;
    setState(() => _signupPreviewNotice = message);
  }

  bool get _canEnterShepherdPreview {
    final draft = widget.signupPreviewIdentity;
    return widget.signupPreview &&
        widget.asShepherd &&
        _signupPreviewAllowed &&
        SelahDeveloperAccess.isMainAppPreview &&
        SelahInternalPreviewClient.isActive &&
        draft != null &&
        draft.role == SelahSignupRole.shepherd &&
        draft.awaitsVerification &&
        draft.isValid();
  }

  void _enterShepherdPreview() {
    if (_enteringShepherdPreview || !_canEnterShepherdPreview) return;
    final draft = widget.signupPreviewIdentity!;
    final navigator = Navigator.of(context);
    _enteringShepherdPreview = true;

    // A first-use Shepherd has no linked Seekers. Simulate the chosen local
    // membership only; no real joining payment or subscription is completed.
    // Reset only the local, network-denied sample; no account or link is
    // created and no persistent member data is written.
    SelahDevScenario.instance.reset();
    AppState.instance.applyDevPreset(
      name: draft.firstName,
      gender: draft.gender,
      dob: draft.dob,
      mentorName: draft.firstName,
      mentorRelationship: draft.relationship,
    );
    final choice = draft.membershipChoice;
    if (choice != null &&
        !SelahDevLocalPreview.applySignupMembershipPreview(
          role: draft.role,
          choice: choice,
        )) {
      _enteringShepherdPreview = false;
      return;
    }
    SelahPromotionEngine.instance.setDeveloperShepherdNetworkState(
      AppState.instance.mentorHasMentorOne
          ? SelahDeveloperShepherdNetworkState.unlinkedEntitled
          : SelahDeveloperShepherdNetworkState.unlinkedBasic,
    );
    SelahDevSurfaceCoordinator.instance.endEntryFlow();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) => const MentorHomeShell(initialOnboardingPreview: true),
      ),
      (_) => false,
    );
  }

  Future<void> _load({bool keepRows = false}) async {
    // Raw requested mode comes before all live readers, even without a latch.
    if (!mounted || widget.signupPreview && !_signupPreviewAllowed) return;
    final readRevision = ++_readRevision;
    if (!keepRows) setState(() => _loading = true);
    if (_isFounderDemoPreview) {
      final nextCode = SelahDevPersonalCodeFixtures.forPersona(
        asShepherd: widget.asShepherd,
        gender: AppState.instance.gender,
      );
      setState(() {
        if (_code?.code != null && _code!.code != nextCode.code) {
          _copyPulseTimer?.cancel();
          _copied = false;
          _copyPulseActive = false;
        }
        _code = nextCode;
        _requests = const [];
        _loading = false;
        _available = true;
        _error = null;
      });
      return;
    }
    final ownerId = _currentMemberId();
    final generation = SelahAccountState.generation;
    final results = await Future.wait<Object>([
      (widget.loadPersonalCode ?? SelahMentorLinkService.personalCode)(
        roleContext: widget.asShepherd ? 'mentor' : 'seeker',
      ),
      (widget.loadShepherdRequests ??
          SelahMentorLinkService.shepherdLinkRequests)(),
    ]);
    if (readRevision != _readRevision ||
        _isFounderDemoPreview ||
        !_isCurrentAccount(ownerId, generation)) {
      return;
    }
    final codeResult = results[0] as SelahSourceResult<SelahPersonalCode>;
    final requestResult =
        results[1] as SelahSourceResult<List<SelahShepherdLinkRequest>>;
    setState(() {
      _loading = false;
      _available = codeResult.isAvailable && requestResult.isAvailable;
      if (codeResult.valueOrNull case final value?) {
        if (_code?.code != null && _code!.code != value.code) {
          _copyPulseTimer?.cancel();
          _copied = false;
          _copyPulseActive = false;
        }
        _code = value;
      }
      if (requestResult.valueOrNull case final value?) {
        _requests = value;
        _rowsOwnerId = ownerId;
        _rowsOwnerGeneration = generation;
      }
    });
  }

  String? _currentMemberId() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      // Preserve the existing unavailable-reader presentation before Auth
      // initialization; absence never authorizes a request mutation.
      return null;
    }
  }

  bool _isCurrentAccount(String? ownerId, int generation) =>
      mounted &&
      !SelahAccountState.isSigningOut &&
      SelahAccountState.generation == generation &&
      _currentMemberId() == ownerId &&
      (ownerId == null
          ? SelahAccountState.userId == null
          : SelahAccountState.isCurrent(ownerId, generation));

  bool _isCurrentRequestAction(String ownerId, int generation) =>
      !_isFounderDemoPreview &&
      _isCurrentAccount(ownerId, generation) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  ({String ownerId, int generation})? _beginRequestAction(
    SelahShepherdLinkRequest request,
  ) {
    final ownerId = _rowsOwnerId;
    final generation = _rowsOwnerGeneration;
    if (_requestMutationInFlight ||
        ownerId == null ||
        !_isCurrentRequestAction(ownerId, generation) ||
        !_requests.any((row) => row.id == request.id && row.isPending)) {
      return null;
    }
    // Claim the one local action before a relationship sheet or service await.
    _requestMutationInFlight = true;
    return (ownerId: ownerId, generation: generation);
  }

  void _finishRequestAction() {
    _requestMutationInFlight = false;
    if (mounted && _busyRequest != null) {
      setState(() => _busyRequest = null);
    }
  }

  Future<void> _copy() async {
    if (widget.signupPreview) {
      _signupInformation(
        'Preview only. In the app, Copy puts your personal code on the '
        'clipboard. Nothing was copied here.',
      );
      return;
    }
    final code = _code?.code;
    if (code == null) return;
    await SelahInteractionStyle.emitSelectionHaptic();
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _copyPulseTimer?.cancel();
    setState(() {
      _copied = true;
      _copyPulseActive = true;
      _copyPulseRevision += 1;
    });
    _copyPulseTimer = Timer(const Duration(milliseconds: 240), () {
      if (mounted) setState(() => _copyPulseActive = false);
    });
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (widget.signupPreview) {
      _signupInformation(
        'Preview only. In the app, Share lets you send your personal code '
        'to someone you know. No sharing sheet opens here.',
      );
      return;
    }
    final code = _code?.code;
    if (code == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await SelahInteractionStyle.emitSelectionHaptic();
    if (!mounted) return;
    setState(() => _shareSelected = true);
    _shareResetTimer?.cancel();
    _shareResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _shareSelected = false);
    });
    await SharePlus.instance.share(
      ShareParams(
        text: _isFounderDemoPreview
            ? 'SELAH Developer Preview code:\n$code\n\n'
                  'This sample code cannot connect real accounts.'
            : 'Use my SELAH Code to send me a Shepherd request:\n$code\n\n'
                  'I will still need to approve the request in SELAH.',
        subject: 'My SELAH Code',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _rotate() async {
    if (widget.signupPreview) {
      _signupInformation('Preview only. No personal code was changed.');
      return;
    }
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.refresh_rounded,
      title: 'Change your SELAH Code?',
      body:
          'Your current code will stop working and will never be issued again. '
          'Requests already sent will stay visible.',
      primaryLabel: 'Change code',
      secondaryLabel: 'Keep code',
    );
    if (confirmed != true || !mounted) return;
    final result = await SelahMentorLinkService.rotatePersonalCode(
      roleContext: widget.asShepherd ? 'mentor' : 'seeker',
    );
    if (!mounted) return;
    setState(() {
      if (result.valueOrNull case final code?) {
        _copyPulseTimer?.cancel();
        _code = code;
        _showQr = false;
        _copied = false;
        _copyPulseActive = false;
        _error = null;
      } else {
        _error = "Your code couldn't be changed. Please try again.";
      }
    });
  }

  void _enterCode([String? initialCode]) {
    if (widget.signupPreview) {
      _signupInformation(
        'Preview only. In the app, enter the other person\'s SELAH Code, '
        'confirm who they are, then send a request. A link is created only '
        'after they accept. No code is checked or request sent here.',
      );
      return;
    }
    final opening = initialCode != null || !_showEnterCode;
    setState(() {
      _initialEnteredCode = initialCode;
      _showEnterCode = opening;
      if (opening) _showQr = false;
    });
    if (opening) _revealCodeEntry();
  }

  void _revealCodeEntry() {
    void reveal() {
      if (_screenScrollController.hasClients) {
        _screenScrollController.animateTo(
          _screenScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      final entryContext =
          _entryActionRevealKey.currentContext ??
          _entryRevealKey.currentContext;
      if (!mounted || entryContext == null) return;
      Scrollable.ensureVisible(
        entryContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.84,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      reveal();
      _entryRevealTimer?.cancel();
      _entryRevealTimer = Timer(const Duration(milliseconds: 380), reveal);
    });
  }

  Future<void> _scan() async {
    if (widget.signupPreview) {
      _signupInformation(
        'Preview only. Scanning uses the camera after you choose to scan '
        'a code in the app. This preview never opens the camera or asks '
        'for access.',
      );
      return;
    }
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScanSelahCodeScreen()),
    );
    if (code != null && mounted) _enterCode(code);
  }

  Future<void> _accept(SelahShepherdLinkRequest request) async {
    if (widget.signupPreview) {
      _signupInformation('Preview only. No Shepherd link was created.');
      return;
    }
    final owner = _beginRequestAction(request);
    if (owner == null) return;
    try {
      String? relationship;
      // The current user is the Shepherd when the requester is a Seeker.
      if (request.otherRole == 'seeker') {
        relationship = await _chooseRelationship();
        if (relationship == null) return;
      }
      if (!_isCurrentRequestAction(owner.ownerId, owner.generation)) return;
      setState(() {
        _busyRequest = request.id;
        _error = null;
      });
      final error = await SelahMentorLinkService.acceptShepherdLinkRequest(
        request.id,
        relationship: relationship,
        currentSeekerPlan: request.otherRole == 'seeker'
            ? null
            : AppState.instance.plan,
      );
      if (!mounted ||
          !_isCurrentRequestAction(owner.ownerId, owner.generation)) {
        return;
      }
      setState(() => _error = error);
      showSelahShepherdCapacityNotice(context, error);
      if (error == null) {
        widget.onLinked?.call();
        if (_isCurrentRequestAction(owner.ownerId, owner.generation)) {
          _load(keepRows: true);
        }
      }
    } finally {
      _finishRequestAction();
    }
  }

  Future<String?> _chooseRelationship() => showModalBottomSheet<String>(
    context: context,
    backgroundColor: SelahColors.mentorSheetBg,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you related?', style: SelahText.heading(size: 19)),
            const SizedBox(height: 12),
            for (final relationship in selahShepherdRelationships)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(relationship.name, style: SelahText.body(size: 14)),
                onTap: () => Navigator.of(sheetContext).pop(relationship.code),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _decline(SelahShepherdLinkRequest request) async {
    if (widget.signupPreview) {
      _signupInformation('Preview only. No request was declined.');
      return;
    }
    final owner = _beginRequestAction(request);
    if (owner == null) return;
    setState(() => _busyRequest = request.id);
    try {
      if (!_isCurrentRequestAction(owner.ownerId, owner.generation)) return;
      final ok = await SelahMentorLinkService.declineShepherdLinkRequest(
        request.id,
      );
      if (!_isCurrentRequestAction(owner.ownerId, owner.generation)) return;
      setState(() {
        if (!ok) _error = "That request couldn't be declined.";
      });
      if (ok) _load(keepRows: true);
    } finally {
      _finishRequestAction();
    }
  }

  Future<void> _cancel(SelahShepherdLinkRequest request) async {
    if (widget.signupPreview) {
      _signupInformation('Preview only. No request was cancelled.');
      return;
    }
    final owner = _beginRequestAction(request);
    if (owner == null) return;
    setState(() => _busyRequest = request.id);
    try {
      if (!_isCurrentRequestAction(owner.ownerId, owner.generation)) return;
      final ok = await SelahMentorLinkService.cancelShepherdLinkRequest(
        request.id,
      );
      if (!_isCurrentRequestAction(owner.ownerId, owner.generation)) return;
      setState(() {
        if (!ok) _error = "That request couldn't be cancelled.";
      });
      if (ok) _load(keepRows: true);
    } finally {
      _finishRequestAction();
    }
  }

  bool get _canUseExpandedComposition =>
      _code != null &&
      _available &&
      !_requests.any((request) => request.isPending) &&
      _error == null;

  Future<void> _toggleQr() async {
    if (widget.signupPreview) {
      if (!_signupPreviewAllowed) return;
      setState(() => _showQr = !_showQr);
      return;
    }
    await SelahInteractionStyle.emitSelectionHaptic();
    if (!mounted) return;
    setState(() => _showQr = !_showQr);
  }

  Widget _buildSharingActions({double height = 54}) {
    return Row(
      children: [
        Expanded(
          child: _SmallAction(
            icon: _copied ? Icons.check_rounded : Icons.copy_outlined,
            label: _copied ? 'Copied' : 'Copy',
            height: height,
            selected: _copied,
            pulse: _copyPulseActive,
            pulseRevision: _copyPulseRevision,
            onTap: _copy,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _SmallAction(
            icon: Icons.qr_code_2,
            label: 'QR',
            height: height,
            selected: _showQr,
            onTap: _toggleQr,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Builder(
            builder: (buttonContext) => _SmallAction(
              icon: Icons.ios_share_outlined,
              label: 'Share',
              height: height,
              selected: _shareSelected,
              onTap: () => _share(buttonContext),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedComposition() {
    final code = _code!;
    return SingleChildScrollView(
      controller: _screenScrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 310,
            child: _CodeCard(
              code: code.code,
              demoOnly: _isFounderDemoPreview,
              prominent: true,
              showQr: _showQr,
            ),
          ),
          const SizedBox(height: 14),
          _buildSharingActions(height: 64),
          if (!_isFounderDemoPreview)
            SizedBox(
              height: 38,
              child: TextButton(
                onPressed: _rotate,
                child: Text('Change code', style: SelahText.subtext(size: 12)),
              ),
            ),
          const SizedBox(height: 18),
          const _OrDivider(),
          const SizedBox(height: 18),
          _LargeAction(
            icon: Icons.qr_code_scanner,
            label: 'Scan code',
            onTap: _scan,
          ),
          const SizedBox(height: 12),
          _buildEnterCodeAction(),
        ],
      ),
    );
  }

  Widget _buildOwnCodeSection() {
    final code = _code;
    if (code == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CodeCard(code: code.code, demoOnly: _isFounderDemoPreview),
        const SizedBox(height: 14),
        _buildSharingActions(),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          crossFadeState: _showQr
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: code.code,
                  size: 190,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        if (!_isFounderDemoPreview)
          TextButton(
            onPressed: _rotate,
            child: Text('Change code', style: SelahText.subtext(size: 12)),
          ),
      ],
    );
  }

  Widget _buildOtherCodeActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LargeAction(
          icon: Icons.qr_code_scanner,
          label: 'Scan code',
          onTap: _scan,
        ),
        const SizedBox(height: 12),
        _buildEnterCodeAction(),
        if (_requests.any((r) => r.isPending)) ...[
          const SizedBox(height: 30),
          Text(
            'REQUESTS',
            style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
          ),
          const SizedBox(height: 10),
          for (final request in _requests.where((r) => r.isPending))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(
                request: request,
                busy: _busyRequest == request.id,
                onAccept: () => _accept(request),
                onDecline: () => _decline(request),
                onCancel: () => _cancel(request),
              ),
            ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          SelahErrorBanner(
            message: error,
            onDismiss: () => setState(() => _error = null),
          ),
        ],
      ],
    );
  }

  Widget _buildEnterCodeAction() => Material(
    color: SelahColors.surfaceFill,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _showEnterCode
              ? SelahColors.accentBorder
              : SelahColors.surfaceBorder,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _enterCode,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.keyboard_outlined,
                      size: 21,
                      color: SelahColors.surfaceSignal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Enter code', style: SelahText.body(size: 14)),
                    ),
                    AnimatedRotation(
                      turns: _showEnterCode ? 0.25 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right,
                        size: 19,
                        color: SelahColors.ink(0.48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showEnterCode
                ? Column(
                    children: [
                      Divider(height: 1, color: SelahColors.surfaceBorder),
                      Padding(
                        key: _entryRevealKey,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        child: _InlineEnterSelahCodePanel(
                          key: ValueKey(
                            _initialEnteredCode ?? 'blank-code-entry',
                          ),
                          initialCode: _initialEnteredCode,
                          asShepherd: widget.asShepherd,
                          developerPreview: _isFounderDemoPreview,
                          primaryActionKey: _entryActionRevealKey,
                          onNeedsReveal: _revealCodeEntry,
                          onSent: () {
                            setState(() {
                              _showEnterCode = false;
                              _initialEnteredCode = null;
                            });
                            _load(keepRows: true);
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    ),
  );

  /// The bounded signup rehearsal does not reuse the request composer: its
  /// existing Founder demo can simulate a sent request, which would be a false
  /// success in a first-use visual preview. These actions explain themselves
  /// locally, without platform calls, live readers, or fabricated links.
  Widget _buildSignupPreview() {
    final previewStyle = OnboardingPreviewStyle.maybeOf(context);
    return SingleChildScrollView(
      key: const ValueKey('signup_code_preview'),
      controller: _screenScrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_canEnterShepherdPreview) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('onboarding_dev_skip'),
                onPressed: _enterShepherdPreview,
                icon: const Icon(Icons.skip_next_rounded, size: 17),
                label: Text(
                  'Skip to Shepherd · DEV',
                  style: SelahText.subtext(size: 11.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (previewStyle != null) ...[
            // This is a code orientation screen, not a counted final step.
            // A full progress rail here implied setup was already complete.
            Align(
              alignment: previewStyle.centered
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: OnboardingPreviewAccent(
                style: previewStyle,
                size: 58,
                progress: 1,
              ),
            ),
            const SizedBox(height: 15),
          ],
          Text(
            'SIGN-UP PREVIEW',
            textAlign: previewStyle?.centered == true
                ? TextAlign.center
                : TextAlign.left,
            style: SelahText.chapterLabel(),
          ),
          const SizedBox(height: 8),
          Text(
            'A personal code, with consent at every step.',
            textAlign: previewStyle?.centered == true
                ? TextAlign.center
                : TextAlign.left,
            style: SelahText.heading(size: previewStyle?.titleSize ?? 22),
          ),
          const SizedBox(height: 10),
          Text(
            'This fictional code shows what comes next. Explore the actions '
            'below; no camera, clipboard, sharing or account actions run here.',
            textAlign: previewStyle?.centered == true
                ? TextAlign.center
                : TextAlign.left,
            style: SelahText.subtext(size: 12.5),
          ),
          const SizedBox(height: 22),
          _CodeCard(
            code: _code!.code,
            demoOnly: true,
            showQr: _showQr,
            previewStyle: previewStyle,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: previewStyle?.centered == true
                ? WrapAlignment.center
                : WrapAlignment.start,
            spacing: 9,
            runSpacing: 9,
            children: [
              _PillAction(
                key: const ValueKey('signup_code_copy'),
                enableFeedback: false,
                icon: Icons.copy_outlined,
                label: 'Copy',
                onTap: _copy,
                previewStyle: previewStyle,
              ),
              _PillAction(
                key: const ValueKey('signup_code_qr'),
                enableFeedback: false,
                icon: Icons.qr_code_2,
                label: _showQr ? 'Hide QR' : 'QR',
                onTap: _toggleQr,
                previewStyle: previewStyle,
              ),
              _PillAction(
                key: const ValueKey('signup_code_share'),
                enableFeedback: false,
                icon: Icons.ios_share_outlined,
                label: 'Share',
                onTap: () => _share(context),
                previewStyle: previewStyle,
              ),
              _PillAction(
                key: const ValueKey('signup_code_scan'),
                enableFeedback: false,
                icon: Icons.qr_code_scanner,
                label: 'Scan code',
                onTap: _scan,
                previewStyle: previewStyle,
              ),
              _PillAction(
                key: const ValueKey('signup_code_enter'),
                enableFeedback: false,
                icon: Icons.keyboard_outlined,
                label: 'Enter code',
                onTap: _enterCode,
                previewStyle: previewStyle,
              ),
            ],
          ),
          if (_signupPreviewNotice case final message?) ...[
            const SizedBox(height: 18),
            Text(
              message,
              key: const ValueKey('signup_code_action_info'),
              style: SelahText.subtext(size: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.signupPreview && !_signupPreviewAllowed) {
      return Scaffold(
        key: const ValueKey('signup_code_preview_denied'),
        backgroundColor: SelahColors.modalSheetSurface,
        body: const SizedBox.expand(),
      );
    }
    final previewStyle = widget.signupPreview
        ? OnboardingPreviewStyle.maybeOf(context)
        : null;
    return Scaffold(
      extendBodyBehindAppBar: !widget.signupPreview,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add a $_other', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ??
              SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: widget.signupPreview
              ? _buildSignupPreview()
              : _loading
              ? const SelahLoading()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_canUseExpandedComposition &&
                        constraints.maxHeight >= 620) {
                      return _buildExpandedComposition();
                    }
                    return SingleChildScrollView(
                      controller: _screenScrollController,
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 44).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOwnCodeSection(),
                              const SizedBox(height: 28),
                              if (!_available) ...[
                                SelahErrorBanner(
                                  message:
                                      "Your SELAH Code couldn't be refreshed.",
                                  onRetry: _load,
                                ),
                                const SizedBox(height: 18),
                              ],
                              const _OrDivider(),
                              const SizedBox(height: 28),
                              _buildOtherCodeActions(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _InlineEnterSelahCodePanel extends StatefulWidget {
  final String? initialCode;
  final bool asShepherd;
  final bool developerPreview;
  final GlobalKey primaryActionKey;
  final VoidCallback onNeedsReveal;
  final VoidCallback onSent;

  const _InlineEnterSelahCodePanel({
    super.key,
    this.initialCode,
    required this.asShepherd,
    required this.developerPreview,
    required this.primaryActionKey,
    required this.onNeedsReveal,
    required this.onSent,
  });

  @override
  State<_InlineEnterSelahCodePanel> createState() =>
      _InlineEnterSelahCodePanelState();
}

class _InlineEnterSelahCodePanelState extends State<_InlineEnterSelahCodePanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  SelahPersonalCodePreview? _preview;
  String? _relationship;
  String? _error;
  bool _busy = false;
  bool _legacyPossible = false;
  bool _sent = false;
  String? _lastInvalidCode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
    _focusNode = FocusNode();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showInvalidCode({required bool legacyPossible}) {
    final invalidCode = _controller.text.trim();
    setState(() {
      _busy = false;
      _preview = null;
      _relationship = null;
      _error = 'Invalid code. Please try again.';
      _legacyPossible = legacyPossible;
      _lastInvalidCode = invalidCode.isEmpty ? null : invalidCode;
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _check() async {
    if (_controller.text.trim().isEmpty) return;
    _recordCodeEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.selahCodeCheck,
    );
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _legacyPossible = false;
      _lastInvalidCode = null;
    });
    if (widget.developerPreview) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      final preview = SelahDevPersonalCodeFixtures.previewEntryCode(
        _controller.text,
        asShepherd: widget.asShepherd,
      );
      if (preview == null) {
        _showInvalidCode(legacyPossible: false);
      } else {
        setState(() {
          _busy = false;
          _preview = preview;
        });
      }
      _recordCodeEvent(
        preview == null
            ? SelahTelemetryEventName.failed
            : SelahTelemetryEventName.completed,
        SelahTelemetryAction.selahCodeCheck,
      );
      if (preview != null) _focusNode.unfocus();
      widget.onNeedsReveal();
      return;
    }
    final result = await SelahMentorLinkService.previewPersonalCode(
      _controller.text,
    );
    if (!mounted) return;
    if (result.isAvailable && result.valueOrNull == null) {
      _showInvalidCode(legacyPossible: true);
    } else {
      setState(() {
        _busy = false;
        if (result.isUnavailable) {
          _error = "The code couldn't be checked. Please try again.";
        } else {
          _preview = result.valueOrNull;
        }
      });
    }
    _recordCodeEvent(
      _preview == null
          ? SelahTelemetryEventName.failed
          : SelahTelemetryEventName.completed,
      SelahTelemetryAction.selahCodeCheck,
    );
    if (_preview != null) _focusNode.unfocus();
    widget.onNeedsReveal();
  }

  Future<void> _send() async {
    final preview = _preview;
    if (preview == null) return;
    if (preview.role == 'seeker' && _relationship == null) {
      setState(() => _error = 'Choose how you are related first.');
      return;
    }
    _recordCodeEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.selahCodeRequest,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    if (widget.developerPreview) {
      if (!widget.asShepherd) {
        final capacity = SelahShepherdCapacity.fromCount(
          plan: AppState.instance.plan,
          linkedShepherdCount: SelahDevScenario.instance.shepherdCount,
        );
        if (!capacity.canAdd) {
          setState(() {
            _busy = false;
            _error = capacity.message;
          });
          showSelahShepherdCapacityNotice(context, capacity.message);
          return;
        }
      }
      await SelahInteractionStyle.emitSelectionHaptic();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      _recordCodeEvent(
        SelahTelemetryEventName.completed,
        SelahTelemetryAction.selahCodeRequest,
      );
      return;
    }
    final error = await SelahMentorLinkService.requestShepherdLink(
      _controller.text,
      relationship: preview.role == 'seeker' ? _relationship : null,
      currentSeekerPlan: widget.asShepherd ? null : AppState.instance.plan,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    showSelahShepherdCapacityNotice(context, error);
    _recordCodeEvent(
      error == null
          ? SelahTelemetryEventName.completed
          : SelahTelemetryEventName.failed,
      SelahTelemetryAction.selahCodeRequest,
    );
    if (error == null) widget.onSent();
  }

  void _recordCodeEvent(
    SelahTelemetryEventName name,
    SelahTelemetryAction action,
  ) {
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.selahCode,
      name: name,
      action: action,
      surface: widget.asShepherd
          ? SelahTelemetrySurface.shepherd
          : SelahTelemetrySurface.seeker,
    );
  }

  void _useDifferentCode() {
    setState(() {
      _preview = null;
      _relationship = null;
      _error = null;
      _legacyPossible = false;
      _lastInvalidCode = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      widget.onNeedsReveal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsRelationship = _preview?.role == 'seeker';
    if (_sent) {
      return Column(
        key: const ValueKey('inline-selah-code-entry'),
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SelahColors.accentBg,
              border: Border.all(color: SelahColors.accentBorder),
            ),
            child: Icon(Icons.check_rounded, color: SelahColors.surfaceSignal),
          ),
          const SizedBox(height: 10),
          Text('Request sent', style: SelahText.heading(size: 16)),
          const SizedBox(height: 4),
          Text(
            '${_preview!.firstName} can now accept or decline it.',
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 12),
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey('inline-selah-code-entry'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_preview == null)
          Container(
            key: const ValueKey('inline-code-composer'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: SelahColors.iconButtonBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SelahColors.iconButtonBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('inline-selah-code-field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.initialCode == null,
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    textCapitalization: TextCapitalization.characters,
                    style: SelahText.body(size: 14),
                    decoration: const InputDecoration(
                      hintText: 'SELAH-XXXX-XXXX-XXXX-XXXX-XXXX',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {
                      _relationship = null;
                      _error = null;
                      _legacyPossible = false;
                      _lastInvalidCode = null;
                    }),
                    onSubmitted: (_) {
                      if (!_busy) _check();
                    },
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: SelahColors.iconButtonBorder,
                ),
                KeyedSubtree(
                  key: widget.primaryActionKey,
                  child: Semantics(
                    button: true,
                    label: _busy ? 'Checking code' : 'Check code',
                    child: Material(
                      key: const ValueKey('inline-code-primary-action'),
                      color: SelahColors.accentBg,
                      child: InkWell(
                        onTap: _busy ? null : _check,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 96,
                            minHeight: 52,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_outlined,
                                  size: 17,
                                  color: SelahColors.surfaceSignal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _busy ? 'Checking…' : 'Check',
                                  style: SelahText.button(
                                    size: 12.5,
                                    color: SelahColors.surfaceSignal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_preview case final preview?) ...[
          Container(
            key: const ValueKey('selah-code-person-confirmation'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SelahColors.iconButtonBg,
              border: Border.all(color: SelahColors.iconButtonBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SelahColors.accentBg,
                    border: Border.all(color: SelahColors.accentBorder),
                  ),
                  child: Center(
                    child: Text(
                      preview.firstName.substring(0, 1).toUpperCase(),
                      style: SelahText.heading(
                        size: 20,
                        color: SelahColors.surfaceSignal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preview.firstName, style: SelahText.body(size: 15)),
                      const SizedBox(height: 2),
                      Text(
                        preview.role == 'mentor' ? 'Shepherd' : 'Seeker',
                        style: SelahText.subtext(size: 11.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.person_outline_rounded,
                  size: 19,
                  color: SelahColors.surfaceSignal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Confirm this is the right person before sending your request.',
            style: SelahText.subtext(size: 11.5),
          ),
          if (needsRelationship) ...[
            const SizedBox(height: 14),
            Text('How are you related?', style: SelahText.body(size: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final relationship in selahShepherdRelationships)
                  ChoiceChip(
                    label: Text(relationship.name),
                    selected: _relationship == relationship.code,
                    onSelected: (_) =>
                        setState(() => _relationship = relationship.code),
                  ),
              ],
            ),
          ],
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          SelahErrorBanner(
            message: error,
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        if (_legacyPossible)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AcceptMentorInviteScreen(
                    initialCode: _lastInvalidCode ?? _controller.text,
                  ),
                ),
              ),
              child: Text(
                'Check an older invite code',
                style: SelahText.subtext(size: 11.5),
              ),
            ),
          ),
        if (_preview != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PillAction(
                  key: const ValueKey('inline-code-different-action'),
                  icon: Icons.refresh_rounded,
                  label: 'Change code',
                  onTap: _busy ? null : _useDifferentCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KeyedSubtree(
                  key: widget.primaryActionKey,
                  child: _PillAction(
                    key: const ValueKey('inline-code-primary-action'),
                    icon: Icons.person_add_alt_1_outlined,
                    label: _busy ? 'Sending…' : 'Confirm',
                    onTap: _busy ? null : _send,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enableFeedback;
  final OnboardingPreviewStyle? previewStyle;

  const _PillAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.enableFeedback = true,
    this.previewStyle,
  });

  Widget _content() => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 17, color: SelahColors.surfaceSignal),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SelahText.body(size: 12.5, color: SelahColors.surfaceSignal),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final style = previewStyle;
    if (style != null) {
      final radius = BorderRadius.circular(style.buttonRadius);
      return Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: style.cardDecoration().copyWith(borderRadius: radius),
          child: InkWell(
            borderRadius: radius,
            enableFeedback: enableFeedback,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
              child: _content(),
            ),
          ),
        ),
      );
    }
    return Material(
      color: SelahColors.accentBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        enableFeedback: enableFeedback,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: SelahColors.accentBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: _content(),
        ),
      ),
    );
  }
}

class _ScanSelahCodeScreen extends StatefulWidget {
  const _ScanSelahCodeScreen();

  @override
  State<_ScanSelahCodeScreen> createState() => _ScanSelahCodeScreenState();
}

class _ScanSelahCodeScreenState extends State<_ScanSelahCodeScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan SELAH Code', style: SelahText.heading(size: 17)),
        backgroundColor: Colors.black,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();
            if (value != null && value.toUpperCase().startsWith('SELAH')) {
              _handled = true;
              Navigator.of(context).pop(value);
              return;
            }
          }
        },
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final bool demoOnly;
  final bool prominent;
  final bool showQr;
  final OnboardingPreviewStyle? previewStyle;
  const _CodeCard({
    required this.code,
    required this.demoOnly,
    this.prominent = false,
    this.showQr = false,
    this.previewStyle,
  });

  Widget _details() => Column(
    key: const ValueKey('selah_code_details'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'YOUR SELAH CODE',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.58)),
      ),
      SizedBox(height: prominent ? 18 : 12),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          code,
          style: SelahText.heading(
            size: prominent ? 24 : 20,
          ).copyWith(letterSpacing: 1.3),
        ),
      ),
      SizedBox(height: prominent ? 14 : 9),
      Text(
        'They can send a request. You still choose whether to link.',
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: prominent ? 13 : 11.5),
      ),
      if (demoOnly) ...[
        SizedBox(height: prominent ? 14 : 10),
        Text(
          'Developer preview only — not stored or accepted by the live service.',
          textAlign: TextAlign.center,
          style: SelahText.subtext(
            size: prominent ? 11.5 : 10.5,
          ).copyWith(color: SelahColors.journeyGold.withValues(alpha: 0.78)),
        ),
      ],
    ],
  );

  Widget _qrPreview() => Column(
    key: const ValueKey('selah_code_qr_preview'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'YOUR SELAH QR CODE',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.58)),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: QrImageView(
          data: code,
          size: prominent ? 184 : 156,
          padding: EdgeInsets.zero,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Tap QR again to return',
        style: SelahText.subtext(size: prominent ? 11.5 : 10.5),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 174),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration:
          previewStyle?.cardDecoration() ??
          BoxDecoration(
            color: SelahColors.surfaceFill,
            border: Border.all(color: SelahColors.surfaceBorder),
            borderRadius: BorderRadius.circular(20),
          ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          reverseDuration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) {
            final entrance = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: entrance,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.965, end: 1).animate(entrance),
                child: child,
              ),
            );
          },
          child: showQr ? _qrPreview() : _details(),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: SelahColors.ink(0.20))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR USE THEIR CODE',
            style: SelahText.chapterLabel(color: SelahColors.ink(0.48)),
          ),
        ),
        Expanded(child: Divider(color: SelahColors.ink(0.20))),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final double height;
  final bool selected;
  final bool pulse;
  final int pulseRevision;
  final VoidCallback? onTap;
  const _SmallAction({
    required this.icon,
    required this.label,
    this.height = 54,
    this.selected = false,
    this.pulse = false,
    this.pulseRevision = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            color: pulse
                ? SelahColors.surfaceSignal.withValues(alpha: 0.22)
                : selected
                ? SelahColors.accentBg
                : SelahColors.iconButtonBg,
            border: Border.all(
              color: pulse
                  ? SelahColors.surfaceSignal
                  : selected
                  ? SelahColors.accentBorder
                  : SelahColors.iconButtonBorder,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: height > 54 ? 19 : 17,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.68,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey('small-action-$label-$pulseRevision'),
                    size: height > 54 ? 19 : 17,
                    color: selected
                        ? SelahColors.surfaceSignal
                        : SelahColors.ink(0.70),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: SelahText.body(
                  size: height > 54 ? 13.5 : 12.5,
                  color: selected ? SelahColors.surfaceSignal : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _LargeAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: SelahColors.surfaceBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: SelahColors.surfaceSignal),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: SelahText.body(size: 14))),
              Icon(Icons.chevron_right, size: 19, color: SelahColors.ink(0.48)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SelahShepherdLinkRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        border: Border.all(color: SelahColors.surfaceBorder),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.otherFirstName, style: SelahText.body(size: 15)),
          const SizedBox(height: 3),
          Text(
            request.isIncoming
                ? 'Wants to link with you'
                : 'Waiting for their answer',
            style: SelahText.subtext(size: 11.5),
          ),
          if (request.isIncoming) ...[
            const SizedBox(height: 8),
            Text(
              SelahMembershipCatalog.shepherdAccessTerms,
              style: SelahText.subtext(size: 10.75),
            ),
          ],
          const SizedBox(height: 12),
          if (busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            )
          else if (request.isIncoming)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel request'),
              ),
            ),
        ],
      ),
    );
  }
}
