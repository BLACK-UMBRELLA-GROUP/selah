// Selah first-draft Values and Preferences bank, adapted from the existing
// product's reusable question-renderer structure. The Christian wording here
// is original draft product copy, not a quotation or a theological assessment.
// Stable question IDs and grouping are retained for the detached local editor;
// there is no deployed Selah answer contract or compatibility scoring service.
// Q26 retains both inherited response-key variants with identical wording so
// existing local renderer structure stays consistent while this draft is tested.

import '../models/onboarding_question.dart';

const List<OnboardingCategory> _sourceQuestionGroups = [
  OnboardingCategory(
    id: 'family',
    name: 'Family',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q1',
        prompt: "What's your current marriage status?",
        options: [
          'Never Married',
          'Separated',
          'Divorced',
          'Annulled',
          'Widowed',
          'Currently Married',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q2',
        prompt: 'Do you have any children?',
        options: [
          'No',
          'Yes, living with me',
          'Yes, shared custody',
          'Yes, living elsewhere',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q3',
        prompt: 'Would you like to have children in the future?',
        options: ['Yes', 'No', 'If God wills', 'Unsure'],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q4',
        prompt:
            'How involved would you like your parents or family to be during your marriage?',
        options: [
          'Very involved',
          'Some involvement',
          'Only when needed',
          'Minimal involvement',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q6',
        prompt:
            'Ideally, how close would you like to live to your parents after marriage?',
        options: [
          'Same home',
          'Same neighbourhood',
          'Same city',
          'Same country',
          'No preference',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q8',
        prompt:
            'If needed, what are your expectations around caring for ageing parents?',
        options: [
          'I expect us both to help',
          'I would mainly take responsibility',
          "I'd support where possible",
          'It depends on the circumstances',
        ],
        ch4Status: Ch4Status.required,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'education_finances',
    name: 'Education & Finances',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q13',
        prompt: 'How financially prepared do you feel for marriage?',
        options: [
          'Ready now',
          'Mostly ready',
          'Still preparing',
          'Just beginning my journey',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q18',
        prompt: 'Which best describes your view on working after marriage?',
        options: [
          'I plan to continue working',
          "I'd prefer to reduce my working hours",
          "I'd prefer not to work",
          'It depends on our circumstances',
        ],
        ch4Status: Ch4Status.required,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'marriage_goals',
    name: 'Marriage Goals',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q23',
        prompt: 'When would you ideally like to get married?',
        options: [
          'As soon as possible',
          'Within 6 months',
          'Within 1 year',
          'Within 2 years',
          "I'm flexible",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        // THE ONLY BRANCH IN THIS FILE, and deliberately so. If someone has
        // said they do not want children, "when would you like to start a
        // family?" is not a question, it is a mistake. Every other rule the
        // 2026-08-05 UX review proposed described follow-up questions that do
        // not exist in this set — see inherited upstream action 188.
        showIf: ShowIf('ch3_q3', notAnyOf: ['No']),
        id: 'ch3_q24',
        prompt:
            'If God blesses you with children, when would you ideally like to start a family?',
        options: [
          'As soon as possible',
          'Within 1 year',
          'Within 2–3 years',
          'After 3 years',
          "I'll decide together with my spouse",
          'If God wills',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q25',
        prompt: 'What do you most hope to build through marriage?',
        options: [
          'A Christ-centred partnership',
          'A loving and supportive family',
          'Lifelong companionship and shared purpose',
          'All of these together',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q26',
        prompt: 'How would you describe commitment in marriage?',
        options: [
          'Faithfulness, trust and a lifelong partnership',
          'Growing together through changing circumstances',
          'Shared faith, care and honest communication',
          'All of these together',
        ],
        ch4Status: Ch4Status.required,
        genderVisibility: GenderVisibility.menOnly,
      ),
      OnboardingQuestion(
        id: 'ch3_q26',
        prompt: 'How would you describe commitment in marriage?',
        options: [
          'Faithfulness, trust and a lifelong partnership',
          'Growing together through changing circumstances',
          'Shared faith, care and honest communication',
          'All of these together',
        ],
        ch4Status: Ch4Status.required,
        genderVisibility: GenderVisibility.womenOnly,
      ),
      OnboardingQuestion(
        id: 'ch3_q28',
        prompt: 'Would you be willing to relocate after marriage?',
        options: [
          'Anywhere',
          'Within my country',
          'Internationally',
          'Only for the right person',
          "I'd prefer not to relocate",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q32',
        prompt: 'Which best describes your long-term vision for marriage?',
        options: [
          'Building a large family',
          'Building a small close-knit family',
          'Focusing on serving the community together',
          'Growing together in faith above all else',
          'A balanced combination of family, faith and personal growth',
        ],
      ),
    ],
  ),
  OnboardingCategory(
    id: 'faith',
    name: 'Faith',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q33',
        prompt: 'How regularly do you make time for personal prayer?',
        options: [
          'Daily',
          'Most days',
          'Several times a week',
          'Occasionally',
          "I'm building a prayer routine",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q34',
        prompt: 'How often do you read the Bible?',
        options: [
          'Daily',
          'Several times a week',
          'Weekly',
          'Occasionally',
          "I'm working towards reading more regularly",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q38',
        prompt: 'How do you approach giving to your church or community?',
        options: [
          'I give regularly when able',
          'I give when particular needs arise',
          'I contribute mainly through time or practical help',
          'I am developing a habit of giving',
          'My circumstances currently limit what I can give',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q39',
        prompt: 'How often do you attend church or worship with others?',
        options: [
          'Most weeks',
          'Several times a month',
          'Occasionally',
          'I participate online or in a home community',
          'I am finding a church community',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q40',
        prompt: 'How often do you volunteer or serve people in need?',
        options: [
          'Regularly',
          'Occasionally',
          'Rarely',
          'Whenever I have the opportunity',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q44',
        selfAnswerOptional: true,
        prompt: 'How often do you join Bible study or a Christian small group?',
        options: [
          'Weekly',
          'Monthly',
          'Occasionally',
          'Rarely',
          'Not currently',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q46',
        prompt: 'Which Christian tradition best describes you?',
        options: [
          'Catholic',
          'Orthodox',
          'Anglican',
          'Baptist',
          'Methodist',
          'Pentecostal or charismatic',
          'Reformed or Presbyterian',
          'Non-denominational',
          'Another Christian tradition',
          'I am exploring',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q47',
        prompt:
            'Which best describes your approach to financial responsibility?',
        options: [
          'I plan carefully, save and avoid unnecessary debt',
          'I balance present needs with future plans',
          'I am working towards more stable finances',
          'I would like to discuss financial priorities together',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q48',
        prompt:
            'How important is Christian education for your future children?',
        options: [
          'Essential',
          'Very important',
          'Important',
          'Somewhat important',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q51',
        selfAnswerOptional: true,
        prompt: 'How would you like faith to be expressed in your home?',
        options: [
          'Through shared prayer, worship and daily life',
          'Through personal practices and meaningful traditions',
          'Through hospitality and serving others',
          'I would like to decide together',
        ],
        ch4Status: Ch4Status.optional,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'lifestyle',
    name: 'Lifestyle',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q52',
        prompt: 'Which best describes you?',
        options: [
          "I don't smoke or vape",
          'I vape only',
          'I smoke only',
          'I both smoke and vape',
          "I'm trying to quit",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q53',
        prompt: 'Which best describes your approach to alcohol?',
        options: [
          'I do not drink',
          'I drink occasionally',
          'I drink socially in moderation',
          'I am reducing or stopping drinking',
          'I would prefer to discuss this privately',
        ],
        ch4Status: Ch4Status.required,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'household_roles',
    name: 'Household Roles & Expectations',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q64',
        prompt:
            'How do you believe household responsibilities should be managed after marriage?',
        options: [
          'Mostly traditional roles',
          'Shared equally',
          "Based on each person's circumstances",
          'Flexible depending on our situation',
          "We'll decide together as our marriage develops",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q67',
        prompt:
            'Who do you believe should primarily provide financially for the household?',
        options: [
          'Husband',
          'Mostly husband, but both may contribute',
          'Shared responsibility',
          'Depends on our circumstances',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q68',
        prompt: 'How would you prefer household finances to be managed?',
        options: [
          'Completely shared finances',
          'Mostly shared with some personal finances',
          'Mostly separate finances',
          "We'd decide together after marriage",
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q70',
        prompt: 'How should important household decisions be made?',
        options: [
          'Joint discussion before every major decision',
          'Husband leads after discussion',
          'Depends on the situation',
          'Every decision should be mutual',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q73',
        prompt:
            'How important is having personal time and space within marriage?',
        options: [
          'Very important',
          'Important',
          'Somewhat important',
          'I prefer spending most of my time together',
        ],
        ch4Status: Ch4Status.optional,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'communication',
    name: 'Communication & Emotional Intelligence',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q75',
        prompt: 'When disagreements happen, what usually describes you best?',
        options: [
          'I prefer to resolve things immediately',
          'I like some time to think before talking',
          'I stay calm and discuss it later',
          'It depends on the situation',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q76',
        prompt: 'How do you usually approach apologising after a disagreement?',
        options: [
          "I apologise quickly when I'm wrong",
          'I prefer to talk things through first',
          'I need time before apologising',
          'It depends on the situation',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q81',
        prompt:
            'If your marriage faced significant challenges, what would you be most open to?',
        options: [
          'Christian mediation',
          'Professional marriage counselling',
          'Family mediation',
          'A combination depending on the situation',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q83',
        prompt: 'Which statement best reflects your approach to forgiveness?',
        options: [
          'I forgive quickly',
          'I usually forgive after discussion',
          'It takes me time',
          'It depends on the situation',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q84',
        prompt: 'How important is spending regular quality time together?',
        options: [
          'Essential',
          'Very important',
          'Important',
          'Nice when possible',
        ],
        ch4Status: Ch4Status.required,
      ),
    ],
  ),
];

List<OnboardingQuestion> _questions(List<String> ids) => [
  for (final id in ids)
    for (final group in _sourceQuestionGroups)
      for (final question in group.questions)
        if (question.id == id) question,
];

/// LOCK 17: only these seven parts are asked. The private source definitions
/// above contain only the kept questions and nine sign-up scoring mappings.
final List<OnboardingCategory> chapter3Categories = [
  OnboardingCategory(
    id: 'faith_practice',
    name: 'Faith at home',
    questions: _questions([
      'ch3_q33',
      'ch3_q34',
      'ch3_q44',
      'ch3_q51',
      'ch3_q38',
    ]),
  ),
  OnboardingCategory(
    id: 'marriage_intentions',
    name: 'Marriage',
    questions: _questions(['ch3_q25', 'ch3_q26', 'ch3_q32', 'ch3_q24']),
  ),
  OnboardingCategory(
    id: 'family_in_laws',
    name: 'Family',
    questions: _questions(['ch3_q4', 'ch3_q6', 'ch3_q8', 'ch3_q48']),
  ),
  OnboardingCategory(
    id: 'finances_provision',
    name: 'Money',
    questions: _questions(['ch3_q47', 'ch3_q67', 'ch3_q68', 'ch3_q13']),
  ),
  OnboardingCategory(
    id: 'home_roles',
    name: 'Home and roles',
    questions: _questions(['ch3_q64', 'ch3_q18', 'ch3_q73']),
  ),
  OnboardingCategory(
    id: 'communication_conflict',
    name: 'Talking things through',
    questions: _questions(['ch3_q75', 'ch3_q76', 'ch3_q83', 'ch3_q81']),
  ),
  OnboardingCategory(
    id: 'lifestyle_wellbeing',
    name: 'Everyday life',
    questions: _questions(['ch3_q52', 'ch3_q53', 'ch3_q84']),
  ),
];

/// LOCK 17 category membership also includes the already-asked sign-up
/// answers. Their definitions do not return to the Your values question list.
final List<OnboardingCategory> chapter3CompatibilityCategories = [
  for (final category in chapter3Categories)
    OnboardingCategory(
      id: category.id,
      name: category.name,
      questions: [
        ...category.questions,
        ..._questions(switch (category.id) {
          'faith_practice' => ['ch3_q46', 'ch3_q39', 'ch3_q40'],
          'marriage_intentions' => ['ch3_q1', 'ch3_q23', 'ch3_q28'],
          'family_in_laws' => ['ch3_q2', 'ch3_q3'],
          'home_roles' => ['ch3_q70'],
          _ => const [],
        }),
      ],
    ),
];

/// LOCK 18 removes every per-option partner screen from the member flow.
final List<OnboardingCategory> chapter4Categories = const [];
