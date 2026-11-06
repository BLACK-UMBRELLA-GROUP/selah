// One Shepherd, in full. Reached by tapping their card on the Shepherd tab.
//
// ADDED 2026-08-06. Founder: "The entire Shepherd card should be tappable
// and open a dedicated Shepherd profile or details page… The cards should
// feel like real people you manage, not just labels."
//
// BUILT ONLY ON DATA THAT EXISTS. Founder, same review: "Don't add empty
// sections or placeholders for future features. If data doesn't exist yet,
// don't design as though it does."
//
// So this page has no Verified row (no verification concept exists in
// SELAH), no photo (Shepherd onboarding never asks for one), no Permissions
// section (the Mentor One capability model is documented but unbuilt). Remove
// Shepherd is available through the guarded confirmation flow below; a Main
// Shepherd must first be replaced when another active Shepherd exists.
//
// Each of those is a real product decision recorded in
// SELAH_SHEPHERD_PAGE_REVIEW_CURRENT_VERSION_V1.md, not an oversight. If you
// are here to add one of them, read that first.

import 'package:flutter/material.dart';
import '../../widgets/selah_switch.dart';
import '../../widgets/selah_loading.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_report_service.dart';
import '../../services/selah_product_telemetry.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/report_profile_sheet.dart';
import '../../widgets/selah_fade_edges.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../theme/selah_card_metrics.dart';
import '../../widgets/selah_glass_dialog.dart';

typedef ShepherdDetailActivityLoader =
    Future<SelahSourceResult<List<ShepherdActivity>>> Function();
typedef ShepherdDetailHistoryConsentLoader =
    Future<SelahSourceResult<ShepherdHistoryConsentState>> Function({
      bool? enabled,
    });

class ShepherdDetailScreen extends StatefulWidget {
  final MentorLinkedPerson person;
  final List<ShepherdActivity> activity;
  final bool activityAvailable;
  final ShepherdDetailActivityLoader? activityLoader;
  final ShepherdDetailHistoryConsentLoader? historyConsentLoader;
  final bool historyConsentPreview;
  final DateTime? comparisonNow;

  /// How many OTHER Shepherds are linked. Decides two things: whether
  /// "Make Main Shepherd" is offered at all, and whether removing this one
  /// is possible when they are Main.
  final int otherShepherdCount;

  /// Called after any change, so the tab behind can reload.
  final VoidCallback onChanged;

  const ShepherdDetailScreen({
    super.key,
    required this.person,
    required this.activity,
    this.activityAvailable = true,
    this.activityLoader,
    this.historyConsentLoader,
    this.historyConsentPreview = false,
    this.comparisonNow,
    required this.otherShepherdCount,
    required this.onChanged,
  });

  @override
  State<ShepherdDetailScreen> createState() => _ShepherdDetailScreenState();
}

class _ShepherdDetailScreenState extends State<ShepherdDetailScreen> {
  bool _busy = false;
  bool _historyBusy = false;
  late bool _historyAvailable;
  late List<ShepherdActivity> _detailActivity;
  bool _consentLoading = false;
  bool _consentAvailable = true;
  bool _consentBusy = false;
  ShepherdHistoryConsentState? _consentState;

  /// The Remove row has been tapped once and is showing Confirm / Cancel.
  ///
  /// ADDED 2026-08-07 (Founder: "when I click remove shepherd, show a
  /// confirm button and cancel on same card").
  ///
  /// In place rather than a dialog. A dialog takes over the screen and hides
  /// the person you are removing; confirming on the card keeps their name,
  /// their relationship and their timeline in view while you decide — which
  /// is the information the decision actually turns on.
  bool _confirmingRemove = false;

  MentorLinkedPerson get person => widget.person;
  List<ShepherdActivity> get activity => _detailActivity;

  @override
  void initState() {
    super.initState();
    _recordShepherdEvent(
      SelahTelemetryEventName.opened,
      SelahTelemetryAction.pageView,
    );
    _historyAvailable = widget.activityAvailable;
    _detailActivity = widget.activity;
    if (person.isMain) {
      if (widget.historyConsentPreview) {
        _consentState = ShepherdHistoryConsentState(
          enabled: false,
          activeShepherdLinkId: 'dev-main-link',
          shepherdId: person.id,
          shepherdIsMain: true,
        );
      } else {
        _consentLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadConsent());
      }
    }
  }

  bool _consentMatchesPerson(ShepherdHistoryConsentState state) =>
      state.shepherdId == person.id &&
      state.activeShepherdLinkId != null &&
      state.shepherdIsMain == true;

  Future<void> _loadConsent() async {
    if (!person.isMain || _consentBusy) return;
    final loader = widget.historyConsentLoader;
    if (loader == null) {
      if (!mounted) return;
      setState(() {
        _consentLoading = false;
        _consentAvailable = false;
        _consentState = null;
      });
      return;
    }

    if (!_consentLoading) setState(() => _consentLoading = true);
    SelahSourceResult<ShepherdHistoryConsentState> result;
    try {
      result = await loader(enabled: null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consentLoading = false;
        _consentAvailable = false;
      });
      return;
    }
    if (!mounted) return;
    final next = result.valueOrNull;
    final confirmed =
        result.isAvailable && next != null && _consentMatchesPerson(next);
    setState(() {
      _consentLoading = false;
      _consentAvailable = confirmed;
      if (confirmed) {
        _consentState = next;
      } else if (result.isAvailable) {
        // A successful response for another/no active Main link must not
        // leave an earlier Shepherd's state visible on this detail page.
        _consentState = null;
      }
    });
  }

  Future<void> _setConsent(bool enabled) async {
    if (widget.historyConsentPreview) return _previewConsent(enabled);
    final loader = widget.historyConsentLoader;
    if (!person.isMain ||
        loader == null ||
        _consentLoading ||
        _consentBusy ||
        !_consentAvailable ||
        _consentState == null) {
      return;
    }

    _recordShepherdEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.shepherdHistoryConsent,
    );
    setState(() => _consentBusy = true);
    SelahSourceResult<ShepherdHistoryConsentState> result;
    try {
      result = await loader(enabled: enabled);
    } catch (_) {
      _recordShepherdEvent(
        SelahTelemetryEventName.failed,
        SelahTelemetryAction.shepherdHistoryConsent,
      );
      if (!mounted) return;
      setState(() {
        _consentBusy = false;
        _consentAvailable = false;
      });
      return;
    }
    if (!mounted) return;
    final next = result.valueOrNull;
    final matchesPerson =
        result.isAvailable && next != null && _consentMatchesPerson(next);
    final confirmed = matchesPerson && next.enabled == enabled;
    _recordShepherdEvent(
      confirmed
          ? SelahTelemetryEventName.completed
          : SelahTelemetryEventName.failed,
      SelahTelemetryAction.shepherdHistoryConsent,
    );
    setState(() {
      _consentBusy = false;
      _consentAvailable = confirmed;
      if (confirmed) {
        _consentState = next;
      } else if (result.isAvailable && !matchesPerson) {
        // Identity/link mismatch is not a failed toggle; it means this state
        // does not belong on the open Shepherd page at all.
        _consentState = null;
      }
      // Transport and echoed-value failures retain the last confirmed value.
    });
  }

  Future<void> _previewConsent(bool _) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview state — no server change made.')),
    );
  }

  Future<void> _retryHistory() async {
    final loader = widget.activityLoader;
    if (loader == null || _historyBusy) return;
    setState(() => _historyBusy = true);
    final result = await loader();
    if (!mounted) return;
    setState(() {
      _historyBusy = false;
      _historyAvailable = result.isAvailable;
      if (result.isAvailable) _detailActivity = result.valueOr(const []);
    });
  }

  /// When they became a Shepherd. Derived from the activity feed rather
  /// than passed separately — `linked` is always present, because a link is
  /// what makes someone a Shepherd in the first place.
  ShepherdActivity? get _linked {
    for (final a in activity) {
      if (a.type == 'linked') return a;
    }
    return null;
  }

  /// Current obligations are present state, never relationship history.
  List<ShepherdActivity> get _currentObligations => [
    for (final a in activity)
      if (a.type == 'review_waiting' && a.line != null) a,
  ];

  /// Only the three governed relationship-history classes. Unknown events
  /// fail closed and a waiting review remains solely in current obligations.
  List<ShepherdActivity> get _history => [
    for (final a in activity)
      if (const {'linked', 'suggested', 'review_answered'}.contains(a.type) &&
          a.line != null)
        a,
  ];

  /// Dev Shepherds have no server rows, so every action here would fail
  /// against a database that has never heard of them. Better to say so than
  /// to show a real error for a fake person.
  bool get _isDev => person.id.startsWith('dev-shepherd-');

  void _devNotice() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Preview Shepherd — sign in as a real account to try this. (dev)',
      ),
    ),
  );

  // Report and Remove are INDEPENDENT (Founder, 2026-08-06). Reporting says
  // "this person broke the rules"; removing says "I no longer want them
  // linked". Someone may report an impersonated Shepherd account and still
  // want the link kept while it is investigated, so reporting never unlinks
  // and never blocks.
  Future<void> _report() async {
    if (_isDev) return _devNotice();
    _recordShepherdEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.shepherdReport,
    );
    final completed = await showReportProfileSheet(
      context,
      profileId: person.id,
      firstName: person.firstName,
      source: SelahReportSource.shepherd,
    );
    if (completed == true) {
      _recordShepherdEvent(
        SelahTelemetryEventName.completed,
        SelahTelemetryAction.shepherdReport,
      );
    }
  }

  Future<void> _makeMain() async {
    if (_isDev) return _devNotice();
    final confirmed = await _confirm(
      title: 'Make ${person.firstName} your Main Shepherd?',
      body:
          'Your Main Shepherd is the one asked to act on your Journey. '
          'Whoever holds it now becomes an Additional Shepherd.',
      action: 'Make Main Shepherd',
    );
    if (confirmed != true) return;

    _recordShepherdEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.shepherdMakeMain,
    );
    setState(() => _busy = true);
    final ok = await SelahMentorLinkService.setMainShepherd(person.id);
    if (!mounted) return;
    setState(() => _busy = false);
    _recordShepherdEvent(
      ok ? SelahTelemetryEventName.completed : SelahTelemetryEventName.failed,
      SelahTelemetryAction.shepherdMakeMain,
    );
    if (ok) {
      widget.onChanged();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That didn't go through. Please try again."),
        ),
      );
    }
  }

  // _makeAdditional() DELETED 2026-08-10 — inherited decision 136, audit 2.9. See the
  // note where its row used to be rendered, further down this file.
  //
  // Deleted rather than left calling a retired method. SelahMentorLinkService
  // .clearMainShepherd now throws, and an orphaned caller would have turned a
  // deliberate refusal into an unhandled StateError the moment anyone tapped
  // it. That is the shape the 2026-08-09 handover warned about in as many
  // words: "a tightened server needs a client that can hear no."

  /// First tap — arms the inline confirm. The refusal case still uses a
  /// dialog, because it is an explanation rather than a decision and there
  /// is nothing on the card for it to become.
  void _askRemove() {
    // NO DEV GUARD HERE, from 2026-08-07 (Founder: "when I click remove
    // shepherd I want that error message removed").
    //
    // It used to refuse before showing anything, so on a panel Shepherd the
    // confirm step could never be seen — the dev notice fired first. The
    // guard now sits on the ACTION rather than the question: the panel opens
    // for everyone, and only the final Confirm knows the difference.

    // Refused before asking, rather than after. Offering an action and then
    // rejecting it is worse than not offering it — the server enforces this
    // too, but the user should not have to hit the wall to learn the rule.
    if (person.isMain && widget.otherShepherdCount > 0) {
      _confirm(
        title: 'Choose a new Main Shepherd first',
        body:
            '${person.firstName} is your Main Shepherd. Make one of your '
            'other Shepherds Main, then remove ${person.firstName}.',
        action: null,
      );
      return;
    }
    setState(() => _confirmingRemove = true);
  }

  /// Second tap — the actual removal. The dev guard lives here now, so the
  /// confirm step is reachable on a panel Shepherd even though the removal
  /// itself cannot be.
  Future<void> _remove() async {
    if (_isDev) {
      setState(() => _confirmingRemove = false);
      return _devNotice();
    }
    _recordShepherdEvent(
      SelahTelemetryEventName.started,
      SelahTelemetryAction.shepherdRemove,
    );
    setState(() => _busy = true);
    final error = await SelahMentorLinkService.removeShepherd(person.id);
    if (!mounted) return;
    setState(() => _busy = false);
    _recordShepherdEvent(
      error == null
          ? SelahTelemetryEventName.completed
          : SelahTelemetryEventName.failed,
      SelahTelemetryAction.shepherdRemove,
    );
    if (error == null) {
      widget.onChanged();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _recordShepherdEvent(
    SelahTelemetryEventName name,
    SelahTelemetryAction action,
  ) {
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.shepherd,
      name: name,
      action: action,
      surface: SelahTelemetrySurface.seeker,
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String? action,
    bool destructive = false,
  }) {
    if (action == null) {
      return showSelahGlassNotice(
        context: context,
        icon: Icons.info_outline_rounded,
        title: title,
        body: body,
      ).then((_) => false);
    }
    return showSelahGlassChoice(
      context: context,
      icon: destructive ? Icons.person_remove_outlined : Icons.shield_outlined,
      title: title,
      body: body,
      primaryLabel: action,
      secondaryLabel: 'Cancel',
      destructivePrimary: destructive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent AppBar over the gradient — without extendBody the
      // Scaffold's flat background shows through and cuts the gradient off
      // with a hard strip. Same fix notifications_screen got on 2026-07-27.
      extendBodyBehindAppBar: true,
      // Scaffold background must be transparent too. Without it the theme's
      // own surface colour shows through wherever the gradient Container
      // does not paint, which is what puts a pale band across the top.
      backgroundColor: Colors.transparent,
      // Transparency and the scrolled-under tint are handled globally by
      // `appBarTheme` in main.dart — see the note there. Only the icon
      // colour is set here.
      appBar: AppBar(
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
        actions: [
          // Top right, matching every other report entry point in the app.
          IconButton(
            onPressed: _busy ? null : _report,
            tooltip: 'Report ${person.firstName}',
            icon: Icon(
              Icons.flag_outlined,
              size: 20,
              color: SelahColors.foreground.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: 4),
        ],
      ),
      // NO GRADIENT HERE, 2026-08-06 (Founder: "can we still remove that
      // line when scrolling on that Mentor page and make it seamless").
      //
      // main.dart already wraps EVERY screen in a gender-matched gradient
      // via MaterialApp's `builder:`. This screen painted a second, identical
      // one over the body. Two gradients drawn over boxes that do not start
      // at the same pixel produce a visible horizontal seam exactly where
      // the lower one begins — which is why the line sat precisely at the
      // bottom of the app bar, and why it looked like a scrolling artefact
      // when it was really a painting one.
      //
      // Removing the duplicate is the fix rather than nudging the geometry:
      // one gradient cannot seam against itself.
      // GRADIENT RESTORED — removing it made this page a different pink from
      // Connections, because the app-level fallback follows the CACHED
      // gender while every page paints its own from AppState.
      //
      // The lines at top and bottom were NOT the gradient. They are the
      // scroll edge: Material draws an overscroll indicator against an
      // opaque surface, which on a gradient reads as a hard rule appearing
      // and vanishing as you reach either end. ScrollConfiguration below
      // removes it, which is what makes the page feel like one surface.
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: SelahFadeEdges(
            // Fades where content meets the viewport edge, so a monogram
            // scrolling under the app bar dissolves instead of being sliced
            // into a half-disc with a flat top — which is what the "line"
            // actually was.
            top: 34,
            child: ScrollConfiguration(
              behavior: const _SeamlessScroll(),
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
                children: [
                  Center(child: _Monogram(letter: person.firstName)),
                  SizedBox(height: 18),
                  Center(
                    child: Text(
                      person.firstName,
                      style: SelahText.heading(size: 27),
                    ),
                  ),

                  // NO relationship line and NO chips here. Removed 2026-08-07
                  // (Founder: "the screen repeats the same information —
                  // Abdul / Brother / Active … Brother / Active").
                  //
                  // The DETAILS rows below carry Relationship, Role and Status
                  // in full. Repeating two of them under the avatar said the
                  // same thing twice within one screenful, which is the exact
                  // duplication this pass removes. The name stands alone.
                  SizedBox(height: 32),
                  Text(
                    'DETAILS',
                    style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                  ),
                  SizedBox(height: 12),
                  _Row(
                    label: 'Relationship',
                    value: person.relationshipLabel ?? 'Not recorded',
                    dim: person.relationshipLabel == null,
                  ),
                  _Row(
                    label: 'Role',
                    value: person.isMain
                        ? 'Main Shepherd'
                        : 'Additional Shepherd',
                  ),
                  // "Linked 3 March" is what a Verified chip was reaching for —
                  // it makes the relationship feel established — with the
                  // difference that every word of it is true.
                  _Row(
                    label: 'Linked',
                    value:
                        person.linkedDateLabel ??
                        (_linked == null
                            ? 'Not recorded'
                            : _linked!.whenLabelAt(
                                widget.comparisonNow ?? DateTime.now(),
                              )),
                    dim: person.linkedDateLabel == null && _linked == null,
                  ),
                  _Row(label: 'Status', value: 'Active'),

                  SizedBox(height: 30),
                  Text(
                    'ROLE & ACCESS',
                    style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SelahColors.foreground.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(
                        SelahCardMetrics.cardRadius,
                      ),
                      border: Border.all(
                        color: SelahColors.foreground.withValues(alpha: 0.10),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      person.isMain
                          ? '${person.firstName} is asked to act on your '
                                'Journey. Journey-summary history follows the '
                                'server-confirmed setting below.'
                          : '${person.firstName} stays linked as an Additional '
                                'Shepherd. When you include them in an active '
                                'Journey, they can view its current context. '
                                'Protected decisions remain led by your Main '
                                'Shepherd.',
                      style: SelahText.subtext(
                        size: 12.5,
                        color: SelahColors.ink(0.54),
                      ),
                    ),
                  ),

                  if (person.isMain) ...[
                    SizedBox(height: 20),
                    _ShepherdHistoryConsentCard(
                      state: _consentState,
                      loading: _consentLoading,
                      available: _consentAvailable,
                      busy: _consentBusy,
                      onRetry:
                          _consentLoading ||
                              _consentBusy ||
                              widget.historyConsentLoader == null
                          ? null
                          : _loadConsent,
                      onChanged: _setConsent,
                    ),
                  ],

                  if (!_historyAvailable) ...[
                    SizedBox(height: 24),
                    SelahErrorBanner(
                      key: const ValueKey(
                        'shepherd-detail-history-unavailable',
                      ),
                      message: 'Shepherd history could not be refreshed.',
                      onRetry: widget.activityLoader == null
                          ? null
                          : _retryHistory,
                    ),
                    if (_historyBusy) ...[
                      SizedBox(height: 8),
                      Text('Refreshing…', style: SelahText.subtext(size: 11.5)),
                    ],
                  ] else ...[
                    if (_currentObligations.isNotEmpty) ...[
                      SizedBox(height: 30),
                      Text(
                        'CURRENT OBLIGATION',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 12),
                      ..._currentObligations.map(
                        (a) => _ActivityRow(
                          activity: a,
                          comparisonNow: widget.comparisonNow,
                        ),
                      ),
                    ],
                    SizedBox(height: 30),
                    Text(
                      'RELATIONSHIP HISTORY',
                      style: SelahText.chapterLabel(
                        color: SelahColors.ink(0.54),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recorded link, suggestion and completed Family Review '
                      'events for ${person.firstName}.',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                    SizedBox(height: 14),
                    if (_history.isEmpty)
                      // An honest nothing. Founder: "If there is no activity,
                      // don't invent it." A Shepherd who has only just linked has
                      // genuinely done nothing yet, and saying so is better than
                      // padding the page with a fabricated milestone.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: SelahColors.foreground.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(
                            SelahCardMetrics.cardRadius,
                          ),
                          border: Border.all(
                            color: SelahColors.foreground.withValues(
                              alpha: 0.10,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'No recorded relationship history yet.',
                          style: SelahText.subtext(
                            size: 12.5,
                            color: SelahColors.ink(0.38),
                          ),
                        ),
                      )
                    else
                      ..._history.map(
                        (a) => _ActivityRow(
                          activity: a,
                          comparisonNow: widget.comparisonNow,
                        ),
                      ),
                  ],

                  // ── Manage ──────────────────────────────────────────────
                  //
                  // Last on the page, and deliberately. These are the only two
                  // things that change a real relationship, and neither should
                  // sit where a thumb lands while reading.
                  SizedBox(height: 34),
                  Text(
                    'MANAGE',
                    style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                  ),
                  SizedBox(height: 12),

                  // PROMOTE — offered to any Additional Shepherd.
                  //
                  // The `otherShepherdCount > 0` condition was removed
                  // 2026-08-07. It was wrong: a Seeker with ONE Shepherd who is
                  // not Main has nobody acting on their Journey, and that is
                  // exactly when promoting matters most. The old test hid the
                  // button in the case that needed it.
                  if (!person.isMain) ...[
                    _ActionRow(
                      icon: Icons.shield_outlined,
                      label: 'Make Main Shepherd',
                      hint: 'They become the one asked to act on your Journey.',
                      onTap: _busy ? null : _makeMain,
                    ),
                    SizedBox(height: 10),
                  ],

                  // "MAKE ADDITIONAL SHEPHERD" REMOVED 2026-08-10 — inherited decision 136,
                  // contradiction-audit finding 2.9.
                  //
                  // Added 2026-08-07 at the Founder's request ("with main
                  // shepherd we need a button to make additional shepherd"), and
                  // the comment here read: "no Main is a legitimate state, just
                  // an unfinished one." The Founder has now ruled the opposite —
                  // that state is not acceptable and the action must stop being
                  // offered.
                  //
                  // What it produced: Family Review reads is_main, so with nobody
                  // Main a review has no voter and cannot be resolved at all, and
                  // the Shepherd's message access closes in the same moment.
                  // Oversight ending with nothing said.
                  //
                  // NOT REPLACED BY A DISABLED ROW. The capability people wanted —
                  // changing WHICH Shepherd is Main — already exists on the other
                  // Shepherd's page: "Make Main Shepherd" demotes the incumbent
                  // and promotes the replacement in one transaction. So this is a
                  // removal, not a loss; the same outcome is one tap away in a
                  // place where it cannot leave a gap.
                  //
                  // selah_clear_main_shepherd and SelahMentorLinkService
                  // .clearMainShepherd both refuse now, so nothing can
                  // reintroduce this by accident without failing loudly.

                  // Two states, same card. Tapping Remove turns the row into the
                  // question rather than opening one somewhere else.
                  if (!_confirmingRemove)
                    _ActionRow(
                      icon: Icons.person_remove_outlined,
                      label: 'Remove Shepherd',
                      hint: person.isMain && widget.otherShepherdCount > 0
                          ? 'Choose a new Main Shepherd first.'
                          : 'They will no longer be linked to you.',
                      destructive: true,
                      onTap: _busy ? null : _askRemove,
                    )
                  else
                    // EXPANDS TO FIT (Founder, 2026-08-07: "make it so the box
                    // expands if needed").
                    //
                    // No fixed height anywhere: the Column sizes to its children,
                    // the body text wraps to as many lines as the name and the
                    // context need, and the buttons below grow with their labels
                    // rather than truncating. A confirmation that clips the
                    // sentence explaining what you are confirming is worse than
                    // no confirmation.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: SelahColors.destructive.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            SelahCardMetrics.cardRadius,
                          ),
                          border: Border.all(
                            color: SelahColors.destructive.withValues(
                              alpha: 0.34,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remove ${person.firstName}?',
                              style: SelahText.body(
                                size: 15,
                                color: SelahColors.destructive,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.otherShepherdCount == 0
                                  ? "You'll have no Shepherd until you add another. "
                                        'You can invite them again at any time.'
                                  : "They'll no longer follow your Journey. You can "
                                        'invite them again at any time.',
                              style: SelahText.subtext(
                                size: 12,
                                color: SelahColors.ink(0.54),
                              ),
                            ),
                            SizedBox(height: 14),
                            Row(
                              children: [
                                // Cancel FIRST and to the left — the safe option
                                // sits where a thumb rests, and the destructive one
                                // takes a deliberate reach.
                                Expanded(
                                  child: _SmallAction(
                                    label: 'Cancel',
                                    onTap: _busy
                                        ? null
                                        : () => setState(
                                            () => _confirmingRemove = false,
                                          ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _SmallAction(
                                    label: _busy ? 'Removing…' : 'Confirm',
                                    destructive: true,
                                    onTap: _busy ? null : _remove,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // The reporting explainer that sat here is gone (Founder,
                  // 2026-08-07: "if reporting behaviour needs explaining, it
                  // belongs inside the reporting flow, not permanently on the
                  // Shepherd profile"). Correct — it is read once and then
                  // becomes furniture on a page visited often.
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShepherdHistoryConsentCard extends StatefulWidget {
  final ShepherdHistoryConsentState? state;
  final bool loading;
  final bool available;
  final bool busy;
  final VoidCallback? onRetry;
  final ValueChanged<bool> onChanged;

  const _ShepherdHistoryConsentCard({
    required this.state,
    required this.loading,
    required this.available,
    required this.busy,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  State<_ShepherdHistoryConsentCard> createState() =>
      _ShepherdHistoryConsentCardState();
}

class _ShepherdHistoryConsentCardState
    extends State<_ShepherdHistoryConsentCard> {
  bool _detailsExpanded = false;

  void _toggleDetails() => setState(() => _detailsExpanded = !_detailsExpanded);

  @override
  Widget build(BuildContext context) {
    final confirmed = widget.state;
    return Container(
      key: const ValueKey('shepherd-history-consent'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: _detailsExpanded,
                  label: 'About sharing past Journey summaries',
                  excludeSemantics: true,
                  onTap: _toggleDetails,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey(
                        'shepherd-history-consent-details-toggle',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _toggleDetails,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Share past Journey summaries',
                                  style: SelahText.body(size: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedRotation(
                                turns: _detailsExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  key: const ValueKey(
                                    'shepherd-history-consent-details-arrow',
                                  ),
                                  size: 20,
                                  color: SelahColors.ink(0.56),
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
              const SizedBox(width: 12),
              if (widget.loading && confirmed == null)
                const SizedBox.square(dimension: 24, child: SelahLoading())
              else if (confirmed != null)
                Semantics(
                  label: 'Share past Journey summaries',
                  child: SelahSwitch(
                    key: const ValueKey('shepherd-history-consent-toggle'),
                    value: confirmed.enabled,
                    onChanged:
                        widget.available && !widget.loading && !widget.busy
                        ? widget.onChanged
                        : null,
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _detailsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      'When off, this Shepherd sees your active Journey and '
                      'ended Journeys from this link period. When on, they can '
                      'also see older Journey summaries. Names, messages, '
                      'answers, notes, reasons and safety information are '
                      'never included.',
                      key: const ValueKey(
                        'shepherd-history-consent-explanation',
                      ),
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.ink(0.48),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (widget.busy) ...[
            const SizedBox(height: 10),
            Text(
              'Confirming with SELAH…',
              style: SelahText.subtext(size: 11.5),
            ),
          ],
          if (!widget.available) ...[
            const SizedBox(height: 12),
            SelahErrorBanner(
              message: confirmed == null
                  ? 'Past-summary permission could not be refreshed.'
                  : 'The last change was not confirmed. Showing the last '
                        'server-confirmed state.',
              onRetry: widget.onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Removes the overscroll indicator. Material paints it on an opaque
/// surface, so on a gradient it reads as a hard line appearing at the top
/// and bottom of the scroll — which is exactly what it was.
class _SeamlessScroll extends ScrollBehavior {
  const _SeamlessScroll();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// A compact button for the inline confirm pair.
class _SmallAction extends StatelessWidget {
  final String label;
  final bool destructive;
  final VoidCallback? onTap;
  const _SmallAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? SelahColors.destructive : Colors.white;
    return Material(
      color: destructive
          ? SelahColors.destructive.withValues(alpha: 0.16)
          : SelahColors.foreground.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          // Horizontal padding as well as vertical, so a longer label like
          // "Removing…" grows the button instead of touching its border.
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: tint.withValues(alpha: destructive ? 0.40 : 0.18),
              width: destructive ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: SelahText.body(
              size: 14,
              color: tint.withValues(alpha: onTap == null ? 0.4 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? Colors.redAccent.shade100 : Colors.white;
    return Material(
      color: SelahColors.foreground.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
            border: Border.all(
              color: SelahColors.foreground.withValues(alpha: 0.11),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: tint.withValues(alpha: 0.85)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: SelahText.body(size: 15, color: tint)),
                    SizedBox(height: 2),
                    Text(
                      hint,
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ShepherdActivity activity;
  final DateTime? comparisonNow;
  const _ActivityRow({required this.activity, this.comparisonNow});

  @override
  Widget build(BuildContext context) {
    final line = activity.line;
    if (line == null) return SizedBox.shrink();
    final outstanding = activity.isOutstanding;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A timeline rail — dot with a line running through it, so a
            // run of entries reads as a sequence rather than a stack of
            // unrelated rows.
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  SizedBox(height: 5),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SelahColors.foreground.withValues(
                        alpha: outstanding ? 0.95 : 0.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 0.5,
                      color: SelahColors.foreground.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line,
                      style: SelahText.body(
                        size: 14,
                        color: SelahColors.foreground.withValues(
                          alpha: outstanding ? 1 : 0.8,
                        ),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      activity.whenLabelAt(comparisonNow ?? DateTime.now()),
                      style: SelahText.subtext(
                        size: 11,
                        color: SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;
  const _Row({required this.label, required this.value, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: SelahText.subtext(size: 13, color: SelahColors.ink(0.54)),
            ),
          ),
          Text(
            value,
            style: SelahText.body(
              size: 14,
              color: SelahColors.foreground.withValues(
                alpha: dim ? 0.35 : 0.95,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  final String letter;
  const _Monogram({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SelahColors.foreground.withValues(alpha: 0.30),
            SelahColors.foreground.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: SelahColors.foreground.withValues(alpha: 0.30),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          letter.isEmpty ? '?' : letter.characters.first.toUpperCase(),
          style: SelahText.heading(size: 42),
        ),
      ),
    );
  }
}
