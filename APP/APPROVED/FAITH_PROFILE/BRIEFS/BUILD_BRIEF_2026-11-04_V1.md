---
id: DOC-SELAH-0019
type: PLAN
status: CURRENT
feature: FAITH_PROFILE
purpose: Build brief for LOCK 4 - SELAH's seven faith questions at sign-up, one per screen, and the Profile faith card
links: [DOC-SELAH-0020, DOC-SELAH-0017, DOC-SELAH-0014, DOC-SELAH-0009, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH FAITH PROFILE (LOCK 4) — 4 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 3. Build after: lines 1 and 2. ROADMAP rows: **Christian content and production experience** and **SELAH's own identity and private delivery acceptance** (tick neither).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `FAITH_PROFILE/RECORD/SELAH_FAITH_PROFILE_SPEC_CURRENT_VERSION_V4.md`, its `LOCK_RECORD.md`, the 16 masters in `FAITH_PROFILE/MASTERS/`, SHEPHERD_INVITE spec V4 §1 screen 4, LOOK spec V2. |
| 2 | Screens | Add the 7 question screens (spec §1-2) after Shepherd invite screen 4: its **Continue** opens question 1 (not Browse) until line 6 puts the consent screen in between. Saved → Browse until line 5 is built; line 5 then sends it to the marriage questions (spec V3). |
| 3 | States | Every state in spec §3. "Saving" and "Didn't save" are reached through the private developer controls (offline draft saves locally at once). |
| 4 | Answers | Store answers in the draft's existing local profile model (find where the Profile faith rows come from today; list the file in the task note). Use exactly the answer words in spec §2. Retire any existing faith questions they replace and list what was removed (move files to `BLACK UMBRELLA GROUP/tmp/_to_delete/selah_<date>/`). If an existing question has no match in spec §2, do not delete it - file a QUESTION. |
| 5 | Profile | FAITH PROFILE card exactly as spec §4 (rows, "Not answered", quote). Browse chips/quote read the same answers. |
| 6 | Checks | `flutter analyze` (no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 7 | Compare | Use `APP/APPROVED/COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`. Test file `SOURCE/test/masters/faith_profile_masters_test.dart`; one `FAITH_PROFILE/BUILT/V1/<master>__master_beside_build.png` per master (all 16). |
| 8 | Task note + queue | "Built from" (these paths), files moved, screenshots, Disk, public checks A-F; mark line 3 BUILT or FAILED. |

## Step 4b — the old faith screens and saved fields (added 6 Nov 2026, answers QUESTIONS row 4)

The seven LOCK 4 screens **replace** Chapter2 cases 4–8 in sign-up (tradition, does tradition matter, other tradition,
Christian journey, other journey). Take those five cases out of the active step list; keep their shared widgets and
every saved contract. No migration of old answers, nothing deleted from storage. Cases 9+ (country, nationality,
ethnicity, languages) are **not** part of this line - leave them exactly as they are.

New answers fill the **existing** fields (no second store). Codes from `lib/data/selah_christian_traditions.dart`:

| LOCK 4 answer | Saved as |
|---|---|
| Q1 Anglican | christianFamily = Anglican & Episcopal |
| Q1 Baptist / Methodist / Presbyterian | christianFamily = Protestant; christianDenomination = that name only if the exact label exists under Protestant, else empty |
| Q1 Catholic | Catholic |
| Q1 Orthodox | Orthodox & Eastern Christian |
| Q1 Pentecostal | Pentecostal, Charismatic & Apostolic |
| Q1 Non-denominational | Independent & Non-denominational |
| Q1 Another tradition | Another Christian tradition or movement |
| Q4 All my life | faithJourney = raised_christian |
| Q4 any other answer | faithJourney = became_christian_later; also keep the Q4 words themselves for the Profile "Christian for" row |
| Q6 Yes, any tradition | church_background.scope = no_preference; outside_flexibility = green |
| Q6 Similar traditions only | scope = same_family; outside_flexibility = yellow |
| Q6 My own tradition only | scope = same_family; outside_flexibility = red; firm preference = true |
| Q2, Q3, Q5, Q7 | Draft profile fields beside the above (list them in the task note) |

Completion check (`seeker_profile_completion.dart`, as repaired on line 4): keep christianFamily, faithJourney,
church_background scope and outside_flexibility (all filled by the new screens); **stop requiring**
`faith_journey.flexibility` (no longer asked; keep any saved value); add the needed LOCK 4 answers 2 and 3.
The `article9Consent != false` rule stays: if the Seeker chose Skip on the consent screen, no faith answer is needed.

Visibility: the tradition shows on Profile and the Browse card (LOCK 4 §4, LOCK 8), so answers given after
"I agree, ask me these" are saved as shown. The old "Show my Christian tradition on my profile" switch is not shown in
sign-up; any existing Settings control for it stays as built. "Similar traditions" = same family code (no new grouping).
