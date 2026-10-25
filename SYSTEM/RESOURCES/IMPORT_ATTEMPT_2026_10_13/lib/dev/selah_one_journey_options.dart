// Caller-owned Journey options, either in the original opaque sheet or
// expanded inside a card. Choosing an option does not itself change a Journey.
import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahConceptJourneyOption {
  profile,
  timeline,
  bio,
  compatibility,
  shepherds,
  report,
  pause,
  end,
}

class SelahConceptJourneyOptions extends StatelessWidget {
  const SelahConceptJourneyOptions({
    super.key,
    required this.id,
    required this.firstName,
    required this.canPause,
    required this.canEnd,
    required this.onSelected,
    required this.onCancel,
    this.inline = false,
    this.canReport = true,
  });
  final String id;
  final String firstName;
  final bool canPause;
  final bool canEnd;
  final ValueChanged<SelahConceptJourneyOption> onSelected;
  final VoidCallback onCancel;
  final bool inline;
  final bool canReport;

  @override
  Widget build(BuildContext context) => inline
      ? Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _rows,
                ),
              );
              // The caller's whole-card reading fallback already scrolls.
              // Do not add a competing nested gesture owner when unbounded.
              return constraints.maxHeight.isFinite
                  ? SingleChildScrollView(
                      key: ValueKey('draft_options_inline_scroll_$id'),
                      child: content,
                    )
                  : content;
            },
          ),
        )
      : Material(
          color: SelahColors.modalSheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 11, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SelahColors.ink(.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Journey options', style: SelahText.heading(size: 22)),
                  const SizedBox(height: 5),
                  Text(
                    'Manage your Journey with $firstName.',
                    style: SelahText.subtext(size: 12),
                  ),
                  const SizedBox(height: 14),
                  ..._rows,
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onCancel,
                    child: Text('Cancel', style: SelahText.button(size: 12)),
                  ),
                ],
              ),
            ),
          ),
        );

  List<Widget> get _rows => [
    _row(
      SelahConceptJourneyOption.profile,
      Icons.person_outline,
      'View Profile',
      'View $firstName’s profile.',
    ),
    _row(
      SelahConceptJourneyOption.timeline,
      Icons.timeline_outlined,
      'Timeline',
      'Your shared Journey history.',
    ),
    _row(
      SelahConceptJourneyOption.bio,
      Icons.notes_outlined,
      'Journey Bio',
      'Beyond a first impression.',
    ),
    _row(
      SelahConceptJourneyOption.compatibility,
      Icons.balance_outlined,
      'Check compatibility score',
      'Your result opens only through mutual reveal.',
    ),
    _row(
      SelahConceptJourneyOption.shepherds,
      Icons.people_outline,
      'Shepherds',
      'Your circle of support for this Journey.',
    ),
    if (canReport)
      _row(
        SelahConceptJourneyOption.report,
        Icons.flag_outlined,
        'Report',
        'Report a concern about this profile.',
      ),
    if (canPause)
      _row(
        SelahConceptJourneyOption.pause,
        Icons.pause_circle_outline,
        'Request Pause',
        '$firstName chooses whether to pause or continue.',
      ),
    if (canEnd)
      _row(
        SelahConceptJourneyOption.end,
        Icons.close_rounded,
        'End Journey',
        'Close this Journey permanently. Your Timeline stays.',
      ),
  ];

  Widget _row(
    SelahConceptJourneyOption option,
    IconData icon,
    String title,
    String detail,
  ) => InkWell(
    key: ValueKey('draft_options_${option.name}_$id'),
    onTap: () => onSelected(option),
    child: Container(
      constraints: BoxConstraints(minHeight: inline ? 48 : 62),
      padding: EdgeInsets.symmetric(vertical: inline ? 5 : 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: SelahColors.ink(.12), width: .6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: option == SelahConceptJourneyOption.end
                  ? SelahColors.destructive.withValues(alpha: .09)
                  : SelahColors.ink(.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: option == SelahConceptJourneyOption.end
                  ? SelahColors.destructive
                  : SelahColors.foreground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SelahText.button(
                    size: 13,
                    color: option == SelahConceptJourneyOption.end
                        ? SelahColors.destructive
                        : SelahColors.foreground,
                  ),
                ),
                if (!inline) ...[
                  const SizedBox(height: 3),
                  Text(detail, style: SelahText.subtext(size: 10.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: SelahColors.ink(.4)),
        ],
      ),
    ),
  );
}

/// The original compact action framing without another vertical card row.
/// The label remains available to assistive technology and long-press tooltip.
class SelahConceptJourneyOptionsButton extends StatelessWidget {
  const SelahConceptJourneyOptionsButton({
    super.key,
    required this.onTap,
    this.expanded = false,
    this.isExpandable = false,
  });
  final VoidCallback onTap;
  final bool expanded;
  final bool isExpandable;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Journey options',
    toggled: isExpandable ? expanded : null,
    child: Tooltip(
      message: isExpandable
          ? '${expanded ? 'Collapse' : 'Expand'} Journey options'
          : 'Journey options',
      child: Material(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: SelahColors.surfaceBorder, width: .6),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.more_horiz,
                size: 16,
                color: SelahColors.ink(.8),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
