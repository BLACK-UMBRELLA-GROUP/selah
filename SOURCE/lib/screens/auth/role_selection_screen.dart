// First-use path selection.
//
// Founder direction, 2026-08-19: this is no longer framed as choosing a
// permanent account type. It asks which SELAH experience the person needs
// first. One trusted identity may later carry both Seeker and Shepherd
// contexts without another sign-in; the server activation for that second
// context remains behind the Founder's explicit migration gate.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../dev/dev_role_choice_design.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_initial_signup_draft_service.dart';
import '../../models/selah_initial_signup_draft.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../../widgets/selah_onboarding_continue_action.dart';
import '../../widgets/selah_onboarding_edge_swipe.dart';
import '../../widgets/selah_onboarding_account_exit.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/account_path_overview_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String? recoveryNotice;
  final String? signupUserId;
  final bool devPreview;
  final bool animateDevEntrance;
  const RoleSelectionScreen({
    super.key,
    this.recoveryNotice,
    this.signupUserId,
    this.devPreview = false,
    this.animateDevEntrance = false,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _saving = false;
  bool _advancing = false;
  String? _error;
  String? _signupUserId;
  SelahSignupRole? _selectedRole;
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _entrance;
  bool _entranceStarted = false;
  static const _roleFocusDuration = Duration(milliseconds: 480);
  Timer? _roleFocusTimer;
  int _roleFocusRevision = 0;
  bool _roleFocusSettling = false;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  bool get _motionReady =>
      !_roleFocusSettling && _entrance.status == AnimationStatus.completed;

  bool get _canAdvance =>
      _selectedRole != null &&
      _motionReady &&
      !_advancing &&
      !_saving &&
      ModalRoute.of(context)?.isCurrent == true &&
      (!widget.devPreview || SelahDeveloperAccess.canUseDeveloperTools);

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: widget.devPreview && widget.animateDevEntrance ? 0 : 1,
    )..addStatusListener(_onEntranceStatus);
    if (widget.devPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SelahDevSurfaceCoordinator.instance.attachRoleChoice(
          this,
          isCurrent: () => mounted && ModalRoute.of(context)?.isCurrent == true,
        );
      });
    }
    // A requested preview is never a live draft reader, even when denied.
    if (widget.devPreview) return;
    try {
      final suppliedUserId = widget.signupUserId;
      if (suppliedUserId != null) {
        SelahInitialSignupDraftService.repository.requireOwner(suppliedUserId);
        _signupUserId = suppliedUserId;
      } else {
        _signupUserId = SelahInitialSignupDraftService.captureUserId();
      }
    } catch (_) {
      _signupUserId = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _roleFocusTimer?.cancel();
      _roleFocusRevision++;
      _roleFocusSettling = false;
    }
    if (!widget.devPreview || !widget.animateDevEntrance) return;
    if (_reduceMotion) {
      _entrance.value = 1;
    } else if (!_entranceStarted) {
      _entranceStarted = true;
      _entrance.forward();
    }
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (mounted && status == AnimationStatus.completed) setState(() {});
  }

  @override
  void dispose() {
    _roleFocusTimer?.cancel();
    _roleFocusRevision++;
    if (widget.devPreview) {
      SelahDevSurfaceCoordinator.instance.detachRoleChoice(this);
    }
    _scrollController.dispose();
    _entrance.removeStatusListener(_onEntranceStatus);
    _entrance.dispose();
    super.dispose();
  }

  void _select(SelahSignupRole role) {
    if (_advancing ||
        ModalRoute.of(context)?.isCurrent != true ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools)) {
      return;
    }
    _roleFocusTimer?.cancel();
    final revision = ++_roleFocusRevision;
    final settling = !_reduceMotion;
    setState(() {
      _selectedRole = _selectedRole == role ? null : role;
      _error = null;
      _roleFocusSettling = settling;
    });
    if (settling) {
      _roleFocusTimer = Timer(_roleFocusDuration, () {
        if (!mounted || revision != _roleFocusRevision) return;
        // This only finishes local layout motion. Current-route and preview
        // authority checks remain in the shared advance gate, including if
        // another route covered this one while the cards were settling.
        setState(() => _roleFocusSettling = false);
      });
    }
  }

  Future<void> _advanceSelected() async {
    final role = _selectedRole;
    if (role == null ||
        !_motionReady ||
        _advancing ||
        _saving ||
        ModalRoute.of(context)?.isCurrent != true ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools)) {
      return;
    }
    setState(() => _advancing = true);
    try {
      if (role == SelahSignupRole.seeker) {
        await _proceedAsSeeker(context);
      } else {
        await _proceedAsMentor(context);
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<String?> _remember(SelahSignupRole role) async {
    if (widget.devPreview) return null;
    if (_saving) return null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = _signupUserId;
      if (userId == null) throw StateError('Missing signup principal.');
      SelahInitialSignupDraftService.repository.requireOwner(userId);
      await SelahInitialSignupDraftService.repository.save(
        userId,
        SelahInitialSignupDraft(
          role: role,
          showIntroduction: role == SelahSignupRole.seeker,
        ),
      );
      if (!mounted) return null;
      setState(() => _saving = false);
      return userId;
    } catch (error) {
      debugPrint(
        'SELAH: role selection draft save failed (${error.runtimeType}).',
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              "We couldn't save your setup securely. Please try again on this device.";
        });
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDeveloperAccess.authorizationChanges,
      if (widget.devPreview) SelahDevRoleChoiceDesign.changes,
    ]),
    builder: (context, _) {
      if (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('role_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildSelection(context);
    },
  );

  Widget _buildSelection(BuildContext context) {
    // Visual comparisons are protected and session-only. The live journey
    // uses Guided paths; the protected toggle can still preview every design.
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final design = widget.devPreview
        ? SelahDevRoleChoiceDesign.current
        : SelahRoleChoiceDesign.guidedPaths;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final cardHeight = design == SelahRoleChoiceDesign.spotlight
        ? (screenHeight * .16).clamp(150.0, 165.0).toDouble()
        : design == SelahRoleChoiceDesign.current
        ? 104.0
        : (screenHeight * .14).clamp(124.0, 176.0).toDouble();
    final focusedCardHeight = (screenHeight * .34)
        .clamp(cardHeight + 74, 310.0)
        .toDouble();
    final selectionDuration = _reduceMotion
        ? Duration.zero
        : _roleFocusDuration;
    final setupLabel = Text(
      'CHOOSE YOUR PATH',
      textAlign: TextAlign.end,
      style: SelahText.chapterLabel(color: SelahColors.ink(0.38)),
    );
    final foreground = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final content = SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (viewport.maxHeight - 46).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: _selectionContents(
                      context,
                      previewStyle: previewStyle,
                      design: design,
                      cardHeight: cardHeight,
                      focusedCardHeight: focusedCardHeight,
                      selectionDuration: selectionDuration,
                      setupLabel: setupLabel,
                    ),
                  ),
                );
                return SelahOnboardingEdgeSwipe(
                  controller: _scrollController,
                  enabled: _canAdvance,
                  onForward: () => _advanceSelected(),
                  child: content,
                );
              },
            ),
          ),
          SizedBox(
            height: 78,
            child: Center(
              child: IgnorePointer(
                ignoring: _selectedRole == null,
                child: ExcludeSemantics(
                  excluding: _selectedRole == null,
                  child: AnimatedSwitcher(
                    duration: selectionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: .9,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _selectedRole == null
                        ? const SizedBox.shrink(
                            key: ValueKey('role-choice-no-continue'),
                          )
                        : SelahOnboardingArrowAction(
                            key: const ValueKey('role-choice-continue'),
                            active: _canAdvance,
                            semanticLabel: 'Continue with selected experience',
                            onPressed: _advanceSelected,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
        ),
        child: widget.devPreview && widget.animateDevEntrance
            ? AnimatedBuilder(
                animation: _entrance,
                child: foreground,
                builder: (context, child) {
                  final progress = Curves.easeOutSine.transform(
                    _entrance.value,
                  );
                  return Opacity(
                    key: const ValueKey('dev_onboarding_downward_entry'),
                    opacity: .08 + .92 * progress,
                    child: Transform.translate(
                      offset: Offset(0, 54 * (1 - progress)),
                      child: child,
                    ),
                  );
                },
              )
            : foreground,
      ),
    );
  }

  Widget _selectionContents(
    BuildContext context, {
    required OnboardingPreviewStyle? previewStyle,
    required SelahRoleChoiceDesign design,
    required double cardHeight,
    required double focusedCardHeight,
    required Duration selectionDuration,
    required Widget setupLabel,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'SELAH',
            style: SelahText.wordmark(
              size: 20,
              color: SelahColors.splashWordmark,
            ),
          ),
          const Spacer(),
          Flexible(child: setupLabel),
        ],
      ),
      SizedBox(height: 12),
      // Path choice is a branch, not step one of an invented two-step bar.
      // Keep the former rail's height so the cards do not jump vertically.
      SizedBox(height: previewStyle == null ? 1.5 : 9),
      if (previewStyle == null)
        SizedBox(height: 62)
      else ...[
        SizedBox(height: previewStyle.spacious ? 23 : 16),
        SizedBox(
          key: ValueKey(
            'onboarding-preview-role-${previewStyle.directionName}',
          ),
          width: double.infinity,
          height: previewStyle.spacious ? 110 : 88,
          child: Align(
            alignment: previewStyle.centered
                ? Alignment.center
                : Alignment.centerLeft,
            child: OnboardingPreviewAccent(
              style: previewStyle,
              size: previewStyle.spacious ? 108 : 84,
              progress: .5,
            ),
          ),
        ),
        SizedBox(height: previewStyle.spacious ? 19 : 12),
      ],
      if (previewStyle?.centered == true)
        Center(
          child: Text(
            'CHOOSE WHERE TO BEGIN',
            textAlign: TextAlign.center,
            style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
          ),
        )
      else
        Text(
          'CHOOSE WHERE TO BEGIN',
          style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
        ),
      SizedBox(height: 10),
      if (previewStyle?.centered == true)
        SizedBox(
          width: double.infinity,
          child: Text(
            'How will you use SELAH first?',
            textAlign: TextAlign.center,
            style: SelahText.heading(size: previewStyle!.titleSize),
          ),
        )
      else
        Text(
          'How will you use SELAH first?',
          style: SelahText.heading(size: previewStyle?.titleSize ?? 28),
        ),
      SizedBox(height: 10),
      if (previewStyle?.centered == true)
        SizedBox(
          width: double.infinity,
          child: Text(
            'Start with the experience you need today.',
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 13.5),
          ),
        )
      else
        Text(
          'Start with the experience you need today.',
          style: SelahText.subtext(size: 13.5),
        ),
      SizedBox(height: previewStyle?.sectionGap ?? 30),
      if (widget.recoveryNotice != null) ...[
        Text(widget.recoveryNotice!, style: SelahText.subtext()),
        const SizedBox(height: 16),
      ],
      if (_error != null) ...[
        Text(_error!, style: SelahText.subtext()),
        const SizedBox(height: 16),
      ],
      Column(
        key: const ValueKey('role-choice-options'),
        children: [
          _animatedRoleSlot(
            SelahSignupRole.seeker,
            visible:
                _selectedRole == null || _selectedRole == SelahSignupRole.seeker,
            previewStyle: previewStyle,
            design: design,
            minHeight: _selectedRole == SelahSignupRole.seeker
                ? focusedCardHeight
                : cardHeight,
            focused: _selectedRole == SelahSignupRole.seeker,
            duration: selectionDuration,
          ),
          AnimatedContainer(
            duration: selectionDuration,
            curve: Curves.easeInOutCubic,
            height: _selectedRole == null
                ? (previewStyle?.spacious == true ? 17 : 14)
                : 0,
          ),
          _animatedRoleSlot(
            SelahSignupRole.shepherd,
            visible:
                _selectedRole == null ||
                _selectedRole == SelahSignupRole.shepherd,
            previewStyle: previewStyle,
            design: design,
            minHeight: _selectedRole == SelahSignupRole.shepherd
                ? focusedCardHeight
                : cardHeight,
            focused: _selectedRole == SelahSignupRole.shepherd,
            duration: selectionDuration,
          ),
        ],
      ),
      if (_signupUserId != null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: SelahOnboardingAccountExit(expectedUserId: _signupUserId!),
          ),
        ),
    ],
  );

  Widget _animatedRoleSlot(
    SelahSignupRole role, {
    required bool visible,
    required OnboardingPreviewStyle? previewStyle,
    required SelahRoleChoiceDesign design,
    required double minHeight,
    required bool focused,
    required Duration duration,
  }) {
    final child = visible
        ? _roleCard(
            role,
            key: ValueKey('role-choice-card-${role.name}'),
            previewStyle: previewStyle,
            design: design,
            minHeight: minHeight,
            focused: focused,
            motionDuration: duration,
          )
        : SizedBox.shrink(key: ValueKey('role-choice-hidden-${role.name}'));
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        // A zero-duration switch can retain the outgoing child for one frame.
        // Accessible/reduced-motion selection must hide it immediately.
        child: duration == Duration.zero
            ? child
            : AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: child,
              ),
      ),
    );
  }

  Widget _roleCard(
    SelahSignupRole role, {
    Key? key,
    required OnboardingPreviewStyle? previewStyle,
    required SelahRoleChoiceDesign design,
    required double minHeight,
    bool focused = false,
    required Duration motionDuration,
  }) => _RoleCard(
    key: key,
    actionKey: ValueKey(
      role == SelahSignupRole.seeker
          ? 'role-select-seeker'
          : 'role-select-shepherd',
    ),
    role: role,
    title: role == SelahSignupRole.seeker
        ? 'Seek marriage'
        : 'Support as Shepherd',
    description: role == SelahSignupRole.seeker
        ? 'Build my profile and begin my own marriage journey.'
        : 'Guide someone I care for through their journey.',
    previewStyle: previewStyle,
    design: design,
    selected: _selectedRole == role,
    focused: focused,
    minHeight: minHeight,
    motionDuration: motionDuration,
    onTap: () => _select(role),
  );

  Future<void> _proceedAsSeeker(BuildContext context) async {
    if (widget.devPreview) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          allowSnapshotting: false,
          builder: (_) => OnboardingFlow(
            // A local rehearsal must not inspect the signed-in member.
            welcomeName: 'Shakeel',
            devPreview: true,
          ),
        ),
      );
      return;
    }
    final userId = await _remember(SelahSignupRole.seeker);
    if (userId == null || !context.mounted) return;
    final firstName = SelahAuth.onboardingFirstName;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            OnboardingFlow(welcomeName: firstName, signupUserId: userId),
      ),
    );
  }

  Future<void> _proceedAsMentor(BuildContext context) async {
    if (widget.devPreview) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          allowSnapshotting: false,
          builder: (_) =>
              const ShepherdOnboardingOverviewScreen(devPreview: true),
        ),
      );
      return;
    }
    final userId = await _remember(SelahSignupRole.shepherd);
    if (userId == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShepherdOnboardingOverviewScreen(signupUserId: userId),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Key actionKey;
  final SelahSignupRole role;
  final String title;
  final String description;
  final OnboardingPreviewStyle? previewStyle;
  final SelahRoleChoiceDesign design;
  final bool selected;
  final bool focused;
  final double minHeight;
  final Duration motionDuration;
  final VoidCallback onTap;

  const _RoleCard({
    super.key,
    required this.actionKey,
    required this.role,
    required this.title,
    required this.description,
    this.previewStyle,
    required this.design,
    required this.selected,
    required this.focused,
    required this.minHeight,
    required this.motionDuration,
    required this.onTap,
  });

  IconData get _roleIcon => role == SelahSignupRole.seeker
      ? Icons.person_outline_rounded
      : Icons.shield_outlined;

  String get _number => role == SelahSignupRole.seeker ? '01' : '02';

  Widget _selectionMark({double size = 28}) => AnimatedContainer(
    duration: motionDuration,
    curve: Curves.easeInOutCubic,
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected
          ? SelahColors.journeyGold.withValues(alpha: .18)
          : Colors.transparent,
      border: Border.all(
        color: SelahColors.journeyGold.withValues(alpha: selected ? .9 : .45),
      ),
    ),
    child: AnimatedSwitcher(
      duration: motionDuration,
      switchInCurve: Curves.easeOutCubic,
      // Leave the transition root unkeyed so AnimatedSwitcher assigns its
      // unique entry number. A rapid checked/unchecked/checked reversal can
      // retain two outgoing states with the same child key briefly.
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: selected
          ? Icon(
              Icons.check_rounded,
              key: ValueKey('role-choice-selected-${role.name}'),
              size: size * .62,
              color: SelahColors.journeyGold,
            )
          : const SizedBox.shrink(key: ValueKey('role-choice-unchecked')),
    ),
  );

  Widget get _title => AnimatedDefaultTextStyle(
    duration: motionDuration,
    curve: Curves.easeInOutCubic,
    style: SelahText.button(
      size: focused ? 20 : 17,
      color: SelahColors.foreground,
    ),
    child: Text(title),
  );

  Widget get _description => AnimatedDefaultTextStyle(
    duration: motionDuration,
    curve: Curves.easeInOutCubic,
    style: SelahText.subtext(size: focused ? 14 : 12.5),
    child: Text(description),
  );

  BoxDecoration _decoration(BorderRadius radius) {
    if (design == SelahRoleChoiceDesign.current) {
      return previewStyle?.cardDecoration(selected: selected) ??
          BoxDecoration(
            color: selected
                ? SelahColors.journeyGold.withValues(alpha: .14)
                : SelahColors.iconButtonBg,
            border: Border.all(
              color: selected
                  ? SelahColors.journeyGold.withValues(alpha: .75)
                  : SelahColors.iconButtonBorder,
              width: selected ? 1 : .5,
            ),
            borderRadius: radius,
          );
    }
    return BoxDecoration(
      color: switch (design) {
        SelahRoleChoiceDesign.quietRails =>
          selected
              ? SelahColors.journeyGold.withValues(alpha: .09)
              : Colors.transparent,
        SelahRoleChoiceDesign.spotlight =>
          selected
              ? SelahColors.journeyGold.withValues(alpha: .13)
              : SelahColors.luxuryDarkPurple.withValues(alpha: .27),
        _ =>
          selected
              ? SelahColors.journeyGold.withValues(alpha: .13)
              : SelahColors.frostFill,
      },
      border: Border.all(
        color: selected
            ? SelahColors.journeyGold.withValues(alpha: .85)
            : SelahColors.frostBorder,
        width: selected ? 1.2 : .8,
      ),
      borderRadius: radius,
    );
  }

  Widget _current() => Row(
    children: [
      Container(
        width: 2,
        height: 48,
        decoration: BoxDecoration(
          color: SelahColors.journeyGold.withValues(alpha: .84),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_title, const SizedBox(height: 5), _description],
        ),
      ),
      const SizedBox(width: 12),
      _selectionMark(size: 38),
    ],
  );

  Widget _editorial() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _number,
        style: SelahText.heading(size: 32, color: SelahColors.journeyGold),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 1,
              color: SelahColors.journeyGold.withValues(alpha: .55),
            ),
            const SizedBox(height: 17),
            _title,
            const SizedBox(height: 9),
            _description,
          ],
        ),
      ),
      const SizedBox(width: 12),
      _selectionMark(),
    ],
  );

  Widget _guidedPaths() => Row(
    children: [
      SizedBox(
        width: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_roleIcon, color: SelahColors.journeyGold, size: 25),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: motionDuration,
              curve: Curves.easeInOutCubic,
              width: 1,
              height: focused ? 116 : 36,
              color: SelahColors.journeyGold.withValues(alpha: .55),
            ),
            const SizedBox(height: 7),
            _selectionMark(size: 20),
          ],
        ),
      ),
      const SizedBox(width: 19),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PATH $_number',
              style: SelahText.chapterLabel(
                color: SelahColors.journeyGold.withValues(alpha: .82),
              ),
            ),
            const SizedBox(height: 9),
            _title,
            const SizedBox(height: 8),
            _description,
          ],
        ),
      ),
    ],
  );

  Widget _quietRails() => Row(
    children: [
      Icon(_roleIcon, size: 27, color: SelahColors.journeyGold),
      const SizedBox(width: 20),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_title, const SizedBox(height: 8), _description],
        ),
      ),
      const SizedBox(width: 13),
      _selectionMark(),
    ],
  );

  Widget _spotlight() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SelahColors.journeyGold.withValues(alpha: .58),
          ),
        ),
        child: Icon(_roleIcon, color: SelahColors.journeyGold, size: 20),
      ),
      const SizedBox(height: 7),
      _title,
      const SizedBox(height: 5),
      Text(
        description,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 12.5),
      ),
      const SizedBox(height: 7),
      _selectionMark(size: 20),
    ],
  );

  Widget _framedChoice() => Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: SelahColors.journeyGold.withValues(alpha: selected ? .65 : .3),
        width: .7,
      ),
      borderRadius: BorderRadius.circular(9),
    ),
    padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              '$_number / 02',
              style: SelahText.chapterLabel(color: SelahColors.journeyGold),
            ),
            const Spacer(),
            _selectionMark(size: 24),
          ],
        ),
        const SizedBox(height: 7),
        _title,
        const SizedBox(height: 4),
        _description,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final radius = switch (design) {
      SelahRoleChoiceDesign.current =>
        previewStyle?.cardRadius ?? BorderRadius.circular(16),
      SelahRoleChoiceDesign.editorial => BorderRadius.circular(5),
      SelahRoleChoiceDesign.guidedPaths => BorderRadius.circular(20),
      SelahRoleChoiceDesign.quietRails => BorderRadius.circular(8),
      SelahRoleChoiceDesign.spotlight => BorderRadius.circular(32),
      SelahRoleChoiceDesign.framedChoice => BorderRadius.circular(19),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      hint: selected
          ? 'Selected. Tap again to show both choices, or swipe up or use the continue control.'
          : 'Select this experience',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: motionDuration,
        curve: Curves.easeInOutCubic,
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: _decoration(radius).copyWith(
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: SelahColors.journeyGold.withValues(alpha: .11),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: actionKey,
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: design == SelahRoleChoiceDesign.spotlight
                  ? const EdgeInsets.symmetric(horizontal: 22, vertical: 8)
                  : design == SelahRoleChoiceDesign.framedChoice
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                  : EdgeInsets.symmetric(
                      horizontal: design == SelahRoleChoiceDesign.current
                          ? 18
                          : 20,
                      vertical: previewStyle?.cardVerticalPadding ?? 18,
                    ),
              child: switch (design) {
                SelahRoleChoiceDesign.current => _current(),
                SelahRoleChoiceDesign.editorial => _editorial(),
                SelahRoleChoiceDesign.guidedPaths => _guidedPaths(),
                SelahRoleChoiceDesign.quietRails => _quietRails(),
                SelahRoleChoiceDesign.spotlight => _spotlight(),
                SelahRoleChoiceDesign.framedChoice => _framedChoice(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
