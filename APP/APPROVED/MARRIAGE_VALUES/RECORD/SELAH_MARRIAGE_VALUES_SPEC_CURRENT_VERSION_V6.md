---
id: DOC-SELAH-0022
type: SPEC
status: CURRENT
feature: MARRIAGE_VALUES
purpose: SELAH's seven marriage-values questions, asked right after the faith questions at sign-up, and where the answers show (LOCK 5)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0017, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH MARRIAGE VALUES — SPEC — CURRENT VERSION V6 (LOCK 5, updated by LOCK 6)

Founder, 6 Nov 2026: "A · Right after faith — LOCK it" (prototype V10, cleaned as V11). Same layout, states and controls as
the faith questions (FAITH_PROFILE spec §1 and §3) - only the header word and the questions differ. Look: LOOK spec V2.
ROADMAP rows: **Christian content and production experience** and **SELAH's own identity and private delivery acceptance**.

## 1. Where it sits
Sign-up: … Shepherd "Invite sent" → faith questions 1-7 → **marriage questions 1-7** → languages (ABOUT_YOU spec V1, LOCK 14) → Browse. Faith question 7's
**Save and continue** (or **Skip**) now opens marriage question 1 (FAITH_PROFILE spec V5; master L05_faith_7__continues_to_marriage).
Toasts: after faith "Faith profile saved."; after marriage "Marriage values saved."
Back on marriage question 1 → faith question 7, or the consent screen if the member chose "Skip these questions" (CONSENT spec V2, LOCK 6).

## 2. Header
"‹ Back" left; "Marriage · <n> of 7" right; 5 px progress bar n/7.

## 3. Questions (exact words, in order; one answer each, all needed)

| # | Question | Help line | Answers |
|---|---|---|---|
| 1 | Have you been married before? | – | No · Yes, divorced · Yes, widowed · Yes, annulled · I’d rather share later |
| 2 | Do you have children? | – | No · Yes, they live with me · Yes, they don’t live with me |
| 3 | Would you like children? | – | Yes · Open to it · No · Not sure yet |
| 4 | How do you see roles in marriage? | There’s no wrong answer. This helps you meet someone who sees it the way you do. | The husband leads, with love and care · Equal partners who decide together · Somewhere in between · I’m still thinking about it |
| 5 | Would you marry someone who has been divorced? | – | Yes · It depends on the situation · No |
| 6 | Where would you like to live after marriage? | – | Near where I live now · Open to moving within my country · Open to moving abroad |
| 7 | When are you hoping to marry? | – | Within a year · In 1–2 years · When it’s the right person · Not sure yet |

Last question's button: **Save and continue**. No Skip on any marriage question.

## 4. States (masters)

| State | Master | Words |
|---|---|---|
| Empty (each) | L05_marriage_<n>_…__empty | – |
| No answer | L05_marriage_1_married_before__error | "Choose one answer to continue." |
| Chosen | L05_marriage_4_roles__selected | Lake ring |
| Saving | L05_marriage_7__saving | "Saving…" |
| Didn't save | L05_marriage_7__didnt_save | Error bar: "Your marriage values didn’t save. Try again." + **Try again** |

## 5. Profile
Under the FAITH PROFILE card: label "MARRIAGE VALUES", card with rows Married before · Children · Would like children ·
Roles in marriage · Open to someone divorced · Where to live · Hoping to marry; value or "Not answered" (muted). Long values
wrap on the right (value max 60% width, label max 40%). Masters L05_profile_marriage__answered / __not_answered (scrolled to the card).
Under the card, muted 13 px: "Marriage history and children show on your Browse card. All seven show once a Journey begins. Your Shepherds can see them."

## 6. Who sees the answers (LOCK 16, Founder 6 Nov: "A · Upfront — LOCK it")
| Who | Sees |
|---|---|
| Members browsing | One line on the Browse card: married before · children · would like children (BROWSE_CARD spec V3). "I’d rather share later" keeps marriage history off it |
| The other person in a Journey | All seven, on that person's profile inside the Journey (opened from their name at the top of the Journey; master L16_journey_their_profile) with the line "You can see these because you’re on a Journey together." |
| Your Shepherds | All seven |
| Journey Bio | No longer asks marriage status, children, future children or relocation (`lib/models/journey_bio.dart`) - these answers are the only source |

## Compatibility (Founder 6 Nov: "A · Ask once, in sign-up")
These answers are asked only here. They are saved as SELAH's own profile fields in the exact words above (one store); nothing else asks them. The Your Values bank no longer repeats them; compatibility reads them (Q1-Q7, including roles → ch3_q70 and divorced → the Chapter 4 "Divorced" preference) through the mapping in `REPAIRS/BRIEFS/REPAIR_BRIEF_2026-11-06_ASK_ONCE_V1.md` (queue line 17).

## Must not change
Faith questions and their words · Shepherd invite · Browse, Journey, My Selah, Shepherd tab · look · draft boundaries.

## Not decided (later LOCKs)
How answers feed filters · editing from Profile.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 5 - Founder: "A · Right after faith — LOCK it" |
| 2026-11-06 | V2 | LOCK 6 (Founder 6 Nov: "Yes — LOCK it"): Back on question 1 goes to consent when faith was skipped. V1 archived |
| 2026-11-06 | V3 | LOCK 14: Save on marriage question 7 now opens the languages question, then Browse. Profile gains an "About you" card below Marriage values, so L05_profile_marriage__answered re-rendered (old in ARCHIVE/MASTERS_V1). V2 archived |
| 2026-11-06 | V4 | Founder "A · Ask once, in sign-up": Q1, Q2, Q3, Q6, Q7 are no longer repeated in Your Values; compatibility reads them (line 17). No screen or master change. V3 archived |
| 2026-11-06 | V5 | Answers Codex QUESTIONS row 6: saved as SELAH's own fields; Q4 roles and Q5 divorced now also feed compatibility (line 17 brief rows 9-10). No screen or master change. V4 archived |
| 2026-11-06 | V6 | LOCK 16 - Founder: "A · Upfront — LOCK it": §6 who sees; profile note; L05 profile master re-rendered; 2 new masters L16_*. V5 archived |
