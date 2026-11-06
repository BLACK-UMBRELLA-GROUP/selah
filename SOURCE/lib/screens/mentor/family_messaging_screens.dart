import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../dev/selah_shepherd_circle_preview.dart';
import '../../dev/selah_shepherd_circle_topic_options.dart';

import '../../data/selah_release_gates.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../models/journey_match.dart';
import '../../models/seeker_profile.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_family_messaging_service.dart';
import '../../services/selah_journey_service.dart';
import '../../services/selah_mentor_journey_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_shepherd_preview_lifetime.dart';
import '../../widgets/selah_message_receipt.dart';
import '../../widgets/selah_state_widgets.dart';
import '../journey/journey_flow_screen.dart';
import '../profile/seeker_profile_screen.dart';
import 'mentor_journey_detail_screen.dart';

class SelahShepherdCirclesInboxScreen extends StatefulWidget {
  final bool preview;

  const SelahShepherdCirclesInboxScreen({super.key, this.preview = false});

  @override
  State<SelahShepherdCirclesInboxScreen> createState() =>
      _SelahShepherdCirclesInboxScreenState();
}

class _SelahShepherdCirclesInboxScreenState
    extends State<SelahShepherdCirclesInboxScreen> {
  bool _loading = true;
  bool _available = true;
  List<SelahShepherdCircleSummary> _circles = const [];
  late final SelahShepherdPreviewLifetime _authority;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _authority = SelahShepherdPreviewLifetime(preview: widget.preview)
      ..addListener(_withdraw);
    _load();
  }

  @override
  void dispose() {
    _authority
      ..removeListener(_withdraw)
      ..dispose();
    super.dispose();
  }

  void _withdraw() {
    if (!mounted) return;
    _loadRequest++;
    setState(() {
      _loading = false;
      _available = false;
      _circles = const [];
    });
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    if (!_authority.isCurrent) {
      _withdraw();
      return;
    }
    if (_authority.canPreview) {
      setState(() {
        _loading = false;
        _available = true;
        _circles = [
          SelahShepherdCircleSummary(
            threadId: 'dev-family-thread',
            seekerId: 'dev-seeker-aaliyah',
            seekerFirstName: 'Rebecca',
            participantCount: 3,
            lastMessage: 'Let me know when you are ready to talk.',
            lastMessageAt: DateTime.now().subtract(const Duration(minutes: 8)),
            unreadCount: 1,
            canSend: true,
            muted: false,
            access: SelahFamilyMessageAccess.ready,
          ),
        ];
      });
      return;
    }
    final result = await SelahFamilyMessagingService.fetchCircles();
    if (!mounted || !_authority.isCurrent || request != _loadRequest) return;
    setState(() {
      _loading = false;
      _available = result.isAvailable;
      _circles = result.valueOr(const []);
    });
  }

  @override
  Widget build(BuildContext context) => SelahShepherdPreviewRouteBoundary(
    authority: _authority,
    child: Scaffold(
      appBar: AppBar(title: const Text('Shepherd Circles')),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          top: false,
          child: _loading
              ? const SelahLoading(label: 'Loading messages…')
              : !_available
              ? SelahUnknownErrorState(contentName: 'Messages', onRetry: _load)
              : _circles.isEmpty
              ? const SelahEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No Shepherd Circles yet',
                  message:
                      'A Seeker’s shared circle appears after you are linked as their Shepherd.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                  itemCount: _circles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final circle = _circles[index];
                    return _ShepherdCircleCard(
                      circle: circle,
                      onTap: () {
                        if (!_authority.isCurrent) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SelahShepherdCircleScreen(
                              seekerId: circle.seekerId,
                              seekerFirstName: circle.seekerFirstName,
                              preview: widget.preview,
                              initialCircle: circle,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    ),
  );
}

class SelahShepherdCircleScreen extends StatefulWidget {
  final String seekerId;
  final String seekerFirstName;
  final bool viewerIsSeeker;
  final bool preview;
  final SelahShepherdCircleSummary? initialCircle;
  final ValueChanged<SelahFamilyMessageContext>? onOpenContext;
  final SelahShepherdCirclePreviewData? previewData;
  // Detached developer presentation only. None of these values grants
  // preview, member access, history access or a send entitlement.
  final ValueListenable<SelahCircleTopicLayout>? previewTopicLayout;
  final List<SelahCircleDiscussionTopic> previewPastTopics;
  final bool Function()? previewForeground;
  final ValueListenable<bool>? previewVisibility;
  // A pure, caller-owned read-only projection. A discussion label never
  // grants profile access; only an admitted current Seeker context may use it.
  final SeekerProfile? Function(SelahFamilyMessageContext)?
  previewDiscussionProfileFor;

  /// Denial-only scope supplied by a protected caller. This never enables
  /// preview or live access, and must allow this Circle's owned child sheets.
  final bool Function()? canAct;
  final VoidCallback? onBack;

  const SelahShepherdCircleScreen({
    super.key,
    required this.seekerId,
    required this.seekerFirstName,
    this.viewerIsSeeker = false,
    this.preview = false,
    this.initialCircle,
    this.onOpenContext,
    this.previewData,
    this.previewTopicLayout,
    this.previewPastTopics = const [],
    this.previewForeground,
    this.previewVisibility,
    this.previewDiscussionProfileFor,
    this.canAct,
    this.onBack,
  });

  @override
  State<SelahShepherdCircleScreen> createState() =>
      _SelahShepherdCircleScreenState();
}

class _CircleDiscussionMarker {
  const _CircleDiscussionMarker({
    required this.sequence,
    required this.afterMessageCount,
    required this.topic,
  });

  final int sequence;
  final int afterMessageCount;
  final SelahCircleDiscussionTopic topic;
}

class _SelahShepherdCircleScreenState extends State<SelahShepherdCircleScreen> {
  final _composer = TextEditingController();
  bool _loading = true;
  bool _available = true;
  bool _sending = false;
  bool _confirmedCanSend = false;
  bool _muted = false;
  int _participantCount = 1;
  String? _threadId;
  SelahFamilyMessageAccess _access = SelahFamilyMessageAccess.unavailable;
  List<SelahFamilyMessage> _messages = const [];
  SelahFamilyMessageContext? _selectedContext;
  late final SelahShepherdPreviewLifetime _authority;
  int _loadRequest = 0;
  late final SelahShepherdCirclePreviewData? _previewData;
  late final bool Function()? _callerGuard;
  bool _callerRevoked = false;
  int _sendRequest = 0;
  late final ValueListenable<SelahCircleTopicLayout>? _topicLayout;
  late final List<SelahCircleDiscussionTopic> _pastTopics;
  late final bool Function()? _previewForeground;
  late final ValueListenable<bool>? _previewVisibility;
  late final SeekerProfile? Function(SelahFamilyMessageContext)?
  _discussionProfileResolver;
  final _topicMessageScroll = ScrollController();
  SelahCircleDiscussionTopic? _discussionTopic;
  final _discussionMessageTags = <String, SelahCircleDiscussionTopic>{};
  final _discussionMarkers = <_CircleDiscussionMarker>[];
  int _discussionMarkerSequence = 0;
  bool _showTopicEntry = false;
  int _topicPickRequest = 0;

  static const _previewContexts = <SelahFamilyMessageContext>[
    SelahFamilyMessageContext(
      referenceId: 'dev-active-h',
      firstName: 'H.',
      kind: SelahFamilyMessageContextKind.active,
    ),
    SelahFamilyMessageContext(
      referenceId: 'dev-potential-m',
      firstName: 'M.',
      kind: SelahFamilyMessageContextKind.potential,
    ),
    SelahFamilyMessageContext(
      referenceId: 'dev-paused-r',
      firstName: 'R.',
      kind: SelahFamilyMessageContextKind.paused,
    ),
    SelahFamilyMessageContext(
      referenceId: 'dev-ended-s',
      firstName: 'S.',
      kind: SelahFamilyMessageContextKind.ended,
    ),
  ];

  bool get _canPresentComposer =>
      mounted &&
      _authority.isCurrent &&
      _callerCurrent &&
      _available &&
      !_loading &&
      _confirmedCanSend &&
      _threadId != null &&
      _access == SelahFamilyMessageAccess.ready;
  bool get _canSend => _canInteract && _canPresentComposer;

  bool get _topicOptionsEnabled =>
      _authority.canPreview &&
      _previewData != null &&
      _topicLayout != null &&
      _pastTopics.map((topic) => topic.id).toSet().length ==
          _pastTopics.length &&
      _pastTopics.every(
        (topic) =>
            topic.kind == SelahCircleTopicKind.past &&
            topic.id.startsWith('draft-circle-past-') &&
            topic.firstName.trim().isNotEmpty &&
            topic.firstName.length <= 80 &&
            topic.endedOn != null &&
            !_previewData.contexts.any(
              (active) => active.referenceId == topic.id,
            ),
      );
  SelahCircleTopicLayout get _discussionLayout => _topicOptionsEnabled
      ? _topicLayout!.value
      : SelahCircleTopicLayout.current;
  List<SelahCircleDiscussionTopic> get _currentTopics => [
    for (final item
        in _previewData?.contexts ?? const <SelahFamilyMessageContext>[])
      SelahCircleDiscussionTopic(
        id: item.referenceId,
        firstName: item.firstName,
        kind: SelahCircleTopicKind.current,
      ),
  ];

  bool _includesDiscussionTopic(SelahCircleDiscussionTopic topic) =>
      topic == SelahCircleDiscussionTopic.general ||
      [..._currentTopics, ..._pastTopics].any(
        (known) =>
            known.id == topic.id &&
            known.firstName == topic.firstName &&
            known.kind == topic.kind &&
            known.endedOn == topic.endedOn,
      );
  String get _currentSenderId => _authority.canPreview
      ? (_previewData?.senderId ?? 'dev-me')
      : (SelahAuth.currentUser?.id ?? 'signed-out');

  bool get _callerCurrent {
    if (_callerRevoked) return false;
    bool allowed;
    try {
      allowed = _callerGuard?.call() ?? true;
    } catch (_) {
      allowed = false;
    }
    final data = _previewData;
    if (!allowed ||
        (widget.initialCircle != null &&
            widget.initialCircle!.seekerId != widget.seekerId) ||
        (data != null &&
            (!widget.preview ||
                !_authority.canPreview ||
                !data.validFor(
                  widget.seekerId,
                  viewerIsSeeker: widget.viewerIsSeeker,
                )))) {
      _denyCaller();
      return false;
    }
    return true;
  }

  bool get _canInteract {
    if (!mounted || !_authority.isCurrent || !_callerCurrent) return false;
    try {
      return (_previewForeground?.call() ?? true) &&
          (_previewVisibility?.value ?? true);
    } catch (_) {
      return false;
    }
  }

  bool get _canActOnCircleRoute =>
      _canInteract && (ModalRoute.of(context)?.isCurrent ?? false);

  void _denyCaller() {
    if (_callerRevoked) return;
    // Deny synchronously, including A→B→A, but withdraw owned routes only
    // after the current build. A getter may be reached during tree layout.
    _callerRevoked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _authority.revoke();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _guardRoute(BuildContext context, Widget child) =>
      SelahShepherdPreviewRouteBoundary(authority: _authority, child: child);

  @override
  void initState() {
    super.initState();
    _previewData = widget.previewData;
    _callerGuard = widget.canAct;
    _topicLayout = widget.previewTopicLayout;
    _pastTopics = List.unmodifiable(widget.previewPastTopics);
    _previewForeground = widget.previewForeground;
    _previewVisibility = widget.previewVisibility;
    _discussionProfileResolver = widget.previewDiscussionProfileFor;
    _authority = SelahShepherdPreviewLifetime(preview: widget.preview)
      ..addListener(_withdraw);
    _showTopicEntry = _discussionLayout.hasEntry;
    _topicLayout?.addListener(_topicLayoutChanged);
    _previewVisibility?.addListener(_topicVisibilityChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant SelahShepherdCircleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekerId != widget.seekerId ||
        oldWidget.viewerIsSeeker != widget.viewerIsSeeker ||
        oldWidget.preview != widget.preview ||
        !identical(_callerGuard, widget.canAct) ||
        !identical(_previewData, widget.previewData) ||
        !identical(_topicLayout, widget.previewTopicLayout) ||
        !identical(oldWidget.previewPastTopics, widget.previewPastTopics) ||
        !identical(_previewForeground, widget.previewForeground) ||
        !identical(_previewVisibility, widget.previewVisibility) ||
        !identical(
          _discussionProfileResolver,
          widget.previewDiscussionProfileFor,
        )) {
      _denyCaller();
    }
  }

  void _withdraw() {
    if (!mounted) return;
    _loadRequest++;
    _sendRequest++;
    _composer.clear();
    setState(() {
      _loading = false;
      _available = false;
      _sending = false;
      _confirmedCanSend = false;
      _muted = false;
      _participantCount = 0;
      _threadId = null;
      _access = SelahFamilyMessageAccess.unavailable;
      _messages = const [];
      _selectedContext = null;
      _discussionTopic = null;
      _discussionMessageTags.clear();
      _discussionMarkers.clear();
      _showTopicEntry = false;
      _topicPickRequest++;
    });
  }

  @override
  void dispose() {
    _topicLayout?.removeListener(_topicLayoutChanged);
    _previewVisibility?.removeListener(_topicVisibilityChanged);
    _topicMessageScroll.dispose();
    _composer.dispose();
    _authority
      ..removeListener(_withdraw)
      ..dispose();
    super.dispose();
  }

  void _topicLayoutChanged() {
    if (!mounted || !_authority.isCurrent || !_callerCurrent) return;
    _topicPickRequest++;
    setState(() => _showTopicEntry = _discussionLayout.hasEntry);
  }

  void _topicVisibilityChanged() {
    if (!mounted || !_authority.isCurrent || !_callerCurrent) return;
    setState(() {});
  }

  void _showLatestTopicMessage(int request, String threadId) {
    if (!_topicOptionsEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canActOnCircleRoute ||
          request != _sendRequest ||
          threadId != _threadId ||
          !_topicMessageScroll.hasClients) {
        return;
      }
      final position = _topicMessageScroll.position;
      if (MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)) {
        _topicMessageScroll.jumpTo(position.maxScrollExtent);
      } else {
        _topicMessageScroll.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _selectDiscussionTopic(SelahCircleDiscussionTopic topic) {
    if (!_canActOnCircleRoute ||
        !_canSend ||
        _sending ||
        !_topicOptionsEnabled ||
        !_includesDiscussionTopic(topic)) {
      return;
    }
    final previous = _discussionTopic ?? SelahCircleDiscussionTopic.general;
    final changed =
        previous.id != topic.id ||
        previous.firstName != topic.firstName ||
        previous.kind != topic.kind ||
        previous.endedOn != topic.endedOn;
    setState(() {
      _discussionTopic = topic.isGeneral ? null : topic;
      _showTopicEntry = false;
      if (changed) {
        _discussionMarkers.add(
          _CircleDiscussionMarker(
            sequence: ++_discussionMarkerSequence,
            afterMessageCount: _messages.length,
            topic: topic,
          ),
        );
      }
    });
    if (changed) _showLatestTopicMessage(_sendRequest, _threadId!);
  }

  ({SelahFamilyMessageContext context, SeekerProfile profile})?
  _discussionProfileFor(SelahCircleDiscussionTopic topic) {
    // This may also be checked by the profile's own child route. Circle
    // route-current status is therefore checked separately before pushing it.
    if (!_canSend ||
        _sending ||
        !_topicOptionsEnabled ||
        !widget.viewerIsSeeker ||
        topic.kind != SelahCircleTopicKind.current ||
        !_includesDiscussionTopic(topic)) {
      return null;
    }
    final resolver = _discussionProfileResolver;
    if (resolver == null) return null;
    for (final candidate in _previewData!.contexts) {
      if (candidate.kind != SelahFamilyMessageContextKind.active ||
          candidate.referenceId != topic.id ||
          candidate.firstName != topic.firstName) {
        continue;
      }
      try {
        final profile = resolver(candidate);
        if (profile == null ||
            profile.id != candidate.referenceId ||
            profile.firstName != candidate.firstName) {
          return null;
        }
        return (context: candidate, profile: profile);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _discussionProfileCurrent(
    SelahCircleDiscussionTopic topic,
    ({SelahFamilyMessageContext context, SeekerProfile profile}) target,
  ) {
    final current = _discussionProfileFor(topic);
    return current != null &&
        identical(current.context, target.context) &&
        identical(current.profile, target.profile);
  }

  Future<void> _openDiscussionProfile(
    SelahCircleDiscussionTopic topic,
    ({SelahFamilyMessageContext context, SeekerProfile profile}) target,
  ) async {
    if (!_canActOnCircleRoute || !_discussionProfileCurrent(topic, target)) {
      return;
    }
    FocusScope.of(context).unfocus();
    BuildContext? profileContext;
    bool profileOwnerCurrent() {
      final child = profileContext;
      return child != null &&
          child.mounted &&
          _discussionProfileCurrent(topic, target);
    }

    void dismissProfile() {
      final child = profileContext;
      if (profileOwnerCurrent() &&
          child != null &&
          (ModalRoute.of(child)?.isCurrent ?? false)) {
        Navigator.of(child).pop();
      }
    }

    // Keep callbacks and the read-only child stable across route rebuilds.
    // The same Circle stays mounted; its lifetime revokes this owned route.
    final profile = SeekerProfileScreen(
      key: ValueKey(
        'circle_discussion_profile_route_${target.context.referenceId}',
      ),
      profile: target.profile,
      swipeDownToDismiss: true,
      showCloseButtonWhenSwipeDismiss: true,
      // Route cover is an interaction denial, not lost profile ownership.
      // The renderer checks its own current route without revoking its owner.
      canAct: profileOwnerCurrent,
      onDismiss: dismissProfile,
    );
    if (!_canActOnCircleRoute || !_discussionProfileCurrent(topic, target)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (childContext) {
          profileContext = childContext;
          return _guardRoute(childContext, profile);
        },
      ),
    );
  }

  Future<void> _chooseDiscussionTopic() async {
    if (!_canActOnCircleRoute ||
        !_canSend ||
        _sending ||
        !_topicOptionsEnabled ||
        _showTopicEntry ||
        !_discussionLayout.hasInChat) {
      return;
    }
    final request = ++_topicPickRequest;
    FocusScope.of(context).unfocus();
    final chosen = await showModalBottomSheet<SelahCircleDiscussionTopic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool sheetCurrent() =>
            sheetContext.mounted &&
            _canInteract &&
            _canSend &&
            !_sending &&
            request == _topicPickRequest &&
            (ModalRoute.of(sheetContext)?.isCurrent ?? false);
        return _guardRoute(
          sheetContext,
          SelahCircleTopicPicker(
            currentTopics: _currentTopics,
            pastTopics: _pastTopics,
            selected: _discussionTopic ?? SelahCircleDiscussionTopic.general,
            canSelect: sheetCurrent,
            onSelected: (topic) {
              if (sheetCurrent() && _includesDiscussionTopic(topic)) {
                Navigator.of(sheetContext).pop(topic);
              }
            },
          ),
        );
      },
    );
    if (chosen != null && request == _topicPickRequest) {
      _selectDiscussionTopic(chosen);
    }
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    if (!_canInteract) {
      _withdraw();
      return;
    }
    if (_authority.canPreview) {
      final data = _previewData;
      if (data != null) {
        setState(() {
          _loading = false;
          _available = true;
          _threadId = 'preview-circle-${data.seekerId}';
          _participantCount = data.participants.length;
          _confirmedCanSend = data.canSend && _participantCount > 1;
          _access = _participantCount <= 1
              ? SelahFamilyMessageAccess.linkInactive
              : _confirmedCanSend
              ? SelahFamilyMessageAccess.ready
              : SelahFamilyMessageAccess.membershipRequired;
          _messages = data.messages;
        });
        return;
      }
      setState(() {
        _loading = false;
        _available = true;
        _threadId = widget.initialCircle?.threadId ?? 'dev-family-thread';
        _muted = widget.initialCircle?.muted ?? false;
        _participantCount = widget.initialCircle?.participantCount ?? 3;
        _access =
            widget.initialCircle?.access ?? SelahFamilyMessageAccess.ready;
        _confirmedCanSend = widget.initialCircle?.canSend ?? true;
        _messages = [
          SelahFamilyMessage(
            id: 'dev-family-1',
            senderId: widget.seekerId,
            senderFirstName: widget.seekerFirstName,
            senderRoleLabel: 'Seeker',
            body: 'Hello. I wanted to discuss this together.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
            context: _previewContexts.first,
          ),
          SelahFamilyMessage(
            id: 'dev-family-2',
            senderId: 'dev-circle-shepherd',
            senderFirstName: 'Peter',
            senderRelationship: 'father',
            senderRoleLabel: 'Main Shepherd',
            body: 'Hello to you too. We can all discuss it here.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
            unreadForMe: true,
          ),
          SelahFamilyMessage(
            id: 'dev-family-3',
            senderId: 'dev-me',
            senderFirstName: 'You',
            senderRoleLabel: widget.viewerIsSeeker ? 'Seeker' : 'Main Shepherd',
            body: 'JazakGod khair. Let’s discuss it together.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
            readBy: [
              SelahFamilyMessageReader(
                userId: widget.viewerIsSeeker
                    ? 'dev-circle-main-shepherd'
                    : widget.seekerId,
                firstName: widget.viewerIsSeeker
                    ? 'Peter'
                    : widget.seekerFirstName,
                roleLabel: widget.viewerIsSeeker ? 'Main Shepherd' : 'Seeker',
                readAt: DateTime.now().subtract(const Duration(minutes: 4)),
              ),
              SelahFamilyMessageReader(
                userId: 'dev-circle-additional-shepherd',
                firstName: 'David',
                roleLabel: 'Additional Shepherd',
                readAt: DateTime.now().subtract(const Duration(minutes: 2)),
              ),
            ],
          ),
        ];
      });
      return;
    }
    if (!SelahReleaseGates.familyMessagingEnabled) {
      _withdraw();
      return;
    }
    setState(() {
      _loading = true;
      _available = false;
      _confirmedCanSend = false;
    });
    final accessResult = await SelahFamilyMessagingService.openCircle(
      widget.seekerId,
    );
    if (!_canInteract || request != _loadRequest) return;
    final access = accessResult.valueOrNull;
    if (!accessResult.isAvailable ||
        access == null ||
        access.seekerId != widget.seekerId) {
      _withdraw();
      return;
    }
    _threadId = access.threadId;
    _access = access.access;
    _confirmedCanSend = access.canSend;
    _muted = access.muted;
    _participantCount = access.participantCount;
    final id = access.threadId;
    if (id == null) {
      setState(() {
        _loading = false;
        _available = true;
        _messages = const [];
        _selectedContext = null;
        _confirmedCanSend = false;
      });
      return;
    }
    final messages = await SelahFamilyMessagingService.fetchMessages(id);
    if (!_canInteract || request != _loadRequest) return;
    if (!messages.isAvailable) {
      _withdraw();
      return;
    }
    setState(() {
      _loading = false;
      _available = messages.isAvailable;
      _messages = messages.valueOr(const []);
    });
    if (_canActOnCircleRoute && request == _loadRequest) {
      await SelahFamilyMessagingService.markRead(id);
    }
  }

  Future<void> _send() async {
    if (!_canActOnCircleRoute || _showTopicEntry) return;
    final draft = _composer.text;
    final text = draft.trim();
    final threadId = _threadId;
    if (!_canSend ||
        _sending ||
        text.isEmpty ||
        text.length > 2000 ||
        threadId == null) {
      return;
    }
    final request = ++_sendRequest;
    final loadRequest = _loadRequest;
    final comparison = _discussionLayout != SelahCircleTopicLayout.current;
    final discussionTopic = comparison ? _discussionTopic : null;
    final selectedContext = comparison ? null : _selectedContext;
    setState(() => _sending = true);
    if (_authority.canPreview) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!_canActOnCircleRoute ||
          !_authority.canPreview ||
          request != _sendRequest ||
          loadRequest != _loadRequest ||
          threadId != _threadId) {
        _finishSending(request);
        return;
      }
      setState(() {
        final messageId = 'dev-family-${_messages.length + 1}';
        if (discussionTopic != null &&
            _includesDiscussionTopic(discussionTopic)) {
          _discussionMessageTags[messageId] = discussionTopic;
        }
        _messages = [
          ..._messages,
          SelahFamilyMessage(
            id: messageId,
            senderId: _currentSenderId,
            senderFirstName: 'You',
            senderRoleLabel: _previewData?.participants
                .where((person) => person.isCurrentUser)
                .firstOrNull
                ?.roleLabel,
            body: text,
            createdAt: DateTime.now(),
            context: selectedContext,
          ),
        ];
        _sending = false;
        _selectedContext = null;
        if (_composer.text == draft) _composer.clear();
      });
      _showLatestTopicMessage(request, threadId);
      return;
    }
    final sent = await SelahFamilyMessagingService.send(threadId, text);
    _finishSending(request);
    if (!_canActOnCircleRoute ||
        request != _sendRequest ||
        loadRequest != _loadRequest ||
        threadId != _threadId) {
      return;
    }
    if (sent) {
      if (_composer.text == draft) _composer.clear();
      await _load();
    } else {
      _notice('That message could not be sent. Please try again.');
    }
  }

  void _finishSending(int request) {
    if (mounted && request == _sendRequest && _sending) {
      setState(() => _sending = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _chooseContext() async {
    if (!_canActOnCircleRoute ||
        !_authority.canPreview ||
        _showTopicEntry ||
        _discussionLayout != SelahCircleTopicLayout.current) {
      return;
    }
    final contexts = _previewData?.contexts ?? _previewContexts;
    if (contexts.isEmpty ||
        (_previewData != null && widget.onOpenContext == null)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final chosen = await showModalBottomSheet<SelahFamilyMessageContext>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _guardRoute(context, _MessageContextPicker(contexts: contexts)),
    );
    if (chosen != null &&
        _canActOnCircleRoute &&
        _authority.canPreview &&
        (_previewData?.includesContext(chosen) ?? true)) {
      setState(() => _selectedContext = chosen);
    }
  }

  Future<void> _openMessageContext(
    SelahFamilyMessageContext messageContext,
  ) async {
    if (!_canActOnCircleRoute) return;
    FocusScope.of(context).unfocus();
    final callback = widget.onOpenContext;
    final supplied = _previewData;
    if (supplied != null) {
      if (supplied.includesContext(messageContext)) {
        callback?.call(messageContext);
      }
      return;
    }
    if (callback != null) {
      callback(messageContext);
      return;
    }

    if (messageContext.kind == SelahFamilyMessageContextKind.active) {
      if (widget.viewerIsSeeker) {
        final journey = await _resolveSeekerJourney(messageContext);
        if (!mounted || !_canInteract) return;
        if (journey != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => _guardRoute(
                context,
                JourneyFlowScreen(
                  matchId: journey.matchId,
                  profile: journey.profile,
                ),
              ),
            ),
          );
          return;
        }
        if (_authority.canPreview) {
          // A fixture has no server Journey to open. Move to the real Journey
          // owner instead of presenting a broken Journey route.
          SelahDevSurfaceCoordinator.instance.openSeekerConnectionsSection(0);
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
          return;
        }
      } else {
        final journey = await _resolveShepherdJourney(messageContext);
        if (!mounted || !_canInteract) return;
        if (journey != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => _guardRoute(
                context,
                MentorJourneyDetailScreen(journey: journey),
              ),
            ),
          );
          return;
        }
      }
      _notice('That Active Journey is not available right now.');
      return;
    }

    final journey = await _resolveSeekerJourney(messageContext);
    if (!mounted || !_canInteract) return;
    final profile =
        journey?.profile ??
        (_authority.canPreview ? _previewProfile(messageContext) : null);
    if (profile == null) {
      _notice('That Active Journey is not available right now.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _guardRoute(
          context,
          SeekerProfileScreen(
            profile: profile,
            stateLabel: messageContext.stateLabel,
            swipeDownToDismiss: true,
            showCloseButtonWhenSwipeDismiss: true,
          ),
        ),
      ),
    );
  }

  Future<JourneyMatch?> _resolveSeekerJourney(
    SelahFamilyMessageContext messageContext,
  ) async {
    if (!_canInteract) return null;
    final cached = <JourneyMatch>[
      ...AppState.instance.activeJourneys,
      ...AppState.instance.potentialJourneys,
    ];
    final cachedMatch = _matchingJourney(cached, messageContext.referenceId);
    if (cachedMatch != null) return cachedMatch;
    if (_authority.canPreview) return null;
    final journeys = await SelahJourneyService.fetchJourneyMatches(
      statuses: const ['potential', 'active', 'ended'],
    );
    if (!_canInteract) return null;
    return _matchingJourney(journeys ?? const [], messageContext.referenceId);
  }

  Future<MentorJourneyView?> _resolveShepherdJourney(
    SelahFamilyMessageContext messageContext,
  ) async {
    if (!_canInteract) return null;
    if (!_authority.canPreview) {
      final journeys = await SelahMentorJourneyService.fetchLinkedJourneys();
      if (!_canInteract) return null;
      if (journeys != null) {
        for (final journey in journeys) {
          if (journey.matchId == messageContext.referenceId) return journey;
        }
      }
      return null;
    }
    final profile = _previewProfile(messageContext);
    return MentorJourneyView(
      matchId: messageContext.referenceId,
      linkedSeekerId: widget.seekerId,
      linkedSeekerName: widget.seekerFirstName,
      partner: profile,
      counterpartShepherdName: null,
      counterpartShepherdSurname: null,
      status: 'active',
      journeyStage: 'greeting_exchange',
      isMock: true,
    );
  }

  JourneyMatch? _matchingJourney(
    List<JourneyMatch> journeys,
    String referenceId,
  ) {
    for (final journey in journeys) {
      if (journey.matchId == referenceId || journey.profile.id == referenceId) {
        return journey;
      }
    }
    return null;
  }

  SeekerProfile _previewProfile(SelahFamilyMessageContext messageContext) {
    final index = SelahFamilyMessageContextKind.values.indexOf(
      messageContext.kind,
    );
    final seed = mockProfiles[index % mockProfiles.length];
    return SeekerProfile(
      id: messageContext.referenceId,
      firstName: messageContext.firstName,
      age: seed.age,
      city: seed.city,
      photos: seed.photos,
      gender: seed.gender,
    );
  }

  Future<void> _toggleMute() async {
    if (!_canActOnCircleRoute) return;
    final threadId = _threadId;
    if (threadId == null) return;
    final request = _loadRequest;
    final next = !_muted;
    final changed = _authority.canPreview
        ? true
        : await SelahFamilyMessagingService.setMuted(threadId, muted: next);
    if (!_canActOnCircleRoute ||
        request != _loadRequest ||
        threadId != _threadId) {
      return;
    }
    if (changed) {
      setState(() => _muted = next);
    } else {
      _notice('Notification setting could not be changed. Please try again.');
    }
  }

  void _showMembers() {
    if (!_canActOnCircleRoute) return;
    final threadId = _threadId;
    if (threadId == null) {
      _notice('Circle members are not available right now.');
      return;
    }
    final previewParticipants = _authority.canPreview
        ? (_previewData?.participants ??
              <SelahFamilyCircleParticipant>[
                SelahFamilyCircleParticipant(
                  userId: widget.seekerId,
                  firstName: widget.seekerFirstName,
                  memberRole: 'seeker',
                  isMainShepherd: false,
                  isCurrentUser: widget.viewerIsSeeker,
                ),
                SelahFamilyCircleParticipant(
                  userId: 'dev-circle-main-shepherd',
                  firstName: 'Peter',
                  memberRole: 'shepherd',
                  isMainShepherd: true,
                  isCurrentUser: !widget.viewerIsSeeker,
                ),
                const SelahFamilyCircleParticipant(
                  userId: 'dev-circle-additional-shepherd',
                  firstName: 'David',
                  memberRole: 'shepherd',
                  isMainShepherd: false,
                  isCurrentUser: false,
                ),
              ])
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _guardRoute(
        context,
        _CircleMembersSheet(
          threadId: threadId,
          expectedCount: _participantCount,
          previewParticipants: previewParticipants,
          canInteract: () => _canInteract,
        ),
      ),
    );
  }

  Future<void> _report(SelahFamilyMessage message) async {
    if (!_canActOnCircleRoute) return;
    if (_authority.canPreview) {
      _notice('Preview only — no report was sent.');
      return;
    }
    final threadId = _threadId;
    if (threadId == null) return;
    final request = _loadRequest;
    final sent = await SelahFamilyMessagingService.report(
      threadId: threadId,
      messageId: message.id,
      reason: 'other',
    );
    if (_canActOnCircleRoute &&
        request == _loadRequest &&
        threadId == _threadId) {
      _notice(sent ? 'Report sent.' : 'Report could not be sent.');
    }
  }

  @override
  Widget build(BuildContext context) => !_callerCurrent
      ? const SizedBox.shrink()
      : SelahShepherdPreviewRouteBoundary(
          authority: _authority,
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                decoration: SelahAppGoldDecoration(
                  gradient: SelahColors.genderGradient(
                    AppState.instance.gender,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      _CircleHeader(
                        title: widget.viewerIsSeeker
                            ? 'Your Shepherd Circle'
                            : '${widget.seekerFirstName}’s Shepherd Circle',
                        participantCount: _participantCount,
                        muted: _muted,
                        onBack: () {
                          if (!_canActOnCircleRoute) return;
                          final back = widget.onBack;
                          if (back != null) {
                            back();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                        onShowMembers: _showMembers,
                        onToggleMute: _toggleMute,
                      ),
                      if (!_loading && _available && !_canPresentComposer)
                        _ReadOnlyBanner(access: _access),
                      if (_canPresentComposer &&
                          !_showTopicEntry &&
                          _discussionLayout.hasInChat)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: SelahCircleTopicBar(
                            topic:
                                _discussionTopic ??
                                SelahCircleDiscussionTopic.general,
                            onChoose: _sending ? null : _chooseDiscussionTopic,
                          ),
                        ),
                      if (_canPresentComposer &&
                          !_showTopicEntry &&
                          _discussionLayout ==
                              SelahCircleTopicLayout.beforeChat &&
                          _discussionTopic != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: SelahCircleTopicTag(topic: _discussionTopic!),
                        ),
                      Expanded(
                        child:
                            _canPresentComposer &&
                                _showTopicEntry &&
                                _topicOptionsEnabled
                            ? SelahCircleTopicPicker(
                                key: const ValueKey('circle_topic_entry'),
                                currentTopics: _currentTopics,
                                pastTopics: _pastTopics,
                                selected:
                                    _discussionTopic ??
                                    SelahCircleDiscussionTopic.general,
                                embedded: true,
                                canSelect: () =>
                                    _showTopicEntry &&
                                    _discussionLayout.hasEntry &&
                                    !_sending &&
                                    _canActOnCircleRoute &&
                                    _canSend,
                                onSelected: (topic) {
                                  if (_showTopicEntry &&
                                      _discussionLayout.hasEntry) {
                                    _selectDiscussionTopic(topic);
                                  }
                                },
                              )
                            : _loading
                            ? const SelahLoading(label: 'Opening conversation…')
                            : !_available
                            ? SelahUnknownErrorState(
                                contentName: 'Messages',
                                onRetry: _load,
                              )
                            : _messages.isEmpty && _discussionMarkers.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: SelahEmptyState(
                                    icon: Icons.forum_outlined,
                                    title: 'Start the Shepherd Circle',
                                    message:
                                        'A private place for the Seeker and their linked Shepherds to talk together.',
                                  ),
                                ),
                              )
                            : _messageList(),
                      ),
                      if (_canPresentComposer && !_showTopicEntry)
                        _Composer(
                          controller: _composer,
                          busy: _sending,
                          selectedContext:
                              _discussionLayout ==
                                  SelahCircleTopicLayout.current
                              ? _selectedContext
                              : null,
                          contextEnabled:
                              _discussionLayout ==
                                  SelahCircleTopicLayout.current &&
                              _authority.canPreview &&
                              (_previewData == null ||
                                  (_previewData.contexts.isNotEmpty &&
                                      widget.onOpenContext != null)),
                          onChooseContext: _chooseContext,
                          onRemoveContext: () {
                            if (_canActOnCircleRoute &&
                                _discussionLayout ==
                                    SelahCircleTopicLayout.current) {
                              setState(() => _selectedContext = null);
                            }
                          },
                          onOpenContext:
                              _discussionLayout !=
                                  SelahCircleTopicLayout.current
                              ? null
                              : switch (_selectedContext) {
                                  final selected? => () {
                                    if (_discussionLayout ==
                                            SelahCircleTopicLayout.current &&
                                        identical(_selectedContext, selected)) {
                                      _openMessageContext(selected);
                                    }
                                  },
                                  null => null,
                                },
                          onSend: _send,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

  Widget _messageList() {
    final latestMine = _messages.lastIndexWhere(
      (message) => message.senderId == _currentSenderId && !message.lifecycle,
    );
    final firstUnread = _messages.indexWhere(
      (message) => message.unreadForMe && !message.lifecycle,
    );
    final children = <Widget>[const _TodayDivider()];
    void appendDiscussionMarkers(int afterMessageCount) {
      for (final marker in _discussionMarkers) {
        if (marker.afterMessageCount.clamp(0, _messages.length) !=
            afterMessageCount) {
          continue;
        }
        final target = _canActOnCircleRoute
            ? _discussionProfileFor(marker.topic)
            : null;
        children.add(
          SelahCircleDiscussionBubble(
            key: ValueKey('circle_discussion_marker_${marker.sequence}'),
            topic: marker.topic,
            onViewProfile: target == null
                ? null
                : () => _openDiscussionProfile(marker.topic, target),
          ),
        );
      }
    }

    appendDiscussionMarkers(0);
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (index == firstUnread) {
        children.add(const SelahUnreadMessagesDivider());
      }
      children.add(
        _FamilyMessageBubble(
          message: message,
          mine: message.senderId == _currentSenderId,
          showReceipt: index == latestMine,
          recipientCount: (_participantCount - 1).clamp(0, 99),
          canInteract: () => _canInteract,
          canOpen: () => _canActOnCircleRoute,
          sheetWrapper: _guardRoute,
          discussionTopic: _discussionMessageTags[message.id],
          onOpenContext: message.context == null
              ? null
              : () => _openMessageContext(message.context!),
          onReport:
              message.senderId != null && message.senderId != _currentSenderId
              ? () => _report(message)
              : null,
        ),
      );
      appendDiscussionMarkers(index + 1);
    }
    return ListView(
      controller: _topicOptionsEnabled ? _topicMessageScroll : null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      children: children,
    );
  }
}

class _ShepherdCircleCard extends StatelessWidget {
  final SelahShepherdCircleSummary circle;
  final VoidCallback onTap;

  const _ShepherdCircleCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.surfaceFill,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: SelahColors.actionFill.withValues(alpha: 0.16),
              child: Text(circle.seekerFirstName[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${circle.seekerFirstName}’s Shepherd Circle',
                    style: SelahText.body(size: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    circle.lastMessage ??
                        '${circle.participantCount} members · No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahText.subtext(size: 12),
                  ),
                ],
              ),
            ),
            if (circle.unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: SelahColors.actionFill,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${circle.unreadCount}',
                  style: SelahText.body(size: 11, color: Colors.black),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: SelahColors.ink(0.5)),
          ],
        ),
      ),
    ),
  );
}

class _CircleHeader extends StatelessWidget {
  final String title;
  final int participantCount;
  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onShowMembers;
  final VoidCallback onToggleMute;

  const _CircleHeader({
    required this.title,
    required this.participantCount,
    required this.muted,
    required this.onBack,
    required this.onShowMembers,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 5, 16, 9),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 23,
            color: SelahColors.foreground,
          ),
        ),
        const SizedBox(width: 3),
        Tooltip(
          message: 'Circle members',
          child: Material(
            color: SelahColors.surfaceEmphasisFill,
            shape: CircleBorder(
              side: BorderSide(color: SelahColors.surfaceEmphasisBorder),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onShowMembers,
              child: SizedBox.square(
                dimension: 42,
                child: Icon(
                  Icons.groups_2_outlined,
                  size: 21,
                  color: SelahColors.surfaceSignal,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.heading(size: 18.5),
              ),
              const SizedBox(height: 1),
              Text(
                '$participantCount ${participantCount == 1 ? 'member' : 'members'} · Private circle',
                style: SelahText.subtext(size: 10.5),
              ),
            ],
          ),
        ),
        _CircleHeaderActionButton(
          tooltip: muted
              ? 'Unmute circle notifications'
              : 'Mute circle notifications',
          icon: muted
              ? Icons.notifications_off_rounded
              : Icons.notifications_none_rounded,
          active: muted,
          onTap: onToggleMute,
        ),
      ],
    ),
  );
}

class _CircleHeaderActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CircleHeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: active
          ? SelahColors.actionFill.withValues(alpha: 0.20)
          : SelahColors.surfaceFill,
      shape: CircleBorder(
        side: BorderSide(
          color: active
              ? SelahColors.actionFill.withValues(alpha: 0.62)
              : SelahColors.surfaceBorder,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 42,
          child: Icon(
            icon,
            size: 21,
            color: active
                ? SelahColors.surfaceSignal
                : SelahColors.foregroundSecondary,
          ),
        ),
      ),
    ),
  );
}

class _CircleMembersSheet extends StatefulWidget {
  final String threadId;
  final int expectedCount;
  final List<SelahFamilyCircleParticipant>? previewParticipants;
  final bool Function()? canInteract;

  const _CircleMembersSheet({
    required this.threadId,
    required this.expectedCount,
    this.previewParticipants,
    this.canInteract,
  });

  @override
  State<_CircleMembersSheet> createState() => _CircleMembersSheetState();
}

class _CircleMembersSheetState extends State<_CircleMembersSheet> {
  bool _loading = true;
  bool _available = true;
  List<SelahFamilyCircleParticipant> _participants = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.canInteract?.call() == false) return;
    final preview = widget.previewParticipants;
    if (preview != null) {
      setState(() {
        _loading = false;
        _available = true;
        _participants = preview;
      });
      return;
    }
    setState(() => _loading = true);
    final result = await SelahFamilyMessagingService.fetchParticipants(
      widget.threadId,
    );
    if (!mounted || widget.canInteract?.call() == false) return;
    setState(() {
      _loading = false;
      _available = result.isAvailable;
      _participants = result.valueOr(const []);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.70,
      ),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: SelahColors.mentorSheetBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: SelahColors.ink(0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Circle members', style: SelahText.heading(size: 21)),
          const SizedBox(height: 5),
          Text(
            '${widget.expectedCount} ${widget.expectedCount == 1 ? 'person' : 'people'} in this private conversation.',
            style: SelahText.subtext(size: 12),
          ),
          const SizedBox(height: 17),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: SelahLoading()),
            )
          else if (!_available)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Members couldn't be loaded.",
                      style: SelahText.body(size: 14),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _participants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, index) =>
                    _CircleMemberRow(participant: _participants[index]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CircleMemberRow extends StatelessWidget {
  final SelahFamilyCircleParticipant participant;

  const _CircleMemberRow({required this.participant});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: SelahColors.surfaceBorder, width: 0.7),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SelahColors.actionFill.withValues(alpha: 0.12),
            border: Border.all(
              color: SelahColors.actionFill.withValues(alpha: 0.40),
            ),
          ),
          child: Text(
            participant.firstName.substring(0, 1).toUpperCase(),
            style: SelahText.body(size: 15, color: SelahColors.surfaceSignal),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(participant.firstName, style: SelahText.body(size: 14.5)),
              const SizedBox(height: 2),
              Text(participant.roleLabel, style: SelahText.subtext(size: 11.5)),
            ],
          ),
        ),
        if (participant.isCurrentUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: SelahColors.actionFill.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SelahColors.actionFill.withValues(alpha: 0.36),
              ),
            ),
            child: Text(
              'You',
              style: SelahText.subtext(
                size: 10.5,
                color: SelahColors.surfaceSignal,
              ),
            ),
          ),
      ],
    ),
  );
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(child: Divider(color: SelahColors.surfaceBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('TODAY', style: SelahText.chapterLabel()),
        ),
        Expanded(child: Divider(color: SelahColors.surfaceBorder)),
      ],
    ),
  );
}

class _FamilyMessageBubble extends StatelessWidget {
  final SelahFamilyMessage message;
  final bool mine;
  final bool showReceipt;
  final int recipientCount;
  final VoidCallback? onReport;
  final VoidCallback? onOpenContext;
  final bool Function()? canInteract;
  final bool Function()? canOpen;
  final Widget Function(BuildContext context, Widget sheet)? sheetWrapper;
  final SelahCircleDiscussionTopic? discussionTopic;

  const _FamilyMessageBubble({
    required this.message,
    required this.mine,
    required this.showReceipt,
    required this.recipientCount,
    this.onReport,
    this.onOpenContext,
    this.canInteract,
    this.canOpen,
    this.sheetWrapper,
    this.discussionTopic,
  });

  @override
  Widget build(BuildContext context) {
    if (message.lifecycle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          message.body,
          textAlign: TextAlign.center,
          style: SelahText.subtext(size: 11.5),
        ),
      );
    }
    final senderIdentity = message.senderIdentityLabel;
    return GestureDetector(
      onLongPress: onReport == null
          ? null
          : () async {
              if ((canOpen ?? canInteract)?.call() == false) return;
              final shouldReport = await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: SelahColors.modalSheetSurface,
                builder: (context) {
                  final sheet = SafeArea(
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Report this message'),
                      onTap: () {
                        if (canInteract?.call() != false) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  );
                  return sheetWrapper?.call(context, sheet) ?? sheet;
                },
              );
              if (shouldReport == true && canInteract?.call() != false) {
                onReport!();
              }
            },
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              margin: EdgeInsets.only(
                left: mine ? 34 : 0,
                right: mine ? 0 : 34,
              ),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              decoration: BoxDecoration(
                color: mine
                    ? SelahColors.actionFill.withValues(alpha: 0.20)
                    : SelahColors.surfaceFill,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 5),
                  bottomRight: Radius.circular(mine ? 5 : 18),
                ),
                border: Border.all(
                  color: mine
                      ? SelahColors.actionFill.withValues(alpha: 0.34)
                      : SelahColors.surfaceBorder,
                  width: 0.7,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine && senderIdentity != null) ...[
                    Text(
                      senderIdentity,
                      style: SelahText.subtext(
                        size: 11,
                        color: SelahColors.actionFill,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  if (message.context != null) ...[
                    _MessageContextCard(
                      context: message.context!,
                      compact: true,
                      onTap: onOpenContext,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (discussionTopic != null) ...[
                    SelahCircleTopicTag(topic: discussionTopic!),
                    const SizedBox(height: 8),
                  ],
                  Text(message.body, style: SelahText.body(size: 13.5)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _messageTime(message.createdAt),
                      style: SelahText.subtext(size: 9.5),
                    ),
                  ),
                ],
              ),
            ),
            if (showReceipt)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SelahMessageReceipt(
                  readBy: message.readBy
                      .map(
                        (reader) => SelahMessageReader(
                          userId: reader.userId,
                          firstName: reader.firstName,
                          roleLabel: reader.roleLabel,
                          readAt: reader.readAt,
                        ),
                      )
                      .toList(),
                  recipientCount: recipientCount,
                  canOpenReaders: canOpen ?? canInteract,
                  readersSheetWrapper: sheetWrapper,
                ),
              ),
            if (!showReceipt) const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  final SelahFamilyMessageAccess access;

  const _ReadOnlyBanner({required this.access});

  @override
  Widget build(BuildContext context) {
    final text = switch (access) {
      SelahFamilyMessageAccess.membershipRequired =>
        'This Circle is read-only. Every current member needs paid membership to send.',
      SelahFamilyMessageAccess.linkInactive =>
        'A linked Shepherd is needed before this Circle can be used.',
      SelahFamilyMessageAccess.blocked =>
        'Shepherd Circle messaging is closed by a safety restriction.',
      _ => 'Messaging is unavailable right now.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: SelahColors.surfaceFill,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: SelahText.subtext(),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool contextEnabled;
  final SelahFamilyMessageContext? selectedContext;
  final VoidCallback onChooseContext;
  final VoidCallback onRemoveContext;
  final VoidCallback? onOpenContext;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.busy,
    required this.contextEnabled,
    required this.selectedContext,
    required this.onChooseContext,
    required this.onRemoveContext,
    required this.onOpenContext,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
    child: Column(
      key: const ValueKey('shepherd-circle-composer'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedContext != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(7, 6, 4, 6),
            decoration: BoxDecoration(
              color: SelahColors.surfaceFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SelahColors.surfaceBorder, width: 0.7),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MessageContextCard(
                    context: selectedContext!,
                    onTap: onOpenContext,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove person',
                  onPressed: onRemoveContext,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: SelahColors.foregroundSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: SelahColors.surfaceFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SelahColors.surfaceBorder,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (contextEnabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: IconButton(
                          tooltip: 'Discuss someone',
                          onPressed: busy ? null : onChooseContext,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: selectedContext == null
                                ? Colors.transparent
                                : SelahColors.actionFill.withValues(
                                    alpha: 0.14,
                                  ),
                          ),
                          icon: Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 21,
                            color: selectedContext == null
                                ? SelahColors.foregroundSecondary
                                : SelahColors.surfaceSignal,
                          ),
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLength: 2000,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Message your circle',
                          hintStyle: SelahText.subtext(
                            size: 13.5,
                            color: SelahColors.ink(0.48),
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SelahColors.actionFill.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton.filled(
                tooltip: 'Send message',
                style: IconButton.styleFrom(
                  backgroundColor: SelahColors.actionFill,
                  foregroundColor: SelahColors.onAction,
                  disabledBackgroundColor: SelahColors.actionFill.withValues(
                    alpha: 0.45,
                  ),
                ),
                onPressed: busy ? null : onSend,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: SelahLoading(),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 23),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MessageContextPicker extends StatelessWidget {
  final List<SelahFamilyMessageContext> contexts;

  const _MessageContextPicker({required this.contexts});

  @override
  Widget build(BuildContext context) {
    final groups = <(SelahFamilyMessageContextKind, String)>[
      (SelahFamilyMessageContextKind.active, 'ACTIVE JOURNEYS'),
      (SelahFamilyMessageContextKind.potential, 'POTENTIAL'),
      (SelahFamilyMessageContextKind.paused, 'PAUSED'),
      (SelahFamilyMessageContextKind.ended, 'ENDED'),
    ];
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: SelahColors.mentorSheetBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: SelahColors.ink(0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Discuss someone', style: SelahText.heading(size: 21)),
            const SizedBox(height: 5),
            Text(
              'Add a person to your next message so everyone knows who the conversation is about.',
              style: SelahText.subtext(size: 12),
            ),
            const SizedBox(height: 17),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final group in groups)
                    if (contexts.any((item) => item.kind == group.$1)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 7),
                        child: Text(
                          group.$2,
                          style: SelahText.chapterLabel(
                            color: SelahColors.foregroundMuted,
                          ),
                        ),
                      ),
                      for (final item in contexts.where(
                        (candidate) => candidate.kind == group.$1,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _MessageContextChoice(item: item),
                        ),
                      const SizedBox(height: 2),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: SelahColors.foregroundMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Archived history is never available here.',
                    style: SelahText.subtext(size: 10.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageContextChoice extends StatelessWidget {
  final SelahFamilyMessageContext item;

  const _MessageContextChoice({required this.item});

  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.surfaceFill,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.of(context).pop(item),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: SelahColors.surfaceBorder, width: 0.7),
        ),
        child: Row(
          children: [
            _ContextAvatar(context: item, size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.firstName, style: SelahText.body(size: 14.5)),
                  const SizedBox(height: 2),
                  Text(item.stateLabel, style: SelahText.subtext(size: 11.5)),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              color: SelahColors.surfaceSignal,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageContextCard extends StatelessWidget {
  final SelahFamilyMessageContext context;
  final bool compact;
  final VoidCallback? onTap;

  const _MessageContextCard({
    required this.context,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: 'Open ${this.context.firstName} ${this.context.stateLabel}',
    child: Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: ValueKey('open-message-context-${this.context.referenceId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 8,
            vertical: compact ? 8 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: SelahColors.surfaceBorder, width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContextAvatar(context: this.context, size: compact ? 30 : 34),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      this.context.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SelahText.body(size: compact ? 12 : 12.5),
                    ),
                    Text(
                      this.context.stateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SelahText.subtext(size: compact ? 9.5 : 10),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 7),
                Icon(
                  Icons.chevron_right_rounded,
                  size: compact ? 16 : 18,
                  color: SelahColors.foregroundMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContextAvatar extends StatelessWidget {
  final SelahFamilyMessageContext context;
  final double size;

  const _ContextAvatar({required this.context, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: SelahColors.actionFill.withValues(alpha: 0.12),
      border: Border.all(color: SelahColors.actionFill.withValues(alpha: 0.40)),
    ),
    child: Text(
      this.context.firstName.substring(0, 1).toUpperCase(),
      style: SelahText.body(
        size: size * 0.36,
        color: SelahColors.surfaceSignal,
      ),
    ),
  );
}

String _messageTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
