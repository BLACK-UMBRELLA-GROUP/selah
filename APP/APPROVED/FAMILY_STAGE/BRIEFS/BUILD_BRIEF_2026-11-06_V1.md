---
id: DOC-SELAH-0074
type: PLAN
status: CURRENT
feature: FAMILY_STAGE
purpose: Build brief for LOCK 22 - Family Compatibility with 4 new Shepherd questions answered by Seekers; Seeker-to-Shepherd questions removed
links: [DOC-SELAH-0072, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH FAMILY COMPATIBILITY STAGE (LOCK 22) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 27. Build after: 26. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `FAMILY_STAGE/RECORD/SELAH_FAMILY_STAGE_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, masters `MASTERS/L22_*`, `lib/data/journey_questions.dart`, `_FamilyStageView` in `journey_flow_screen.dart`, and the draft's family stage (`selah_one_journey_concept_shell.dart`, "Your families meet your Journey here."). |
| 2 | Questions | Replace `mentorToSeeker` with the 4 questions of spec §1 (ids `fam_q1..4`, 400-character limit). Remove `seekerToMentor` and every use of it (incl. `journey_flow_screen.dart` ~line 1003). Leave stored rows for old ids untouched. |
| 3 | Page | Production `_FamilyStageView` and the draft family stage both follow spec §2 and the masters (label, note, Send answers rule). The draft's "<Name>’s family asks:" and its read-only fields go. |
| 4 | States | Sending / didn't send / sent as spec §3; completion as built once both Seekers have sent. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: 4 questions and ids; send needs all 4; no `seekerToMentor`), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; 5 beside images in `FAMILY_STAGE/BUILT/V1/`. |
| 7 | Task note + queue | "Built from", files, removed code, screenshots, Disk, public checks A-F; mark line 27 BUILT or FAILED. |
