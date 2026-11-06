---
id: DOC-SELAH-0078
type: PLAN
status: CURRENT
feature: DELIVERY_REPAIR
purpose: Founder-named task - repair SELAH's iPhone delivery route so the current app (and the LOCK 23 icon) can be installed on the Founder's iPhone again (QUESTIONS row 14)
links: [OA-SELAH-007, OA-SELAH-001, AD-AIOS-123]
owner: Fable (Founder-named task; written for the SELAH queue)
---

# BUILD BRIEF — SELAH iPHONE DELIVERY REPAIR — 6 Nov 2026

**Founder decision (6 Nov 2026, clickable question in the BLACK UMBRELLA GROUP chat):** asked whether Codex should repair
SELAH's out-of-date iPhone installer (QUESTIONS row 14) - "rebuilding SELAH's iPhone build with your existing Xcode,
possibly downloading SELAH's own build packages. No new apps or upgrades on your Mac." - he chose **"Yes, repair it
(Recommended)"**. This is tooling repair, not a design change: no app screen, wording or behaviour changes.

## Allowed

| Allowed | Detail |
|---|---|
| Rebuild the native iOS shell | With the Flutter, Dart and Xcode already on the Mac and the iPhoneOS SDK Xcode already has. Recreate the prepared build inputs `run.sh` and `tooling/dart_layer_delivery.sh` need (Runner.app, generated Swift-package/plugin files, package config) from the current `pubspec.yaml` / `pubspec.lock`. |
| Downloads | Only SELAH's own declared dependencies: Dart packages exactly as pinned in `pubspec.lock`, and the Swift packages / CocoaPods the iOS project already declares, into their normal caches. Record each download and its size in the task note. |
| Refresh pins | Update the pins in `run.sh` and `tooling/dart_layer_delivery.sh` (pubspec/package-config hashes, reviewed App.framework size/hash, icon/storyboard resources) to the new reviewed build, with the reason for each change in the task note. |
| Keep every safety check | Strict signature, provisioning profile, paired-device, unlocked-device and 22-second launch checks stay exactly as strict. No bypass flags. |

## Not allowed (lesson F33, OA-AIOS-420)

No macOS, Xcode, Flutter, Dart, CocoaPods, Homebrew or other tool install or upgrade; no new SDK or simulator download;
no new app on the Mac. If the repair needs any of those, stop and file it in `QUESTIONS.md` with what and how big. No
credentials, signing identities or team IDs in files or notes.

## Steps

1. Diagnose with the existing tools first (`tooling/check_delivery_chain.sh`, `tooling/delivery_preflight.dart`) and
   list exactly what is missing or stale.
2. Rebuild the prepared native route as allowed above and refresh the pins.
3. Run the app's checks (analyze, release-safety test) - no new failures.
4. **Phone install only when Shakeel types GO in the SELAH Codex chat** (he is at home with the phone connected and
   unlocked): install, open, and confirm the 22-second launch check on the paired iPhone, then screenshot the first frame.
5. Then set line 28 (LOCK 23 icon) back to WAITING and build it, and put the current app on the phone the same way.
6. Task note: what was missing, what was rebuilt, downloads and sizes, pin changes, check results, phone result.
   Public checks A-F (this repo is public).

Deadline: before 21 Nov 2026 (Founder abroad from 21 Nov; no installs or phone work while away).
