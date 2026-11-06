---
id: DOC-SELAH-0068
type: PLAN
status: CURRENT
feature: SHEPHERD_DASHBOARD
purpose: Build brief for LOCK 20 - Shepherd Dashboard with Needs you and gentle check-ins; snapshot and paid insights removed
links: [DOC-SELAH-0066, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH SHEPHERD DASHBOARD (LOCK 20) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 25. Build after: 24. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SHEPHERD_DASHBOARD/RECORD/SELAH_SHEPHERD_DASHBOARD_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, masters L20_* and re-rendered `PRAYER/MASTERS/L10_shepherd_dashboard__*`, `mentor_dashboard_screen.dart`. |
| 2 | Remove | FAMILY SNAPSHOT / YOUR FAMILY and SHEPHERD INSIGHTS (incl. the upgrade card) from the Dashboard. Leave `SelahMembershipCatalog` and any server insight code unchanged (list what is no longer reachable). |
| 3 | Needs you | Rename RIGHT NOW → NEEDS YOU; show only actionable priorities the app already computes, in spec §1 words; Encourage → that Seeker's Shepherd Circle. |
| 4 | Check-ins | From existing Journey stage-change events for the Shepherd's linked Seekers (last 7 days, newest first, max 3); Message → Shepherd Circle. No new store. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: check-in window/limit, empty Needs you), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/shepherd_dashboard_masters_test.dart`; 5 beside images (2 L20 + 3 L10) in `SHEPHERD_DASHBOARD/BUILT/V1/`. |
| 7 | Task note + queue | "Built from", sections removed, files, screenshots, Disk, public checks A-F; mark line 25 BUILT or FAILED. |
