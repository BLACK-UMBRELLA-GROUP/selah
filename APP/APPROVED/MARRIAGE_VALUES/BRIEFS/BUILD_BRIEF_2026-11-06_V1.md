---
id: DOC-SELAH-0024
type: PLAN
status: CURRENT
feature: MARRIAGE_VALUES
purpose: Build brief for LOCK 5 - seven marriage-values questions right after the faith questions, and the Profile card
links: [DOC-SELAH-0022, DOC-SELAH-0017, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH MARRIAGE VALUES (LOCK 5) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 5. Build after: line 3 (faith profile). ROADMAP rows: **Christian content and production experience** and **SELAH's own identity and private delivery acceptance** (tick neither).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `MARRIAGE_VALUES/RECORD/SELAH_MARRIAGE_VALUES_SPEC_CURRENT_VERSION_V6.md`, its `LOCK_RECORD.md`, the 14 masters in `MARRIAGE_VALUES/MASTERS/`, FAITH_PROFILE spec V5, LOOK spec V2. |
| 2 | Reuse | Use the same question screen built for line 3 (one shared widget for both sections, header word and question list as inputs) - no second copy of the screen. |
| 3 | Flow | Faith question 7 → marriage question 1 → Browse (spec §1). Back on marriage 1 → faith 7. |
| 4 | Answers | Store in the draft's existing local profile model. If the model already has fields for any of these (e.g. previous marriage, children - check the retained `values_preferences_flow.dart` / `compatibility_categories.dart`), use them with exactly the spec's answer words; list in the task note which field each question uses. If an existing field conflicts with the spec words, stop and file a QUESTION - do not invent a mapping. |
| 5 | Profile | MARRIAGE VALUES card (spec §5) under the faith card. |
| 6 | States | Spec §4; saving/didn't save via the private developer controls. |
| 7 | Checks | `flutter analyze` (no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 8 | Compare | `APP/APPROVED/COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/marriage_values_masters_test.dart`; one `MARRIAGE_VALUES/BUILT/V1/<master>__master_beside_build.png` per master (all 14). |
| 9 | Task note + queue | "Built from", fields used, screenshots, Disk, public checks A-F; mark line 5 BUILT or FAILED. |

## Update 2026-11-06 (LOCK 14)
Spec is now V3. If line 15 is not BUILT yet, Save on question 7 still goes to Browse; line 15 inserts the languages question there. Profile master L05_profile_marriage__answered now shows the About you card (built by line 15) - compare the Marriage values card only.

## Update 2026-11-06 (answers QUESTIONS row 6; spec V5)
Save the seven answers as SELAH's own profile fields in the exact LOCK words (scoped new-field exception). Do **no** ch3/ch4 mapping here - line 17 does it (rows 1-10). Keep existing ch3/ch4 contracts untouched on this line.
