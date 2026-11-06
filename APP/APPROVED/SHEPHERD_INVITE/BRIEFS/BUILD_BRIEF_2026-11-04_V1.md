---
id: DOC-SELAH-0016
type: PLAN
status: CURRENT
feature: SHEPHERD_INVITE
purpose: Build brief for LOCK 3 - SELAH's own Shepherd invite at sign-up, replacing the copied code-and-scan link for Seekers
links: [DOC-SELAH-0014, DOC-SELAH-0009, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH SHEPHERD INVITE (LOCK 3) — 4 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 2. Build after: line 1 (the look must be in first). ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `SHEPHERD_INVITE/RECORD/SELAH_SHEPHERD_INVITE_SPEC_CURRENT_VERSION_V1.md`, its `LOCK_RECORD.md`, the 12 masters in `SHEPHERD_INVITE/MASTERS/`, and LOOK spec V2 for colours/type. |
| 2 | Sign-up start | Add spec §1 screens 1-4 (with states 2e, 3e, 3s, 3f) as the start of the Seeker sign-up in the draft. The retained story pages in `lib/dev/dev_onboarding_opening.dart` stay where they are today (Private Home control), unchanged. |
| 3 | Replace the Seeker's code link | Where a Seeker links a Shepherd today (`lib/screens/mentor/link_shepherd_panel.dart` → `SelahCodeScreen(asShepherd: false)`), open spec screen 3 instead. Keep `SelahCodeScreen` for its other uses (`find_by_selah_code_screen.dart`, `mentor_invite_seeker_screen.dart`, `link_mentor_screen.dart`). Remove only code that no longer has a caller; move removed files to `BLACK UMBRELLA GROUP/tmp/_to_delete/selah_<date>/` and list them in the task note. |
| 4 | Waiting state | Spec §2 exactly: Browse bar + **Ask later**, Accept blocked with toast, Shepherd tab pending card. A local "Shepherd accepted" flag ends it as described. |
| 5 | Shepherd side | Restyle and reword `lib/screens/mentor/accept_shepherd_invite_screen.dart` to spec §3 (master L03_shepherd_invitation). Same accept/decline behaviour as today, plus the two toasts. |
| 6 | Developer controls | Add to the existing private developer controls: "Invite · sending", "Invite · didn't send", "Shepherd accepts". Not visible to members; release still refuses the draft. |
| 7 | No real sending | No network, share sheet, link domain or backend. Send and Copy link act locally (spec §4). |
| 8 | Checks | `flutter analyze` (no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 9 | Compare | Render each master's state at 430 × 932; save `SHEPHERD_INVITE/BUILT/V1/<master>__master_beside_build.png`. If no run is possible, file a QUESTION. |
| 10 | Task note | "Built from" (these paths), files removed/moved, screenshots, Disk, public checks A-F. |
| 11 | Queue | Mark line 2 BUILT or FAILED. |
