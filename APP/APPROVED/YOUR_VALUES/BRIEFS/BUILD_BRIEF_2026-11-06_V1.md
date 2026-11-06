---
id: DOC-SELAH-0059
type: PLAN
status: CURRENT
feature: YOUR_VALUES
purpose: Build brief for LOCK 17 - Your values becomes 27 questions in 7 parts
links: [DOC-SELAH-0057, DOC-SELAH-0052, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH YOUR VALUES (LOCK 17) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 20. Build after: 15, 17. Before 12. ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `YOUR_VALUES/RECORD/SELAH_YOUR_VALUES_SPEC_CURRENT_VERSION_V3.md`, its LOCK_RECORD, the 8 masters, line 17's brief, FAITH_PROFILE V5 §1, `lib/data/chapter3_categories.dart`, `lib/data/compatibility_categories.dart`, `lib/screens/onboarding/values_preferences_flow.dart`, `compatibility_category_intro_screen.dart`. |
| 2 | Questions | The flow asks only the 27 in spec §1, grouped and ordered as listed. Remove the rest from every list the flow and Profile editors use. Question definitions may stay only where scoring needs them; nothing removed is asked or shown. Saved answers stay in storage, unused. |
| 3 | Screens | Overview + question screens to spec §2 (reuse the faith question layout from line 3). Replace the old category intro screens. |
| 4 | Compatibility | Categories = the 7 parts + "Location & Language"; line 17's mapped answers count in the parts named in spec §3. Scoring of each kept question unchanged. |
| 5 | Partner screens | See LOCK 18 brief (line 22): partner screens go; this line leaves them as built so line 22 removes them in one place. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: only 27 asked, part order, q24 show-if, categories), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/your_values_masters_test.dart`; 8 beside images in `YOUR_VALUES/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", ids kept / removed, files, screenshots, Disk, public checks A-F; mark line 20 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 11; spec V3)
Add a self-answer optional flag for exactly ch3_q44 and ch3_q51 (Skip shown); every other kept question stays needed; ch3_q24 needed when shown. Do not derive this from Ch4Status.
