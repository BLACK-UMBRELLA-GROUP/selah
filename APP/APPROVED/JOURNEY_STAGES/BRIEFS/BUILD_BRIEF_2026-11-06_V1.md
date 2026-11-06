---
id: DOC-SELAH-0071
type: PLAN
status: CURRENT
feature: JOURNEY_STAGES
purpose: Build brief for LOCK 21 - 7 Journey stages; the Shepherd support stage leaves the app, the server map is untouched
links: [DOC-SELAH-0069, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH JOURNEY STAGES (LOCK 21) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 26. Build after: 25. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `JOURNEY_STAGES/RECORD/SELAH_JOURNEY_STAGES_SPEC_CURRENT_VERSION_V2.md`, its LOCK_RECORD, the re-rendered masters in `LOOK/MASTERS` (5 listed in spec §2) and `MARRIAGE_PREP/MASTERS/L09_*`, `lib/data/selah_journey_stages.dart`, `journey_flow_screen.dart`, `selah_journey_service.dart`. |
| 2 | Stage list | `SelahJourneyStages.all` = the 7 stages of spec §1, in order; `order` and `count` follow (count 7). `of('mentor_gate')` must still resolve without a crash (legacy value, not in `all`, displays as Faith & Values). Update the file's header notes to say 7 and why (LOCK 21). |
| 3 | Pass-through | After `advanceStage(id,'compatibility_reveal')` returns stage `mentor_gate`, call `advanceStage(id,'mentor_gate')` at once. Opening a Journey stored at `mentor_gate` does the same. `stage_moved` = already moved (fine). Any other refusal → existing "That didn't save. Try again." state, and write the reason in the task note. Do not change the RPC or any SQL. |
| 4 | Remove | `_MentorGateView` and its Shepherd reveal / greeting steps from the flow; `mentor_gate` branches in `selah_shepherd_dashboard_resolver.dart`, `selah_shepherd_seeker_roster_resolver.dart`, `selah_mentor_journey_service.dart` (treat as Faith & Values, no "waiting" item); dev scenario / test-control entries that open that stage (same rule as queue line 16). List anything left unreachable. |
| 4b | Draft too | The local draft (`lib/dev/selah_one_journey_concept_shell.dart` ~line 2944, `selah_view_request_draft_model.dart` ~line 778, `selah_one_journey_journey_presentation.dart`) uses the same list: no `mentor_gate` step there either. Under "Ready to move forward?" delete the line "Selah will first confirm that both Main Shepherds are present." (no replacement line). |
| 5 | Header | Journey header "Stage n of 7 · Shepherds: <A> and <B>" as master L01_seeker_journey__stages. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: 7 stages in order; legacy `mentor_gate` resolves; pass-through after Compatibility Reveal; update any test asserting 8), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; 9 beside images (5 L01 + 4 L09) in `JOURNEY_STAGES/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", files, removed code, screenshots, Disk, public checks A-F; mark line 26 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 15; spec V2)
| # | Change |
|---|---|
| a | Shepherd names: spec §2a - draft-only fixture field for the 4 demo Seekers; everyone else and the real app "<Name>’s Shepherd"; your own Main Shepherd's display name; no Shepherd → header "Stage n of 7" only. No paid lookup, no server or contract change. |
| b | Shepherd Seekers caption stays "Stage n · <label>" (master L01_shepherd_seekers). "of 7" is for Seeker screens only. |
