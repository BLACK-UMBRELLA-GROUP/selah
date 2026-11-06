---
id: DOC-SELAH-0048
type: SPEC
status: CURRENT
feature: ABOUT_YOU
purpose: SELAH asks only which languages a Seeker speaks at sign-up - no country of birth, nationality or ethnicity, and no background filters (LOCK 14)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0017, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH ABOUT YOU — SPEC — CURRENT VERSION V2 (LOCK 14)

Founder, 6 Nov 2026: "A · Languages only — LOCK it" (prototype V29, cleaned as V30). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

Today `lib/screens/onboarding/chapter2_flow.dart` asks 12 screens copied from ZYRA after faith: country of birth,
nationality, ethnicity and languages, each with "preferred for your future spouse" and "happy to be introduced outside".
SELAH keeps **one** of them.

## 1. What is removed from sign-up

| Steps today | Question | After LOCK 14 |
|---|---|---|
| 9-11 | Country of birth · preferred countries · flexibility | Removed |
| 12-14 | Nationality · preferred nationalities · flexibility | Removed |
| 15-17 | Ethnic background · preferred backgrounds · flexibility | Removed |
| 18 | Which languages do you speak fluently? | **Kept, re-presented (§2)** |
| 19-20 | Preferred languages for your spouse · flexibility | Removed |

Steps 0-3 (photos, where you live, where your spouse lives, flexibility) are not part of this LOCK.

## 2. The languages question (one screen)

| Part | Value |
|---|---|
| Place | After marriage question 7 "Save and continue" (MARRIAGE_VALUES spec V7) → this screen → Browse. Shown whether or not the Seeker agreed to the faith questions |
| Header | "‹ Back" (to marriage question 7, answers kept); right: "About you" (muted 13 px). No "n of n" and no progress bar - it is one screen |
| Question | Which languages do you speak? (page-title style, as faith questions) |
| Help line | Choose any you speak well. |
| Answers | Option rows as faith questions (LOCK 4 §1), many may be chosen, exactly as the masters: English · Spanish · Portuguese · French · Polish · Yoruba · Igbo · Twi · Tagalog · Korean · **Another language**. Another language opens a search of the app's existing full language list (field placeholder "Search languages"); each language picked there is added as a chosen row above "Another language". |
| Button | Primary **Save and continue**. No Skip - at least one language is needed |
| Saved | Browse; toast "Profile saved." |

## 3. States (rule 11)

| State | Master | Words |
|---|---|---|
| Empty | L14_languages__empty | Nothing chosen |
| Chosen | L14_languages__chosen | Lake ring on each chosen row |
| No answer | L14_languages__no_answer | Under the answers, dawn 13 px: "Choose at least one language to continue." |
| Saving | L14_languages__saving | "Saving…", 75%, not tappable |
| Didn't save | L14_languages__didnt_save | Error bar: "Your answers didn’t save. Try again." + **Try again** |

## 4. Where it shows
Profile: new label "ABOUT YOU" and card below Marriage values, one row "Languages" = chosen names joined by ", "
(master L14_profile_about_you). Browse card: unchanged (BROWSE_CARD spec V4, faith chips only).

## 5. Saved data
Languages save into the existing languages field. The removed questions' saved fields stay in storage untouched (no
migration, nothing deleted); they are no longer asked, required or shown to members. Consent wording follows (CONSENT spec V2).

## Must not change
Steps 0-3 · faith and marriage questions · consent behaviour · Browse card · look · draft boundaries.

## Not decided
Whether languages feed matching · deleting the old saved background answers (data clean-up, later brief).

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 14 - Founder: "A · Languages only — LOCK it" |
| 2026-11-06 | V2 | Build check of line 15: the full alphabetical list (Abkhazian, Afar…) was shown as rows - V1 allowed it (the SELAH chat's mistake). Now the 11 rows in the masters, with Another language opening a search. No master change. V1 archived |
