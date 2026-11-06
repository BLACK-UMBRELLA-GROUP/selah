---
id: DOC-SELAH-0020
type: STANDARD
status: CURRENT
feature: COMPARE
purpose: How Codex renders SELAH's built screens beside their LOCK masters without the phone delivery route (answers QUESTIONS row 2)
links: [OA-SELAH-001, OA-SELAH-003, AD-AIOS-115]
owner: SELAH chat
---

# SELAH MASTER COMPARE ROUTE — CURRENT VERSION V1

Shakeel, 6 Nov 2026: "either write a small setup brief to restore the run, or name another way to compare". This names
another way. Phone delivery (`SOURCE/run.sh`, `tooling/dart_layer_delivery.sh`) is **not** used, changed or re-pinned for
master comparisons; restoring it stays separate work under OA-SELAH-001 and needs its own Founder-named brief.

## Route: widget screenshots in `flutter test`

| # | Step | Detail |
|---|---|---|
| 1 | Packages | From `SELAH/SOURCE`: `flutter pub get` using the existing `pubspec.lock` (no version changes). If it cannot resolve offline or online, stop and file a QUESTION. |
| 2 | Test file | One file per feature: `SOURCE/test/masters/<feature>_masters_test.dart` (e.g. `look_masters_test.dart`). Only made-up demo data, as in the draft. |
| 3 | Size | Each test sets the view to **430 × 932 logical, device pixel ratio 3** (1290 × 2796 physical) with the iPhone 15 Pro Max safe areas (top 59, bottom 34), text scale 1.0, light mode. |
| 4 | Fonts | Load the bundled `.ttf` files from `SOURCE/assets/fonts/` with `FontLoader` before pumping, so text is real (never the test box font). `GoogleFonts.config.allowRuntimeFetching = false`. |
| 5 | Reach the state | Pump the real screen widget and drive it to the master's state (taps, or the draft's developer-control state). Never build a fake copy of a screen for the test. |
| 6 | Beside image | In the same test, pump a 860 × 932 frame: left = the master PNG (`Image.file`, from the feature's `MASTERS/`), right = the built screen; capture with `matchesGoldenFile` / `RepaintBoundary.toImage` to `APP/APPROVED/<FEATURE>/BUILT/V<n>/<master>__master_beside_build.png`. Also save the build alone as `<master>__build.png`. |
| 7 | Run | `flutter test test/masters/<feature>_masters_test.dart --update-goldens` to write the images, then once more without `--update-goldens` (must pass). |
| 8 | What it proves | Layout, words, colours, fonts and states of the Flutter screens. It does **not** prove phone install, native launch or device behaviour (OA-SELAH-001). Say so in the task note. |
| 9 | Keep it clean | The masters test files stay in the repo as SELAH's visual checks. No new packages; no change to `run.sh`, `tooling/`, pins, signing or native files. |

## Who checks
The SELAH chat compares every `__master_beside_build.png` with its master (charters rule 8) and writes MATCH or each difference in its chat note.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | Written to answer QUESTIONS row 2 (Founder: "name another way to compare") |
