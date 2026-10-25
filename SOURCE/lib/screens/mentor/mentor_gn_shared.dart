// Shepherd Network — SHARED LIBRARY (GN DRAFT 3, 2026-08-23).
//
// Founder directive, 2026-08-23: "dashboard is where everything lives
// about the user". Three consequences, and this file is how all three
// are possible at once:
//
//   1. The CONNECTIONS context (incoming requests, sent requests,
//      connected Mentors, history) moved OFF the Network page and INTO
//      the Mentor Dashboard — GNConnectionsPanel below.
//   2. The top slider on BOTH pages is now the Shepherd's SEEKERS BY
//      NAME — GNSeekerSlider below. Four names remain visible at once;
//      a compact overflow control opens the complete list when a
//      Shepherd supports a larger family. No more Discover/Connections
//      toggle.
//   3. Selecting a Seeker on either page selects them EVERYWHERE:
//      slide to a Seeker on the Dashboard, open Network, the same
//      Seeker is already chosen — and vice versa. GNContext (a
//      ChangeNotifier singleton) is that shared selection, plus the
//      D14 preview's stages, scenes and analytics, so the two pages
//      can never disagree about the state of a request.
//
// Everything D14 here is the SAME ratified interaction model as
// Draft 2.x (SELAH_GN_BUILD_CONTRACT V1, Rules 1-44): mock data is
// PROVISIONAL and developer-preview only; nothing in this library
// touches live data. Rule 44's "mock data in-file" now reads "in this
// GN library" — recorded as a contract amendment, because one screen's
// file cannot feed two screens.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/seeker_profile.dart';
import '../../services/selah_mentor_link_service.dart';
import '../profile/seeker_profile_screen.dart';
import '../../theme/selah_card_metrics.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_segmented_toggle.dart';
import '../../widgets/selah_state_widgets.dart';

// ── D14 PROVISIONAL mock model (contract Rule 44, amended: GN library) ──────

enum GNPhotoLevel { card, afterConnect, never } // Rule 34

enum GNStage {
  none, // servable
  setAside, // Rule 19
  sent, // Rung 1 — awaiting their Mentor
  incoming, // Rung 1 — their request awaiting us
  connected, // Rung 2
  proceedMine, // Rung 3 — we confirmed, awaiting them
  revealed, // Rung 4 — introduced to both Seekers
  closed, // Rule 27 — "No longer active"
}

enum GNScene { standard, merge, capReached, empty, loading, error }

class GNFamily {
  const GNFamily({
    required this.id,
    required this.initial,
    required this.display,
    required this.region,
    required this.band,
    required this.shepherdLabel,
    required this.photoLevel,
    required this.reasons,
    this.photos = const [],
    this.incomingAtStart = false,
    this.theirMentorConfirmed = false,
  });
  final String id;
  final String initial;
  final String display; // "H., 27" — initials only (Rule 12)
  final String region;
  final String band;
  final String shepherdLabel;
  final GNPhotoLevel photoLevel;
  final List<String> reasons;
  final List<String> photos;

  String get photoUrl => photos.isEmpty ? '' : photos.first;
  final bool incomingAtStart;
  final bool theirMentorConfirmed;
}

const gnGold = Color(0xFFDEC979);

// PROVISIONAL mock families per ward index (Rule 44).
const List<GNFamily> _gnFamiliesA = [
  GNFamily(
    id: 'fam-h',
    initial: 'H',
    display: 'H., 27',
    region: 'West Midlands, UK',
    band: 'HIGH FIT',
    shepherdLabel: 'Main Shepherd · Father',
    photoLevel: GNPhotoLevel.card,
    reasons: ['Practising', 'Nearby region', 'High compatibility'],
  ),
  GNFamily(
    id: 'fam-s',
    initial: 'S',
    display: 'S., 29',
    region: 'Yorkshire, UK',
    band: 'GOOD FIT',
    shepherdLabel: 'Main Shepherd · Brother',
    photoLevel: GNPhotoLevel.afterConnect,
    reasons: ['Within preferences', 'Also speaks Urdu'],
  ),
  GNFamily(
    id: 'fam-t',
    initial: 'T',
    display: 'T., 26',
    region: 'North West, UK',
    band: 'GOOD FIT',
    shepherdLabel: 'Main Shepherd · Uncle',
    photoLevel: GNPhotoLevel.never,
    reasons: ['Practising', 'Within preferences'],
  ),
  GNFamily(
    id: 'fam-m',
    initial: 'M',
    display: 'M., 31',
    region: 'Greater London, UK',
    band: 'HIGH FIT',
    shepherdLabel: 'Main Shepherd · Father',
    photoLevel: GNPhotoLevel.afterConnect,
    reasons: ['High compatibility', 'Practising'],
    incomingAtStart: true,
    theirMentorConfirmed: true,
  ),
];

const List<GNFamily> _gnFamiliesB = [
  GNFamily(
    id: 'fam-k',
    initial: 'K',
    display: 'K., 31',
    region: 'Greater London, UK',
    band: 'HIGH FIT',
    shepherdLabel: 'Main Shepherd · Father',
    photoLevel: GNPhotoLevel.afterConnect,
    reasons: ['Practising', 'High compatibility'],
  ),
  GNFamily(
    id: 'fam-r',
    initial: 'R',
    display: 'R., 28',
    region: 'South East, UK',
    band: 'GOOD FIT',
    shepherdLabel: 'Main Shepherd · Uncle',
    photoLevel: GNPhotoLevel.never,
    reasons: ['Within preferences', 'Nearby region'],
  ),
];

// ── GNContext — the ONE shared Shepherd Network state ───────────────────────
//
// Which Seeker the Shepherd is acting for, plus the D14 preview's mock
// stages, scene, role and analytics. Dashboard and Network both listen;
// a tap on either page repaints both. Never disposed — an app-lifetime
// singleton, exactly like AppState.

enum GNNetworkCardDesign {
  openCanvas('1 · Open canvas'),
  cinematic('2 · Cinematic overlay'),
  editorial('3 · Editorial profile'),
  portraitFocus('4 · Portrait focus'),
  actionRail('5 · Minimal action rail');

  final String label;
  const GNNetworkCardDesign(this.label);
}

/// Browser-only presentation choices. Request and response actions keep their
/// own governed layout; this never changes the underlying set-aside action.
enum GNNetworkActionLayout {
  current('1 · Current'),
  quietNext('2 · Quiet Next'),
  speakFirst('3 · Speak first'),
  profileFirst('4 · Profile first');

  final String label;
  const GNNetworkActionLayout(this.label);
}

enum GNNetworkPreviewArea { browser, sent, received }

class GNContext extends ChangeNotifier {
  GNContext._();

  static final GNContext instance = GNContext._();

  String? _selectedSeekerId;

  String? get selectedSeekerId => _selectedSeekerId;

  void selectSeeker(String id) {
    if (_selectedSeekerId == id) return;
    _selectedSeekerId = id;
    track('seeker_selected', id);
    notifyListeners();
  }

  /// The selected ward when they are still in [wards]; otherwise the
  /// first ward. There is deliberately no "nothing selected" state any
  /// more — the slider always names somebody (Founder, Draft 3).
  MentorLinkedPerson? effectiveSelected(List<MentorLinkedPerson> wards) {
    if (wards.isEmpty) return null;
    if (_selectedSeekerId != null) {
      for (final ward in wards) {
        if (ward.id == _selectedSeekerId) return ward;
      }
    }
    return wards.first;
  }

  // PROVISIONAL MOCK STATE FOR THE D14 DEV PREVIEW (Rule 44)
  GNScene scene = GNScene.standard;
  bool isMainMentor = true; // Rule 37 dev toggle
  bool choosing = false; // Rule 23: algorithm-serve transition
  GNNetworkCardDesign networkCardDesign = GNNetworkCardDesign.portraitFocus;
  GNNetworkActionLayout networkActionLayout = GNNetworkActionLayout.current;
  final Map<GNNetworkPreviewArea, int> _previewCounts = {};

  final Map<String, GNStage> _stage = {};
  final List<String> analytics = []; // Rule 41 PROVISIONAL tracker

  void setScene(GNScene s) {
    scene = s;
    notifyListeners();
  }

  void setMainMentor(bool main) {
    isMainMentor = main;
    notifyListeners();
  }

  void setNetworkCardDesign(GNNetworkCardDesign design) {
    if (networkCardDesign == design) return;
    networkCardDesign = design;
    notifyListeners();
  }

  void setNetworkActionLayout(GNNetworkActionLayout layout) {
    if (networkActionLayout == layout) return;
    networkActionLayout = layout;
    notifyListeners();
  }

  /// Developer-only visual fixture count. When absent, the Network keeps
  /// using its real local request stages; selecting 1/2/3 lets the Founder
  /// inspect each tab without fabricating request transitions.
  int? previewCountFor(GNNetworkPreviewArea area) => _previewCounts[area];

  void setPreviewCount(GNNetworkPreviewArea area, int count) {
    final safeCount = count.clamp(1, 3);
    if (_previewCounts[area] == safeCount) return;
    _previewCounts[area] = safeCount;
    notifyListeners();
  }

  void clearPreviewCount(GNNetworkPreviewArea area) {
    if (_previewCounts.remove(area) != null) notifyListeners();
  }

  void reset() {
    _selectedSeekerId = null;
    _stage.clear();
    analytics.clear();
    scene = GNScene.standard;
    isMainMentor = true;
    choosing = false;
    networkCardDesign = GNNetworkCardDesign.portraitFocus;
    networkActionLayout = GNNetworkActionLayout.current;
    _previewCounts.clear();
    notifyListeners();
  }

  /// Mock families for a ward — even ward index serves list A, odd
  /// serves list B, same rule Draft 2 used.
  List<GNFamily> familiesFor(
    List<MentorLinkedPerson> wards,
    MentorLinkedPerson ward,
  ) {
    final index = wards.indexWhere((w) => w.id == ward.id);
    return (index <= 0 || index.isEven) ? _gnFamiliesA : _gnFamiliesB;
  }

  String _key(MentorLinkedPerson ward, GNFamily f) => '${ward.id}/${f.id}';

  GNStage stageOf(MentorLinkedPerson ward, GNFamily f) {
    final s = _stage[_key(ward, f)];
    if (s != null) return s;
    return f.incomingAtStart ? GNStage.incoming : GNStage.none;
  }

  void setStage(MentorLinkedPerson ward, GNFamily f, GNStage s) {
    _stage[_key(ward, f)] = s;
    notifyListeners();
  }

  int liveCount(MentorLinkedPerson ward, List<GNFamily> fams) {
    var n = 0;
    for (final f in fams) {
      final s = stageOf(ward, f);
      if (s == GNStage.sent ||
          s == GNStage.connected ||
          s == GNStage.proceedMine) {
        n++;
      }
    }
    return n; // Rule 40
  }

  int incomingCount(MentorLinkedPerson ward, List<GNFamily> fams) {
    return fams.where((f) => stageOf(ward, f) == GNStage.incoming).length;
  }

  int sentCount(MentorLinkedPerson ward, List<GNFamily> fams) {
    return fams.where((f) => stageOf(ward, f) == GNStage.sent).length;
  }

  GNFamily? servedFamily(MentorLinkedPerson ward, List<GNFamily> fams) {
    for (final f in fams) {
      final s = stageOf(ward, f);
      if (s == GNStage.none) return f;
    }
    return null;
  }

  void advance() {
    // Rule 23: the algorithm chooses the next family; brief transition.
    choosing = true;
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      choosing = false;
      notifyListeners();
    });
  }

  // Rule 41: PROVISIONAL analytics tracker.
  void track(String event, [String detail = '']) {
    final line = detail.isEmpty ? event : '$event · $detail';
    analytics.add(line);
    if (kDebugMode) {
      debugPrint('[GN-ANALYTICS] $line');
    }
  }
}

// ── GNSeekerSlider — the top slider, on BOTH pages ──────────────────────────
//
// One segment per linked Seeker, by first name. Up to four names are kept
// visible at once; the rest remain available through the adjacent overflow
// picker, so ten linked Seekers never become ten unreadable slivers.
// Draft 3.1
// (Founder, phone feedback): this is the SAME control as the Seeker
// Connections page's top pill — SelahSegmentedToggle, the sliding frosted
// fill that travels with a screen swipe. The Network page feeds it a live
// PageController position. On the Dashboard the control itself is
// horizontally draggable, so its fill also follows the finger before the
// selected Connections context settles. The
// white unseen-dot (the toggle's own, Founder-ratified) marks a Seeker
// with an incoming request waiting. Tapping writes GNContext, so the
// other page follows automatically.
//
// Draft 3.2 REVERSAL (Founder, same day, from screenshots): with no
// Seeker linked the bar renders NOTHING — blank pages show only the
// picture-1 "+" invitation (SelahAddCircle), and the bar first appears
// with the first Seeker. (Draft 3.1 briefly showed a "Waiting for your
// Seeker…" pill here; both pages also gate at the call site.)

class GNSeekerSlider extends StatefulWidget {
  const GNSeekerSlider({
    super.key,
    required this.wards,
    this.position,
    this.onSelect,
  });

  final List<MentorLinkedPerson> wards;

  /// Live pager position — the Network page feeds its PageController's
  /// `page` so the fill travels with the swipe (the Seeker Connections
  /// page's exact mechanic). Null → the settled selected index.
  final double? position;

  /// Called with the tapped index AFTER selection is written to
  /// GNContext (the Network page animates its pager here; the Dashboard
  /// needs nothing extra).
  final ValueChanged<int>? onSelect;

  @override
  State<GNSeekerSlider> createState() => _GNSeekerSliderState();
}

class _GNSeekerSliderState extends State<GNSeekerSlider> {
  static const _maxVisible = 4;

  double? _dragPosition;
  int? _dragWindowStart;
  double _dragSegmentWidth = 1;

  int _selectedIndex(GNContext ctx) {
    final selected = ctx.effectiveSelected(widget.wards);
    for (var i = 0; i < widget.wards.length; i++) {
      if (widget.wards[i].id == selected?.id) return i;
    }
    return 0;
  }

  int _windowStart(int index) {
    if (widget.wards.length <= _maxVisible) return 0;
    return (index ~/ _maxVisible) * _maxVisible;
  }

  void _select(int index) {
    final safe = index.clamp(0, widget.wards.length - 1);
    setState(() {
      _dragPosition = null;
      _dragWindowStart = null;
    });
    GNContext.instance.selectSeeker(widget.wards[safe].id);
    widget.onSelect?.call(safe);
  }

  void _startDrag(double position, int windowStart, double segmentWidth) {
    setState(() {
      _dragPosition = position;
      _dragWindowStart = windowStart;
      _dragSegmentWidth = segmentWidth;
    });
  }

  void _updateDrag(double delta) {
    final current = _dragPosition;
    if (current == null || widget.wards.isEmpty) return;
    setState(() {
      _dragPosition = (current - (delta / _dragSegmentWidth)).clamp(
        0.0,
        (widget.wards.length - 1).toDouble(),
      );
    });
  }

  void _finishDrag(DragEndDetails details) {
    final current = _dragPosition;
    if (current == null) return;

    var target = current.round();
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 450) {
      final onSegment = (current - current.round()).abs() < 0.01;
      target = velocity < 0
          ? (onSegment ? current.round() + 1 : current.ceil())
          : (onSegment ? current.round() - 1 : current.floor());
    }
    _select(target);
  }

  void _cancelDrag() {
    setState(() {
      _dragPosition = null;
      _dragWindowStart = null;
    });
  }

  Future<void> _showAllSeekers(BuildContext context) async {
    final selectedIndex = _selectedIndex(GNContext.instance);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final availableHeight =
            (MediaQuery.sizeOf(sheetContext).height * 0.5 - 90)
                .clamp(104.0, 420.0)
                .toDouble();
        final listHeight = (widget.wards.length * 80.0)
            .clamp(104.0, availableHeight)
            .toDouble();
        return GNSheetShell(
          title: 'CHOOSE A SEEKER',
          child: SizedBox(
            height: listHeight,
            child: ListView.separated(
              itemCount: widget.wards.length,
              separatorBuilder: (_, index) =>
                  Divider(height: 1, color: SelahColors.surfaceBorder),
              itemBuilder: (context, i) {
                final ward = widget.wards[i];
                final incoming = GNContext.instance.incomingCount(
                  ward,
                  GNContext.instance.familiesFor(widget.wards, ward),
                );
                return InkWell(
                  key: Key('gn-seeker-option-${ward.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(sheetContext).pop(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: GNSeekerPickerIdentity(person: ward)),
                          if (incoming > 0)
                            Semantics(
                              label: incoming == 1
                                  ? '1 unseen request'
                                  : '$incoming unseen requests',
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: SelahColors.surfaceSignal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          if (i == selectedIndex)
                            Icon(Icons.check_rounded, size: 18, color: gnGold),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (!mounted || chosen == null) return;
    _select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = GNContext.instance;

    if (widget.wards.isEmpty) {
      // Draft 3.2: no Seeker → no bar (see the header note). Callers
      // gate on wards.isNotEmpty too; this is defence in depth.
      return SizedBox.shrink();
    }

    final selectedIndex = _selectedIndex(ctx);
    final globalPosition =
        _dragPosition ??
        widget.position?.clamp(0.0, (widget.wards.length - 1).toDouble()) ??
        selectedIndex.toDouble();
    final windowStart = _dragWindowStart ?? _windowStart(selectedIndex);
    var windowEnd = windowStart + _maxVisible;
    if (windowEnd > widget.wards.length) windowEnd = widget.wards.length;
    final visible = widget.wards.sublist(windowStart, windowEnd);
    final hasOverflow = widget.wards.length > _maxVisible;
    final hiddenCount = widget.wards.length - visible.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflowWidth = hasOverflow ? 52.0 : 0.0;
        final sliderWidth = constraints.maxWidth - overflowWidth;
        final segmentWidth = sliderWidth / visible.length;
        final localPosition = (globalPosition - windowStart).clamp(
          0.0,
          (visible.length - 1).toDouble(),
        );

        return Row(
          key: const Key('gn-seeker-slider'),
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) =>
                    _startDrag(globalPosition, windowStart, segmentWidth),
                onHorizontalDragUpdate: (details) =>
                    _updateDrag(details.primaryDelta ?? 0),
                onHorizontalDragEnd: _finishDrag,
                onHorizontalDragCancel: _cancelDrag,
                child: SelahSegmentedToggle(
                  labels: [for (final ward in visible) ward.firstName],
                  position: localPosition,
                  labelSize: visible.length >= 3 ? 11.5 : 13,
                  badges: [
                    for (final ward in visible)
                      ctx.incomingCount(
                        ward,
                        ctx.familiesFor(widget.wards, ward),
                      ),
                  ],
                  onChanged: (i) => _select(windowStart + i),
                ),
              ),
            ),
            if (hasOverflow) ...[
              SizedBox(width: 8),
              Semantics(
                button: true,
                label:
                    'Show all ${widget.wards.length} Seekers, $hiddenCount hidden',
                child: GestureDetector(
                  key: const Key('gn-seeker-more'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAllSeekers(context),
                  child: Container(
                    width: 44,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SelahColors.surfaceFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SelahColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+$hiddenCount',
                          style: SelahText.button(
                            size: 10.5,
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: SelahColors.ink(0.54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── shared small widgets ────────────────────────────────────────────────────

class GNDevChip extends StatelessWidget {
  const GNDevChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Shepherd Network preview controls',
      child: Semantics(
        button: true,
        label: 'Shepherd Network preview controls',
        child: GestureDetector(
          key: const Key('gn-preview-controls'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SelahColors.iconButtonBg,
              shape: BoxShape.circle,
              border: Border.all(color: SelahColors.iconButtonBorder),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 15,
              color: SelahColors.ink(0.38),
            ),
          ),
        ),
      ),
    );
  }
}

class _GNInitialCircle extends StatelessWidget {
  const _GNInitialCircle({
    required this.text,
    this.size = 30,
    this.gold = false,
  });
  final String text;
  final double size;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SelahColors.iconButtonBg,
        border: Border.all(
          color: gold
              ? gnGold.withValues(alpha: 0.7)
              : SelahColors.iconButtonBorder,
        ),
      ),
      child: Text(
        text.isEmpty ? '?' : text.characters.first.toUpperCase(),
        style: SelahText.body(size: size * 0.4, color: SelahColors.foreground),
      ),
    );
  }
}

class GNVerifiedBadge extends StatelessWidget {
  const GNVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gnGold.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        '✓ VERIFIED',
        style: SelahText.chapterLabel(color: gnGold).copyWith(fontSize: 7.5),
      ),
    );
  }
}

class GNFamilySeal extends StatelessWidget {
  const GNFamilySeal({
    super.key,
    required this.family,
    required this.size,
    required this.showPhoto,
  });
  final GNFamily family;
  final double size;
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    if (showPhoto) {
      // PROVISIONAL photo placeholder (Rule 34: level permits at this rung).
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: const SelahProfileImage(''),
              ),
              Container(
                color: SelahColors.luxuryDarkPurple.withValues(alpha: 0.35),
              ),
              Text(
                family.initial,
                style: SelahText.heading(size: size * 0.4, color: Colors.white),
              ),
              Positioned(
                bottom: 2,
                child: Text(
                  'PHOTO',
                  style: SelahText.chapterLabel(
                    color: SelahColors.ink(0.70),
                  ).copyWith(fontSize: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SelahColors.iconButtonBg,
        border: Border.all(color: gnGold.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Text(
        family.initial,
        style: SelahText.heading(size: size * 0.4, color: SelahColors.ink(0.70)),
      ),
    );
  }
}

class GNActionPill extends StatelessWidget {
  const GNActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.goldAccent = false,
    this.borderless = false,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool goldAccent;
  final bool borderless;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fill = goldAccent
        ? gnGold.withValues(alpha: enabled ? 0.18 : 0.08)
        : primary
        ? SelahColors.actionFill.withValues(alpha: enabled ? 1.0 : 0.18)
        : enabled
        ? SelahColors.surfaceFill
        : SelahColors.surfaceFill.withValues(alpha: 0.45);
    final foreground = goldAccent
        ? gnGold.withValues(alpha: enabled ? 1.0 : 0.32)
        : primary
        ? SelahColors.onAction.withValues(alpha: enabled ? 1.0 : 0.32)
        : SelahColors.foreground.withValues(alpha: enabled ? 0.78 : 0.25);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: borderless || primary || goldAccent
                  ? Colors.transparent
                  : enabled
                  ? SelahColors.surfaceBorder
                  : SelahColors.surfaceBorder.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SelahText.button(size: 11.5, color: foreground),
          ),
        ),
      ),
    );
  }
}

class GNQuietNotice extends StatelessWidget {
  const GNQuietNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SelahColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SelahColors.glassBorder, width: 0.7),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: SelahColors.ink(0.54)),
          SizedBox(height: 10),
          Text(title, style: SelahText.heading(size: 16)),
          SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Linked Seeker identity with the signed-in Shepherd's recorded relationship
/// and role, without a repetitive introductory label. The recorded relation
/// remains the Shepherd's relation to the Seeker; never infer it from a name.
class GNSeekerPickerIdentity extends StatelessWidget {
  const GNSeekerPickerIdentity({super.key, required this.person});
  final MentorLinkedPerson person;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(person.firstName, style: SelahText.body(size: 13.5)),
      const SizedBox(height: 3),
      Text(
        '${person.relationshipLabel ?? 'Relationship not recorded'} · ${person.isMain ? 'Main Shepherd' : 'Additional Shepherd'}',
        style: SelahText.subtext(size: 10.5),
      ),
    ],
  );
}

class GNSheetShell extends StatelessWidget {
  const GNSheetShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('selah-modal-sheet-surface'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: SelahColors.modalSheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: SelahText.chapterLabel(color: SelahColors.ink(0.38)),
            ),
            SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── connections cards (Rules 24-32) — panel- and sheet-internal ─────────────

class _GNIncomingCard extends StatelessWidget {
  const _GNIncomingCard({
    required this.ward,
    required this.family,
    required this.capped,
    required this.onShepherd,
    required this.onConnect,
    required this.onNotForUs,
  });
  final MentorLinkedPerson ward;
  final GNFamily family;
  final bool capped;
  final VoidCallback onShepherd;
  final VoidCallback onConnect;
  final VoidCallback onNotForUs;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('gn-incoming-${family.id}'),
      margin: const EdgeInsets.only(bottom: SelahCardMetrics.spacing),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        border: Border.all(
          color: Color.alphaBlend(
            gnGold.withValues(alpha: 0.38),
            SelahColors.surfaceBorder,
          ),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GNFamilySeal(family: family, size: 42, showPhoto: false),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.display,
                      style: SelahText.body(
                        size: 14,
                        color: SelahColors.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Their Mentor requested connection for ${ward.firstName}',
                      style: SelahText.subtext(size: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: onShepherd,
            child: Text(
              '${family.shepherdLabel} · ✓ verified · View Shepherd ›',
              style: SelahText.subtext(size: 10.5, color: gnGold),
            ),
          ),
          SizedBox(height: 10),
          if (capped)
            Text(
              '3 of 3 live processes — close one before connecting (Rule 40).',
              style: SelahText.subtext(size: 10.5, color: gnGold),
            )
          else
            Row(
              children: [
                Expanded(
                  child: GNActionPill(label: 'Not for us', onTap: onNotForUs),
                ),
                SizedBox(width: 7),
                Expanded(
                  flex: 2,
                  child: GNActionPill(
                    key: const Key('gn-connect-family-action'),
                    label: 'Connect with this family',
                    goldAccent: true,
                    onTap: onConnect,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GNSentCard extends StatelessWidget {
  const _GNSentCard({required this.family, required this.onWithdraw});
  final GNFamily family;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('gn-sent-${family.id}'),
      margin: const EdgeInsets.only(bottom: SelahCardMetrics.spacing),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Row(
        children: [
          GNFamilySeal(family: family, size: 36, showPhoto: false),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.display,
                  style: SelahText.body(size: 13, color: SelahColors.foreground),
                ),
                SizedBox(height: 2),
                Text(
                  'Awaiting their Mentor · quietly becomes "No longer active" after 14 days',
                  style: SelahText.subtext(size: 10),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onWithdraw,
            child: Text(
              'Withdraw',
              style: SelahText.subtext(size: 11, color: SelahColors.ink(0.54)),
            ),
          ),
        ],
      ),
    );
  }
}

enum GNNetworkRequestKind { sent, received }

/// One Network request inbox for the currently selected Seeker. Browser owns
/// only untouched families; once a request exists, its family is rendered
/// here and cannot be served again as a discovery card.
class GNNetworkRequestList extends StatelessWidget {
  const GNNetworkRequestList({
    super.key,
    required this.wards,
    required this.ward,
    required this.kind,
  });

  final List<MentorLinkedPerson> wards;
  final MentorLinkedPerson ward;
  final GNNetworkRequestKind kind;

  @override
  Widget build(BuildContext context) {
    final ctx = GNContext.instance;
    final families = ctx.familiesFor(wards, ward);
    final requests = families.where((family) {
      final stage = ctx.stageOf(ward, family);
      return kind == GNNetworkRequestKind.sent
          ? stage == GNStage.sent
          : stage == GNStage.incoming;
    }).toList();

    final title = kind == GNNetworkRequestKind.sent
        ? 'No sent requests'
        : 'No received requests';
    final message = kind == GNNetworkRequestKind.sent
        ? 'Requests you send for ${ward.firstName} will appear here.'
        : 'Requests another family sends for ${ward.firstName} will appear here.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: PageStorageKey('shepherd-network-${kind.name}-${ward.id}'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 120)
                .clamp(0.0, double.infinity)
                .toDouble(),
          ),
          child: !ctx.isMainMentor
              ? Center(
                  child: GNQuietNotice(
                    icon: Icons.shield_outlined,
                    title: 'Handled by the Main Shepherd',
                    message:
                        'Only the Main Shepherd manages requests for ${ward.firstName}.',
                  ),
                )
              : requests.isEmpty
              ? Center(
                  child: SelahEmptyState(
                    icon: kind == GNNetworkRequestKind.sent
                        ? Icons.outbox_outlined
                        : Icons.mark_email_unread_outlined,
                    title: title,
                    message: message,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final family in requests)
                      if (kind == GNNetworkRequestKind.sent)
                        _GNSentCard(
                          family: family,
                          onWithdraw: () {
                            ctx.track('request_withdrawn', family.id);
                            ctx.setStage(ward, family, GNStage.closed);
                          },
                        )
                      else
                        _GNIncomingCard(
                          ward: ward,
                          family: family,
                          capped: ctx.liveCount(ward, families) >= 3,
                          onShepherd: () {
                            ctx.track('shepherd_viewed', family.id);
                            showGNShepherdSheet(context, family);
                          },
                          onConnect: () {
                            ctx.track('connected', family.id);
                            ctx.setStage(ward, family, GNStage.connected);
                          },
                          onNotForUs: () {
                            ctx.track('not_for_us', family.id);
                            ctx.setStage(ward, family, GNStage.closed);
                          },
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GNConnectedCard extends StatelessWidget {
  const _GNConnectedCard({
    required this.ward,
    required this.family,
    required this.stage,
    required this.onShepherd,
    required this.onProfile,
    required this.onWithdraw,
    required this.onProceed,
  });
  final MentorLinkedPerson ward;
  final GNFamily family;
  final GNStage stage;
  final VoidCallback onShepherd;
  final VoidCallback onProfile;
  final VoidCallback onWithdraw;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final revealed = stage == GNStage.revealed;
    final mineConfirmed = stage == GNStage.proceedMine || revealed;
    return Container(
      key: Key('gn-connected-${family.id}'),
      margin: const EdgeInsets.only(bottom: SelahCardMetrics.spacing),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          gnGold.withValues(alpha: revealed ? 0.12 : 0.07),
          revealed ? SelahColors.surfaceEmphasisFill : SelahColors.surfaceFill,
        ),
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        border: Border.all(
          color: Color.alphaBlend(
            gnGold.withValues(alpha: 0.46),
            revealed
                ? SelahColors.surfaceEmphasisBorder
                : SelahColors.surfaceBorder,
          ),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GNInitialCircle(text: ward.firstName, gold: true),
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Transform.translate(
                  offset: const Offset(-8, 0),
                  child: GNFamilySeal(
                    family: family,
                    size: 30,
                    showPhoto: false,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      revealed ? 'Introduced' : 'Connected',
                      style: SelahText.body(size: 13.5, color: gnGold),
                    ),
                    SizedBox(height: 1),
                    Text(
                      '${family.display} · ${family.shepherdLabel.toLowerCase()}',
                      style: SelahText.subtext(size: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 9),
          if (revealed) ...[
            Text(
              'Both Mentors agreed — the introduction is now visible to ${ward.firstName} and to ${family.display}\'s family, at the same moment. Their decisions continue on the Shepherd Dashboard.',
              style: SelahText.subtext(size: 11, color: SelahColors.ink(0.70)),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: GNActionPill(label: 'Their profile', onTap: onProfile),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: GNActionPill(label: 'Their Mentor', onTap: onShepherd),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              family.theirMentorConfirmed
                  ? 'Their Mentor has confirmed "Proceed to the Seekers".'
                  : 'Structured exchange is open (no free text — D6).',
              style: SelahText.subtext(size: 10.5),
            ),
            SizedBox(height: 8),
            if (mineConfirmed)
              Text(
                'You have confirmed — awaiting their Mentor. You can withdraw until both confirm.',
                style: SelahText.subtext(size: 10.5, color: gnGold),
              )
            else
              SizedBox(
                width: double.infinity,
                child: GNActionPill(
                  label: 'Proceed to the Seekers',
                  primary: true,
                  onTap: onProceed,
                ),
              ),
            SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: onWithdraw,
                child: Text(
                  'Withdraw — shown only as "No longer active"',
                  style: SelahText.subtext(
                    size: 10,
                    color: SelahColors.ink(0.38),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GNClosedRow extends StatelessWidget {
  const _GNClosedRow({required this.family});
  final GNFamily family;

  @override
  Widget build(BuildContext context) {
    // Rule 30: privacy-minimal neutral record only.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Text(
            '${family.initial}.',
            style: SelahText.body(size: 12.5, color: SelahColors.ink(0.54)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              family.region,
              style: SelahText.subtext(size: 11, color: SelahColors.ink(0.38)),
            ),
          ),
          Text(
            'No longer active',
            style: SelahText.subtext(size: 11, color: SelahColors.ink(0.54)),
          ),
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Text(
      text,
      style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
    ),
  );
}

// ── GNConnectionsPanel — the Connections context, now ON THE DASHBOARD ──────
//
// Founder, 2026-08-23: "add connections info in dashboard, meaning the
// context that would have been in Connections showing in dashboard".
// This renders that whole context for ONE Seeker (the slider's pick) as
// a plain Column, sized to sit inside the Dashboard's ListView.

class GNConnectionsPanel extends StatelessWidget {
  const GNConnectionsPanel({
    super.key,
    required this.wards,
    required this.ward,
  });

  final List<MentorLinkedPerson> wards;
  final MentorLinkedPerson ward;

  @override
  Widget build(BuildContext context) {
    final ctx = GNContext.instance;
    final fams = ctx.familiesFor(wards, ward);
    final live = ctx.liveCount(ward, fams);

    final header = Row(
      children: [
        Expanded(
          child: Text(
            'CONNECTIONS',
            style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
          ),
        ),
        Text(
          '$live OF 3 LIVE',
          style: SelahText.chapterLabel(
            color: live >= 3 ? gnGold : SelahColors.ink(0.38),
          ),
        ),
      ],
    );

    if (!ctx.isMainMentor) {
      // Rule 37: Additional Shepherds see neutral status only.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: 10),
          GNQuietNotice(
            icon: Icons.shield_outlined,
            title: 'Handled by the Main Mentor',
            message:
                '$live live process(es) for ${ward.firstName} are handled by the Main Mentor. Additional Shepherds advise the family — they do not see the other family\'s details.',
          ),
        ],
      );
    }

    final incoming = fams
        .where((f) => ctx.stageOf(ward, f) == GNStage.incoming)
        .toList();
    final sent = fams
        .where((f) => ctx.stageOf(ward, f) == GNStage.sent)
        .toList();
    final connected = fams.where((f) {
      final s = ctx.stageOf(ward, f);
      return s == GNStage.connected ||
          s == GNStage.proceedMine ||
          s == GNStage.revealed;
    }).toList();
    final closed = fams
        .where((f) => ctx.stageOf(ward, f) == GNStage.closed)
        .toList();

    if (incoming.isEmpty &&
        sent.isEmpty &&
        connected.isEmpty &&
        closed.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: 10),
          Text(
            'No connection activity yet for ${ward.firstName}. Requests you send, and requests other families send, appear here.',
            style: SelahText.subtext(
              size: 12.5,
              color: SelahColors.foreground.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (incoming.isNotEmpty) ...[
          _sectionLabel('INCOMING — OLDEST FIRST'),
          for (final f in incoming)
            _GNIncomingCard(
              ward: ward,
              family: f,
              capped: live >= 3,
              onShepherd: () {
                ctx.track('shepherd_viewed', f.id);
                showGNShepherdSheet(context, f);
              },
              onConnect: () {
                ctx.track('connected', f.id);
                ctx.setStage(ward, f, GNStage.connected);
              },
              onNotForUs: () {
                ctx.track('not_for_us', f.id);
                ctx.setStage(ward, f, GNStage.closed);
              },
            ),
        ],
        if (sent.isNotEmpty) ...[
          _sectionLabel('SENT'),
          for (final f in sent)
            _GNSentCard(
              family: f,
              onWithdraw: () {
                ctx.track('request_withdrawn', f.id);
                ctx.setStage(ward, f, GNStage.closed);
              },
            ),
        ],
        if (connected.isNotEmpty) ...[
          _sectionLabel('CONNECTED'),
          for (final f in connected)
            _GNConnectedCard(
              ward: ward,
              family: f,
              stage: ctx.stageOf(ward, f),
              onShepherd: () {
                ctx.track('shepherd_viewed', f.id);
                showGNShepherdSheet(context, f);
              },
              onProfile: () {
                ctx.track('card_viewed', '${f.id} rung2');
                showGNProfileSheet(context, f, rung2: true);
              },
              onWithdraw: () {
                ctx.track('request_withdrawn', f.id);
                ctx.setStage(ward, f, GNStage.closed);
              },
              onProceed: () {
                if (f.theirMentorConfirmed) {
                  ctx.track('proceed_confirmed', f.id);
                  ctx.track('introduction_revealed', f.id);
                  ctx.setStage(ward, f, GNStage.revealed);
                } else {
                  ctx.track('proceed_confirmed', f.id);
                  ctx.setStage(ward, f, GNStage.proceedMine);
                }
              },
            ),
        ],
        if (closed.isNotEmpty) ...[
          _sectionLabel('HISTORY'),
          for (final f in closed) _GNClosedRow(family: f),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Closures show only "No longer active" — one neutral state for every cause. Preview: PROVISIONAL mock data; nothing here changes live data.',
            style: SelahText.subtext(size: 10.5, color: SelahColors.ink(0.38)),
          ),
        ),
      ],
    );
  }
}

// ── shared sheets ───────────────────────────────────────────────────────────

void showGNShepherdSheet(BuildContext context, GNFamily family) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => GNSheetShell(
      title: 'THE OTHER SHEPHERD',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GNInitialCircle(text: 'G', size: 44, gold: true),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.shepherdLabel,
                      style: SelahText.body(
                        size: 14.5,
                        color: SelahColors.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Main Shepherd · represents 1 Seeker',
                      style: SelahText.subtext(size: 11),
                    ),
                  ],
                ),
              ),
              const GNVerifiedBadge(),
            ],
          ),
          SizedBox(height: 12),
          _factRow('Verification', 'ID verified · 2026'),
          _factRow('Region', family.region),
          SizedBox(height: 10),
          Text(
            'PROVISIONAL field set — the Shepherd-profile contents are a pending Founder decision. No free text (D6); no responsiveness indicators (Rule 29).',
            style: SelahText.subtext(size: 10, color: SelahColors.ink(0.38)),
          ),
        ],
      ),
    ),
  );
}

Widget _factRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: SelahText.subtext(size: 11.5))),
        Text(
          value,
          style: SelahText.body(size: 12, color: SelahColors.foreground),
        ),
      ],
    ),
  );
}

void showGNProfileSheet(
  BuildContext context,
  GNFamily family, {
  required bool rung2,
}) {
  final showPhoto = rung2
      ? family.photoLevel != GNPhotoLevel.never
      : family.photoLevel == GNPhotoLevel.card;
  if (!rung2) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SeekerProfileScreen(
          profile: SeekerProfile(
            id: family.id,
            // Shepherd Network intentionally exposes the bounded display
            // identity already present on the card, not a full legal name or
            // extra profile fields.
            firstName: family.display,
            age: 0,
            city: '',
            photos: family.photos,
            gender: '',
          ),
          swipeDownToDismiss: true,
          showCloseButtonWhenSwipeDismiss: true,
          matchBrowseIdentityLayout: true,
          emptyPhoto: _GNFullProfilePhoto(
            initial: family.initial,
            showPhoto: showPhoto,
          ),
        ),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => GNSheetShell(
      title: rung2 ? 'PROFILE — CONNECTED (RUNG 2)' : 'CARD — RUNG 0',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GNFamilySeal(family: family, size: 54, showPhoto: showPhoto),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.display, style: SelahText.heading(size: 18)),
                    SizedBox(height: 2),
                    Text(
                      '${family.region} · ${family.band.toLowerCase()}',
                      style: SelahText.subtext(size: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (!showPhoto)
            Text(
              family.photoLevel == GNPhotoLevel.afterConnect && !rung2
                  ? 'Photo is shared after the Mentors connect.'
                  : 'No photo is shared in Shepherd Network.',
              style: SelahText.subtext(size: 11, color: SelahColors.ink(0.54)),
            ),
          if (rung2) ...[
            SizedBox(height: 6),
            Text(
              'Connected unlock: the ordinary Browse-level profile appears here (PROVISIONAL in this draft). Never unlocked: contact details, exact location, private answers, numeric scores, histories (Rule 29).',
              style: SelahText.subtext(size: 11),
            ),
          ] else ...[
            SizedBox(height: 6),
            Text(
              'More unlocks only when both Mentors connect (Rule 28).',
              style: SelahText.subtext(size: 11),
            ),
          ],
        ],
      ),
    ),
  );
}

class _GNFullProfilePhoto extends StatelessWidget {
  const _GNFullProfilePhoto({required this.initial, required this.showPhoto});

  final String initial;
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('gn-profile-photo-viewer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: showPhoto
              ? [
                  SelahColors.royalPurple.withValues(alpha: 0.88),
                  SelahColors.luxuryDarkPurple,
                ]
              : [SelahColors.iconButtonBg, SelahColors.luxuryDarkPurple],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: SelahText.heading(size: 78, color: Colors.white),
        ),
      ),
    );
  }
}

// The Network page's merge card opens THIS instead of switching pages —
// the incoming request is reviewable in place, and the Dashboard shows
// the same request in its Connections section (one shared state).
void showGNIncomingSheet(
  BuildContext context, {
  required List<MentorLinkedPerson> wards,
  required MentorLinkedPerson ward,
}) {
  final ctx = GNContext.instance;
  final fams = ctx.familiesFor(wards, ward);
  final incoming = fams
      .where((f) => ctx.stageOf(ward, f) == GNStage.incoming)
      .toList();
  final live = ctx.liveCount(ward, fams);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => GNSheetShell(
      title: 'INCOMING REQUEST — FOR ${ward.firstName.toUpperCase()}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incoming.isEmpty)
            Text(
              'Nothing is waiting — this request has already been handled.',
              style: SelahText.subtext(size: 12),
            )
          else
            for (final f in incoming)
              _GNIncomingCard(
                ward: ward,
                family: f,
                capped: live >= 3,
                onShepherd: () {
                  ctx.track('shepherd_viewed', f.id);
                  showGNShepherdSheet(context, f);
                },
                onConnect: () {
                  Navigator.of(sheetContext).pop();
                  ctx.track('connected', f.id);
                  ctx.setStage(ward, f, GNStage.connected);
                },
                onNotForUs: () {
                  Navigator.of(sheetContext).pop();
                  ctx.track('not_for_us', f.id);
                  ctx.setStage(ward, f, GNStage.closed);
                },
              ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Requests also live on your Dashboard — everything about your Seekers lives there.',
              style: SelahText.subtext(size: 10.5, color: SelahColors.ink(0.38)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── dev sheet (Rule 44: never in release builds) ────────────────────────────
// Opened from the icon-only preview control on BOTH pages, so scenes set while looking at
// the Dashboard apply on Network too — it is all one GNContext.

void showGNDevSheet(BuildContext context) {
  final ctx = GNContext.instance;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (chipContext, setSheet) {
        Widget chip(String label, bool on, VoidCallback onTap) {
          return GestureDetector(
            onTap: () {
              onTap();
              setSheet(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: on
                    ? Color.alphaBlend(
                        gnGold.withValues(alpha: 0.16),
                        SelahColors.frostSelectedFill,
                      )
                    : SelahColors.surfaceFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: on
                      ? Color.alphaBlend(
                          gnGold.withValues(alpha: 0.42),
                          SelahColors.frostSelectedBorder,
                        )
                      : SelahColors.surfaceBorder,
                  width: 0.6,
                ),
              ),
              child: Text(
                label,
                style: SelahText.subtext(
                  size: 11,
                  color: on ? gnGold : SelahColors.ink(0.70),
                ),
              ),
            ),
          );
        }

        return GNSheetShell(
          title: 'PREVIEW CONTROLS · SCENES · ROLE · ANALYTICS',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final scene in GNScene.values)
                    chip(
                      scene.name,
                      ctx.scene == scene,
                      () => ctx.setScene(scene),
                    ),
                  chip(
                    ctx.isMainMentor ? 'role: Main' : 'role: Additional',
                    !ctx.isMainMentor,
                    () => ctx.setMainMentor(!ctx.isMainMentor),
                  ),
                  chip('reset', false, ctx.reset),
                ],
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GNActionPill(
                  label: 'Analytics events (${ctx.analytics.length}) ›',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showGNAnalyticsSheet(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showGNAnalyticsSheet(BuildContext context) {
  final ctx = GNContext.instance;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => GNSheetShell(
      title: 'ANALYTICS EVENTS — PROVISIONAL TRACKER (RULE 41)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ctx.analytics.isEmpty)
            Text(
              'No events yet — interact with the preview.',
              style: SelahText.subtext(size: 12),
            )
          else
            for (final line in ctx.analytics.reversed.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  line,
                  style: SelahText.subtext(
                    size: 11,
                    color: SelahColors.ink(0.70),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
