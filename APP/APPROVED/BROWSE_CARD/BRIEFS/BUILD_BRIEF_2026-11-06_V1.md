---
id: DOC-SELAH-0034
type: PLAN
status: CURRENT
feature: BROWSE_CARD
purpose: Build brief for LOCK 8 - faith chips on the Browse card, the no-one-new state, and SELAH's own demo cast
links: [DOC-SELAH-0032, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH BROWSE CARD + DEMO CAST (LOCK 8) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 9. Build after: lines 3 (faith answers) and 7 (clean-up touches the demo scenario file). ROADMAP rows: **SELAH's own identity and private delivery acceptance**; **Christian content and production experience** (tick neither).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `BROWSE_CARD/RECORD/SELAH_BROWSE_CARD_SPEC_CURRENT_VERSION_V4.md`, its LOCK_RECORD, the 6 masters, FAITH_PROFILE spec V5. |
| 2 | Chips | On the Browse card, replace the nationality/ethnicity chips with spec §1 faith chips (exact texts and order). Do not remove nationality/ethnicity from the full profile or the model. |
| 3 | No one new | Add spec §2 state where Browse runs out of people; its button opens the existing filters. |
| 4 | Demo cast | In the draft's demo data (`lib/dev/selah_dev_scenario.dart`, `lib/dev/selah_one_journey_concept_shell.dart` and any other fixture file), replace every demo person and Shepherd with spec §3: names, relations that match, traditions, UK towns, plausible nationality/ethnicity, existing photos matched by gender. List old → new in the task note. |
| 5 | Search | Afterwards no demo data uses the old ZYRA cast names (e.g. Sara Ahmed, Amira Rahman, Adam Khan, and the list in the old scenario); put the search command and result in the task note. |
| 6 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`; existing tests updated only where they assert old demo names. |
| 7 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/browse_card_masters_test.dart`; 6 beside images in `BROWSE_CARD/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", old → new cast list, screenshots, Disk, public checks A-F; mark line 9 BUILT or FAILED. |

## Update 2026-11-06 (from the SELAH chat's build check of line 3)
The signed-in demo Seeker still shows as "Adam Khan" on Profile. Old cast names also sit as defaults in screen files, not only fixtures - include them: `lib/screens/journey/journey_flow_screen.dart` (~2981, ~5388), `lib/screens/mentor/seeker_mentor_tab.dart` (~283), `lib/dev/selah_one_journey_concept_shell.dart` (~3137, ~3231). The signed-in demo Seeker is **James** (as in every master).

## Update 2026-11-06 (answers QUESTIONS row 9; spec V4)
No "In a Journey" state: keep `discoverableProfiles` excluding this pair (peerOccupied) exactly as built. Five card states, not six; your default is right.
