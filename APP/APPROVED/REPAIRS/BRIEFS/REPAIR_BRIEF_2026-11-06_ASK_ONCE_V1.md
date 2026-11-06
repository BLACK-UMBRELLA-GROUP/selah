---
id: DOC-SELAH-0052
type: PLAN
status: CURRENT
feature: REPAIRS
purpose: Repair brief - eight questions asked twice (LOCK 4/5 sign-up and the Your Values bank); ask once in sign-up, the bank reads those answers
links: [DOC-SELAH-0017, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# REPAIR BRIEF — ASK ONCE (SIGN-UP WINS) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear → QUESTIONS.md (rule 10).**

Founder-named (Shakeel 6 Nov, clickable: "A · Ask once, in sign-up (Recommended)"). Found by the SELAH chat: LOCK 4 and
LOCK 5 were designed without checking `lib/data/chapter3_categories.dart` (the SELAH chat's mistake). Queue line 17.
Build after: 3, 5. ROADMAP row: **Christian content and production experience** (not ticked).

## Rule
Each question is asked **once**, on the LOCK 4 / LOCK 5 sign-up screens. The bank questions below are taken out of
the Your Values flow. Wherever the compatibility work reads one of them, it reads the sign-up answer translated by this
table. Scoring, weights and category membership do not change. Old saved bank answers stay in storage, unused.

| Bank question (remove from Your Values) | Sign-up answer (LOCK) → bank value used for compatibility |
|---|---|
| ch3_q46 Which Christian tradition best describes you? | Faith Q1: Anglican → Anglican · Baptist → Baptist · Catholic → Catholic · Methodist → Methodist · Orthodox → Orthodox · Pentecostal → Pentecostal or charismatic · Presbyterian → Reformed or Presbyterian · Non-denominational → Non-denominational · Another tradition → Another Christian tradition |
| ch3_q39 How often do you attend church or worship with others? | Faith Q2: Every week → Most weeks · Most weeks → Several times a month · Sometimes → Occasionally · Rarely right now → Occasionally |
| ch3_q40 How often do you volunteer or serve people in need? | Faith Q5: "Not right now" → Rarely · one area → Occasionally · two or more → Regularly · skipped → no value |
| ch3_q1 What's your current marriage status? | Marriage Q1: No → Never Married · Yes, divorced → Divorced · Yes, widowed → Widowed · Yes, annulled → Annulled · I’d rather share later → no value. ("Separated" and "Currently Married" are no longer possible) |
| ch3_q2 Do you have any children? | Marriage Q2: No → No · Yes, they live with me → Yes, living with me · Yes, they don’t live with me → Yes, living elsewhere |
| ch3_q3 Would you like to have children in the future? | Marriage Q3: Yes → Yes · Open to it → If God wills · No → No · Not sure yet → Unsure. `ch3_q24`'s show-if now reads this answer (shown unless "No") |
| ch3_q23 When would you ideally like to get married? | Marriage Q7: Within a year → Within 1 year · In 1–2 years → Within 2 years · When it’s the right person → I'm flexible · Not sure yet → I'm flexible |
| ch3_q28 Would you be willing to relocate after marriage? | Marriage Q6: Near where I live now → I'd prefer not to relocate · Open to moving within my country → Within my country · Open to moving abroad → Internationally |

| ch3_q70 How should important household decisions be made? (row 9, added for QUESTIONS row 6) | Marriage Q4: The husband leads, with love and care → Husband leads after discussion · Equal partners who decide together → Every decision should be mutual · Somewhere in between → Depends on the situation · I’m still thinking about it → no value. ch3_q64 (household responsibilities) is a different question - it stays |
| Chapter 4 per-option preference for ch3_q1 "Divorced" (row 10) | Marriage Q5: Yes → No preference · It depends on the situation → No preference · No → Not for me (not a hard requirement). The other ch3_q1 option preferences are no longer asked |

"No value" = treated as unanswered, exactly as the bank treats an optional question left blank today.

| # | Step | Detail |
|---|---|---|
| 1 | Read | This brief, `FAITH_PROFILE` spec V5, `MARRIAGE_VALUES` spec V4, `lib/data/chapter3_categories.dart`, `lib/data/compatibility_categories.dart`. |
| 2 | Remove | The eight ids from every Your Values list (`chapter3Categories` and the grouped categories near line 1246 on). Keep the question definitions only if the compatibility code needs them for option lists. |
| 3 | Translate | One small mapping (one file) from the sign-up answers to the bank values above; compatibility reads through it. No second store. |
| 4 | Counts | Any "n of N" or progress count in Your Values updates itself; no empty category is shown (if one becomes empty, skip it and say which in the task note). |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: each mapping row; ch3_q24 show-if), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Task note + queue | Ids removed, file of the mapping, categories affected, Disk, public checks A-F; mark line 17 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 6)
Line 5 saves the seven marriage answers as **SELAH's own profile fields** in the exact LOCK words (a scoped new-field exception, one store) and does no mapping. All translation to ch3/ch4 values happens here (rows 1-10). Children "shared custody" is not offered in SELAH; no value maps to it.

## Update 2026-11-06 (LOCK 17)
"Category membership does not change" is superseded by line 20: Your values becomes 27 questions in 7 parts; line 20 places these mapped answers into its parts (YOUR_VALUES spec §3). This line keeps doing only the removal and the mapping.
