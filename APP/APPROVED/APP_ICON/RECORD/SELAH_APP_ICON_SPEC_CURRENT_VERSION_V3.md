---
id: DOC-SELAH-0075
type: SPEC
status: CURRENT
feature: APP_ICON
purpose: Selah's app icon, launch (splash) screen and the opening hand-over in the LOOK - pale water background, Cormorant "S" in ink with the warm mark; splash shows the wordmark only (LOCK 23); the app holds it 1 s and fades into the first screen (LOCK 24)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH APP ICON AND SPLASH — SPEC — CURRENT VERSION V3 (LOCK 23, LOCK 24)

Founder, 6 Nov 2026: "A · Light — LOCK it" (prototype V51, cleaned as V52). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## Why
Founder, 6 Nov 2026: "also tell codex to design a new app icon and splash screen based upon latest updates". Today
`ios/Runner/Assets.xcassets/AppIcon.appiconset/Selah-1024.png` (and `assets/icon/icon.png`) is a purple background with a
gold "S" in a ring and a cross, and `LaunchScreen.storyboard` is the same purple with gold text - the last place the look from
before the LOOK LOCK survives. Codex builds from LOCKed masters, so it was drafted here first (old icon kept in `ARCHIVE/`).

## 1. App icon

| Item | Value |
|---|---|
| Background | `#EEF1F0` (LOOK `--bg`), full square, no ring, no gradient, no cross |
| Letter | "S", Cormorant Garamond 600, `#1E2B33` (LOOK `--ink`) |
| Mark | "’", Cormorant Garamond 600, `#C7826B` (LOOK `--warm`) - the mark from the "Selah’" wordmark |
| Geometry (100-unit square) | "S" centred at x 47, baseline y 73, size 78 · "’" centred at x 71, baseline y 45, size 44 |
| Master | `MASTERS/L23_icon_1024.png` (1024×1024, RGB, no transparency, square - the system rounds the corners) |
| Android adaptive | background colour `#EEF1F0`; foreground `MASTERS/L23_icon_android_foreground_1024.png` (transparent, glyph inside the 66% safe zone) |
| Seen | `MASTERS/L23_home_screen.png`, `MASTERS/L23_close_up.png` (home screen · Settings · Notifications sizes) |

## 2. Launch (splash) screen

| Item | Value |
|---|---|
| Background | `#EEF1F0` (same as the app's first screen, so opening is seamless) |
| Content | the wordmark "Selah’" centred - `MASTERS/L23_splash_wordmark_3x.png` (780×240 @3x, transparent; 260×80 pt) |
| Not shown | no spinner (LOOK: no spinners), no tagline, no cross, no version text |
| Dark mode | same light splash (the app has no dark look yet) |
| Master | `MASTERS/L23_splash.png` |

## 2b. Opening hand-over (LOCK 24)

Founder, 11 Nov 2026, after seeing the built launch screen on his iPhone: "yeh there a slapsh screen but very quick like
0.3 seconds so it looks buggy and needs fixing"; then clickable "A · Hold, then fade — LOCK it" (prototype V53, cleaned as V54,
screen "App icon · Opening the app").

| Item | Value |
|---|---|
| First app frame | Shows the launch view again, drawn by the app: `#EEF1F0` full screen, the same wordmark image (`L23_splash_wordmark_3x.png`, 260×80 pt) at the same centre, so the hand-over from the native launch screen is invisible |
| Hold | The wordmark is on screen for **1.0 s** counted from the app's first frame |
| Fade | Then it fades out over **0.45 s** (ease) to reveal the first app screen underneath |
| Still loading | If the first app screen is not ready after 1.0 s, the wordmark stays until it is, then fades |
| Reduce Motion | Same 1.0 s hold, then the wordmark is removed without a fade |
| During the hold | Taps are ignored; screen readers do not announce it (decorative); the first screen underneath is not announced until the fade ends |
| Every launch | Cold start only (app opened from closed). Returning from the background shows no hold |
| Master | Held frame = `MASTERS/L23_splash.png`; behaviour = prototype screen "App icon · Opening the app" |

## 3. Platforms (answers QUESTIONS row 17)

| Platform | Scope |
|---|---|
| iPhone (iOS) | §1 and §2 in full - the app SELAH has today |
| Android | Not built now: `SOURCE/android` does not exist, and creating an Android app is its own decision (new host, manifest, bundle settings), not part of this LOCK. The Android rows of §1 and §2 and the masters `L23_icon_android_foreground_1024.png` / `L23_splash_wordmark_3x.png` stay ready for the brief that adds an Android app, if one is ever approved |

## Must not change
App name "Selah" under the icon (WORDING V1) · bundle ids · the look of every in-app screen.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 23 - Founder: "A · Light — LOCK it" |
| 2026-11-08 | V2 | QUESTIONS row 17 (no Founder decision needed): iOS only; Android waits for a separately approved Android app (none exists). The V1 brief assumed an `android` folder without checking - SELAH chat error. V1 archived |
| 2026-11-11 | V3 | LOCK 24 - Founder: "A · Hold, then fade — LOCK it" (opening hand-over §2b). V2 archived |
