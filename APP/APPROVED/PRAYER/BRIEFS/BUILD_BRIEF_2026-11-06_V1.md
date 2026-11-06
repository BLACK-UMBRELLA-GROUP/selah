---
id: DOC-SELAH-0040
type: PLAN
status: CURRENT
feature: PRAYER
purpose: Build brief for LOCK 10 - prayer requests from Seeker to Shepherd, shown on the Shepherd Dashboard
links: [DOC-SELAH-0038, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH PRAYER (LOCK 10) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 11. Build after: lines 1 and 9 (demo cast names). ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `PRAYER/RECORD/SELAH_PRAYER_SPEC_CURRENT_VERSION_V2.md`, its LOCK_RECORD, the 7 masters, LOOK spec V2. |
| 2 | Seeker | Add the **Ask for prayer** button to the Seeker's Shepherd tab and the page in spec §1. Nothing else on that tab changes. |
| 3 | Shepherd | Add the PRAYER REQUESTS block at the top of the existing Shepherd Dashboard (`lib/screens/mentor/mentor_dashboard_screen.dart` or wherever the Dashboard tab of `mentor_home_shell.dart` renders). Tabs unchanged. |
| 4 | Data | Local draft data only: request (seeker, text, time), prayed count, whether this Shepherd prayed; the My Selah update. Seed two demo requests from the LOCK 8 cast. List any model field added. |
| 5 | States | Spec §4; sending/didn't send via the private developer controls. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add checks: send, pray once, count), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/prayer_masters_test.dart`; 7 beside images in `PRAYER/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", files, fields, screenshots, Disk, public checks A-F; mark line 11 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 8; spec V2)
Step 4: seed the **four** requests in the masters (spec V2 §3), not two. My Selah update: Journey form when the request names a Journey, general form otherwise. The masters are right as they are.
