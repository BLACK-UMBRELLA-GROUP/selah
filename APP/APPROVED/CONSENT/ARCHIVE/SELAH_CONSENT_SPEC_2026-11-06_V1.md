---
id: DOC-SELAH-0025
type: SPEC
status: ARCHIVED
feature: CONSENT
purpose: SELAH's sensitive-questions consent screen - its wording in SELAH's own words, where it sits in sign-up, and what Skip does (LOCK 6)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0014, DOC-SELAH-0017, DOC-SELAH-0022]
owner: SELAH chat
---

# SELAH CONSENT — SPEC — V1 (ARCHIVED 2026-11-06) (LOCK 6)

Founder, 6 Nov 2026: "Yes — LOCK it" (prototype V12, marked V13). Replaces the copied wording in
`SOURCE/lib/services/selah_consent_service.dart` (`kArticle9ConsentTitle/Body/DeclineNote`) and the button labels in
`SOURCE/lib/screens/onboarding/article9_consent_screen.dart`. Look: LOOK spec V2. ROADMAP row: **Christian content and
production experience**. **Legal check before any public launch** (wording is not legal advice).

## 1. Where it sits
Shepherd "Invite sent" → **Continue** → **this screen** → I agree → faith question 1 (FAITH_PROFILE V4) → marriage (MARRIAGE_VALUES V2) → Browse.
Skip → marriage question 1 (faith questions not asked). Back → "Invite sent".

## 2. Words (exact)

| Part | Text |
|---|---|
| Header | "‹ Back" · right, muted 13 px: "Before your faith questions" |
| Title | Some of these questions are sensitive |
| Body 1 | The next questions ask about your faith and your background: your church tradition, how long you’ve been a Christian, whether you’ve been baptised, your ethnicity, where you were born and your nationality. |
| Body 2 | UK data protection law treats these as special-category information and asks us to get your clear permission before recording them. |
| Body 3 | Selah uses them only to find you compatible matches. Your Shepherd can see your faith profile; other members see only what your profile shows. |
| Small (muted 13) | You can withdraw this permission at any time in Settings, and we will delete these answers. |
| Primary | I agree, ask me these |
| Ghost | Skip these questions |
| Under buttons (muted 13, centred) | You can carry on without answering. Some matches may be less accurate. |
| Toast after Skip | No problem. You can answer these later in Settings. |

## 3. States (masters)

| State | Master | Look / words |
|---|---|---|
| Default | L06_consent | as §2 |
| Saving | L06_consent__saving | Primary reads "Saving…", 75%, not tappable; ghost hidden |
| Didn't save | L06_consent__didnt_save | Error bar (LOOK §5): "We couldn’t save your choice. Try again." + **Try again** (replaces today's snackbar) |
| Skipped, on Profile | L06_profile_faith__skipped | Above the FAITH PROFILE card, muted 13 px: "You chose not to share these. You can change this in Settings."; rows read "Not answered" |

## 4. Rules
- Consent is recorded exactly as today (same storage, same withdraw in Settings); only words, place in sign-up and the error bar change.
- New wording = new policy version: `kArticle9PolicyVersion` becomes `2026-11-06`.
- Skip never blocks sign-up; the marriage questions are not special-category and are still asked.

## Must not change
Consent storage and withdrawal logic · Shepherd invite screens 1-3 · faith and marriage questions and words · look · draft boundaries.

## Not decided
Settings "change your mind" screen design · legal review outcome.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 6 - Founder: "Yes — LOCK it" |
