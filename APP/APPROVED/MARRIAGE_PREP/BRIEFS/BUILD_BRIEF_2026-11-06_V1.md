---
id: DOC-SELAH-0037
type: PLAN
status: CURRENT
feature: MARRIAGE_PREP
purpose: Build brief for LOCK 9 - the Preparing for marriage card at Open Conversation
links: [DOC-SELAH-0035, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH MARRIAGE PREPARATION (LOCK 9) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 10. Build after: line 1 (look). ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `MARRIAGE_PREP/RECORD/SELAH_MARRIAGE_PREP_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, the 4 masters, LOOK spec V2. |
| 2 | Where | Find the Active Journey screen's Open Conversation (`conversation`) view (e.g. `lib/screens/journey/journey_flow_screen.dart` and the concept shell in `lib/dev/`). Add the card below the stage content there only. No change to `selah_journey_stages.dart`. |
| 3 | Data | Store the three ticks on the local Journey (draft data, both members see the same). If the Journey model has no place for them, add the smallest field and list it in the task note. |
| 4 | States | Spec §3; "didn't save" via the private developer controls. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add checks for toggling), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/marriage_prep_masters_test.dart`; 4 beside images in `MARRIAGE_PREP/BUILT/V1/` (scrolled to the card). |
| 7 | Task note + queue | "Built from", files, field added, screenshots, Disk, public checks A-F; mark line 10 BUILT or FAILED. |
