---
id: DOC-SELAH-0065
type: PLAN
status: CURRENT
feature: SHEPHERD_INTRODUCE
purpose: Build brief for LOCK 19 - Network becomes Introduce; suggestions to the Shepherd's own Seeker
links: [DOC-SELAH-0063, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH SHEPHERD INTRODUCE (LOCK 19) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 24. Build after: 23. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SHEPHERD_INTRODUCE/RECORD/SELAH_SHEPHERD_INTRODUCE_SPEC_CURRENT_VERSION_V2.md`, its LOCK_RECORD, the 6 L19 masters and the re-rendered L01_shepherd_seekers, L03_shepherd_invitation, L10_shepherd_dashboard__* masters; `mentor_network_screen.dart`, `mentor_home_shell.dart`, the existing Introductions code behind My Selah. |
| 2 | Tab | Rename Network → Introduce in the Shepherd tab bar (`mentor_home_shell.dart`) and wherever its label is read. |
| 3 | Replace | The Network tab body becomes spec §2. Remove from the member app every Shepherd-to-Shepherd family request screen, cap message and "families" wording; keep the server/model code that is not reachable (list it). |
| 4 | Suggest | A suggestion is stored as an **existing Introduction** for that Seeker (no new store); spec §3 card on My Selah; "Not now" dismisses; "See <Name>" opens Browse on that person. The Shepherd is never shown the answer. |
| 5 | States | Spec §4; suggesting / didn't send via the private developer controls. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: suggestion stored once, discovery rules respected, dismiss), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/shepherd_introduce_masters_test.dart`; beside images for the 6 L19 masters and the 5 re-rendered Shepherd masters in `SHEPHERD_INTRODUCE/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", files, screens removed, screenshots, Disk, public checks A-F; mark line 24 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 16; spec V2)
| # | Change |
|---|---|
| a | Scope: offline draft only - one same-account local Introductions collection with the existing ShepherdSuggestion DTO and read / markSeen; no new table, store, RPC or backend call. Step 3's removal applies to the draft; the real HomeShell Network stays exactly as built until OA-SELAH-002. |
| b | Joel fixture and his candidates: spec §5 (Grace first). Never copy James's hidden, blocked, request or preference data. |
