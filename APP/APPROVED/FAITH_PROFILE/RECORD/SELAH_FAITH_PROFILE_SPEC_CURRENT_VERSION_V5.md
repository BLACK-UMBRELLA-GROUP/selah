---
id: DOC-SELAH-0017
type: SPEC
status: CURRENT
feature: FAITH_PROFILE
purpose: SELAH's faith profile - the seven questions a Seeker answers at sign-up, how they are asked, and where the answers show (LOCK 4)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009, DOC-SELAH-0014]
owner: SELAH chat
---

# SELAH FAITH PROFILE — SPEC — CURRENT VERSION V5 (LOCK 4, updated by LOCKs 5, 6 and 8)

Founder, 4 Nov 2026: "A · One per screen — LOCK it" (prototype V8, cleaned as V9). Look: LOOK spec V2. Comes straight after
Shepherd invite screen 4 ("Invite sent" → **Continue**), see SHEPHERD_INVITE spec V4 and the consent screen (CONSENT spec V2). ROADMAP rows: **Christian content and
production experience** (questions) and **SELAH's own identity and private delivery acceptance** (onboarding flow).

## 1. Layout (every question)

| Part | Value |
|---|---|
| Header | "‹ Back" (lake) left; "Your faith · <n> of 7" muted 13 px right |
| Progress | 5 px bar, lake on line, width n/7 |
| Question | Page-title style (Cormorant 600, 33.6) |
| Help line | Muted 15 px, only where given below |
| Answers | Option rows (surface, 1 px line, radius 14, 12 × 14 padding, 14.5 px); chosen = lake border + inner 1 px lake ring |
| Bottom | Primary **Continue** (question 7: **Save and continue**); optional questions also show ghost **Skip** below it |
| Back | Question 1 → consent screen (CONSENT spec V2, LOCK 6); others → previous question, answers kept. Faith questions are only shown after "I agree, ask me these" |

## 2. Questions (exact words, in order)

| # | Question | Help line | Answers | Type |
|---|---|---|---|---|
| 1 | Which church tradition are you part of? | Choose the closest one. | Anglican · Baptist · Catholic · Methodist · Orthodox · Pentecostal · Presbyterian · Non-denominational · Another tradition | one, needed |
| 2 | How often are you at church? | – | Every week · Most weeks · Sometimes · Rarely right now | one, needed |
| 3 | Have you been baptised? | – | Yes · Not yet · I’d rather not say | one, needed |
| 4 | How long have you been a Christian? | – | All my life · More than 10 years · 5–10 years · 1–5 years · Less than a year | one, needed |
| 5 | Where do you serve? | Choose any, or skip. | Worship · Youth · Children’s work · Welcome team · Small group · Prayer · Missions · Not right now | many, optional; "Not right now" clears the others and is cleared by any other |
| 6 | Are you open to someone from another tradition? | – | Yes, any tradition · Similar traditions only · My own tradition only | one, needed |
| 7 | Your faith, in your own words | Shown on your profile. Up to 150 characters. You can skip this. | Text box (placeholder "What does your faith mean to you day to day?"), counter "<n> of 150" under it | text, optional, max 150 |

## 3. States

| State | Master | Look / words |
|---|---|---|
| Empty (each question) | L04_faith_<n>_…__empty | Nothing chosen |
| Chosen | L04_faith_1_tradition__selected, L04_faith_5_serving__selected | Lake ring on chosen rows |
| No answer (needed question) | L04_faith_1_tradition__error | Under the answers, dawn 13 px: "Choose one answer to continue." |
| Own words filled | L04_faith_7_own_words__filled | Counter muted |
| Too long | L04_faith_7_own_words__too_long | Counter turns dawn while over 150; on Save: "Keep it under 150 characters." above the buttons |
| Saving | L04_faith_7__saving | Primary reads "Saving…", 75%, not tappable |
| Didn't save | L04_faith_7__didnt_save | Error bar (LOOK §5) at top: "Your faith profile didn’t save. Try again." + **Try again** |
| Saved | L05_faith_7__continues_to_marriage (MARRIAGE_VALUES) | Goes to marriage question 1 (MARRIAGE_VALUES spec V6, LOCK 5); toast "Faith profile saved." Browse comes after the marriage questions |

## 4. Where the answers show

| Place | Master | What |
|---|---|---|
| Profile → FAITH PROFILE card | L04_profile_faith__answered | Rows: Church tradition · Church · Baptised · Christian for · Serving (joined by ", ") · Open to other traditions; own words as a quote under the card |
| – not answered | L04_profile_faith__not_answered | Value "Not answered" in muted |
| Browse card | BROWSE_CARD masters | Chips and quote exactly as BROWSE_CARD spec V3 §1 (LOCK 8) |

## Compatibility (Founder 6 Nov: "A · Ask once, in sign-up")
These answers are asked only here. The Your Values bank no longer repeats them; compatibility reads them through the mapping in `REPAIRS/BRIEFS/REPAIR_BRIEF_2026-11-06_ASK_ONCE_V1.md` (queue line 17).

## Must not change
Look (LOOK V2) · Shepherd invite screens 1-4 except where Continue goes · Browse, Journey, My Selah, Shepherd tab · draft boundaries.

## Not decided (later LOCKs)
Editing the faith profile from Profile ("Edit faith profile" opens these same screens - layout to confirm) · how answers feed filters · who can see each answer.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-04 | V1 | LOCK 4 - Founder: "A · One per screen — LOCK it" |
| 2026-11-06 | V2 | LOCK 5 (Founder 6 Nov: "A · Right after faith — LOCK it"): saved faith profile now opens the marriage questions. V1 archived |
| 2026-11-06 | V3 | LOCK 6 (Founder 6 Nov: "Yes — LOCK it"): consent screen sits before question 1; Skip on it bypasses these questions. V2 archived |
| 2026-11-06 | V4 | LOCK 8: Browse row points to the BROWSE_CARD spec (V3 wrongly said the chips were "as today" - today's card showed nationality/ethnicity). V3 archived |
| 2026-11-06 | V5 | Founder "A · Ask once, in sign-up": Q1, Q2, Q5 are no longer repeated in Your Values; compatibility reads them (line 17). No screen or master change. V4 archived |
