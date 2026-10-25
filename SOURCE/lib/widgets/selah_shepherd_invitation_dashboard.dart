// Shared Shepherd invitation presentation for the dedicated Seeker and
// Shepherd manager flows. The legacy dashboard surface remains available to
// developer previews, but production Dashboards do not own lifecycle actions.
//
// The live backend still uses bearer invite codes: sent/pending invitations
// are queryable by their sender, while an incoming invitation is not known to
// SELAH until its code is entered. Code entry now lives inside the Shepherd
// page's Add a Shepherd flow; this manager module is only for invitations that
// already have a visible received or pending state. Developer-only addressed
// invitations remain clearly preview state.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/selah_reference_data.dart';
import '../dev/selah_dev_scenario.dart';
import '../screens/mentor/accept_shepherd_invite_screen.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_mentor_link_service.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_glass_dialog.dart';
import 'selah_state_widgets.dart';

enum SelahShepherdInvitationAudience { seeker, shepherd }

enum SelahShepherdInvitationSurface { dashboard, manager }

typedef ShepherdPendingInvitesLoader =
    Future<SelahSourceResult<List<PendingInvite>>> Function();

class SelahShepherdInvitationDashboard extends StatefulWidget {
  final SelahShepherdInvitationAudience audience;
  final bool includeHeading;
  final SelahShepherdInvitationSurface surface;

  /// Frozen only by governed visual fixtures. Production uses wall time.
  final DateTime? comparisonNow;

  /// Test seam for exercising source truth without contacting Supabase.
  /// Production callers leave this null and use the server-authoritative read.
  @visibleForTesting
  final ShepherdPendingInvitesLoader? pendingInvitesLoader;

  const SelahShepherdInvitationDashboard({
    super.key,
    required this.audience,
    this.includeHeading = true,
    this.surface = SelahShepherdInvitationSurface.dashboard,
    this.comparisonNow,
    this.pendingInvitesLoader,
  });

  @override
  State<SelahShepherdInvitationDashboard> createState() =>
      _SelahShepherdInvitationDashboardState();
}

class _SelahShepherdInvitationDashboardState
    extends State<SelahShepherdInvitationDashboard> {
  List<PendingInvite> _livePending = const [];
  bool _pendingAvailable = true;
  String? _error;
  String? _busyToken;
  PendingInvite? _failedCancel;
  String? _expandedToken;
  late bool _lastSeekerPreview;

  SelahDevScenario get _scenario => SelahDevScenario.instance;
  bool get _hasDeveloperPreview => SelahDeveloperAccess.canUseDeveloperTools;

  bool get _seekerPreview =>
      widget.audience == SelahShepherdInvitationAudience.seeker &&
      _hasDeveloperPreview &&
      !_scenario.useLiveShepherdData;

  String get _keyPrefix =>
      widget.surface == SelahShepherdInvitationSurface.manager
      ? 'manager-shepherd-invitations'
      : 'dashboard-shepherd-invitations';

  List<PendingInvite> get _pending {
    if (!_hasDeveloperPreview) return _livePending;
    if (widget.audience == SelahShepherdInvitationAudience.seeker) {
      return _scenario.useLiveShepherdData
          ? _livePending
          : SelahDevScenario.fakePending(_scenario.pendingInviteCount);
    }
    return SelahDevScenario.composeMentorSentInvites(real: _livePending);
  }

  List<({String from, String relationship, int daysAgo})> get _received =>
      _seekerPreview
      ? SelahDevScenario.fakeReceived(_scenario.receivedInviteCount)
      : const [];

  @override
  void initState() {
    super.initState();
    _lastSeekerPreview = _seekerPreview;
    if (_hasDeveloperPreview) _scenario.addListener(_onScenarioChanged);
    SelahMentorLinkService.invitationRevision.addListener(_onInvitationChanged);
    _loadPending();
  }

  @override
  void dispose() {
    _scenario.removeListener(_onScenarioChanged);
    SelahMentorLinkService.invitationRevision.removeListener(_onInvitationChanged);
    super.dispose();
  }

  void _onScenarioChanged() {
    if (!mounted) return;
    final preview = _seekerPreview;
    final becameLive = _lastSeekerPreview && !preview;
    _lastSeekerPreview = preview;
    setState(() {});
    if (becameLive) _loadPending();
  }

  void _onInvitationChanged() {
    if (mounted) _loadPending();
  }

  Future<void> _loadPending() async {
    if (_seekerPreview) {
      if (mounted) {
        setState(() {
          _pendingAvailable = true;
        });
      }
      return;
    }
    final result =
        await (widget.pendingInvitesLoader?.call() ??
            SelahMentorLinkService.fetchPendingInvitesResult());
    if (!mounted) return;
    if (result.isUnavailable) {
      // Keep the last authoritative rows visible. A failed refresh must not
      // erase invitations or turn them into a genuine empty-state claim.
      setState(() {
        _pendingAvailable = false;
      });
      return;
    }
    setState(() {
      _livePending = result.valueOr(const []);
      _pendingAvailable = true;
    });
  }

  Future<void> _reviewReceived(
    ({String from, String relationship, int daysAgo}) invite,
  ) async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AcceptShepherdInviteScreen(
          from: invite.from,
          theirAnswer: invite.relationship,
        ),
      ),
    );
    if (accepted == true) _scenario.consumeReceivedInvite();
  }

  Future<void> _declineReceived(
    ({String from, String relationship, int daysAgo}) invite,
  ) async {
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.person_remove_outlined,
      title: 'Decline ${invite.from}’s invitation?',
      body:
          'This closes the preview invitation. You can still link later '
          'through a new invite code.',
      primaryLabel: 'Decline invitation',
      secondaryLabel: 'Keep invitation',
    );
    if (confirmed == true) _scenario.consumeReceivedInvite();
  }

  Future<void> _cancelPending(PendingInvite invite) async {
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.link_off_outlined,
      title: 'Cancel this invitation?',
      body:
          'Its code will stop working. A new invitation can be created '
          'whenever you are ready.',
      primaryLabel: 'Cancel invitation',
      secondaryLabel: 'Keep invitation',
    );
    if (confirmed != true || !mounted) return;

    final synthetic = invite.token.startsWith('DEV');
    if (synthetic) {
      if (widget.audience == SelahShepherdInvitationAudience.seeker) {
        _scenario.consumePendingInvite();
      } else {
        _scenario.setMentorSentInvites(_scenario.mentorSentInvites - 1);
      }
      return;
    }

    await _revokePending(invite);
  }

  Future<void> _revokePending(PendingInvite invite) async {
    if (!mounted) return;
    setState(() {
      _busyToken = invite.token;
      _failedCancel = null;
      _error = null;
    });
    final cancelled = await SelahMentorLinkService.revokeInvite(invite.token);
    if (!mounted) return;
    if (!cancelled) {
      setState(() {
        _busyToken = null;
        _failedCancel = invite;
        _error = "That invitation couldn't be cancelled.";
      });
      return;
    }
    setState(() {
      _busyToken = null;
      _failedCancel = null;
      _error = null;
      _livePending = [
        for (final pending in _livePending)
          if (pending.token != invite.token) pending,
      ];
    });
    if (_hasDeveloperPreview &&
        widget.audience == SelahShepherdInvitationAudience.shepherd) {
      _scenario.setMentorSentInvites(_scenario.mentorSentInvites - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = _received;
    final pending = _pending;
    final pendingUnavailable = !_seekerPreview && !_pendingAvailable;

    if (received.isEmpty &&
        pending.isEmpty &&
        _error == null &&
        !pendingUnavailable) {
      return SizedBox.shrink(
        key: ValueKey('$_keyPrefix-${widget.audience.name}-empty'),
      );
    }

    // The initial in-flight read is intentionally silent: this module must not
    // hold the whole Dashboard hostage. A completed unavailable read is not
    // silent below, and therefore can never masquerade as genuine empty.
    return Padding(
      key: ValueKey('$_keyPrefix-${widget.audience.name}'),
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.includeHeading) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 9),
              child: Text(
                'SHEPHERD INVITATIONS',
                style: SelahText.chapterLabel(color: SelahColors.ink(0.58)),
              ),
            ),
          ],
          if (received.isNotEmpty || pending.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: SelahColors.surfaceFill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SelahColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < received.length; index++) ...[
                        _ReceivedInvitationRow(
                          key: ValueKey('shepherd-invite-received-$index'),
                          invite: received[index],
                          onReview: () => _reviewReceived(received[index]),
                          onDecline: () => _declineReceived(received[index]),
                        ),
                        if (index < received.length - 1 || pending.isNotEmpty)
                          const _InvitationDivider(),
                      ],
                      for (var index = 0; index < pending.length; index++) ...[
                        _PendingInvitationRow(
                          key: ValueKey(
                            'shepherd-invite-pending-${pending[index].token}',
                          ),
                          invite: pending[index],
                          busy: _busyToken == pending[index].token,
                          manager:
                              widget.surface ==
                              SelahShepherdInvitationSurface.manager,
                          expanded: _expandedToken == pending[index].token,
                          comparisonNow: widget.comparisonNow ?? DateTime.now(),
                          onView: () => setState(() {
                            _expandedToken =
                                _expandedToken == pending[index].token
                                ? null
                                : pending[index].token;
                          }),
                          onCancel: () => _cancelPending(pending[index]),
                        ),
                        if (index < pending.length - 1)
                          const _InvitationDivider(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (pendingUnavailable) ...[
            if (received.isNotEmpty || pending.isNotEmpty)
              const SizedBox(height: 9),
            SelahErrorBanner(
              key: ValueKey('$_keyPrefix-${widget.audience.name}-unavailable'),
              message: 'Shepherd invitations could not be refreshed.',
              onRetry: _loadPending,
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 9),
            SelahErrorBanner(
              message: error,
              onRetry: _failedCancel == null
                  ? _loadPending
                  : () => _revokePending(_failedCancel!),
              onDismiss: () => setState(() {
                _error = null;
                _failedCancel = null;
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceivedInvitationRow extends StatelessWidget {
  final ({String from, String relationship, int daysAgo}) invite;
  final VoidCallback onReview;
  final VoidCallback onDecline;

  const _ReceivedInvitationRow({
    super.key,
    required this.invite,
    required this.onReview,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final role = selahRelationshipLabel(invite.relationship) ?? 'Shepherd';
    final when = invite.daysAgo == 0
        ? 'Today'
        : '${invite.daysAgo} ${invite.daysAgo == 1 ? 'day' : 'days'} ago';
    return _InvitationRowShell(
      icon: Icons.person_add_alt_1_outlined,
      emphasized: true,
      title: '${invite.from} invited you',
      detail: '$role · $when · Preview',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _InvitationAction(label: 'Review', onTap: onReview),
          _InvitationAction(label: 'Decline', onTap: onDecline, quiet: true),
        ],
      ),
    );
  }
}

class _PendingInvitationRow extends StatelessWidget {
  final PendingInvite invite;
  final bool busy;
  final bool manager;
  final bool expanded;
  final DateTime comparisonNow;
  final VoidCallback onView;
  final VoidCallback onCancel;

  const _PendingInvitationRow({
    super.key,
    required this.invite,
    required this.busy,
    required this.manager,
    required this.expanded,
    required this.comparisonNow,
    required this.onView,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final days = invite.daysLeftAt(comparisonNow);
    final expiry = days == null
        ? 'Awaiting response'
        : days == 0
        ? 'Awaiting response · Expires today'
        : 'Awaiting response · $days ${days == 1 ? 'day' : 'days'} left';
    return Column(
      children: [
        _InvitationRowShell(
          icon: Icons.schedule_outlined,
          title: invite.label?.trim().isNotEmpty == true
              ? invite.label!.trim()
              : 'Invite ${invite.token}',
          detail: expiry,
          trailing: manager
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _InvitationAction(
                      label: expanded ? 'Close' : 'View',
                      onTap: onView,
                    ),
                    _InvitationAction(
                      label: busy ? 'Cancelling…' : 'Cancel',
                      onTap: busy ? null : onCancel,
                      quiet: true,
                    ),
                  ],
                )
              : _InvitationAction(
                  label: busy ? 'Cancelling…' : 'Cancel',
                  onTap: busy ? null : onCancel,
                  quiet: true,
                ),
        ),
        if (manager && expanded)
          Container(
            key: ValueKey('shepherd-invite-detail-${invite.token}'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                _InvitationDetail(label: 'Code', value: invite.token),
                const SizedBox(height: 7),
                _InvitationDetail(
                  label: 'Created',
                  value: _dateLabel(invite.createdAt),
                ),
                const SizedBox(height: 7),
                _InvitationDetail(
                  label: 'Expires',
                  value: invite.expiresAt == null
                      ? 'No expiry recorded'
                      : _dateLabel(invite.expiresAt!),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class _InvitationDetail extends StatelessWidget {
  final String label;
  final String value;

  const _InvitationDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 62,
        child: Text(label, style: SelahText.subtext(size: 11.25)),
      ),
      Expanded(child: Text(value, style: SelahText.body(size: 12.25))),
    ],
  );
}

class _InvitationRowShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Widget trailing;
  final bool emphasized;

  const _InvitationRowShell({
    required this.icon,
    required this.title,
    required this.detail,
    required this.trailing,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: emphasized ? SelahColors.surfaceEmphasisFill : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      child: Row(
        children: [
          _InvitationIcon(icon: icon, emphasized: emphasized),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.body(size: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.subtext(size: 11.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _InvitationIcon extends StatelessWidget {
  final IconData icon;
  final bool emphasized;

  const _InvitationIcon({required this.icon, this.emphasized = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: emphasized
          ? SelahColors.surfaceSignal.withValues(alpha: 0.16)
          : SelahColors.iconButtonBg,
      border: Border.all(color: SelahColors.iconButtonBorder),
    ),
    child: Icon(
      icon,
      size: 18,
      color: emphasized ? SelahColors.surfaceSignal : SelahColors.foreground,
    ),
  );
}

class _InvitationAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool quiet;

  const _InvitationAction({
    required this.label,
    required this.onTap,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: SelahText.button(
              size: 11,
              color: quiet ? SelahColors.ink(0.60) : SelahColors.surfaceSignal,
            ),
          ),
        ),
      ),
    ),
  );
}

class _InvitationDivider extends StatelessWidget {
  const _InvitationDivider();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 61),
    color: SelahColors.surfaceBorder,
  );
}
