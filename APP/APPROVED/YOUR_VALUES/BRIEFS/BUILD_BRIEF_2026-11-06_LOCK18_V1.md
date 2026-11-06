---
id: DOC-SELAH-0061
type: PLAN
status: CURRENT
feature: YOUR_VALUES
purpose: Build brief for LOCK 18 - no partner-preference screens; one optional deal-breakers screen
links: [DOC-SELAH-0057, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — DEAL-BREAKERS (LOCK 18) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 22. Build after: 20. Before 12. ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `YOUR_VALUES/RECORD/SELAH_YOUR_VALUES_SPEC_CURRENT_VERSION_V3.md` §2-2b, its LOCK_RECORD, masters L18_* and the re-rendered L17 overview masters. |
| 2 | Remove | Every per-option partner-preference screen (`traffic_light_question_screen.dart` and its use in `values_preferences_flow.dart` and the Profile `compatibility_editors.dart`) from the member flow. Saved `ch4_preferences` stay in storage, unused. The Divorced preference from Marriage Q5 (line 17 row 10) stays - it is set by the sign-up answer, not a screen. |
| 3 | Add | The deal-breakers screen and overview row (spec §2, §2b). Save writes `ch4_hard_requirements` exactly per the §2b table; "None of these" or nothing chosen writes none of those keys. |
| 4 | Matching | Draft keeps its fixture score. No server, scorer or schema change (OA-SELAH-002 later). |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: each choice's hard-requirement rows; None clears; partner screens unreachable), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/dealbreakers_masters_test.dart`; 8 beside images (6 L18 + 2 L17 overview) in `YOUR_VALUES/BUILT/LOCK18_V1/`. |
| 7 | Task note + queue | "Built from", screens removed, files, screenshots, Disk, public checks A-F; mark line 22 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 12; spec V3)
The overview shows "Done" on every finished part. The all-done master is re-rendered with all seven parts and Deal-breakers Done. Reach it in the capture by finishing all seven parts and the deal-breakers screen (a private developer preset may fill the answers) - no fake state.
