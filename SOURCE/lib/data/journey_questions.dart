// Fixed-order question bank for the Pre-Journey Ritual's three
// sustained phases and the Family Compatibility stage, per
// APP/Journey/PRE-JOURNEY RITUAL/Summary.md.
//
// NAMING, 2026-08-09: `phase1/2/3` here are STORAGE names and match
// matches.journey_stage's phase_1/phase_2/phase_3. What the member
// reads is Faith & Values, Building a Life and Navigating Life, and
// that lives in exactly one place — data/selah_journey_stages.dart.
// Do not put a user-facing label in this file.
//
// DELIBERATE V1 SIMPLIFICATION (Founder decision, 2026-07-25): the
// spec calls for "Part A — AI-generated questions (adaptive)" that
// react to answer tensions and private ratings in real time. There is
// no LLM integration anywhere in this codebase, so this file stands
// in with a fixed, curated, hand-written question set per phase
// instead. Real AI-adaptive question selection (and Part B's
// searchable personal question library) is future work — out of
// scope for this pass.

class JourneyQuestion {
  final String id; // stable string id, e.g. 'p1_q1'
  final String text;

  /// Two or three words naming what this question is ABOUT, for use in a
  /// sentence: "worth returning to `<topic>`". Added 2026-08-11 with the SELAH
  /// intelligence layer, which has to be able to say which subject it means.
  ///
  /// It lives here, on the question, and not in a lookup beside the layer
  /// that reads it — a second map keyed by question id is exactly the drift
  /// this file's header warns about, and it would fall out of step the first
  /// time a question was reworded.
  final String topic;

  const JourneyQuestion({
    required this.id,
    required this.text,
    required this.topic,
  });
}

class JourneyQuestions {
  JourneyQuestions._();

  /// Founder-selected cap for each Faith & Values response (2026-08-18).
  /// Other Journey phases stay unchanged until they receive their own
  /// explicit writing limits.
  static const int faithAndValuesAnswerCharacterLimit = 400;

  static int? answerCharacterLimitForPhase(int phase) =>
      phase == 1 ? faithAndValuesAnswerCharacterLimit : null;

  static bool answerFitsCharacterLimit(int phase, String answer) {
    final limit = answerCharacterLimitForPhase(phase);
    return limit == null || answer.runes.length <= limit;
  }

  // phase_1, shown as "Faith & Values". Guiding question: "Are we
  // fundamentally compatible?" — the question itself now lives on
  // SelahJourneyStage.guidingQuestion; this is a pointer, not a copy.
  // Topics: practising Christianity, marriage intentions, core
  // values, non-negotiables, daily lifestyle, personality basics.
  static const List<JourneyQuestion> phase1 = [
    JourneyQuestion(
      id: 'p1_q1',
      text:
          'How would you describe your relationship with your faith day to day?',
      topic: 'faith in daily life',
    ),
    JourneyQuestion(
      id: 'p1_q2',
      text:
          'How does following Christ shape your daily life — prayer, worship, relationships and beyond?',
      topic: 'prayer and worship',
    ),
    JourneyQuestion(
      id: 'p1_q3',
      text: 'What is drawing you to marriage at this point in your life?',
      topic: 'intentions for marriage',
    ),
    JourneyQuestion(
      id: 'p1_q4',
      text:
          'What are two or three core values you would never compromise on in a marriage?',
      topic: 'core values',
    ),
    JourneyQuestion(
      id: 'p1_q5',
      text:
          'Is there anything you consider a non-negotiable when choosing a spouse?',
      topic: 'non-negotiables',
    ),
    JourneyQuestion(
      id: 'p1_q6',
      text: 'What does a typical weekday look like for you right now?',
      topic: 'daily routine',
    ),
    JourneyQuestion(
      id: 'p1_q7',
      text: 'How would people close to you describe your personality?',
      topic: 'personality',
    ),
    JourneyQuestion(
      id: 'p1_q8',
      text: 'What role does your family play in your day-to-day decisions?',
      topic: 'family influence',
    ),
  ];

  // phase_2, shown as "Building a Life". Guiding question: "Could we
  // realistically build a life together?" Topics: children, career
  // ambitions, financial expectations, living arrangements, household
  // responsibilities, work-life balance.
  static const List<JourneyQuestion> phase2 = [
    JourneyQuestion(
      id: 'p2_q1',
      text:
          'How do you feel about having children, and if so, roughly how many and when?',
      topic: 'children',
    ),
    JourneyQuestion(
      id: 'p2_q2',
      text: 'What are your career ambitions over the next five to ten years?',
      topic: 'career ambitions',
    ),
    JourneyQuestion(
      id: 'p2_q3',
      text:
          'What are your expectations around finances — earning, saving, and spending — in a marriage?',
      topic: 'finances',
    ),
    JourneyQuestion(
      id: 'p2_q4',
      text:
          'Where would you want to live, and how do you feel about living near or with extended family?',
      topic: 'where you would live',
    ),
    JourneyQuestion(
      id: 'p2_q5',
      text:
          'How do you picture household responsibilities being shared between spouses?',
      topic: 'sharing the home',
    ),
    JourneyQuestion(
      id: 'p2_q6',
      text:
          'How do you currently balance work with the rest of your life, and how do you want that to look in marriage?',
      topic: 'work and home life',
    ),
    JourneyQuestion(
      id: 'p2_q7',
      text:
          'Would you expect your spouse to work outside the home, and does that depend on circumstances?',
      topic: 'working after marriage',
    ),
  ];

  // phase_3, shown as "Navigating Life". Guiding question: "Can we
  // navigate life together?" Topics: conflict resolution, communication styles,
  // family expectations, long-term goals, health, difficult
  // situations, personal growth.
  static const List<JourneyQuestion> phase3 = [
    JourneyQuestion(
      id: 'p3_q1',
      text:
          'When you disagree with someone close to you, how do you usually handle it?',
      topic: 'handling disagreement',
    ),
    JourneyQuestion(
      id: 'p3_q2',
      text:
          'How would you describe your communication style, especially during a difficult conversation?',
      topic: 'communication',
    ),
    JourneyQuestion(
      id: 'p3_q3',
      text:
          'What expectations do you think your family will have of your spouse?',
      topic: 'family expectations',
    ),
    JourneyQuestion(
      id: 'p3_q4',
      text:
          'Where do you see yourself, personally and spiritually, in ten years?',
      topic: 'the long term',
    ),
    JourneyQuestion(
      id: 'p3_q5',
      text:
          'Is there anything about your health, past or present, that you feel is important for a future spouse to understand?',
      topic: 'health',
    ),
    JourneyQuestion(
      id: 'p3_q6',
      text:
          'Can you describe a difficult period in your life and how you got through it?',
      topic: 'facing hardship',
    ),
    JourneyQuestion(
      id: 'p3_q7',
      text:
          'What is something you are actively working to improve about yourself?',
      topic: 'personal growth',
    ),
  ];

  static List<JourneyQuestion> forPhase(int phase) => switch (phase) {
    1 => phase1,
    2 => phase2,
    3 => phase3,
    _ => const [],
  };

  /// The real question bank for a sustained Journey stage, derived from its
  /// stored `phase_N` value. Returns null for every non-question stage.
  ///
  /// The arrival handoff uses this instead of copying 8/7/7 into the UI, so a
  /// future question-bank edit automatically updates the member's briefing.
  static List<JourneyQuestion>? forStageValue(String? stageValue) {
    if (stageValue == null || !stageValue.startsWith('phase_')) return null;
    final phase = int.tryParse(stageValue.substring('phase_'.length));
    if (phase == null || stageValue != 'phase_$phase') return null;
    final questions = forPhase(phase);
    return questions.isEmpty ? null : questions;
  }

  // family_stage, shown as "Family Compatibility" — Seeker<->Mentor
  // directions only. Mentor
  // <-> Mentor engagement is explicitly marked TBC in the source spec
  // ("Exact format and questions: TBC") and is not built here.

  /// Questions the SEEKER asks the OTHER PARTY's Shepherd.
  static const List<JourneyQuestion> seekerToMentor = [
    JourneyQuestion(
      id: 'fam_stw_q1',
      text: 'What are your expectations for this marriage?',
      topic: 'expectations for the marriage',
    ),
    JourneyQuestion(
      id: 'fam_stw_q2',
      text: 'How involved would you like to be in our life together?',
      topic: 'how involved the family will be',
    ),
    JourneyQuestion(
      id: 'fam_stw_q3',
      text: 'What are your hopes for your daughter/son in this marriage?',
      topic: 'their hopes for you',
    ),
    JourneyQuestion(
      id: 'fam_stw_q4',
      text:
          'Is there anything about our family you would like to understand better before we go further?',
      topic: 'understanding each other’s families',
    ),
  ];

  /// Questions a MENTOR asks the OTHER PARTY's Seeker.
  static const List<JourneyQuestion> mentorToSeeker = [
    JourneyQuestion(
      id: 'fam_wts_q1',
      text: 'Why do you want to marry?',
      topic: 'why you want to marry',
    ),
    JourneyQuestion(
      id: 'fam_wts_q2',
      text: 'What are your long-term intentions with my son/daughter?',
      topic: 'your intentions',
    ),
    JourneyQuestion(
      id: 'fam_wts_q3',
      text: 'How will you support a family, financially and otherwise?',
      topic: 'providing for a family',
    ),
    JourneyQuestion(
      id: 'fam_wts_q4',
      text: 'How do you plan to involve our family in your life together?',
      topic: 'involving family',
    ),
  ];
}
