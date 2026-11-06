---
id: DOC-SELAH-0053
type: SPEC
status: CURRENT
feature: FIRST_PAGES
purpose: The four pages a person sees when they first open SELAH, replacing the story pages copied from ZYRA (LOCK 15)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH FIRST PAGES — SPEC — CURRENT VERSION V1 (LOCK 15)

Founder, 6 Nov 2026: "A · Four quiet pages — LOCK it" (prototype V31, cleaned as V32). Look: LOOK spec V2 (Selah pause
layout, SELAH_PAUSE spec V4 §2). ROADMAP row: **SELAH's own identity and private delivery acceptance**.

Replaces the five story pages in `lib/dev/dev_onboarding_opening.dart` ("Welcome to SELAH", "Match on attraction.
Connect on faith." with "Why photos first?" and its quote, "Discover where you align.", "A Journey you share with your
Shepherds", "Verified people. Serious intentions.") and their artwork.

## 1. Layout (each page)
Selah pause layout: soft background `#DCE7E8`; top row "‹ Back" (pages 2-4, left) and "Skip" (pages 1-3, right), both lake
15 px; dawn breath mark ’ (Cormorant 120 px); middle: label "HOW SELAH WORKS" (label style), heading Cormorant 600 48 px,
body 15 px, four 22 × 3 px dashes (current = lake, others = line); bottom: one primary button. No artwork, no links, no quote.

## 2. Words (exact)

| # | Heading | Body | Button | Master |
|---|---|---|---|---|
| 1 | A pause before every step. | Selah is a Christian space to seek marriage slowly, with prayer and with people who know you. | Next | L15_opening_1 |
| 2 | You won’t walk alone. | Every Seeker has a Shepherd: a parent, pastor or friend in faith who sees each request and prays with you. | Next | L15_opening_2 |
| 3 | Faith first. | You meet each person with their church and their faith beside their photo. You both choose before anything begins. | Next | L15_opening_3 |
| 4 | Everyone is verified. | Every Seeker and Shepherd confirms who they are before joining. It keeps Selah a place for people serious about marriage. | Continue | L15_opening_4 |

**Next** → next page · **‹ Back** → previous · **Skip** and **Continue** → what follows the story today (role choice as
built, then the Seeker's LOCK 3 welcome). Swipe left/right does Next/Back. Screen readers hear "Page n of 4".

## 3. States
No data is loaded or sent - no loading, error or saving states (rule 11: not applicable, stated here).

## Must not change
What follows the pages (role choice, LOCK 3 sign-up) · verification itself · look · draft boundaries.

## Not decided
Showing the pages again from Settings ("How Selah works").

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 15 - Founder: "A · Four quiet pages — LOCK it" |
