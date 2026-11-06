// Selah first-draft Values and Preferences bank, adapted from the existing
// product's reusable question-renderer structure. The Christian wording here
// is original draft product copy, not a quotation or a theological assessment.
// Stable question IDs and grouping are retained for the detached local editor;
// there is no deployed Selah answer contract or compatibility scoring service.
// Q26 retains both inherited response-key variants with identical wording so
// existing local renderer structure stays consistent while this draft is tested.

import '../models/onboarding_question.dart';
import '../models/selah_sign_up_compatibility.dart';

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
        id: 'ch3_q5',
        prompt: 'How often do you usually visit your family?',
        options: [
          'Daily',
          'Weekly',
          'Fortnightly',
          'Monthly',
          'Occasionally',
          'Rarely',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q7',
        prompt:
            'Do you currently provide financial support to your parents or family?',
        options: ['Yes, regularly', 'Occasionally', 'Not currently'],
        ch4Status: Ch4Status.optional,
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
      OnboardingQuestion(
        id: 'ch3_q9',
        prompt: 'Would you expect to live with your in-laws after marriage?',
        options: ['Yes', 'For a short period only', 'Only if necessary', 'No'],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q10',
        prompt: 'Do you have any siblings?',
        options: ['No', 'One', 'Two', 'Three', 'Four', 'Five or more'],
      ),
    ],
  ),
  OnboardingCategory(
    id: 'education_finances',
    name: 'Education & Finances',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q11',
        prompt: 'What is your highest completed level of education?',
        options: [
          'No Formal Qualification',
          'Secondary School / GCSE',
          'College / A Levels / Equivalent',
          'Diploma',
          "Bachelor's Degree",
          "Master's Degree",
          'Doctorate (PhD)',
          'Theology or Christian Ministry Qualification',
          'Other',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q12',
        prompt: 'Which income range best describes your annual income?',
        options: [
          'Under £20,000',
          '£20,000 – £39,999',
          '£40,000 – £59,999',
          '£60,000 – £79,999',
          '£80,000 – £99,999',
          '£100,000+',
        ],
        ch4Status: Ch4Status.required,
      ),
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
        id: 'ch3_q14',
        prompt: 'Which best describes your savings habits?',
        options: [
          'I save consistently',
          'I save when I can',
          "I'm just starting to save",
          "I'm not currently saving",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q15',
        prompt: 'How would you describe the way you manage your finances?',
        options: [
          'Very organised',
          'Mostly organised',
          'Fairly relaxed',
          'Improving my financial habits',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q16',
        prompt: 'How important is career progression to you?',
        options: [
          'Extremely important',
          'Important',
          'Moderately important',
          'Not a major priority',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q17',
        prompt: 'Are you currently studying?',
        options: ['Full-Time', 'Part-Time', 'No'],
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
      OnboardingQuestion(
        id: 'ch3_q19',
        prompt: 'Which best reflects your hopes for a wedding budget?',
        options: [
          'Simple and modest',
          'Moderate',
          'Flexible depending on circumstances',
          "I'd rather discuss it together",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q20',
        prompt: 'Which best describes your current debt situation?',
        options: [
          'No debt',
          'Mortgage only',
          'Student finance only',
          'Personal debt',
          'Business debt',
          'Multiple types of debt',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q21',
        prompt: 'Do you currently have a mortgage?',
        options: ['Yes', 'No', 'Planning to in the future'],
      ),
      OnboardingQuestion(
        id: 'ch3_q22',
        prompt: 'How would you describe your spending habits?',
        options: [
          'Very careful spender',
          'Balanced spender',
          'Enjoy spending when appropriate',
          'Working on improving my spending habits',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q27',
        prompt: 'What is your main motivation for seeking marriage?',
        options: [
          'To build a Christ-centred family',
          'Companionship',
          'To grow together in faith',
          'To have children',
          'Personal growth and partnership',
          'All of the above equally',
        ],
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
        id: 'ch3_q29',
        prompt: 'What are your views on homeschooling children?',
        options: [
          'I would prefer homeschooling',
          'I would prefer mainstream schooling',
          'I would consider either',
          "I haven't thought about it yet",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q30',
        prompt: 'How important is travelling together as a couple?',
        options: [
          'Very important',
          'Quite important',
          'Nice occasionally',
          'Not particularly important',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q31',
        prompt: 'How would you like your marriage journey to progress?',
        options: [
          "I'd like to move quickly if we're compatible",
          'A balanced pace',
          "I'd prefer to take things slowly",
          'It depends on the situation',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q35',
        prompt: 'How would you describe your familiarity with the Bible?',
        options: [
          'I am beginning to explore it',
          'I know some passages and stories',
          'I read it regularly',
          'I study it in depth',
          'I would like to learn more',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q36',
        prompt: 'Does fasting have a place in your Christian practice?',
        options: [
          'Regularly',
          'Occasionally or in particular seasons',
          'Not currently',
          'I choose other spiritual practices',
          'I am exploring this',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q37',
        prompt: 'Which practices help you grow in faith?',
        options: [
          'Prayer',
          'Bible reading',
          'Worship',
          'Fasting',
          'Serving others',
          'Fellowship or a small group',
          'Quiet reflection',
          'I am still exploring',
        ],
        selectionType: QuestionSelectionType.multi,
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q41',
        prompt: 'Are you part of a church community?',
        options: [
          'Yes, and I am actively involved',
          'Yes, though my involvement varies',
          'I am looking for a community',
          'Not currently',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q42',
        prompt: 'Have you taken part in a Christian retreat or service trip?',
        options: [
          'Yes',
          'No',
          'I would like to when possible',
          'I prefer other ways of growing in faith',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q43',
        prompt: 'How important is learning more about your Christian faith?',
        options: [
          'A major part of my life',
          'Very important',
          'Important',
          'Somewhat important',
          "I'm trying to improve",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q44',
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
        id: 'ch3_q45',
        prompt: 'How often do you engage with sermons or Christian teaching?',
        options: [
          'Daily',
          'Several times a week',
          'Weekly',
          'Occasionally',
          'Rarely',
        ],
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
        id: 'ch3_q49',
        prompt: 'How often do you make time for quiet prayer or reflection?',
        options: [
          'Regularly',
          'Occasionally',
          'Rarely',
          "I'm working towards it",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q50',
        prompt: 'How often do you make time for a personal devotional?',
        options: [
          'Daily',
          'Most days',
          'Occasionally',
          'Rarely',
          "I'm working towards making it a habit",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q51',
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
      OnboardingQuestion(
        id: 'ch3_q54',
        prompt: 'Which best describes your diet?',
        options: [
          'No particular dietary preference',
          'Vegetarian',
          'Vegan',
          'Pescatarian',
          'Diet shaped by health needs or allergies',
          'Other dietary preference',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q55',
        prompt: 'What place does music have in your everyday life?',
        options: [
          'Worship music is especially important to me',
          'I enjoy a range of music',
          'I listen occasionally',
          'I prefer quiet or other activities',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q56',
        prompt: 'How physically active are you?',
        options: [
          'Very active',
          'Active',
          'Occasionally active',
          'Rarely active',
          "I'm working on becoming more active",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q57',
        prompt: 'How do you feel about pets?',
        options: [
          'I enjoy having pets',
          "I'm happy either way",
          "I'd prefer not to have pets",
          'It depends on the type of pet',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q58',
        prompt: 'How would you describe yourself at home?',
        options: [
          'Very tidy and organised',
          'Generally tidy',
          'Fairly relaxed',
          "I'm working on becoming more organised",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q59',
        prompt: 'Which best describes you?',
        options: [
          'Early bird',
          'Mostly an early bird',
          'Night owl',
          'It depends on my schedule',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q60',
        prompt: 'How do you feel about hosting family and guests?',
        options: [
          'I love hosting',
          "I'm happy to host occasionally",
          'Only for close family',
          "I'd rather keep things private",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q61',
        prompt: 'Which best describes your personality?',
        options: ['Introvert', 'Ambivert', 'Extrovert'],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q62',
        prompt: 'How do you usually prefer to spend your free time?',
        options: [
          'Spending time with family',
          'Spending time with friends',
          'Reading',
          'Christian learning',
          'Sports & Fitness',
          'Travelling',
          'Nature & Outdoors',
          'Gaming',
          'Cooking & Baking',
          'Volunteering',
          'Arts & Creativity',
          'Learning new skills',
          'Relaxing at home',
        ],
        selectionType: QuestionSelectionType.multi,
      ),
      OnboardingQuestion(
        id: 'ch3_q63',
        prompt: 'Which statement best reflects your lifestyle?',
        options: [
          'Family always comes first',
          'I try to balance family and career equally',
          'Career is my current priority',
          'It depends on my stage of life',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q65',
        prompt: 'Which best reflects your approach to cooking?',
        options: [
          'I enjoy cooking regularly',
          "I don't mind cooking",
          "I'd prefer to share cooking responsibilities",
          "I'd rather cook only occasionally",
          'It depends on our circumstances',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q66',
        prompt: 'How should household cleaning be managed?',
        options: [
          'Shared equally',
          'Mostly by me',
          'Mostly by my spouse',
          'Whoever has more time',
          'We would consider hiring help if possible',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q69',
        prompt:
            'How do you feel about hiring domestic help if financially possible?',
        options: [
          "I'd definitely consider it",
          'Only if genuinely needed',
          'Only occasionally',
          "I'd rather manage ourselves",
        ],
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
        id: 'ch3_q71',
        prompt: 'Which type of home environment do you prefer?',
        options: [
          'Quiet and peaceful',
          'Family-centred and lively',
          'Frequently hosting guests',
          'A balance of both',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q72',
        prompt: 'How structured do you like your daily home routine to be?',
        options: [
          'Highly structured',
          'Fairly organised',
          'Flexible',
          'I prefer not to follow a routine',
        ],
        ch4Status: Ch4Status.optional,
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
        id: 'ch3_q74',
        prompt: 'Which best describes your communication style?',
        options: [
          'Open and direct',
          'Calm and thoughtful',
          "Quiet until I'm comfortable",
          'It depends on the situation',
        ],
        ch4Status: Ch4Status.optional,
      ),
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
        id: 'ch3_q77',
        prompt: 'How comfortable are you having difficult conversations?',
        options: [
          'Very comfortable',
          'Comfortable',
          'Somewhat comfortable',
          'I find them difficult but I am improving',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q78',
        prompt: 'How do you prefer to make important life decisions?',
        options: [
          'After discussing everything together',
          'I like taking the lead after discussion',
          'I prefer my spouse to lead after discussion',
          'It depends on the situation',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q79',
        prompt: 'How do you usually respond to constructive feedback?',
        options: [
          'I appreciate honest feedback',
          'I need a little time to process it',
          "It depends how it's delivered",
          "I'm working on becoming more open",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q80',
        prompt:
            'How often do you naturally express appreciation to those close to you?',
        options: [
          'Very often',
          'Quite often',
          'Occasionally',
          "I'm trying to improve",
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
        id: 'ch3_q82',
        prompt:
            'How important is continuously improving yourself within marriage?',
        options: [
          'Extremely important',
          'Very important',
          'Somewhat important',
          "I'm still developing this mindset",
        ],
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
      OnboardingQuestion(
        id: 'ch3_q85',
        prompt: 'How private would you like your marriage to be?',
        options: [
          'Completely private',
          'Mostly private',
          'Comfortable sharing major milestones',
          'Fairly open with close family and friends',
        ],
        ch4Status: Ch4Status.required,
      ),
    ],
  ),
  OnboardingCategory(
    id: 'technology',
    name: 'Technology & Digital Lifestyle',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q86',
        prompt: 'Which best describes your use of social media?',
        options: [
          "I don't use social media",
          'Private accounts for family and friends only',
          'Active but mostly private',
          'Public and regularly active',
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q87',
        prompt:
            'How comfortable are you sharing your marriage or family life on social media?',
        options: [
          'I prefer to keep everything private',
          'I am happy sharing major milestones only',
          'Occasionally sharing is fine',
          'I am comfortable sharing regularly',
        ],
        ch4Status: Ch4Status.required,
      ),
      OnboardingQuestion(
        id: 'ch3_q88',
        prompt:
            'How would you describe your daily screen time outside of work or study?',
        options: [
          'Very little',
          'Moderate',
          'Quite a lot',
          'It varies depending on the day',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q89',
        prompt: 'Which statement best reflects your use of technology at home?',
        options: [
          'I prefer technology only when necessary',
          'I enjoy a balanced use of technology',
          'I enjoy using technology regularly',
          'Technology is a major part of my lifestyle',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q90',
        prompt:
            'How important are healthy phone boundaries during family time?',
        options: [
          'Extremely important',
          'Very important',
          'Important',
          "I haven't really thought about it",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q91',
        prompt: 'Which best describes your gaming habits?',
        options: ["I don't play games", 'Occasionally', 'Weekly', 'Most days'],
      ),
      OnboardingQuestion(
        id: 'ch3_q92',
        prompt: 'How often do you watch television or streaming services?',
        options: ['Rarely', 'Occasionally', 'Weekly', 'Most days'],
      ),
      OnboardingQuestion(
        id: 'ch3_q93',
        prompt:
            'How often do you use technology to learn new skills or gain knowledge?',
        options: [
          'Daily',
          'Several times a week',
          'Weekly',
          'Occasionally',
          'Rarely',
        ],
      ),
    ],
  ),
  OnboardingCategory(
    id: 'health',
    name: 'Health & Well-being',
    questions: [
      OnboardingQuestion(
        id: 'ch3_q94',
        prompt: 'How would you describe your overall health?',
        options: [
          'Excellent',
          'Good',
          'Fair',
          "I'm currently working on improving my health",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q95',
        prompt: 'How important is maintaining your physical health?',
        options: [
          'Extremely important',
          'Very important',
          'Moderately important',
          "I'm trying to make it more important",
        ],
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q96',
        prompt: 'Which best describes your eating habits?',
        options: [
          'Very healthy',
          'Mostly healthy',
          'Fairly balanced',
          "I'm working on improving my diet",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q97',
        prompt: 'Do you have any dietary requirements?',
        options: [
          'None',
          'Vegetarian',
          'Vegan',
          'Gluten Free',
          'Dairy Free',
          'Nut Allergy',
          'Seafood Allergy',
          'Other Food Allergy',
        ],
        selectionType: QuestionSelectionType.multi,
        ch4Status: Ch4Status.optional,
      ),
      OnboardingQuestion(
        id: 'ch3_q98',
        prompt: 'How would you describe your sleeping habits?',
        options: [
          'Very consistent',
          'Mostly consistent',
          'Irregular due to work or study',
          "I'm working on improving my routine",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q99',
        prompt: 'When life becomes stressful, what helps you the most?',
        options: [
          'Prayer and worship',
          'Talking with family or friends',
          'Exercise',
          'Quiet time and reflection',
          'Keeping busy',
          'A combination of these',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q100',
        prompt:
            'How much time do you intentionally make for your personal well-being?',
        options: [
          'Every day',
          'Several times a week',
          'Weekly',
          'Occasionally',
          'Rarely',
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q101',
        prompt:
            'Do you currently have any long-term medical conditions that may affect your daily life?',
        options: ['No', 'Yes', "I'd prefer to discuss this privately later"],
      ),
      OnboardingQuestion(
        id: 'ch3_q102',
        prompt:
            'Do you have any disabilities or accessibility requirements that may affect daily life?',
        options: ['No', 'Yes', "I'd prefer to discuss this privately later"],
      ),
      OnboardingQuestion(
        id: 'ch3_q103',
        prompt:
            'Which statement best describes your approach to looking after your long-term health?',
        options: [
          'I actively prioritise my health',
          'I try my best to stay healthy',
          'I am gradually improving my habits',
          "I haven't focused on this much yet",
        ],
      ),
      OnboardingQuestion(
        id: 'ch3_q104',
        prompt: 'Which statement best describes you today?',
        options: [
          "I'm happy with who I am and ready for marriage.",
          "I'm always striving to become a better Christian.",
          "I'm still growing and improving every day.",
          'I believe marriage will help me become a better person.',
        ],
      ),
    ],
  ),
];

List<OnboardingQuestion> _questions(List<String> ids) => [
  for (final group in _sourceQuestionGroups)
    for (final question in group.questions)
      if (ids.contains(question.id)) question,
];

/// Reused presentation order for this local Selah draft.
/// Christian questions and options have changed; they must never be treated
/// as the prior product's persisted answers or deployed scoring contract.
final List<OnboardingCategory> chapter3CompatibilityCategories = [
  OnboardingCategory(
    id: 'faith_practice',
    name: 'Faith & Christian Practice',
    questions: _questions([
      'ch3_q33',
      'ch3_q34',
      'ch3_q35',
      'ch3_q36',
      'ch3_q37',
      'ch3_q38',
      'ch3_q39',
      'ch3_q40',
      'ch3_q41',
      'ch3_q42',
      'ch3_q43',
      'ch3_q44',
      'ch3_q45',
      'ch3_q46',
      'ch3_q49',
      'ch3_q50',
      'ch3_q51',
    ]),
  ),
  OnboardingCategory(
    id: 'marriage_intentions',
    name: 'Marriage Intentions & Structure',
    questions: _questions([
      'ch3_q1',
      'ch3_q23',
      'ch3_q25',
      'ch3_q26',
      'ch3_q27',
      'ch3_q28',
      'ch3_q31',
      'ch3_q32',
    ]),
  ),
  OnboardingCategory(
    id: 'children_parenting',
    name: 'Children & Parenting',
    questions: _questions([
      'ch3_q2',
      'ch3_q3',
      'ch3_q24',
      'ch3_q29',
      'ch3_q48',
    ]),
  ),
  OnboardingCategory(
    id: 'family_in_laws',
    name: 'Family & In-Laws',
    questions: _questions([
      'ch3_q4',
      'ch3_q5',
      'ch3_q6',
      'ch3_q7',
      'ch3_q8',
      'ch3_q9',
      'ch3_q10',
    ]),
  ),
  OnboardingCategory(
    id: 'finances_provision',
    name: 'Finances & Provision',
    questions: _questions([
      'ch3_q12',
      'ch3_q13',
      'ch3_q14',
      'ch3_q15',
      'ch3_q19',
      'ch3_q20',
      'ch3_q21',
      'ch3_q22',
      'ch3_q47',
      'ch3_q67',
      'ch3_q68',
    ]),
  ),
  OnboardingCategory(
    id: 'education_career',
    name: 'Education, Career & Work',
    questions: _questions([
      'ch3_q11',
      'ch3_q16',
      'ch3_q17',
      'ch3_q18',
      'ch3_q63',
    ]),
  ),
  OnboardingCategory(
    id: 'home_roles',
    name: 'Home Life & Household Roles',
    questions: _questions([
      'ch3_q64',
      'ch3_q65',
      'ch3_q66',
      'ch3_q69',
      'ch3_q70',
      'ch3_q71',
      'ch3_q72',
      'ch3_q73',
    ]),
  ),
  OnboardingCategory(
    id: 'communication_conflict',
    name: 'Communication & Conflict',
    questions: _questions([
      'ch3_q74',
      'ch3_q75',
      'ch3_q76',
      'ch3_q77',
      'ch3_q78',
      'ch3_q79',
      'ch3_q80',
      'ch3_q81',
      'ch3_q82',
      'ch3_q83',
    ]),
  ),
  OnboardingCategory(
    id: 'personality_connection',
    name: 'Personality & Connection',
    questions: _questions(['ch3_q61', 'ch3_q62', 'ch3_q84']),
  ),
  OnboardingCategory(
    id: 'lifestyle_wellbeing',
    name: 'Lifestyle, Health & Well-being',
    questions: _questions([
      'ch3_q30',
      'ch3_q52',
      'ch3_q53',
      'ch3_q54',
      'ch3_q55',
      'ch3_q56',
      'ch3_q57',
      'ch3_q58',
      'ch3_q59',
      'ch3_q60',
      'ch3_q94',
      'ch3_q95',
      'ch3_q96',
      'ch3_q97',
      'ch3_q98',
      'ch3_q99',
      'ch3_q100',
      'ch3_q101',
      'ch3_q102',
      'ch3_q103',
      'ch3_q104',
    ]),
  ),
  OnboardingCategory(
    id: 'digital_boundaries',
    name: 'Digital Life, Privacy & Boundaries',
    questions: _questions([
      'ch3_q85',
      'ch3_q86',
      'ch3_q87',
      'ch3_q88',
      'ch3_q89',
      'ch3_q90',
      'ch3_q91',
      'ch3_q92',
      'ch3_q93',
    ]),
  ),
];

/// Ask sign-up questions once; retain their full definitions above for the
/// existing compatibility category membership and saved answer contracts.
final List<OnboardingCategory> chapter3Categories = [
  for (final category in chapter3CompatibilityCategories)
    if (category.questions.any(
      (question) => !selahSignUpQuestionIds.contains(question.id),
    ))
      OnboardingCategory(
        id: category.id,
        name: category.name,
        questions: category.questions
            .where((question) => !selahSignUpQuestionIds.contains(question.id))
            .toList(growable: false),
      ),
];

/// The other eight questions' partner preferences remain distinct choices.
/// Only q1 preferences are replaced by the sign-up Divorced preference.
final List<OnboardingCategory> chapter4Categories = [
  for (final category in chapter3CompatibilityCategories)
    if (category.questions.any(
      (question) =>
          question.id != 'ch3_q1' && question.ch4Status != Ch4Status.none,
    ))
      OnboardingCategory(
        id: category.id,
        name: category.name,
        questions: category.questions
            .where((question) => question.id != 'ch3_q1')
            .toList(growable: false),
      ),
];
