---
id: DOC-SELAH-0010
type: PLAN
status: CURRENT
feature: LOOK
purpose: Build brief for LOCK 1 - give SELAH its own look (Still Water) in place of the copied purple/gold look
links: [DOC-SELAH-0009, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH LOOK (LOCKs 1 and 2) — 3 NOV 2026 — V1 (updated after QUESTIONS rows 1 and 2)

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 1. Build after: nothing. Build before: any later SELAH line.
ROADMAP row: **SELAH's own identity and private delivery acceptance** (do not tick it - this is one step of it).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `SELAH/MAP.md` to "Route paths", `LOOK/RECORD/SELAH_LOOK_SPEC_CURRENT_VERSION_V2.md` (the numbers), `LOOK/RECORD/LOCK_RECORD.md`, the 15 masters in `LOOK/MASTERS/`. There are no baseline captures yet. |
| 2 | Scope | **Look only.** Apply spec §1-5 to SELAH's existing screens. Do **not** build anything the masters show that SELAH does not have today (Selah pause, prayer, Shepherd permissions, Marriage preparation stage, Shepherd Prayer tab, demo people) - spec "What this LOCK covers". Words and flows stay as they are. |
| 3 | Colours | In `SOURCE/lib/theme/selah_colors.dart` make the spec §1 tokens the app's colours. Remove the purple/gold app styling and palette choices from what the app shows (`selah_app_gold_style.dart`, the dev palette selection) so there is one look. Leave colour values used only by retained, unused code alone and **list them in the task note** (e.g. the `wafa*` colours) - do not delete files; anything removed goes to `BLACK UMBRELLA GROUP/tmp/_to_delete/selah_<date>/`. |
| 4 | Fonts | Add Cormorant Garamond (600, 600 italic) and Figtree (400, 500, 600) as bundled `.ttf` files in `SOURCE/assets/fonts/` with their OFL text, from the Google Fonts repository (github.com/google/fonts, `ofl/cormorantgaramond`, `ofl/figtree`). Register them in `pubspec.yaml`. In `SOURCE/lib/theme/selah_text.dart` apply spec §2; Cormorant only for wordmark, titles, names, quotes and the pause heading; Figtree for everything else. Remove Poppins/Syne/Jost from what the app shows (font picker options and pubspec entries); move the old font files to `_to_delete` as in step 3. `GoogleFonts.config.allowRuntimeFetching = false` stays. |
| 5 | Shapes | Apply spec §3 (cards, buttons, chips, photos, thumbnails, icon buttons, switches, progress). Update `selah_card_metrics.dart` / `selah_interaction_style.dart` where those values live. |
| 6 | Tab bar | Replace the floating nav bar (`SOURCE/lib/widgets/floating_nav_bar.dart`, used by `screens/home/home_shell.dart`, `screens/mentor/mentor_home_shell.dart`, `dev/selah_one_journey_concept_shell.dart`, `widgets/selah_shell_navigation.dart`) with the docked bar in spec §4, same tabs and same behaviour. Keep its other menus (e.g. Cancel / Hide profile) working; restyle them to the spec. No dead code left behind. |
| 6b | States (LOCK 2) | Apply spec §5 to every loading and failure point the existing code already has (list each one in the task note: screen, which state). Add none where the code has none. |
| 7 | Wordmark | "Selah" + dawn ’ as spec §2 wherever the app shows its name in a header. |
| 8 | Checks | `flutter analyze` (no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`; app still starts on the current Browse shell; release mode still refuses the draft. |
| 9 | Compare | Use `APP/APPROVED/COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md` (widget screenshots in `flutter test`; the phone delivery route is not used). Test file `SOURCE/test/masters/look_masters_test.dart`; one `LOOK/BUILT/V1/<master>__master_beside_build.png` for each master that shows an existing screen (masters showing screens SELAH does not have yet are skipped - list them). |
| 10 | Task note | Daily report: "Built from" (these paths), the list from step 3, screenshots, Disk, public checks A-F. |
| 11 | Queue | Mark line 1 BUILT or FAILED in `APP/APPROVED/BUILD_QUEUE.md`. |
