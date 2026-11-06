---
id: DOC-SELAH-0072
type: SPEC
status: CURRENT
feature: FAMILY_STAGE
purpose: Family Compatibility (Journey stage 6) - each Seeker answers 4 questions from the other Seeker's Shepherd, written to fit a pastor or a parent; the unbuilt Seeker-to-Shepherd direction is removed (LOCK 22)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0069, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH FAMILY COMPATIBILITY STAGE — SPEC — CURRENT VERSION V1 (LOCK 22)

Founder, 6 Nov 2026: "A · Seekers answer — LOCK it" (prototype V49, cleaned as V50). Look: LOOK spec V2. Stages: JOURNEY_STAGES V1 (stage 6 of 7).
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## Why
`lib/data/journey_questions.dart` `mentorToSeeker` was written for a parent ("What are your long-term intentions with my
son/daughter?", "How do you plan to involve our family…?") and reads wrongly from a pastor. `fam_wts_q1` repeats `p1_q3`
(why marry) and `fam_wts_q3` repeats `p2_q3` (finances). `seekerToMentor` has no Shepherd screen to answer it
(`journey_flow_screen.dart` header note) - half a feature.

## 1. Questions (exact; `<Name>` = the other Seeker's first name)

| # | New id | Question |
|---|---|---|
| 1 | `fam_q1` | How have you seen God lead you in this Journey so far? |
| 2 | `fam_q2` | Which church would you belong to together, and how would you serve there? |
| 3 | `fam_q3` | How will you welcome <Name>’s family and church into your life together? |
| 4 | `fam_q4` | Who will you turn to for counsel and prayer when things are hard? |

Each answer: free text, up to 400 characters, counter "n of 400". `mentorToSeeker` (`fam_wts_q1..4`) and `seekerToMentor`
(`fam_stw_q1..4`) leave the app. Stored answers to the old ids stay where they are (not shown, not deleted).

## 2. Page (top to bottom) — masters `MASTERS/L22_*`

| # | Item | Content |
|---|---|---|
| 1 | Entry | Journey page at stage 6: main button **Answer questions** (replaces Continue) until sent | L22_journey__family_stage |
| 2 | Header | ‹ Back · title "Family Compatibility" · line "Now your families enter the conversation." |
| 3 | Label | "<Shepherd name>, <Name>’s Shepherd, asks you" |
| 4 | Questions | 4 cards: question, answer box (placeholder "Your answer"), counter | L22_family__questions |
| 5 | Note | "<Name> and both Shepherds read your answers." |
| 6 | Button | **Send answers** - inactive until all 4 are answered, with "n of 4 answered" beneath |

## 3. States (rule 11)
| State | What shows | Master |
|---|---|---|
| Answering | as §2 | L22_family__questions |
| Sending | button "Sending…" (busy) | L22_family__sending |
| Didn't send | warm bar "Your answers didn’t send. Try again." + **Try again**; answers kept | L22_family__didnt_send |
| Sent | answers shown as text; card "Sent to <Shepherd> and <Name>." / "Waiting for <Name> to answer <your Shepherd>’s questions. The Journey moves on when you have both answered." | L22_family__sent |
| Both answered | stage completes as built ("Both families have spoken." / completion line unchanged) and the Journey moves to Open Conversation | (as built) |

## Must not change
Stage label, introduction, completion copy and Family Review gate (as built) · stages 3-5 question sets · look · draft boundaries.
Server tables unchanged: new ids are written to the existing answer store the stage already uses.

## Not decided
Shepherd ↔ Shepherd conversation (was "TBC" in the earlier spec) · whether Shepherds can comment on answers.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 22 - Founder: "A · Seekers answer — LOCK it" |
