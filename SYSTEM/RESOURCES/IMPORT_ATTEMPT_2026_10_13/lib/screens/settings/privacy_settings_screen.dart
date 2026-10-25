// Privacy settings — real scope defined 2026-07-26 (DR-SELAH-101 audit,
// Settings/Search/Notifications build-out). APP/Settings/Summary.md
// was, until this pass, literally "Placeholder — Approved Application
// Structure" with no feature definition at all.
//
// Scope for this pass: a single, genuinely-wired control — "Visible
// in Browse," toggling `profiles.is_active` (SelahProfileService.
// setVisibility). This is the same column Browse's own discovery
// query filters on (`selah_discovery_service.dart`: `.eq('is_active',
// true)`) and that profiles_select's RLS policy checks to decide
// whether the row is visible to anyone but its owner — so this
// toggle has a real, immediate effect: turning it off genuinely
// removes the Seeker from Browse for every other signed-in user, not
// just a cosmetic switch. Deliberately kept to one control rather
// than inventing a larger privacy settings surface with no backing
// mechanism yet.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_profile_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    super.key,
    this.loadVisibility,
    this.saveVisibility,
  });

  final Future<bool?> Function()? loadVisibility;
  final Future<bool> Function(bool)? saveVisibility;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _loading = true;
  bool? _visible;
  bool _saving = false;
  int _loadRequest = 0;

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
    setState(() => _loading = true);
    bool? visible;
    try {
      visible =
          await (widget.loadVisibility?.call() ??
              SelahProfileService.fetchVisibility());
    } catch (_) {
      visible = null;
    }
    if (!mounted) return;
    if (request != _loadRequest) return;
    setState(() {
      _visible = _sameOwner(owner, generation) ? visible : null;
      _loading = false;
    });
  }

  Future<void> _setVisible(bool value) async {
    if (_saving || _visible == null) return;
    final owner = _ownerId();
    final generation = SelahAccountState.generation;
    setState(() => _saving = true);
    var saved = false;
    try {
      saved =
          await (widget.saveVisibility?.call(value) ??
              SelahProfileService.setVisibility(value));
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (!_sameOwner(owner, generation)) {
      setState(() {
        _visible = null;
        _saving = false;
      });
      return;
    }
    // A write returning without an error does not prove that a row changed
    // (for example, when an RLS policy permits no matching update). Read the
    // authoritative value again before presenting a privacy change as saved.
    bool? confirmed;
    try {
      confirmed =
          await (widget.loadVisibility?.call() ??
              SelahProfileService.fetchVisibility());
    } catch (_) {
      confirmed = null;
    }
    if (!mounted) return;
    if (!_sameOwner(owner, generation)) {
      setState(() {
        _visible = null;
        _saving = false;
      });
      return;
    }
    setState(() {
      _visible = confirmed;
      _saving = false;
    });
    if (!saved || confirmed != value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't update or confirm Browse visibility. Please try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIXED 2026-08-01 (Founder: "there should be no purple at top, it
      // should blend the pink/purple colour... that should be across all
      // things"). Same fix notifications_screen.dart got on 2026-07-27:
      // without this the transparent AppBar shows the Scaffold's own flat
      // background through, cutting the gender gradient off with a hard
      // purple strip. Body content compensates with SafeArea, which still
      // clears the status bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Privacy', style: SelahText.heading(size: 17)),
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SelahColors.iconButtonBg,
                        border: Border.all(
                          color: SelahColors.iconButtonBorder,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visible in Browse',
                                      style: SelahText.body(
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'When off, other Seekers will not see your profile in Browse. '
                                      'Existing Matches and Journeys are not affected.',
                                      style: SelahText.subtext(size: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (_visible != null) ...[
                                const SizedBox(width: 12),
                                Switch(
                                  value: _visible!,
                                  onChanged: _saving ? null : _setVisible,
                                  activeThumbColor: SelahColors.accentBorder,
                                ),
                              ],
                            ],
                          ),
                          if (_visible == null) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Visibility status unavailable',
                              style: SelahText.body(
                                size: 13,
                                color: SelahColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We could not confirm whether your profile appears in Browse.',
                              style: SelahText.subtext(size: 11.5),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Profiles you block are managed separately in Settings '
                      'under Hidden Profiles.',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
