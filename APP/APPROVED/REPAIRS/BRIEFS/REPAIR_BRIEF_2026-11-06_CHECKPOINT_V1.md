---
id: DOC-SELAH-0021
type: PLAN
status: CURRENT
feature: REPAIRS
purpose: Founder-named repair - make seeker_setup_checkpoint.dart use SELAH's own Christian fields instead of ZYRA's old faith fields (answers QUESTIONS row 3)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0020]
owner: SELAH chat
---

# REPAIR BRIEF — SEEKER SETUP CHECKPOINT — 6 NOV 2026 — V1

**Founder-named task** (Shakeel, 6 Nov 2026, clickable answer: "Yes, queue the repair (Recommended)").
**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 4. Build **before** line 1 (line 1 waits for it). No member-visible change. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

## Why
`SOURCE/lib/models/seeker_setup_checkpoint.dart` (`seekerProfileSectionComplete`, the `article9Consent != false` block, lines ~50-68) still checks ZYRA's fields (`details.sect`, `details.revertStatus`, `selahSectCodeFor`, the two hard-coded faith-branch keys, `preferences['sect']`, `preferences['revert']`). SELAH's `SeekerDetails` (`lib/services/selah_seeker_details_service.dart`) no longer has them, so the app does not compile. SELAH's own onboarding (`lib/screens/onboarding/chapter2_flow.dart`) already saves the Christian equivalents.

## Steps

| # | Step | Detail |
|---|---|---|
| 1 | Replace the field checks | `details.sect` → `details.christianFamily` (must be non-empty). `details.revertStatus == null` → `details.faithJourney == null`. Country of birth, nationality, ethnicity checks stay as they are. |
| 2 | Replace the preference checks | Remove the faith-branch matrix (`preferences['sect']`, `matrix`, the two branch keys, `selahSectCodeFor`). Instead read `preferences['church_background']`: `scope` must be one of the keys of `selahChurchPreferenceScopeLabels` (`no_preference`, `same_family`, `same_denomination`, `selected`); when `scope == 'selected'`, `family_codes` must be a non-empty List; `outside_flexibility` must be green/yellow/red **only where `chapter2_flow.dart` asks that question for the chosen scope** - read its logic; if it is unclear, stop and file a QUESTION. |
| 3 | Journey flexibility | `preferences['revert']['flexibility']` → `preferences['faith_journey']['flexibility']` (green/yellow/red), the key `selah_seeker_details_service.dart` saves. |
| 4 | Nothing else | Do not change `SeekerSetupCheckpoint.select`, the enum, the callers (`account_path_overview_screen.dart`, `profile_ready_screen.dart`), the onboarding screens, saved data shapes or consent rules. Do not add stubs, fake fields or skip checks. |
| 5 | Tests | Add model checks to `SOURCE/tool/test_models.dart`: complete profile → true; missing christianFamily → false; missing faithJourney → false; scope `selected` with empty family_codes → false; missing faith_journey flexibility → false. |
| 6 | Checks | `flutter analyze` (the 5 checkpoint errors gone, no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Report other leftovers | List (do not change) every other file that still mentions ZYRA's faith-branch names or "revert" (at least: `screens/onboarding/traffic_light_question_screen.dart`, `data/compatibility_categories.dart`, `services/selah_consent_service.dart`, `services/selah_discovery_service.dart`, `services/selah_unlock_service.dart`, `widgets/selah_profile_name_block.dart`) with line numbers in the task note, for a later SELAH clean-up line. |
| 8 | Commit + queue | Commit this repair on its own. Mark line 4 BUILT or FAILED. Line 1 then continues from your 6 Nov look candidate (`LOOK/BUILT/V1/CANDIDATE_2026-11-06.json`). |
