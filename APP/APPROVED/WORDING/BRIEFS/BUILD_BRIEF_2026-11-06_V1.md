---
id: DOC-SELAH-0043
type: PLAN
status: CURRENT
feature: WORDING
purpose: Build brief for LOCK 11 - write the app's name as "Selah" in all member-facing text and keep "Request a Journey" wording
links: [DOC-SELAH-0041, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH WORDING (LOCK 11) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 12. Build after: every other SELAH line queued before it (2, 3, 5, 6, 7, 8, 9, 10, 11) so it sweeps their new text too. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `WORDING/RECORD/SELAH_WORDING_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD. |
| 2 | Name | In `SOURCE/lib`, change every member-visible "SELAH" to "Selah" (spec §1). Do not change log/debug strings, internal IDs/keys, identifiers or file names. Put a count (before/after) and the list of files in the task note. |
| 3 | Requests | Check every request button/label against spec §2; change any that differ (e.g. leftover "Ask to begin"). |
| 4 | Tests | Update only tests that assert the old capitalised text. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | Re-run all `SOURCE/test/masters/*_masters_test.dart` that exist; any master now showing "Selah"/"Request a Journey" must match. Beside images to each feature's `BUILT/` folder as a new version if it changed. |
| 7 | Task note + queue | Counts, files, screenshots, Disk, public checks A-F; mark line 12 BUILT or FAILED. |

## Update 2026-11-06
Build after lines 13, 14, 15 and 16 as well (16 removes demo words first; sweep its result).
