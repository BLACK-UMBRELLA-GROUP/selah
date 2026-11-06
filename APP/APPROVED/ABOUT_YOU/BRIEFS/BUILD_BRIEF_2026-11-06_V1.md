---
id: DOC-SELAH-0050
type: PLAN
status: CURRENT
feature: ABOUT_YOU
purpose: Build brief for LOCK 14 - remove country of birth, nationality and ethnicity questions; one languages question
links: [DOC-SELAH-0048, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH ABOUT YOU (LOCK 14) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 15. Build after: 3, 5, 6 (faith, marriage, consent). ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `ABOUT_YOU/RECORD/SELAH_ABOUT_YOU_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, the 6 masters, CONSENT V2, MARRIAGE_VALUES V3, LOOK V2. |
| 2 | Remove | `chapter2_flow.dart` steps 9-17 and 19-20 (spec §1) from the active step list, back/skip logic and `_totalSteps`; update the consent-gate constants (`_firstNonArticle9Step` etc.) so declining consent still skips only faith. Keep shared widgets used elsewhere; list any file moved to `BLACK UMBRELLA GROUP/tmp/_to_delete/selah_<date>/`. |
| 3 | Languages | Step 18 re-presented to spec §2 after the marriage questions; existing languages field and list. |
| 4 | Completion check | `seeker_profile_completion.dart`: stop requiring countryOfBirth, nationality, ethnicity, their preferred/flexibility sections and the languages preference/flexibility; require at least one language. Keep the consent-Skip rule. |
| 5 | Shown nowhere | Remove country of birth, nationality and ethnicity from every member-visible place (profile, preview "as others see", Shepherd views). List each place. Saved values stay in storage. |
| 6 | Profile | ABOUT YOU card (spec §4). |
| 7 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (update completion checks; add: one language required), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 8 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/about_you_masters_test.dart`; 6 beside images in `ABOUT_YOU/BUILT/V1/`. |
| 9 | Task note + queue | "Built from", steps removed, files, places from step 5, screenshots, Disk, public checks A-F; mark line 15 BUILT or FAILED. |

## Update 2026-11-06 (found by the SELAH chat after LOCK 14)
| # | Step | Detail |
|---|---|---|
| 4b | Compatibility category | `lib/data/compatibility_categories.dart` `culture_location` reads chapter2 keys `location`, `sect`, `revert`, `country_of_birth`, `nationality`, `ethnicity`, `languages`. Keep only `location` and `languages`; rename the category "Location & Language". `sect` and `revert` are leftovers from the earlier app (no SELAH question fills them) - remove them here and list any other place that still reads them. |
