---
id: DOC-SELAH-0046
type: PLAN
status: CURRENT
feature: SEEKER_SHEPHERD
purpose: Build brief for LOCK 12 - the Seeker's Shepherd tab with the Main Shepherd first
links: [DOC-SELAH-0044, DOC-SELAH-0038, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH SEEKER SHEPHERD TAB (LOCK 12) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 13. Build after: 2 (Shepherd invite), 9 (demo cast), 11 (Ask for prayer button). ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `SEEKER_SHEPHERD/RECORD/SELAH_SEEKER_SHEPHERD_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, the 6 masters, PRAYER spec V2, LOOK spec V2. |
| 2 | Reorder | In `seeker_mentor_tab.dart` / `seeker_shepherd_designs.dart`: Main Shepherd card first (spec §1-2), then RECENTLY FROM, then the existing Additional Shepherds, Journey access and Past Journey summaries. Main Shepherd shown once. |
| 3 | Buttons | Ask for prayer (line 11) · Message → existing Your Shepherd Circle · Manage → existing Main Shepherd actions. Remove the separate Shepherd Circle button. No new chat, permission model or store. |
| 4 | Recent | Build the 3-line list from existing data only: LOCK 10 prayed events and the Main Shepherd's latest Shepherd Circle messages. List any getter added. |
| 5 | States | Spec §3 words replace the caps labels; loading / didn't load via the private developer controls. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add a check: recent list order and limit 3), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/seeker_shepherd_masters_test.dart`; 6 beside images in `SEEKER_SHEPHERD/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", files, getters, screenshots, Disk, public checks A-F; mark line 13 BUILT or FAILED. |
