import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../models/journey_match.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_journey_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_card_metrics.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_segmented_toggle.dart';
import '../../widgets/selah_state_widgets.dart';
import '../matches/journey_timeline_screen.dart';

typedef PastJourneysLoader =
    Future<List<JourneyMatch>?> Function({required List<String> statuses});

/// The profile-owned archive for Paused and Ended Journey records.
///
/// Connections remains the live working surface. This page is deliberately
/// read-only: an archived row never gains a return action merely because it
/// is visible here. Exact expiry, response-time and Paused-cap rules remain
/// owned by OA-SELAH-299 rather than being invented in the client.
class PastJourneysScreen extends StatefulWidget {
  final PastJourneysLoader? loader;
  final List<JourneyMatch>? previewPaused;
  final List<JourneyMatch>? previewEnded;

  const PastJourneysScreen({
    super.key,
    this.loader,
    this.previewPaused,
    this.previewEnded,
  });

  @override
  State<PastJourneysScreen> createState() => _PastJourneysScreenState();
}

class _PastJourneysScreenState extends State<PastJourneysScreen> {
  late final PageController _pageController;
  double _position = 0;
  bool _loading = true;
  bool _failed = false;
  List<JourneyMatch> _paused = const [];
  List<JourneyMatch> _ended = const [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController()..addListener(_followSwipe);
    _load();
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_followSwipe)
      ..dispose();
    super.dispose();
  }

  void _followSwipe() {
    final page = _pageController.page;
    if (!mounted || page == null || page == _position) return;
    setState(() => _position = page);
  }

  void _selectPage(int index) {
    SelahSegmentedMotion.animateToPage(_pageController, index);
  }

  Future<void> _load() async {
    if (widget.previewPaused != null || widget.previewEnded != null) {
      setState(() {
        _paused = widget.previewPaused ?? const [];
        _ended = widget.previewEnded ?? const [];
        _loading = false;
      });
      return;
    }

    final loader = widget.loader ?? SelahJourneyService.fetchJourneyMatches;
    final active = await loader(statuses: const ['active']);
    final ended = await loader(statuses: const ['ended']);
    if (!mounted) return;
    if (active == null || ended == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _paused = active
          .where((journey) => journey.isSuspended)
          .toList(growable: false);
      _ended = ended;
      _loading = false;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: SelahColors.foregroundSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Past Journeys',
                      style: SelahText.heading(size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: SelahSegmentedToggle(
                key: const ValueKey('past-journeys-toggle'),
                labels: const ['Paused', 'Ended'],
                position: _position,
                onChanged: _selectPage,
                labelSize: 13,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PageView(
                  key: const ValueKey('past-journeys-pages'),
                  controller: _pageController,
                  physics: SelahSegmentedMotion.pagePhysics,
                  onPageChanged: (index) => setState(() {
                    _position = index.toDouble();
                  }),
                  children: [_body(0), _body(1)],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _body(int index) {
    if (_loading) return const Center(child: SelahLoading());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SelahEmptyState(
            icon: Icons.refresh_rounded,
            title: "We couldn't load this just now",
            message: 'Check your connection and try again. Nothing changed.',
            ctaLabel: 'Try again',
            onCta: () {
              setState(() {
                _loading = true;
                _failed = false;
              });
              _load();
            },
          ),
        ),
      );
    }

    final rows = index == 0 ? _paused : _ended;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SelahEmptyState(
            icon: index == 0
                ? Icons.pause_circle_outline_rounded
                : Icons.history_rounded,
            title: index == 0
                ? 'No Paused Journeys yet'
                : 'No Ended Journeys yet',
            message: index == 0
                ? 'Journeys placed on hold will appear here until they continue or end.'
                : 'Journeys brought to a close will appear here, with their history kept.',
          ),
        ),
      );
    }

    // Preview/test archives do not initialise Supabase. Keep the archive
    // renderable from local preview rows without touching the auth singleton.
    String? currentUserId;
    if (widget.previewPaused == null && widget.previewEnded == null) {
      try {
        currentUserId = SelahAuth.currentUser?.id;
      } catch (_) {
        currentUserId = null;
      }
    }
    final requestsForYou = index == 0
        ? rows
              .where(
                (journey) =>
                    journey.pause.isPending &&
                    journey.pause.requestedBy != null &&
                    journey.pause.requestedBy != currentUserId,
              )
              .toList(growable: false)
        : const <JourneyMatch>[];
    final ordinary = requestsForYou.isEmpty
        ? rows
        : rows.where((journey) => !requestsForYou.contains(journey)).toList();

    return ListView(
      key: ValueKey<String>('past-journeys-${index == 0 ? 'paused' : 'ended'}'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 42),
      children: [
        if (requestsForYou.isNotEmpty) ...[
          _PastSectionLabel('REQUESTS FOR YOU'),
          const SizedBox(height: 8),
          ...requestsForYou.map(
            (journey) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PastJourneyCard(journey: journey),
            ),
          ),
          if (ordinary.isNotEmpty) ...[
            const SizedBox(height: 6),
            _PastSectionLabel('YOUR PAUSED JOURNEYS'),
            const SizedBox(height: 8),
          ],
        ],
        ...ordinary.map(
          (journey) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PastJourneyCard(journey: journey),
          ),
        ),
      ],
    );
  }
}

class _PastSectionLabel extends StatelessWidget {
  final String text;
  const _PastSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: SelahText.chapterLabel(color: SelahColors.foregroundMuted),
  );
}

class _PastJourneyCard extends StatelessWidget {
  final JourneyMatch journey;

  const _PastJourneyCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final profile = journey.profile;
    final state = journey.status == 'ended'
        ? 'Ended Journey'
        : journey.pausedFor.isEmpty
        ? 'Paused Journey'
        : 'Paused · ${journey.pausedFor}';

    return Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JourneyTimelineScreen(
              withProfile: profile,
              isMock: journey.isMock,
              journeyStage: journey.journeyStage,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(SelahCardMetrics.padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
            border: Border.all(color: SelahColors.surfaceBorder, width: 0.6),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  SelahCardMetrics.thumbRadius,
                ),
                child: profile.photos.isEmpty
                    ? Container(
                        width: SelahCardMetrics.thumb,
                        height: SelahCardMetrics.thumb,
                        color: SelahColors.iconButtonBg,
                        alignment: Alignment.center,
                        child: Text(
                          profile.firstName.isEmpty
                              ? '?'
                              : profile.firstName[0],
                          style: SelahText.heading(size: 16),
                        ),
                      )
                    : SelahProfileImage(
                        profile.photoUrl,
                        width: SelahCardMetrics.thumb,
                        height: SelahCardMetrics.thumb,
                      ),
              ),
              const SizedBox(width: SelahCardMetrics.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.firstName}, ${profile.age}',
                      style: SelahText.body(
                        size: 14,
                        color: SelahColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(state, style: SelahText.subtext(size: 11)),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: SelahColors.foregroundMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
