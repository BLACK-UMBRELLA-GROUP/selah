---
id: DOC-SELAH-0031
type: PLAN
status: CURRENT
feature: SELAH_PAUSE
purpose: Build brief for LOCK 7 - the Selah pause before sending, accepting and ending a Journey
links: [DOC-SELAH-0029, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH PAUSE (LOCK 7) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 8. Build after: line 1 (look). ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `SELAH_PAUSE/RECORD/SELAH_PAUSE_SPEC_CURRENT_VERSION_V3.md`, its LOCK_RECORD, the 9 masters, LOOK spec V2. |
| 2 | Find the three actions | In the draft, find every place that sends a Journey request, accepts one, or ends a Journey (e.g. Browse/Connections "Send request", My SELAH accept, `screens/journey/journey_flow_screen.dart` "End Journey"; also the concept shell in `lib/dev/`). List each in the task note. |
| 3 | One pause widget | Build one full-screen pause widget (kind = ask / accept / end / replace) to spec §2-3 and show it before each action commits. Where an existing confirmation dialog/sheet already guards that action, replace it with the pause - no double confirmation, no dead code left. |
| 4 | Names | <Name> and <Shepherd> come from the existing profile and Shepherd data; pronouns from the profile. If the draft has no Shepherd name at that point, file a QUESTION (do not invent one). |
| 5 | States | Spec §4; sending/failed via the private developer controls. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/selah_pause_masters_test.dart`; 9 beside images in `SELAH_PAUSE/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", the list from step 2, replaced dialogs, screenshots, Disk, public checks A-F; mark line 8 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 5; spec V2, LOCK 13)
| # | Change |
|---|---|
| a | **Replace** kind (spec §1 d, §3): one pause replaces `_confirmCapacityReplacement` and any takeover path with the same effect. The ending Journey is picked as today; end + accept stay one action (both or neither). Masters L07_pause_replace, __ending, __didnt_go_through. |
| b | **No Shepherd pronoun.** End body is now "<Shepherd> will be told and can support you." - do not infer gender from names or relations. Accept keeps his/hers from the other member's profile (as built). Re-rendered L07_pause_end and __ending. |

## Update 2026-11-06 (answers QUESTIONS row 7; spec V3)
| # | Change |
|---|---|
| c | **No Shepherd**: ask, accept and Replace show the toast "Add a Shepherd to request or accept a Journey." and open no pause; End shows its pause without the Shepherd sentence (master L07_pause_end__no_shepherd, 10 masters now). Never invent a name. |
