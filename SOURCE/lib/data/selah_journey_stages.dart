// THE CANONICAL JOURNEY STAGE MODEL — one definition, every surface.
//
// Agreed with the Founder 2026-08-09 after working the wording through
// from the machine outwards rather than from a copy deck inwards.
//
// ── WHY THIS FILE EXISTS. Before it, three screens each carried their own
// switch over the same eight strings, and they had already drifted:
//
//   mentor_journey_detail_screen  'Phase 1 — Foundations'
//   mentor_dashboard_screen       'Phase 1'
//   connections_screen          did not show stages at all — it said
//                               'In the Pre-Journey Ritual' for seven of
//                               the eight, which is not even true: the
//                               Ritual is what turns a POTENTIAL Journey
//                               into an Active one, and all eight of these
//                               stages run while status is already
//                               'active'.
//
// A fourth copy was about to be written for the Connections subtitle. That
// is invariant I3 — "one path, or the paths will drift" — and this project
// has paid for ignoring it twice already today, in four copies of an
// age-fetch and two copies of a comet animation.
//
// ═══════════════════════════════════════════════════════════════════════
// THE NAMING PHILOSOPHY. Read this before adding or renaming a stage.
// ═══════════════════════════════════════════════════════════════════════
//
//   EVERY LABEL NAMES THE SUBJECT OF THE COUPLE'S ATTENTION AT THAT
//   MOMENT.
//
// Not what the software is doing. Not what the stage is "for". What the
// two of them are actually thinking about. Revealing their compatibility ·
// the Greeting · their Shepherds · faith and values · building a life ·
// navigating life · the two families · each other, freely.
//
// ── AND THE STAGES ARE NOT ALL ONE KIND OF THING, which is why an earlier
// attempt to force them all into "topic" or all into "purpose" kept
// producing one label that felt wrong:
//
//   THRESHOLD    a mutual act both parties must complete. Nothing is
//                discussed; it is a door. selah_advance_stage() moves
//                these directly.
//   SUSTAINED    a subject worked through over days or weeks, with a
//                question set behind it and a Family Review at the end.
//                selah_advance_stage() REFUSES these with
//                'gated_transition' — they go through open_family_review.
//   DESTINATION  the end of the sequence.
//
// ── THE GRAMMAR IS LOAD-BEARING. Thresholds and the destination are noun
// phrases; the two longest sustained phases are gerunds — "Building a
// Life", "Navigating Life". That is deliberate. A threshold is something
// you COMPLETE; a phase is something you DO OVER TIME. Flattening all
// eight into tidy noun phrases would hide a distinction the user can feel.
// If you add a stage, match the grammar of its kind.
//
// ── ONE KNOWN EXCEPTION, recorded rather than hidden: "Shepherd Gate"
// names a mechanism, not a subject. It is kept because it is already
// approved and already on two screens, and because "gate" is honest that
// the Journey stops there.
//
// ═══════════════════════════════════════════════════════════════════════
// EXTENDING THIS
// ═══════════════════════════════════════════════════════════════════════
//
// Founder, 2026-08-09: "if we ever need icons, colours, descriptions,
// helper text, progress indicators or localisation, I'd rather extend this
// one shared definition than create separate mappings."
//
// So: add a FIELD to [SelahJourneyStage], never a second map somewhere
// else. [icon] and [description] are deliberately absent rather than
// stubbed — nobody has designed them, and a null field that every screen
// null-checks is worse than a field that does not exist yet.
//
// Localisation, when it comes: [label] becomes a key and the lookup moves
// behind a delegate. Having one map is the precondition for that being a
// half-day change instead of a hunt.

/// What kind of thing a stage is. See the philosophy note above — this is
/// not decoration, it decides the grammar of the label and whether
/// selah_advance_stage() can move it directly.
enum SelahStageKind { threshold, sustained, destination }

class SelahJourneyStage {
  /// The value stored in `matches.journey_stage`. Authoritative — this
  /// list is the CHECK constraint on that column, in order.
  final String value;

  /// The user-facing label. Identical for Seeker and Shepherd, on every
  /// screen, by design.
  final String label;

  final SelahStageKind kind;

  /// 1-based position, for "step 4 of 8" style progress. Derived from the
  /// list order rather than hand-written, so it cannot fall out of step.
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

  /// Display-only renumbering used by the nine-stage Life Snapshot mock.
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
  /// database and there must not be. It is the gate between stages 4→5,
  /// 5→6, 6→7 and 7→8. A Journey is never "in" Family Review; it is in
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
      value: 'mentor_gate',
      label: 'Shepherd support',
      kind: SelahStageKind.threshold,
      order: 3,
      introduction: 'You do not have to walk towards marriage alone.',
      supportingLine:
          'Each of you needs a Shepherd beside you before the Journey continues.',
      completionHeading: 'Both Shepherds are present.',
      completionLine: 'Your trusted supporters walk with you from here.',
      timelineMilestoneType: 'shepherd_linked',
    ),
    SelahJourneyStage(
      value: 'phase_1',
      label: 'Faith & Values',
      kind: SelahStageKind.sustained,
      order: 4,
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
      order: 5,
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
      order: 6,
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
      order: 7,
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
      order: 8,
      introduction: 'The structure now begins to lift.',
      supportingLine:
          'You can speak freely, while your Timeline and Shepherds remain part of the Journey.',
      completionHeading: 'Your conversation is open.',
      completionLine: 'The Journey continues with more freedom.',
      timelineMilestoneType: 'conversation_started',
    ),
  ];

  /// Founder-requested Journey-only Bio mock (2026-08-18).
  ///
  /// This is deliberately NOT in [all]: `life_snapshot_preview` is not yet a
  /// database stage and must never be sent to `selah_advance_stage()`. The
  /// Active Journey inserts it between the two real server stages while the
  /// experience and per-field sharing choices are tested. Once approved and
  /// persisted, it can become a real stored value in one migration.
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

  /// Nine-stage visual sequence used by the Active Journey mock. The real
  /// server stages after Compatibility keep their stored values and are
  /// shifted by one only for numbering and the ribbon.
  static final List<SelahJourneyStage> previewAll = List.unmodifiable([
    all[0],
    all[1],
    lifeSnapshotPreview,
    for (final stage in all.skip(2)) stage.withOrder(stage.order + 1),
  ]);

  static SelahJourneyStage? previewOf(String? value) {
    if (value == null) return null;
    for (final stage in previewAll) {
      if (stage.value == value) return stage;
    }
    return null;
  }

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
  };

  static final Map<String, SelahJourneyStage> _byTimelineMilestone = {
    for (final s in all) s.timelineMilestoneType: s,
  };

  /// Total stages, for "step 4 of 8". Derived, never written down twice.
  static int get count => all.length;

  /// Null for an unknown or absent stage — a Potential Journey has no
  /// stage at all, so null is a legitimate answer, not an error.
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
