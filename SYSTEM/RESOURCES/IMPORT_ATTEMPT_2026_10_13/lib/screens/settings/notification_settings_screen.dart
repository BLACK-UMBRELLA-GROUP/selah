// Notification preferences.
//
// REBUILT 2026-08-06. The previous version's own header said the toggles
// were "honest" about being local-only: they wrote to AppState and nowhere
// else, so every choice was lost on restart.
//
// That was tolerable for three product notifications. It stopped being
// tolerable when the Founder's Settings brief added Marketing Emails and
// Product Updates, because those are not preferences — under UK GDPR and
// PECR they are records of CONSENT. A consent switch that forgets means the
// consent was never recorded, a withdrawal is never honoured, and neither
// can be evidenced.
//
// Now backed by `notification_preferences`, which is append-only: every
// change is a new row and nothing is ever updated or deleted, so opting in,
// withdrawing and opting in again all survive. A single mutable row could
// only prove the most recent one.
//
// Defaults come from the server, not from here — marketing and product
// updates default OFF, because a pre-ticked consent box is not consent.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_notification_prefs_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_loading.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final SelahPromotionRole role;
  final Future<Map<SelahNotifyCategory, bool>?> Function()? loadPreferences;
  final Future<bool> Function(SelahNotifyCategory, bool)? savePreference;

  const NotificationSettingsScreen({
    super.key,
    this.role = SelahPromotionRole.seeker,
    this.loadPreferences,
    this.savePreference,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<SelahNotifyCategory, bool>? _values;
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;
  final Set<SelahNotifyCategory> _saving = {};

  String? _ownerId() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null; // Local preview or widget test without a client.
    }
  }

  bool _sameOwner(String? owner, int generation) =>
      !SelahAccountState.isSigningOut &&
      SelahAccountState.generation == generation &&
      _ownerId() == owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    setState(() {
      _loading = true;
      _values = null;
      _saving.clear();
      _error = null;
    });
    Map<SelahNotifyCategory, bool>? v;
    try {
      v =
          await (widget.loadPreferences?.call() ??
              SelahNotificationPrefsService.fetch());
    } catch (_) {
      v = null;
    }
    // The RPC is expected to include every category, including consent
    // defaults. A partial response is not permission to invent an off value.
    if (v != null &&
        SelahNotifyCategory.values.any(
          (category) => !v!.containsKey(category),
        )) {
      v = null;
    }
    if (!mounted) return;
    if (request != _loadRequest) return;
    if (!_sameOwner(owner, generation)) v = null;
    setState(() {
      _values = v == null ? null : Map.of(v);
      _loading = false;
      _error = v == null ? "We couldn't load your preferences." : null;
    });
  }

  /// Optimistic, but ONLY until the write comes back.
  ///
  /// If the save fails the switch goes back and the user is told. Leaving a
  /// consent switch showing "on" for a consent that was never recorded is
  /// the one outcome worse than the switch appearing not to work.
  Future<void> _set(SelahNotifyCategory c, bool v) async {
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    final loadRequest = _loadRequest;
    final previous = _values![c]!;
    setState(() {
      _values![c] = v;
      _saving.add(c);
      _error = null;
    });

    var ok = false;
    try {
      ok =
          await (widget.savePreference?.call(c, v) ??
              SelahNotificationPrefsService.set(c, v));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (loadRequest != _loadRequest) return;
    if (!_sameOwner(owner, generation)) {
      // A previous account's completion cannot publish a preference, a
      // consent failure message, or a promotion event into the new account.
      setState(() {
        _values = null;
        _saving.clear();
        _error = "We couldn't load your preferences.";
      });
      return;
    }
    setState(() {
      _saving.remove(c);
      if (!ok) {
        _values![c] = previous;
        _error = c.isConsent
            ? "We couldn't record that. Your preference is unchanged — "
                  'please try again.'
            : "That didn't save. Please try again.";
      }
    });
    if (ok) {
      SelahPromotionEngine.instance.recordPreferenceChanged(
        role: widget.role,
        categoryCode: c.code,
        marketing: c.isConsent,
        enabled: v,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const product = [
      SelahNotifyCategory.matchesJourneys,
      SelahNotifyCategory.shepherdActivity,
      SelahNotifyCategory.introductions,
    ];
    const consent = [
      SelahNotifyCategory.productUpdates,
      SelahNotifyCategory.marketingEmails,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Notifications', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: _loading
              ? const SelahLoading()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
                  children: [
                    if (_error != null) ...[
                      SelahErrorBanner(
                        message: _error!,
                        onRetry: _values == null ? _load : null,
                        onDismiss: _values == null
                            ? null
                            : () => setState(() => _error = null),
                      ),
                      SizedBox(height: 18),
                    ],

                    if (_values != null) ...[
                      const _DeviceNotificationStatus(),
                      SizedBox(height: 28),

                      Text(
                        'SERVICE NOTIFICATIONS',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.role == SelahPromotionRole.seeker
                            ? 'Matches, Journeys and Shepherd activity that need your attention.'
                            : 'Seeker links, Journey activity and introductions that need your attention.',
                        style: SelahText.subtext(
                          size: 11.5,
                          color: SelahColors.ink(0.38),
                        ),
                      ),
                      SizedBox(height: 12),
                      ...product.map(_row),

                      SizedBox(height: 28),
                      // Separated, and labelled as consent rather than as
                      // preference. They are a different kind of decision and
                      // presenting them identically would obscure that.
                      Text(
                        'MARKETING',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Off unless you turn them on. You can withdraw at any '
                        'time, and we keep a record of both.',
                        style: SelahText.subtext(
                          size: 11.5,
                          color: SelahColors.ink(0.38),
                        ),
                      ),
                      SizedBox(height: 12),
                      ...consent.map(_row),

                      SizedBox(height: 28),
                      Text(
                        'ACCOUNT & SAFETY',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 10),
                      const _EssentialNotificationRow(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _row(SelahNotifyCategory c) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: _ToggleRow(
      label: c.label,
      subtitle: c.hint,
      value: _values![c]!,
      busy: _saving.contains(c),
      onChanged: (v) => _set(c, v),
    ),
  );
}

class _DeviceNotificationStatus extends StatelessWidget {
  const _DeviceNotificationStatus();

  @override
  Widget build(BuildContext context) {
    final state = SelahPromotionEngine.instance.permissionState;
    final enabled = state == SelahNotificationPermissionState.enabled;
    final unavailable = state == SelahNotificationPermissionState.unavailable;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SelahColors.foreground.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.ink(0.12), width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: enabled ? SelahColors.unlockDot : SelahColors.ink(0.38),
            size: 20,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Device notifications',
                        style: SelahText.body(size: 14, color: Colors.white),
                      ),
                    ),
                    Text(
                      enabled
                          ? 'On'
                          : unavailable
                          ? 'Not connected'
                          : 'Off',
                      style: SelahText.subtext(
                        size: 11,
                        color: enabled
                            ? SelahColors.unlockDot
                            : SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  unavailable
                      ? 'Device alerts are not connected in this preview. Updates in My SELAH still work.'
                      : enabled
                      ? 'SELAH can alert you outside the app. Category choices below still decide what you receive.'
                      : 'Device alerts are off. Updates in My SELAH still work.',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.54),
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

class _EssentialNotificationRow extends StatelessWidget {
  const _EssentialNotificationRow();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SelahColors.foreground.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SelahColors.ink(0.10), width: 0.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 18, color: SelahColors.ink(0.54)),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Essential account notices',
                style: SelahText.body(size: 13.5, color: Colors.white),
              ),
              SizedBox(height: 3),
              Text(
                'Security, account and safety notices have no marketing switch. SELAH keeps an in-app route even if device alerts are off.',
                style: SelahText.subtext(
                  size: 11.5,
                  color: SelahColors.ink(0.54),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SelahText.body(size: 15, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.38),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Disabled while in flight. A switch you can flip again before the
          // first write lands is how a consent log ends up with events in an
          // order nobody intended.
          Switch(
            value: value,
            onChanged: busy ? null : onChanged,
            activeThumbColor: SelahColors.accentBorder,
          ),
        ],
      ),
    );
  }
}
