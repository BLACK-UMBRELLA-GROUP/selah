import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../models/seeker_profile.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_hidden_profile_store.dart';
import '../../services/selah_report_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_glass_dialog.dart';

class HiddenProfilesScreen extends StatefulWidget {
  final Future<List<String>?> Function()? loadServerIds;
  final Future<List<SeekerProfile>> Function(List<String>)? loadProfiles;
  final Future<bool> Function(String)? unhideServerProfile;

  const HiddenProfilesScreen({
    super.key,
    this.loadServerIds,
    this.loadProfiles,
    this.unhideServerProfile,
  });

  @override
  State<HiddenProfilesScreen> createState() => _HiddenProfilesScreenState();
}

class _HiddenProfilesScreenState extends State<HiddenProfilesScreen> {
  bool _loading = true;
  bool _unavailable = false;
  int _loadRequest = 0;
  List<SelahHiddenProfileRecord> _hidden = [];
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _ownerId() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      // Pre-auth developer previews and widget tests have no client yet.
      return null;
    }
  }

  bool _sameOwner(String? owner, int generation) =>
      SelahAccountState.generation == generation &&
      !SelahAccountState.isSigningOut &&
      _ownerId() == owner;

  bool _currentLoad(int request, String? owner, int generation) =>
      mounted && _loadRequest == request && _sameOwner(owner, generation);

  void _showUnavailable(int request) {
    if (!mounted || _loadRequest != request) return;
    setState(() {
      _hidden = [];
      _unavailable = true;
      _loading = false;
    });
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    setState(() {
      _hidden = [];
      _unavailable = false;
      _loading = true;
    });
    try {
      final serverIds =
          await (widget.loadServerIds?.call() ??
              SelahReportService.blockedIdsOrNull());
      if (!_currentLoad(request, owner, generation) || serverIds == null) {
        _showUnavailable(request);
        return;
      }

      // Usually empty because mutual-block RLS makes a blocked profile
      // unreadable. Prefer the account-scoped summary captured at hide time.
      final readableProfiles =
          await (widget.loadProfiles?.call(serverIds) ??
              SelahDiscoveryService.profilesByIds(serverIds));
      if (!_currentLoad(request, owner, generation)) {
        _showUnavailable(request);
        return;
      }
      for (final profile in readableProfiles) {
        if (!_currentLoad(request, owner, generation)) {
          _showUnavailable(request);
          return;
        }
        await SelahHiddenProfileStore.remember(profile);
      }
      if (!_currentLoad(request, owner, generation)) {
        _showUnavailable(request);
        return;
      }
      final cached = await SelahHiddenProfileStore.records();
      if (!_currentLoad(request, owner, generation)) {
        _showUnavailable(request);
        return;
      }
      final byId = {for (final record in cached) record.id: record};
      final records = <SelahHiddenProfileRecord>[
        for (final id in serverIds)
          byId[id] ?? SelahHiddenProfileRecord.fallback(id),
        // Non-UUID profiles are developer previews and never reach Supabase.
        for (final record in cached)
          if (record.isDemo) record,
      ];
      setState(() {
        _hidden = records;
        _loading = false;
      });
    } catch (_) {
      _showUnavailable(request);
    }
  }

  Future<void> _unhide(SelahHiddenProfileRecord profile) async {
    if (_working.contains(profile.id)) return;
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    setState(() => _working.add(profile.id));
    var ok = profile.isDemo;
    if (!profile.isDemo) {
      try {
        ok =
            await (widget.unhideServerProfile?.call(profile.id) ??
                SelahReportService.unblock(profile.id));
      } catch (_) {
        ok = false;
      }
    }
    if (!mounted) return;
    if (!_sameOwner(owner, generation)) {
      _showUnavailable(_loadRequest);
      _working.remove(profile.id);
      return;
    }
    if (ok) await SelahHiddenProfileStore.forget(profile.id);
    if (!mounted) return;
    if (!_sameOwner(owner, generation)) {
      _showUnavailable(_loadRequest);
      _working.remove(profile.id);
      return;
    }
    setState(() {
      _working.remove(profile.id);
      if (ok) _hidden.removeWhere((record) => record.id == profile.id);
    });
    if (ok) {
      AppState.instance.refreshBrowseDeck();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profile.isDemo
                ? 'Preview profile restored locally.'
                : '${profile.firstName} can appear in Browse again.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("That didn't go through. Please try again."),
      ),
    );
  }

  Future<void> _confirmUnhide(SelahHiddenProfileRecord profile) async {
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.visibility_outlined,
      title: 'Unhide ${profile.firstName}?',
      body:
          'You may see each other in Browse again. Any report stays with '
          'SELAH, and any Journey ended by the hide will not be restored.',
      primaryLabel: 'Unhide',
      secondaryLabel: 'Cancel',
    );
    if (!mounted) return;
    if (!_sameOwner(owner, generation)) {
      _showUnavailable(_loadRequest);
      return;
    }
    if (confirmed == true && mounted) await _unhide(profile);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Hidden Profiles', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: _loading
            ? const SelahLoading()
            : _unavailable
            ? ListView(
                padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 40),
                children: [
                  SelahEmptyState(
                    icon: Icons.refresh_outlined,
                    title: 'Hidden profiles unavailable',
                    message:
                        'We could not confirm your hidden profiles right now.',
                    ctaLabel: 'Try again',
                    onCta: _load,
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 40),
                children: [
                  if (_hidden.isEmpty)
                    const SelahEmptyState(
                      icon: Icons.visibility_off_outlined,
                      title: 'No hidden profiles',
                      message:
                          'Profiles you hide will appear here, where you can '
                          'unhide them at any time.',
                    )
                  else ...[
                    Text(
                      'Hidden profiles cannot see you either. Unhiding restores '
                      'future visibility, not a Journey that already ended.',
                      style: SelahText.subtext(size: 12.5),
                    ),
                    const SizedBox(height: 16),
                    for (final profile in _hidden)
                      _HiddenProfileRow(
                        profile: profile,
                        busy: _working.contains(profile.id),
                        onUnhide: () => _confirmUnhide(profile),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HiddenProfileRow extends StatelessWidget {
  final SelahHiddenProfileRecord profile;
  final bool busy;
  final VoidCallback onUnhide;

  const _HiddenProfileRow({
    required this.profile,
    required this.busy,
    required this.onUnhide,
  });

  @override
  Widget build(BuildContext context) {
    final detail = profile.age > 0
        ? '${profile.age} · ${profile.city}'
        : profile.city;
    final initial = profile.firstName.isEmpty
        ? '?'
        : profile.firstName.characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SelahColors.iconButtonBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SelahColors.iconButtonBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SelahColors.surfaceEmphasisFill,
                border: Border.all(color: SelahColors.surfaceEmphasisBorder),
              ),
              child: Text(initial, style: SelahText.heading(size: 17)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahText.body(size: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahText.subtext(size: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : onUnhide,
              child: Text(
                busy ? 'Unhiding…' : 'Unhide',
                style: SelahText.button(
                  size: 12.5,
                  color: SelahColors.foreground.withValues(
                    alpha: busy ? 0.4 : 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
