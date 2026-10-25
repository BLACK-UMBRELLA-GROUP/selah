// Data-driven question model shared by Chapter 3 (Your Values) and
// Chapter 4 (Your Preferences, auto-derived from Ch3's CH4-flagged
// questions). Built this way because the real spec is a long data-driven walk
// across multiple categories (SEEKER ONBOARDING QUESTIONS/*.md) — far too many
// to hand-write one bespoke screen per question. One generic renderer
// (generic_select_question_screen.dart / traffic_light_question_screen.dart)
// + this data covers all of them faithfully.

enum QuestionSelectionType { single, multi }

/// Which Chapter 4 preference screen (if any) this Chapter 3 question
/// generates, per Chapter 3 Classification — Ch4 Mapping.md (V3 Approved).
enum Ch4Status { none, required, optional }

enum GenderVisibility { all, menOnly, womenOnly }

/// Conditional display (H4, Onboarding Direction B, 2026-08-10).
///
/// Declarative on purpose. A predicate function would let arbitrary logic hide
/// questions, and a hidden Chapter 3 question is a hole in the compatibility
/// data — `score_candidates()` treats an absent answer as neutral, so a wrong
/// rule silently removes signal rather than failing. This form can be read,
/// listed and argued about without running the app.
///
/// READ THIS BEFORE ADDING ONE. The bar is not "this is probably implied", it
/// is "the question is incoherent given that answer". The 2026-08-05 UX review
/// proposed four rules; measured against the real 104 questions, all four
/// turned out to describe follow-up questions that do not exist in this set
/// (see inherited upstream action 188). Only add a rule you can state as: *asking this would be
/// nonsense, and the answer we would have got is worthless.*
class ShowIf {
  /// The Chapter 3 question whose answer controls this one.
  final String questionId;

  /// Hide when the controlling answer is any of these.
  final List<String> notAnyOf;

  const ShowIf(this.questionId, {this.notAnyOf = const []});

  /// True when the dependent question should be SHOWN.
  ///
  /// An unanswered controlling question shows the dependent one. Onboarding
  /// runs forward, so this only arises if the order is ever changed — and
  /// showing a question that could have been skipped is recoverable, whereas
  /// hiding one that should have been asked is not.
  bool evaluate(Map<String, dynamic> answers) {
    final value = answers[questionId];
    if (value == null) return true;
    if (value is List) return !value.any((v) => notAnyOf.contains(v));
    return !notAnyOf.contains(value);
  }
}

class OnboardingCategory {
  final String id;
  final String name;
  final List<OnboardingQuestion> questions;

  const OnboardingCategory({
    required this.id,
    required this.name,
    required this.questions,
  });

  // REMOVED 2026-08-10: `ch4Questions`, which filtered on ch4Status alone.
  // It had no callers and it became a trap the moment conditional display
  // landed — it ignored BOTH gender visibility and showIf, so anything that
  // picked it up would have shown women the men-only Masjid question and
  // asked people who want no children when they would like to start a family.
  // Use ValuesPreferencesFlow's own _visibleCh4, which applies every gate.
}

class OnboardingQuestion {
  final String id; // e.g. "ch3_q1"
  final String prompt;
  final List<String> options;
  final QuestionSelectionType selectionType;
  final Ch4Status ch4Status;
  final GenderVisibility genderVisibility;
  final bool hardRequirementSupported;

  /// Null means always shown. See [ShowIf] — and read its doc before adding
  /// one, because a wrong rule removes compatibility signal silently.
  final ShowIf? showIf;

  const OnboardingQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.selectionType = QuestionSelectionType.single,
    this.ch4Status = Ch4Status.none,
    this.genderVisibility = GenderVisibility.all,
    this.hardRequirementSupported = true,
    this.showIf,
  });

  /// Client-side response identity.
  ///
  /// Most questions are identified by [id]. The two `ch3_q26` variants
  /// deliberately share a server qid but have different answer vocabularies,
  /// so using only [id] in a client map lets one variant overwrite the other.
  /// The server already evaluates that qid by gender variant; the client must
  /// preserve the same distinction while the flow is in memory.
  String get responseKey => switch (genderVisibility) {
    GenderVisibility.menOnly => '$id::male',
    GenderVisibility.womenOnly => '$id::female',
    GenderVisibility.all => id,
  };

  /// Both gates at once: gender, then the conditional rule. Chapter 4 mirrors
  /// Chapter 3, so a question hidden here is hidden in both chapters — which
  /// is right: there is no sense asking what you want in a partner on a topic
  /// the app just decided not to ask you about.
  bool visibleGiven(String? gender, Map<String, dynamic> answers) =>
      visibleFor(gender) && (showIf?.evaluate(answers) ?? true);

  bool visibleFor(String? gender) {
    switch (genderVisibility) {
      case GenderVisibility.all:
        return true;
      case GenderVisibility.menOnly:
        return gender == 'male';
      case GenderVisibility.womenOnly:
        return gender == 'female';
    }
  }
}

/// Traffic light preference value for one option of a Chapter 4 question.
enum TrafficLight { green, yellow, red }

extension TrafficLightX on TrafficLight {
  String get emoji => switch (this) {
    TrafficLight.green => '🟢',
    TrafficLight.yellow => '🟡',
    TrafficLight.red => '🔴',
  };
}
