// LOCK 15 quiet opening pages. The existing parent retains role/signup routing.
import 'package:flutter/material.dart';

import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_onboarding_edge_swipe.dart';
import '../widgets/selah_onboarding_study.dart';
import '../widgets/selah_quiet_page_presentation.dart';
import '../widgets/selah_shepherd_invite_views.dart';

class DevOnboardingOpening extends StatefulWidget {
  const DevOnboardingOpening({
    super.key,
    required this.direction,
    required this.welcomeName,
    required this.onContinue,
    this.onBackToProvider,
  });

  final SelahOnboardingDirection direction;
  final String welcomeName;
  final VoidCallback onContinue;
  final VoidCallback? onBackToProvider;

  @override
  State<DevOnboardingOpening> createState() => _DevOnboardingOpeningState();
}

class _DevOnboardingOpeningState extends State<DevOnboardingOpening> {
  static const _headings = [
    'A pause before every step.',
    'You won’t walk alone.',
    'Faith first.',
    'Everyone is verified.',
  ];
  static const _bodies = [
    'Selah is a Christian space to seek marriage slowly, with prayer and with people who know you.',
    'Every Seeker has a Shepherd: a parent, pastor or friend in faith who sees each request and prays with you.',
    'You meet each person with their church and their faith beside their photo. You both choose before anything begins.',
    'Every Seeker and Shepherd confirms who they are before joining. It keeps Selah a place for people serious about marriage.',
  ];
  int _page = 0;
  bool _finished = false;
  bool _revoked = false;

  bool get _allowed {
    if (!SelahDeveloperAccess.canUseDeveloperTools) _revoked = true;
    return mounted &&
        !_revoked &&
        !_finished &&
        ModalRoute.of(context)?.isCurrent != false;
  }

  @override
  void initState() {
    super.initState();
    _revoked = !SelahDeveloperAccess.canUseDeveloperTools;
    SelahDeveloperAccess.authorizationChanges.addListener(_authorityChanged);
  }

  void _authorityChanged() {
    if (!SelahDeveloperAccess.canUseDeveloperTools) _revoked = true;
    if (mounted) setState(() {});
  }

  bool _current(int page) => _allowed && _page == page;

  void _finish(int page) {
    if (!_current(page)) return;
    setState(() => _finished = true);
    widget.onContinue();
  }

  void _next(int page) {
    if (!_current(page)) return;
    if (page == _headings.length - 1) {
      _finish(page);
    } else {
      setState(() => _page++);
    }
  }

  void _back(int page) {
    if (!_current(page) || page == 0) return;
    setState(() => _page--);
  }

  Widget _link(String text, Key key, VoidCallback action) => TextButton(
    key: key,
    onPressed: action,
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: SelahColors.lake,
    ),
    child: Text(text, style: SelahText.button(color: SelahColors.lake)),
  );

  @override
  void dispose() {
    SelahDeveloperAccess.authorizationChanges.removeListener(_authorityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      key: ValueKey('dev_onboarding_introduction_${widget.direction.name}'),
      backgroundColor: SelahColors.mist,
      body: !_allowed
          ? const SizedBox.shrink()
          : Semantics(
              key: const ValueKey('first_pages_page_count'),
              label: 'Page ${page + 1} of 4',
              liveRegion: true,
              child: SelahOnboardingHorizontalSwipe(
                key: ValueKey('first_pages_page_${page + 1}'),
                // The retained listener names rightward travel "Next".
                // LOCK15 uses the physical leftward swipe for Next instead.
                onNext: page > 0 ? () => _back(page) : null,
                onPrevious: () => _next(page),
                child: SelahQuietPagePresentation(
                  header: Row(
                    children: [
                      if (page > 0)
                        _link(
                          '‹ Back',
                          const ValueKey('first_pages_back'),
                          () => _back(page),
                        ),
                      const Spacer(),
                      if (page < 3)
                        _link(
                          'Skip',
                          const ValueKey('first_pages_skip'),
                          () => _finish(page),
                        ),
                    ],
                  ),
                  label: 'HOW Selah WORKS',
                  heading: _headings[page],
                  body: _bodies[page],
                  headingKey: ValueKey('first_pages_heading_${page + 1}'),
                  bodyKey: ValueKey('first_pages_body_${page + 1}'),
                  afterBody: [
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Container(
                              key: ValueKey('first_pages_dash_$i'),
                              width: 22,
                              height: 3,
                              decoration: BoxDecoration(
                                color: page == i
                                    ? SelahColors.lake
                                    : SelahColors.line,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  actions: [
                    SelahInviteButton(
                      key: const ValueKey('first_pages_next'),
                      label: page == 3 ? 'Continue' : 'Next',
                      onPressed: () => _next(page),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
