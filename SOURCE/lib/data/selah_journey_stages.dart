// The seven member-visible Journey stages — LOCK 21, 6 Nov 2026.
// One definition supplies labels, order and copy for Seeker and Shepherd views.
// Shepherd support is no longer a separate stage: every ordinary Journey
// action still requires the existing Main Shepherd guards. The app moves
// directly from Compatibility Reveal to Faith & Values.
//
// Server stage IDs, the RPC map and database constraints remain unchanged.
// A stored mentor_gate resolves to phase_1 for display; the retained service
// passes its raw value through the existing RPC before continuing.
// Sustained-stage Family Review gates and all stage copy remain unchanged.

/// What kind of thing a stage is. It decides the label grammar and whether
/// selah_advance_stage() can move it directly.
enum SelahStageKind { threshold, sustained, destination }

class SelahJourneyStage {
  /// A stored stage value used by the member app. The server also retains
  /// legacy mentor_gate; this display list does not redefine its constraint.
  final String value;

  /// The user-facing label. Identical for Seeker and Shepherd, on every
  /// screen, by design.
  final String label;

  final SelahStageKind kind;

  /// The 1-based member-visible position in the seven-stage sequence.
  final int order;

  /// The question the couple is answering during this stage, where one
  /// exists. Shown in the Journey flow above the question set.
  ///
  /// These three are not new copy — they were already on screen, in
  /// journey_flow_screen's `_phaseGuidingQuestion`, and the phase labels
  /// were derived FROM them. Moved here so the label and the question can
  /// never say different things.
  final String? guidingQuestion;

  /// Short arrival copy shown before the member scrolls into the stage.
  final String introduction;

  /// Optional human title for the arrival page where repeating the formal
  /// stage label would make the page sound mechanical. The ribbon still
  /// carries [label], so the member never loses their place.
  final String? arrivalTitle;

  /// Optional second arrival line. Sustained phases use
  /// [guidingQuestion] here instead.
  final String? supportingLine;

  /// The two-line completion beat shown before the Journey moves forward.
  final String completionHeading;
  final String completionLine;

  /// The durable Timeline event written when this stage is completed. The
  /// destination's event is written when it is reached. Kept here so the
  /// stage order, Journey history and Timeline cannot silently name
  /// different chapters.
  final String timelineMilestoneType;

  const SelahJourneyStage({
    required this.value,
    required this.label,
    required this.kind,
    required this.order,
    required this.introduction,
    required this.completionHeading,
    required this.completionLine,
    required this.timelineMilestoneType,
    this.arrivalTitle,
    this.guidingQuestion,
    this.supportingLine,
  });

  /// Retained display-only renumbering helper for historical previews.
  /// The stored [value] and every piece of copy remain canonical.
  SelahJourneyStage withOrder(int displayOrder) => SelahJourneyStage(
    value: value,
    label: label,
    kind: kind,
    order: displayOrder,
    introduction: introduction,
    completionHeading: completionHeading,
    completionLine: completionLine,
    timelineMilestoneType: timelineMilestoneType,
    arrivalTitle: arrivalTitle,
    guidingQuestion: guidingQuestion,
    supportingLine: supportingLine,
  );
}

class SelahJourneyStages {
  SelahJourneyStages._();

  /// Shown INSTEAD of the stage whenever a Family Review is open.
  ///
  /// An override, not a stage — there is no `family_review` value in the
  /// database and there must not be. It is the gate between stages 3→4,
  /// 4→5, 5→6 and 6→7. A Journey is never "in" Family Review; it is in
  /// phase_2 with a review open.
  ///
  /// It wins because it is the only moment an Active Journey is stalled
  /// for a reason the Seeker cannot act on. "Building a Life" while two
  /// Shepherds deliberate explains nothing about why nothing is moving.
  static const String familyReviewOverride = 'Family Review';

  /// In order. This IS the successor sequence — index n advances to
  /// index n+1, and `conversation` is terminal.
  static const List<SelahJourneyStage> all = [
    // Reused greeting-first order for the Selah local draft. These detached
    // stage keys do not claim a deployed Selah server state or migration.
    SelahJourneyStage(
      value: 'greeting_exchange',
      label: 'First greeting',
      kind: SelahStageKind.threshold,
      order: 1,
      arrivalTitle: 'Let’s begin',
      introduction: 'The first words can be simple.',
      completionHeading: 'Greetings exchanged.',
      completionLine: 'Your Journey has begun.',
      timelineMilestoneType: 'greeting_exchanged',
    ),
    SelahJourneyStage(
      value: 'compatibility_reveal',
      label: 'Compatibility Reveal',
      kind: SelahStageKind.threshold,
      order: 2,
      introduction: 'Now, choose whether to reveal your compatibility.',
      completionHeading: 'Compatibility, revealed.',
      completionLine: 'You now know where you begin.',
      timelineMilestoneType: 'compatibility_revealed',
    ),
    SelahJourneyStage(
      value: 'phase_1',
      label: 'Faith & Values',
      kind: SelahStageKind.sustained,
      order: 3,
      introduction:
          'Share how faith, values and family shape your everyday life.',
      guidingQuestion: 'Are we fundamentally compatible?',
      completionHeading: 'Faith & Values complete.',
      completionLine: 'You have both shared what guides you.',
      timelineMilestoneType: 'phase_1_complete',
    ),
    SelahJourneyStage(
      value: 'phase_2',
      label: 'Building a Life',
      kind: SelahStageKind.sustained,
      order: 4,
      introduction: 'Share your hopes for family, work, home and the future.',
      guidingQuestion: 'Could we realistically build a life together?',
      completionHeading: 'Building a Life complete.',
      completionLine: 'You have both shared the life you hope to build.',
      timelineMilestoneType: 'phase_2_complete',
    ),
    SelahJourneyStage(
      value: 'phase_3',
      label: 'Navigating Life',
      kind: SelahStageKind.sustained,
      order: 5,
      introduction: 'Share how you communicate, handle difficulty and grow.',
      guidingQuestion: 'Can we navigate life together?',
      completionHeading: 'Navigating Life complete.',
      completionLine: 'You have both shared how you face life and grow.',
      timelineMilestoneType: 'phase_3_complete',
    ),
    SelahJourneyStage(
      value: 'family_stage',
      label: 'Family Compatibility',
      kind: SelahStageKind.sustained,
      order: 6,
      introduction: 'Now your families enter the conversation.',
      supportingLine: 'Answer openly, as though you were sitting together.',
      completionHeading: 'Both families have spoken.',
      completionLine: 'Each family has been heard.',
      timelineMilestoneType: 'family_stage',
    ),
    // "Open Conversation", not "Conversation" — Founder, 2026-08-09.
    //
    // Both are accurate: free messaging genuinely begins here and nowhere
    // earlier (ChatScreen has exactly one entry point in the app, gated on
    // this stage; the phases exchange structured answers, not messages).
    // But the Journey is conversational THROUGHOUT, so the bare word
    // implied talking starts here. "Open" names what actually changes:
    // the structure lifts.
    SelahJourneyStage(
      value: 'conversation',
      label: 'Open Conversation',
      kind: SelahStageKind.destination,
      order: 7,
      introduction: 'The structure now begins to lift.',
      supportingLine:
          'You can speak freely, while your Timeline and Shepherds remain part of the Journey.',
      completionHeading: 'Your conversation is open.',
      completionLine: 'The Journey continues with more freedom.',
      timelineMilestoneType: 'conversation_started',
    ),
  ];

  /// Historical preview data only. LOCK 21 excludes this value from both
  /// numbered lists and lookups; it must never be sent to the server RPC.
  static const SelahJourneyStage lifeSnapshotPreview = SelahJourneyStage(
    value: 'life_snapshot_preview',
    label: 'Life Snapshot',
    kind: SelahStageKind.threshold,
    order: 3,
    arrivalTitle: 'Beyond the score',
    introduction: 'Meet the person in their own words.',
    supportingLine:
        'Only the biography and life details they chose to share appear here.',
    completionHeading: 'You have seen their story.',
    completionLine: 'You can now decide whether to bring your families in.',
    timelineMilestoneType: 'life_snapshot_preview',
  );

  /// The member preview uses the same seven stages as every other view.
  static const List<SelahJourneyStage> previewAll = all;

  static SelahJourneyStage? previewOf(String? value) => of(value);

  static String previewLabelFor(
    String? value, {
    bool reviewOpen = false,
    String fallback = 'Journey in progress',
  }) {
    if (reviewOpen) return familyReviewOverride;
    return previewOf(value)?.label ?? fallback;
  }

  static final Map<String, SelahJourneyStage> _byValue = {
    for (final s in all) s.value: s,
    'mentor_gate': all[2],
  };

  static final Map<String, SelahJourneyStage> _byTimelineMilestone = {
    for (final s in all) s.timelineMilestoneType: s,
  };

  /// Total member-visible stages, derived from the locked list.
  static int get count => all.length;

  /// Legacy mentor_gate displays as Faith & Values. Unknown or absent values
  /// remain null; a Potential Journey has no stage at all.
  static SelahJourneyStage? of(String? value) =>
      value == null ? null : _byValue[value];

  /// The stage completed/reached by a durable Timeline milestone.
  static SelahJourneyStage? ofTimelineMilestone(String type) =>
      _byTimelineMilestone[type];

  /// The `phase_N` stage for a 1-based phase number.
  ///
  /// journey_flow_screen carries the phase as an int — its three phase
  /// views are ONE widget parameterised by number, not three widgets — so
  /// it cannot call [of] directly. This is the bridge, and it lives here
  /// rather than there so the `phase_$n` naming convention sits with the
  /// values it names.
  static SelahJourneyStage? phase(int n) => of('phase_$n');

  /// Stages that the server sequence proves are complete before [value].
  /// Used by the Active Journey's upward history: it may render completion
  /// summaries for these stages, but must never recreate their old controls.
  static List<SelahJourneyStage> completedBefore(String? value) {
    final current = of(value);
    if (current == null || current.order <= 1) return const [];
    return List.unmodifiable(all.take(current.order - 1));
  }

  /// The label for a stage, with the Family Review override applied.
  ///
  /// [reviewOpen] must come from real data. Passing a hardcoded false is
  /// fine and honest — it simply never shows the override — but passing a
  /// guess is not, because this string is the only explanation the Seeker
  /// gets for why their Journey has stopped.
  ///
  /// [fallback] covers a stage the app does not recognise, which can only
  /// happen if the database gains a value this file has not been taught.
  static String labelFor(
    String? value, {
    bool reviewOpen = false,
    String fallback = 'Journey in progress',
  }) {
    if (reviewOpen) return familyReviewOverride;
    return of(value)?.label ?? fallback;
  }
}
