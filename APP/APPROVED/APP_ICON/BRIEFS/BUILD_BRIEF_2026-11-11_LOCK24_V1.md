---
id: DOC-SELAH-0081
type: PLAN
status: CURRENT
feature: APP_ICON
purpose: Build brief for LOCK 24 - the app holds the launch wordmark 1 s from its first frame, then fades 0.45 s into the first screen (fixes the 0.3 s flash)
links: [DOC-SELAH-0075, DOC-SELAH-0078, DOC-SELAH-0020, AD-AIOS-131]
owner: SELAH chat
---

# BUILD BRIEF — SELAH OPENING HAND-OVER (LOCK 24) — 11 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 31. Build after: 30. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).
**SELAH is paused (AD-AIOS-131).** This one line is a Founder-named fix ("needs fixing", 11 Nov, then "A · Hold, then fade — LOCK it"); it restarts nothing else.

Why: on the Founder's iPhone the LOCK 23 launch screen shows for ~0.3 s and the app jumps in - it reads as a glitch.

| # | Step | Detail |
|---|---|---|
| 1 | Read | `APP_ICON/RECORD/SELAH_APP_ICON_SPEC_CURRENT_VERSION_V4.md` §2 and §2b, its LOCK_RECORD (row 24), master `MASTERS/L23_splash.png`, `lib/main.dart` (the note there: the first Flutter frame must render immediately). |
| 2 | Overlay | Above the app's first route, draw the launch view in Flutter on the very first frame: `#EEF1F0` full screen, `L23_splash_wordmark_3x.png` (bundle it as an app asset; 260×80 logical px) centred exactly as the native `LaunchScreen.storyboard` centres it. **Do not delay or defer the first frame** and do not change the native launch screen. |
| 3 | Timing | Hold 1.0 s from the first frame, then fade the overlay out over 0.45 s (ease) to the first screen underneath. If that screen is not ready at 1.0 s, keep holding until it is, then fade. Reduce Motion (`MediaQuery.disableAnimations`) → remove after the hold with no fade. |
| 4 | Behaviour | Cold start only (not on return from background). The overlay absorbs taps and is excluded from semantics; the screen underneath is not focused for screen readers until the overlay is gone. No spinner, no text. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`; add a widget test: overlay present at 0.9 s, fading at 1.2 s, gone by 1.5 s; Reduce Motion gone right after 1.0 s; no overlay on resume. |
| 6 | Compare | Widget screenshot of the first frame beside `L23_splash` in `APP_ICON/BUILT/V1_LOCK24/` (Codex working file - never shown to Shakeel, charters rule 13). |
| 7 | Phone | Through the existing reviewed delivery route (DELIVERY_REPAIR brief, all strict checks) and **only when Shakeel types GO** with the phone connected and unlocked. He then checks the opening on the phone himself. |
| 8 | Task note + queue | "Built from", files, test results, Disk, public checks A-F; mark line 31 BUILT or FAILED. |

## Update 2026-11-12 (answers your FAILED design check, task note 2026-11-12_SELAH_ROW31; spec V4)
| # | Change |
|---|---|
| a | You were right: the old `L23_splash` master drew the wordmark as text, 3 px right and 9 px down of the native placement. `MASTERS/L23_splash.png` is re-rendered from `L23_splash_wordmark_3x.png` at the exact storyboard centre - compositing the asset at the centre of a 1290×2796 `#EEF1F0` raster now matches the master with 0 pixels differing by more than 3 in the wordmark area (status bar excluded). Old master in `ARCHIVE/MASTERS_LOCK24_OFFCENTRE/` |
| b | Native placement and the master now agree: step 2 stands as written (same asset, same centre as the storyboard). Line 31 is back to WAITING |
