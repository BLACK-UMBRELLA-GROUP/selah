---
id: DOC-SELAH-0077
type: PLAN
status: CURRENT
feature: APP_ICON
purpose: Build brief for LOCK 23 - new app icon (all sizes, iOS and Android) and launch screens from the masters
links: [DOC-SELAH-0075, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH APP ICON AND SPLASH (LOCK 23) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Do not redraw the icon - use the master files. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 28. Build after: 27. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `APP_ICON/RECORD/SELAH_APP_ICON_SPEC_CURRENT_VERSION_V1.md`, its LOCK_RECORD, all `APP_ICON/MASTERS/L23_*`. |
| 2 | iOS icon | Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset/Selah-1024.png` with `L23_icon_1024.png` (keep the file name and `Contents.json` unless a size is missing; list any you add). Replace `assets/icon/icon.png` with the same file. |
| 3 | Android icon | Every `android/app/src/main/res/mipmap-*` launcher icon from `L23_icon_1024.png`; adaptive icon = background `#EEF1F0` + foreground `L23_icon_android_foreground_1024.png`. If an icon-generator package is already in `pubspec.yaml`, use it; do not add a new dependency without reporting it. |
| 4 | iOS launch | `LaunchScreen.storyboard`: background `#EEF1F0` (sRGB 0.933/0.945/0.941), the purple and gold text removed, centred image from `L23_splash_wordmark_3x.png` (@1x/@2x/@3x at 260×80 pt) in a new image set. |
| 5 | Android launch | `launch_background.xml` (and `values-v31` splash if present): background `#EEF1F0`, centred wordmark; Android 12+ splash icon = the adaptive foreground on `#EEF1F0`. |
| 6 | Checks | `flutter analyze`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`; search the repo for the old purple values (0.118/0.078/0.157 and its hex) and list every hit. |
| 7 | Compare | Simulator screenshots of the home screen and the launch screen beside `L23_home_screen` and `L23_splash` in `APP_ICON/BUILT/V1/`. |
| 8 | Task note + queue | "Built from", files, screenshots, Disk, public checks A-F; mark line 28 BUILT or FAILED. |
