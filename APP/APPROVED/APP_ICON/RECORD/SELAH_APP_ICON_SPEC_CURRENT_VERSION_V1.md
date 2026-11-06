---
id: DOC-SELAH-0075
type: SPEC
status: CURRENT
feature: APP_ICON
purpose: Selah's app icon and launch (splash) screen in the LOOK - pale water background, Cormorant "S" in ink with the warm mark; splash shows the wordmark only (LOCK 23)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH APP ICON AND SPLASH — SPEC — CURRENT VERSION V1 (LOCK 23)

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

## Must not change
App name "Selah" under the icon (WORDING V1) · bundle ids · the look of every in-app screen.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 23 - Founder: "A · Light — LOCK it" |
