// Help & Support — rebuilt 2026-08-01 (Founder: "the help and support
// page we gotta start building it... start building Q/A etc to let users
// navigate for any issues").
//
// WAS: four lines of text and an email address, with rows that rendered
// as "Email Report a technical issue to support@selah.invalid" — a label
// sandwiched inside a sentence, which read as broken English.
//
// NOW: a real help centre. Searchable questions grouped by category,
// with the support email kept as the last resort at the BOTTOM rather
// than the first thing offered. Someone who can answer their own
// question in four seconds should never be asked to write an email and
// wait.
//
// Content lives in data/help_content.dart, deliberately separate — see
// that file's header for why, and for the note about moving it to
// Supabase so answers can be corrected without a release.
//
// GRADIENT: extendBodyBehindAppBar + manual top padding, matching
// notifications_screen.dart's fix from 2026-07-27 (Founder: "the purple
// at top doesn't suit so I'd rather the pink/purple takes whole
// screen"). Without it the transparent AppBar shows the Scaffold's flat
// background through, cutting the gender gradient off with a hard purple
// strip — exactly what the Founder screenshotted on this screen.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/help_content.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_product_telemetry.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import 'safety_case_status_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  final SelahTelemetrySurface telemetrySurface;
  final String initialQuery;
  final bool _preview;
  final bool Function()? _previewCanAct;
  final List<SelahHelpCategory>? _previewCategories;
  final bool embedded;

  const HelpSupportScreen({
    super.key,
    this.telemetrySurface = SelahTelemetrySurface.seeker,
    this.initialQuery = '',
  }) : _preview = false,
       _previewCanAct = null,
       _previewCategories = null,
       embedded = false;

  /// Reuses the original Help search and FAQ presentation with caller-owned,
  /// approved content only. Account reports, identity, telemetry and native
  /// contact actions are never mounted in this mode. The caller owns return.
  const HelpSupportScreen.preview({
    super.key,
    required bool Function() canAct,
    required List<SelahHelpCategory> categories,
    this.initialQuery = '',
    this.embedded = true,
  }) : _preview = true,
       _previewCanAct = canAct,
       _previewCategories = categories,
       telemetrySurface = SelahTelemetrySurface.seeker;

  static const String supportEmail = 'support@selah.invalid';
  static Uri get supportMailto => Uri(scheme: 'mailto', path: supportEmail);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _search = TextEditingController();
  late final bool _previewMode;
  late final bool _embeddedPreview;
  late final bool Function()? _previewOwnerCanAct;
  late final List<SelahHelpCategory> _categories;
  bool _previewRevoked = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Mode, owner and content are sticky for this mounted route. Rebuilding a
    // preview as the default constructor must never fall through to live Help.
    _previewMode = widget._preview;
    _embeddedPreview = widget.embedded;
    _previewOwnerCanAct = widget._previewCanAct;
    _categories = _previewMode
        ? List<SelahHelpCategory>.unmodifiable([
            for (final category in widget._previewCategories!)
              SelahHelpCategory(
                category.title,
                List<SelahHelpEntry>.unmodifiable(category.entries),
              ),
          ])
        : selahHelpCategories;
    _query = widget.initialQuery;
    _search.text = widget.initialQuery;
    if (!_previewMode) {
      SelahProductTelemetry.instance.record(
        feature: SelahTelemetryFeature.support,
        name: SelahTelemetryEventName.opened,
        action: SelahTelemetryAction.pageView,
        surface: widget.telemetrySurface,
      );
    }
  }

  @override
  void dispose() {
    // ES-11 (proposed): every controller created here is disposed here.
    // Two existing leaks in this codebase came from skipping this.
    _search.dispose();
    super.dispose();
  }

  List<SelahHelpCategory> get _filtered {
    if (_query.trim().isEmpty) return _categories;
    final out = <SelahHelpCategory>[];
    for (final category in _categories) {
      if (category.title.toLowerCase().contains(_query.trim().toLowerCase())) {
        out.add(category);
        continue;
      }
      final hits = category.entries.where((e) => e.matches(_query)).toList();
      if (hits.isNotEmpty) out.add(SelahHelpCategory(category.title, hits));
    }
    return out;
  }

  bool get _previewAvailable {
    if (!mounted || !_previewMode || _previewRevoked) return false;
    try {
      if (!widget._preview ||
          _previewOwnerCanAct?.call() != true ||
          widget._previewCanAct?.call() != true) {
        _previewRevoked = true;
        return false;
      }
    } catch (_) {
      // A failed admission check is not permission to use ordinary Help.
      _previewRevoked = true;
      return false;
    }
    return true;
  }

  void _hideRevokedPreview() {
    if (mounted && _previewMode) setState(() {});
  }

  void _changeQuery(String value) {
    if (!mounted) return;
    if (_previewMode && !_previewAvailable) {
      _hideRevokedPreview();
      return;
    }
    if (widget._preview != _previewMode) return;
    setState(() => _query = value);
  }

  List<Widget> _faqContent(List<SelahHelpCategory> results) => [
    if (results.isEmpty)
      _NoResults(query: _query, contactAvailable: !_previewMode)
    else
      for (final category in results) ...[
        Text(
          category.title.toUpperCase(),
          style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
        ),
        SizedBox(height: 8),
        for (final entry in category.entries)
          _HelpTile(
            key: _previewMode
                ? ValueKey(
                    'help-support-faq:${category.title}:${entry.question}',
                  )
                : null,
            entry: entry,
            telemetrySurface: widget.telemetrySurface,
            recordTelemetry: !_previewMode,
            canAct: _previewMode ? () => _previewAvailable : null,
            onUnavailable: _previewMode ? _hideRevokedPreview : null,
          ),
        SizedBox(height: 22),
      ],
  ];

  Widget _previewPage(List<SelahHelpCategory> results) {
    final content = Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Help & Support',
                key: const ValueKey('help-support-preview-title'),
                style: SelahText.heading(size: 28),
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('help-support-preview-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                children: [
                  _SearchField(
                    key: const ValueKey('help-support-preview-search'),
                    controller: _search,
                    onChanged: _changeQuery,
                  ),
                  const SizedBox(height: 22),
                  ..._faqContent(results),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (_embeddedPreview) return content;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_previewMode) {
      if (!_previewAvailable) {
        return const SizedBox.shrink(
          key: ValueKey('help-support-preview-unavailable'),
        );
      }
      return _previewPage(_filtered);
    }
    // A live route cannot be repurposed into an admitted preview by updating
    // the widget in place, either. Its owner must mount a distinct route.
    if (widget._preview) return const SizedBox.shrink();
    final results = _filtered;
    // SafeArea's top inset covers the status bar only, not the toolbar —
    // so with the body extended behind the AppBar, content needs both.
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Help & Support', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        // Only ever reached from inside a signed-in profile, so gender is
        // known — gender-matched gradient like every other profile-context
        // screen (DR-SELAH-094 / OA-SELAH-123).
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 40),
          children: [
            _SearchField(controller: _search, onChanged: _changeQuery),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('support-safety-case-status'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SafetyCaseStatusScreen(),
                ),
              ),
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(
                'Your safety reports',
                style: SelahText.button(size: 12.5),
              ),
            ),
            SizedBox(height: 22),

            ..._faqContent(results),

            SizedBox(height: 4),
            _ContactCard(telemetrySurface: widget.telemetrySurface),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: SelahText.body(size: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'What do you need help with?',
        hintStyle: SelahText.subtext(size: 14),
        prefixIcon: Icon(Icons.search, color: SelahColors.ink(0.38), size: 20),
        filled: true,
        fillColor: SelahColors.iconButtonBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// One expandable question. Collapsed by default so the whole centre can
/// be scanned in a few seconds — the point is to find your question, not
/// to read everyone else's.
class _HelpTile extends StatefulWidget {
  final SelahHelpEntry entry;
  final SelahTelemetrySurface telemetrySurface;
  final bool recordTelemetry;
  final bool Function()? canAct;
  final VoidCallback? onUnavailable;

  const _HelpTile({
    super.key,
    required this.entry,
    required this.telemetrySurface,
    this.recordTelemetry = true,
    this.canAct,
    this.onUnavailable,
  });

  @override
  State<_HelpTile> createState() => _HelpTileState();
}

class _HelpTileState extends State<_HelpTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // ADDED 2026-08-01 (Fable's review): the collapse state was invisible
      // to VoiceOver — a screen-reader user got the question text with no
      // indication it could expand, or that it had. This screen is exactly
      // where a blind user is most likely to be when they are already stuck.
      child: Semantics(
        button: true,
        expanded: _open,
        label: widget.entry.question,
        child: GestureDetector(
          onTap: () {
            if (!mounted) return;
            if (widget.canAct?.call() == false) {
              widget.onUnavailable?.call();
              return;
            }
            final opening = !_open;
            setState(() => _open = opening);
            if (opening && widget.recordTelemetry) {
              SelahProductTelemetry.instance.record(
                feature: SelahTelemetryFeature.support,
                name: SelahTelemetryEventName.completed,
                action: SelahTelemetryAction.supportAnswer,
                surface: widget.telemetrySurface,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: SelahColors.foreground.withValues(
                alpha: _open ? 0.09 : 0.05,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SelahColors.foreground.withValues(
                  alpha: _open ? 0.16 : 0.10,
                ),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.entry.question,
                        style: SelahText.body(size: 14.5, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
                if (_open) ...[
                  SizedBox(height: 10),
                  Text(
                    widget.entry.answer,
                    style: SelahText.subtext(size: 13.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  final bool contactAvailable;
  const _NoResults({required this.query, this.contactAvailable = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.search_off, color: SelahColors.ink(0.38), size: 30),
          SizedBox(height: 12),
          Text(
            'Nothing matched "$query"',
            style: SelahText.body(size: 15, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            contactAvailable
                ? 'Try a different word, or email us below — a real person will read it.'
                : 'Try a different word.',
            style: SelahText.subtext(size: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Last resort, at the bottom. There is genuinely no ticketing system yet
/// and the screen says so — an honest "email us" beats a Contact Us form
/// that goes nowhere.
class _ContactCard extends StatelessWidget {
  final SelahTelemetrySurface telemetrySurface;

  const _ContactCard({required this.telemetrySurface});

  Future<void> _emailSupport(BuildContext context) async {
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.support,
      name: SelahTelemetryEventName.started,
      action: SelahTelemetryAction.supportEmail,
      surface: telemetrySurface,
    );
    try {
      final opened = await launchUrl(
        HelpSupportScreen.supportMailto,
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        SelahProductTelemetry.instance.record(
          feature: SelahTelemetryFeature.support,
          name: SelahTelemetryEventName.completed,
          action: SelahTelemetryAction.supportEmail,
          surface: telemetrySurface,
        );
        return;
      }
    } catch (_) {}
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.support,
      name: SelahTelemetryEventName.failed,
      action: SelahTelemetryAction.supportEmail,
      surface: telemetrySurface,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No email app opened. Email support@selah.invalid directly.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = SelahAuth.currentUser?.email;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SelahColors.foreground.withValues(alpha: 0.06),
        border: Border.all(color: SelahColors.ink(0.12), width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still need us?',
            style: SelahText.body(size: 15, color: Colors.white),
          ),
          SizedBox(height: 6),
          Text(
            "There's no in-app messaging for support yet — email us and a real "
            'person will reply.',
            style: SelahText.subtext(size: 13),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const ValueKey('help-support-email-action'),
              onPressed: () => _emailSupport(context),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              icon: Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: SelahColors.ink(0.72),
              ),
              label: Text(
                HelpSupportScreen.supportEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.body(
                  size: 15.5,
                  color: Colors.white,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (email != null) ...[
            SizedBox(height: 14),
            Divider(
              color: SelahColors.foreground.withValues(alpha: 0.10),
              height: 1,
            ),
            SizedBox(height: 12),
            Text.rich(
              key: const ValueKey('help-support-signed-in-line'),
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Signed in as  ',
                    style: SelahText.subtext(size: 12.5),
                  ),
                  TextSpan(
                    text: email,
                    style: SelahText.body(size: 12.5, color: Colors.white),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
