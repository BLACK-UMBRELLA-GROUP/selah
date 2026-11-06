---
id: DOC-SELAH-0055
type: PLAN
status: CURRENT
feature: FIRST_PAGES
purpose: Build brief for LOCK 15 - four quiet first pages replacing the copied story pages
links: [DOC-SELAH-0053, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH FIRST PAGES (LOCK 15) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 18. Build after: 7 (clean-up), 16. Before 12. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `FIRST_PAGES/RECORD/SELAH_FIRST_PAGES_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, the 4 masters, SELAH_PAUSE spec V4 §2, LOOK V2. |
| 2 | Replace | The story pages in `lib/dev/dev_onboarding_opening.dart` (headings, bodies, closings, "Why photos first?", "The Selah approach", the quote, "See SELAH’s verification standard", per-page art) with spec §1-2. Reuse the pause layout widget from line 8 if built; otherwise build the same layout once and note it for line 8. |
| 3 | Keep | Where Skip/Continue lead (role choice, then LOCK 3), any direction switch used by developer previews. Remove art assets used only by the old pages: move them to `BLACK UMBRELLA GROUP/tmp/_to_delete/selah_<date>/` and list them. |
| 4 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`; update widget tests that read the old keys/words. |
| 5 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/first_pages_masters_test.dart`; 4 beside images in `FIRST_PAGES/BUILT/V1/`. |
| 6 | Task note + queue | "Built from", files, assets moved, screenshots, Disk, public checks A-F; mark line 18 BUILT or FAILED. |
