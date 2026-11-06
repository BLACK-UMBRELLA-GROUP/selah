---
id: DOC-SELAH-0057
type: SPEC
status: ARCHIVED
feature: YOUR_VALUES
purpose: SELAH's own compatibility questions - 27 in 7 parts, replacing the 104-question bank copied from ZYRA (LOCK 17)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0017, DOC-SELAH-0052]
owner: SELAH chat
---

# SELAH YOUR VALUES — SPEC — V1 (ARCHIVED 2026-11-06) (LOCK 17)

Founder, 6 Nov 2026: "A · 27 only — LOCK it" (prototype V36, cleaned as V37). Look: LOOK spec V2; question screens use
the FAITH_PROFILE layout (spec V5 §1). ROADMAP row: **Christian content and production experience**.

Today `lib/data/chapter3_categories.dart` holds 104 questions in 11 parts (structure copied from ZYRA). SELAH keeps 27.

## 1. The 27 (ids from `chapter3_categories.dart`; questions and answer words exactly as built)

| Part (in order) | Questions (in order) |
|---|---|
| Faith at home | ch3_q33 personal prayer · ch3_q34 Bible reading · ch3_q44 Bible study / small group · ch3_q51 faith expressed at home · ch3_q38 giving |
| Marriage | ch3_q25 hope to build · ch3_q26 commitment · ch3_q32 long-term vision · ch3_q24 when to start a family (shown unless Marriage Q3 = "No", see line 17) |
| Family | ch3_q4 family involvement · ch3_q6 how close to parents · ch3_q8 caring for ageing parents · ch3_q48 Christian education for children |
| Money | ch3_q47 financial responsibility · ch3_q67 who provides · ch3_q68 how finances are managed · ch3_q13 financially prepared |
| Home and roles | ch3_q64 household responsibilities · ch3_q18 working after marriage · ch3_q73 personal time and space |
| Talking things through | ch3_q75 disagreements · ch3_q76 apologising · ch3_q83 forgiveness · ch3_q81 help if the marriage struggles |
| Everyday life | ch3_q52 smoking / vaping · ch3_q53 alcohol · ch3_q84 quality time |

Required / optional: as each question is built today (optional ones show **Skip**).
**Removed:** every other question in the bank - including income (q12), debt (q20), mortgage (q21), medical conditions
(q101), disabilities (q102), dietary needs (q97), living with in-laws (q9), domestic help (q69), supporting parents (q7),
siblings (q10). The nine asked in sign-up (line 17) are not in this flow either.

## 2. Screens

| Screen | Master | Words / look |
|---|---|---|
| Overview | L17_values_overview | Header "‹ Back" · right "Your values"; title "What matters to you in marriage"; muted "27 questions in 7 short parts. About 8 minutes. Your answers stay private: they only shape who you’re introduced to."; card listing each part (name 600, "<n> questions"); primary **Begin** |
| Part done | L17_values_overview__part_done | Finished parts show a "Done" pill; button reads **Continue** (next unfinished part) |
| Question | L17_values_question / __chosen / __optional | FAITH_PROFILE layout; header right "<Part> · <n> of <count>"; progress bar per part; last question of a part: **Save and continue** → overview, toast "Saved. <n> questions to go." |
| No answer | L17_values_question__no_answer | "Choose one answer to continue." |
| Saving / didn't save | L17_values_part__saving / __didnt_save | "Saving…" 75%; error bar "Your answers didn’t save. Try again." + **Try again** |

All 7 done → the app continues as it does today after Your values.

## 3. Compatibility
Categories become the 7 parts plus "Location & Language" (ABOUT_YOU brief 4b). Line 17's sign-up answers count in:
q46/q39/q40 → Faith at home · q1/q23/q28 → Marriage · q2/q3 → Family · q70 → Home and roles. Scoring of each kept question is unchanged.

## Must not change
The answer words and scoring of the 27 · sign-up questions (LOCK 4, 5, 14) · look · draft boundaries.

## Not decided
The partner-preference screen after each question (Prefer this / No preference / Not for me) - kept as built for the 27 until decided · editing answers from Profile.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 17 - Founder: "A · 27 only — LOCK it" |
