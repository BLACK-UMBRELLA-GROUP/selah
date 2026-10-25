// Internal Phase A moderation review queue preview.
//
// Local state only. It must never be presented as an operational queue: Phase
// C provides the server-owned report/photo records and Vision verdicts.

import 'package:flutter/material.dart';

import '../../models/seeker_profile.dart';
import '../../models/selah_moderation_review.dart';
import '../../dev/selah_developer_route_gate.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_moderation_preview_store.dart';
import '../../services/selah_report_service.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/report_profile_sheet.dart';
import '../../widgets/selah_profile_image.dart';

class ModerationReviewQueueScreen extends StatelessWidget {
  const ModerationReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }
    return const SelahDeveloperRouteGate(child: _ModerationReviewQueueContent());
  }
}

class _ModerationReviewQueueContent extends StatefulWidget {
  const _ModerationReviewQueueContent();

  @override
  State<_ModerationReviewQueueContent> createState() =>
      _ModerationReviewQueueContentState();
}

class _ModerationReviewQueueContentState
    extends State<_ModerationReviewQueueContent> {
  final _store = SelahModerationPreviewStore.instance;
  SelahModerationReviewStatus? _filter;

  @override
  void initState() {
    super.initState();
    _store.ensureDemoItems();
  }

  Future<void> _openReport(SelahReportTarget target) async {
    final profile = mockProfiles.first;
    await showReportProfileSheet(
      context,
      profileId: profile.id,
      firstName: profile.firstName,
      source: SelahReportSource.profile,
      profileSnapshot: profile,
      simulateOnly: true,
      applySimulatedHideLocally: false,
      target: target,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Moderation preview', style: SelahText.heading(size: 17)),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              final items = _filter == null
                  ? _store.items
                  : _store.items
                        .where((item) => item.status == _filter)
                        .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 64, 18, 32),
                children: [
                  Text(
                    'INTERNAL PREVIEW · LOCAL STATE ONLY',
                    style: SelahText.chapterLabel(color: SelahColors.unlockText),
                  ),
                  const SizedBox(height: 8),
                  Text('Photo review queue', style: SelahText.heading(size: 27)),
                  const SizedBox(height: 7),
                  Text(
                    'Review the Phase C queue shape now. Decisions below are '
                    'not written to Supabase and do not affect any member.',
                    style: SelahText.subtext(size: 12.5),
                  ),
                  const SizedBox(height: 16),
                  _MemberActionPreview(onOpen: _openReport),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final status in SelahModerationReviewStatus.values)
                          _FilterChip(
                            label: status.name,
                            selected: _filter == status,
                            onTap: () => setState(() => _filter = status),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const _EmptyQueue()
                  else
                    for (final item in items) ...[
                      _ReviewCard(
                        item: item,
                        onApproved: () => _store.decide(
                          item.id,
                          SelahModerationReviewStatus.approved,
                        ),
                        onRejected: () => _store.decide(
                          item.id,
                          SelahModerationReviewStatus.rejected,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberActionPreview extends StatelessWidget {
  final Future<void> Function(SelahReportTarget target) onOpen;
  const _MemberActionPreview({required this.onOpen});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Member report action', style: SelahText.body(size: 14)),
        const SizedBox(height: 4),
        Text(
          'Runs the real reason picker against a local fixture, then adds a '
          'pending item here.',
          style: SelahText.subtext(size: 10.5),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('moderation-report-profile-preview'),
                onPressed: () => onOpen(SelahReportTarget.profile),
                child: const Text('Report profile'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('moderation-report-photo-preview'),
                onPressed: () => onOpen(SelahReportTarget.photo),
                child: const Text('Report photo'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  final SelahModerationReviewItem item;
  final VoidCallback onApproved;
  final VoidCallback onRejected;

  const _ReviewCard({
    required this.item,
    required this.onApproved,
    required this.onRejected,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SelahProfileImage(item.photoUrl, width: 82, height: 104),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.firstName, style: SelahText.body(size: 14)),
                  ),
                  _StatusPill(status: item.status),
                ],
              ),
              const SizedBox(height: 5),
              Text(item.reason, style: SelahText.subtext(size: 10.5)),
              const SizedBox(height: 9),
              if (item.status == SelahModerationReviewStatus.pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onApproved,
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRejected,
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final SelahModerationReviewStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(status.name, style: SelahText.subtext(size: 9.5)),
  );
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Text('No items in this state.', style: SelahText.subtext()),
    ),
  );
}
