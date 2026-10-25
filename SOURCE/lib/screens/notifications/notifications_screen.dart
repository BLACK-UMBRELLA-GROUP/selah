// Notification feed (#16) — opened from the Bell icon
// (widgets/notification_bell.dart). Shared by both Seeker and Mentor
// accounts; the underlying `notifications` table doesn't distinguish
// role, just whichever profile the event was for.
//
// Deep-linking a tapped notification to its Journey/match (Seeker's
// journey_flow_screen vs Mentor's mentor_journey_detail_screen are
// different screens with different data shapes) is out of scope for
// this pass — tapping a row marks it read only. Now tracked properly as
// inherited upstream action 216 (the Founder's "Go" button), deliberately NOT built in the
// same pass as this one: its routing table has to be checked against
// inherited upstream action 161's safety rules first, because a destination is a tell in
// exactly the way wording is.
//
// 2026-08-13, inherited decision 154 — THIS SCREEN AND THE NAV DOTS ARE TWO
// SYSTEMS. The dots answer "is there anything over there?" and clear
// when you arrive in that section. This screen answers "what actually
// happened?" and clears only when you act. They share `read_at` and
// nothing else, and this screen is the one place arriving marks
// nothing — opening it is not reading it, which is what leaves Mark all
// read something to do.
//
// SELECTION MODE added the same day (Founder: Select All + Mark All as
// Read, both disabled and visibly non-pressable when there is nothing
// to act on). The disabled state is drawn rather than hidden on
// purpose: a control that vanishes when it has no work teaches nobody
// it exists, and the Founder asked for "unavailable", not "absent".

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_notification_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_loading.dart';

typedef SelahNotificationsLoader = Future<List<SelahNotification>?> Function();

class NotificationsScreen extends StatefulWidget {
  /// True when living as the nav bar's fifth tab (inherited decision 149) rather
  /// than a pushed route: hides the AppBar back arrow (popping here
  /// would pop HomeShell itself) and pads the list clear of the
  /// floating nav pill.
  final bool isTab;
  final SelahNotificationsLoader? loadNotifications;

  const NotificationsScreen({
    super.key,
    this.isTab = false,
    this.loadNotifications,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<SelahNotification> _items = [];
  late final String? _ownerUserId;
  late final int _ownerGeneration;
  int _loadRevision = 0;

  bool get _currentAccount =>
      SelahAccountState.userId == _ownerUserId &&
      SelahAccountState.generation == _ownerGeneration;

  /// BUG-05 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15): true
  /// when the LAST fetch failed. Failure used to render as the empty
  /// state — "All caught up" — which is misleading exactly when the
  /// person needs to retry. A failed refresh with rows already on
  /// screen keeps showing them (stale beats blank); a failed first
  /// load shows an honest error with a retry.
  bool _loadFailed = false;

  /// Selection mode, and what is selected. Ids rather than objects so a
  /// refresh mid-selection cannot leave a stale row selected.
  bool _selecting = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _ownerUserId = SelahAccountState.userId;
    _ownerGeneration = SelahAccountState.generation;
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A substituted loader is a new read source (used by local fixtures).
    // Do not let its previous in-flight request publish after this one.
    if (oldWidget.loadNotifications != widget.loadNotifications) _load();
  }

  Future<void> _load() async {
    if (!_currentAccount) return;
    final revision = ++_loadRevision;
    final loader =
        widget.loadNotifications ?? SelahNotificationService.fetchRecent;
    final items = await loader();
    if (mounted && revision == _loadRevision && _currentAccount) {
      setState(() {
        if (items == null) {
          // Fetch FAILED — keep whatever we already had. See [_loadFailed].
          _loadFailed = true;
        } else {
          _loadFailed = false;
          _items = items;
          // Drop anything that no longer exists — see [_selected].
          _selected.removeWhere((id) => !items.any((n) => n.id == id));
        }
        _loading = false;
      });
    }
  }

  void _retry() {
    if (!_currentAccount) return;
    setState(() => _loading = true);
    _load();
  }

  Future<void> _markAllRead() async {
    if (!_currentAccount) return;
    await SelahNotificationService.markAllRead();
    if (!_currentAccount) return;
    await _load();
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      // Leaving selection mode drops the selection with it. Keeping it
      // would mean a hidden set of chosen rows waiting to surprise
      // whoever presses Select next.
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleOne(SelahNotification n) {
    setState(() {
      if (!_selected.add(n.id)) _selected.remove(n.id);
    });
  }

  /// Select all / Deselect all on one control — it flips once everything
  /// is chosen, so the button is never a no-op you have to notice.
  void _selectAll() {
    setState(() {
      if (_selected.length == _items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_items.map((n) => n.id));
      }
    });
  }

  Future<void> _markSelectedRead() async {
    if (_selected.isEmpty || !_currentAccount) return;
    // One statement, not a loop — see markManyRead. Selection mode
    // closes on success, because the work it was opened for is done.
    await SelahNotificationService.markManyRead(_selected.toList());
    if (!mounted || !_currentAccount) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    await _load();
  }

  Future<void> _tap(SelahNotification n) async {
    if (!_currentAccount) return;
    if (_selecting) {
      _toggleOne(n);
      return;
    }
    if (!n.isRead) {
      await SelahNotificationService.markRead(n.id);
      if (!_currentAccount) return;
      await _load();
    }
  }

  @override
  void dispose() {
    ++_loadRevision;
    super.dispose();
  }

  // 2026-07-26: check_circle_outline replaces favorite_border (Founder:
  // app-wide heart-icon removal) — outline variant matches this
  // switch's other three entries.
  static IconData _iconFor(String type) => switch (type) {
    'new_match' => Icons.check_circle_outline,
    'new_message' => Icons.forum_outlined,
    'mentor_request' => Icons.shield_outlined,
    'mentor_invite_received' => Icons.mark_email_unread_outlined,
    'mentor_invite_declined' => Icons.person_off_outlined,
    'mentor_invite_expiring' => Icons.hourglass_top_rounded,
    'mentor_invite_expired' => Icons.event_busy_outlined,
    'mentor_invite_revoked' => Icons.link_off_outlined,
    _ => Icons.notifications_outlined,
  };

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      // FIXED 2026-07-27 (Founder, screenshot: "the purple at top doesn't
      // suit so I'd rather the pink/purple takes whole screen"). Without
      // extendBodyBehindAppBar, the body (which carries the gender
      // gradient) starts below the AppBar, so the transparent AppBar's
      // row + status bar just showed the Scaffold's own flat background
      // colour through — a solid purple strip cutting off the gradient.
      // Now the gradient Container fills the entire screen behind the
      // AppBar, and the scrollable content below gets manual top padding
      // (status bar + toolbar height) instead of relying on SafeArea's
      // top inset, which alone only accounts for the status bar.
      extendBodyBehindAppBar: true,
      // AS A TAB (inherited decision 150, Founder: "make notifications one be same
      // as connections and shepherd one"): no AppBar at all — the title
      // renders in the body, top-LEFT at heading size, exactly the
      // header language Connections and Shepherd speak. The pushed form
      // (the Mentor side's Bell still pushes this screen) keeps its
      // AppBar and back arrow.
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('Notifications', style: SelahText.heading(size: 17)),
              iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
              // The Mark-all action left this row on 2026-08-13
              // (inherited decision 154): both forms of this screen now draw one
              // action strip in the body, so the pushed version and the
              // tab version cannot drift into offering different
              // controls.
            ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          top: widget.isTab,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The Connections/Shepherd header, spoken here too — same
              // padding, same heading size, title top-left. Mark all
              // read keeps its seat on the row's right.
              if (widget.isTab)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: SelahText.heading(size: 26),
                        ),
                      ),
                      if (_selecting)
                        Text(
                          '${_selected.length} selected',
                          style: SelahText.subtext(
                            size: 12.5,
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                    ],
                  ),
                ),
              // THE ACTION STRIP — drawn in BOTH forms, and drawn even
              // when every control in it is dead. The Founder asked for
              // "unavailable/non-pressable", not absent: a button that
              // disappears when it has no work never teaches anyone it
              // is there, and this screen's whole job is to be the place
              // notifications are managed.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.isTab
                      ? 4
                      : MediaQuery.of(context).padding.top + kToolbarHeight,
                  20,
                  8,
                ),
                child: Row(
                  children: [
                    if (!_selecting) ...[
                      _StripAction(
                        label: 'Select',
                        icon: Icons.checklist_rtl,
                        // Nothing to select is the disabled case the
                        // Founder named. Not "no unread" — you can
                        // legitimately want to select rows you have
                        // already read.
                        enabled: _items.isNotEmpty,
                        onTap: _toggleSelecting,
                      ),
                      SizedBox(width: 8),
                      _StripAction(
                        label: 'Mark all read',
                        icon: Icons.done_all,
                        enabled: hasUnread,
                        onTap: _markAllRead,
                      ),
                    ] else ...[
                      _StripAction(
                        label: _selected.length == _items.length
                            ? 'Deselect all'
                            : 'Select all',
                        icon: Icons.select_all,
                        enabled: _items.isNotEmpty,
                        onTap: _selectAll,
                      ),
                      SizedBox(width: 8),
                      _StripAction(
                        label: 'Mark read',
                        icon: Icons.done_all,
                        enabled: _selected.isNotEmpty,
                        onTap: _markSelectedRead,
                      ),
                      SizedBox(width: 8),
                      _StripAction(
                        label: 'Cancel',
                        icon: Icons.close,
                        enabled: true,
                        onTap: _toggleSelecting,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: _loading
                      ? const SelahLoading()
                      // BUG-05: a failed FIRST load is an error, not an empty
                      // feed — "All caught up" only ever describes a successful
                      // read. With rows already on screen, a failed refresh
                      // falls through and keeps showing them.
                      : _loadFailed && _items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SelahEmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: "Couldn't load notifications",
                            message: 'Check your connection.',
                            ctaLabel: 'Try again',
                            onCta: _retry,
                          ),
                        )
                      : _items.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: SelahEmptyState(
                            icon: Icons.notifications_none,
                            // 2026-08-13 (ChatGPT review): the state, then
                            // the fact. Same icon, same layout.
                            title: 'All caught up',
                            message: 'No new notifications.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final n = _items[i];
                            final picked = _selected.contains(n.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _tap(n),
                                  // Long-press opens selection mode with
                                  // this row already chosen — the gesture
                                  // people try first, and it saves a trip to
                                  // the strip to select one thing.
                                  onLongPress: _selecting
                                      ? null
                                      : () => setState(() {
                                          _selecting = true;
                                          _selected.add(n.id);
                                        }),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: n.isRead
                                          ? SelahColors.iconButtonBg
                                          : SelahColors.accentBg,
                                      border: Border.all(
                                        // A picked row outlines white rather
                                        // than changing fill: unread already
                                        // owns the fill, and one row cannot
                                        // say two things with one colour.
                                        color: picked
                                            ? SelahColors.foreground.withValues(
                                                alpha: 0.7,
                                              )
                                            : n.isRead
                                            ? SelahColors.iconButtonBorder
                                            : SelahColors.accentBorder,
                                        width: picked ? 1.2 : 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _selecting
                                              ? (picked
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked)
                                              : _iconFor(n.type),
                                          color: SelahColors.ink(0.70),
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: SelahText.body(
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (n.body != null &&
                                                  n.body!.isNotEmpty) ...[
                                                SizedBox(height: 3),
                                                Text(
                                                  n.body!,
                                                  style: SelahText.subtext(
                                                    size: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          _timeAgo(n.createdAt),
                                          style: SelahText.subtext(size: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One control in the Notifications action strip.
///
/// DISABLED IS DRAWN, NOT HIDDEN (Founder, 2026-08-13: "buttons should
/// appear unavailable/non-pressable"). Dimmed to 0.32, and with a null
/// onTap rather than a guard inside the callback — a disabled control
/// that still ripples under a press has told the person it worked.
class _StripAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StripAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SelahColors.foreground.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SelahColors.foreground.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(label, style: SelahText.button(size: 12, color: Colors.white)),
        ],
      ),
    );

    if (!enabled) {
      return Semantics(
        enabled: false,
        label: '$label, unavailable',
        child: Opacity(opacity: 0.32, child: content),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
