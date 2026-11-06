---
id: DOC-SELAH-0009
type: SPEC
status: ARCHIVED (2026-11-03, replaced by SELAH_LOOK_SPEC_CURRENT_VERSION_V2.md)
feature: LOOK
purpose: SELAH's own look (LOCK 1, Still Water) - colours, type, shapes and the docked tab bar every SELAH screen uses
links: [OA-SELAH-003, OA-AIOS-414, AD-AIOS-123]
owner: SELAH chat
---

# SELAH LOOK — SPEC — 2026-11-03 — V1 (ARCHIVED)

Founder, 3 Nov 2026: "A · Still Water — LOCK it". Prototype V4 (`../../PROTOTYPE/selah-prototype.html`).
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

**What this LOCK covers:** the look only - colours, fonts, sizes, shapes, the wordmark and a docked tab bar - applied to the
screens SELAH already has. **It does not cover features.** The masters also show designs that are not locked yet (Selah
pause, prayer, Shepherd permissions, Marriage preparation stage, Shepherd's Prayer tab, demo people). They are there to
show the look; they are **not** to be built under this LOCK.

## 1. Colours (one light theme)

| Token | Hex | Use |
|---|---|---|
| mist (page) | `#EEF1F0` | Screen background |
| surface | `#FFFFFF` | Cards, tab bar, icon buttons |
| ink | `#1E2B33` | Main text, titles |
| muted | `#5E6C72` | Secondary text, labels, inactive tab |
| line | `#D5DCDC` | 1 px card borders, dividers, ghost-button borders, switch off |
| lake (accent) | `#3E6B78` | Primary buttons, active tab, progress, switch on, links ("‹ Back") |
| on-lake | `#FFFFFF` | Text on lake |
| soft | `#DCE7E8` | Chips, avatar circles, tags, Selah pause background |
| dawn | `#C7826B` | The breath mark ’ in the wordmark and empty states; "End Journey" outline and text |

No purple, gold, gradients, glass or glow anywhere. No shadows on cards.

## 2. Type

| Role | Font | Weight | Size (logical px) |
|---|---|---|---|
| Wordmark "Selah’" | Cormorant Garamond | 600 | 36, letter-spacing 0.02em; ’ in dawn at 0.9× |
| Page title (Journeys, My Selah…) | Cormorant Garamond | 600 | 33.6, line-height 1.1 |
| Member name on Browse | Cormorant Garamond | 600 | 36, line-height 1 |
| Quote / member's own words | Cormorant Garamond | 600 italic | 22.8, line-height 1.35 |
| Pause heading | Cormorant Garamond | 600 | 48, line-height 1.05 |
| Body | Figtree | 400 | 15, line-height 1.5 |
| Small / secondary | Figtree | 400 | 13 |
| Row title | Figtree | 600 | 15 |
| Section label | Figtree | 600 | 11, uppercase, letter-spacing 0.12em, muted |
| Button | Figtree | 600 | 15 (small button 13.5) |
| Chip | Figtree | 500 | 12.5 |
| Tab label | Figtree | 500 | 11 |

Both fonts are SIL Open Font License; bundle the .ttf files with their OFL text (no runtime fetching).

## 3. Shapes and spacing

| Item | Value |
|---|---|
| Side padding | 22 |
| Gap between blocks | 14 |
| Card | surface, 1 px line border, radius 14, padding 16, no shadow |
| Button (primary) | lake fill, white text, radius 12, padding 15 × 18 |
| Button (ghost) | transparent, ink text, 1 px line border, radius 12 |
| Button (small) | padding 10 × 14 |
| Chip | soft fill, ink text, radius 12, padding 7 × 10 |
| Main photo | radius 18, fills the free height; photo bars at top: 28 × 3, white 50% / white |
| List thumbnail | 56 × 56, radius 18 |
| Icon button | 40 × 40, surface, 1 px line, radius 12 |
| Switch | 46 × 28, lake when on, line when off |
| Progress bar | 5 high, radius 3, lake on line |

## 4. Docked tab bar (replaces the floating bar)

| Item | Value |
|---|---|
| Position | Flat, full width, fixed to the bottom edge; not floating, no pill, no blur |
| Background / top edge | surface, 1 px line on top |
| Padding | 8 top, 6 sides, 26 bottom (home-indicator space) |
| Item | icon 23 px outline (stroke 1.7; 2.2 when active) over label 11 px, gap 4 |
| Colours | inactive muted; active lake |
| Seeker tabs (as today) | Browse · Journey · My Selah · Shepherd · Profile |
| Shepherd tabs | keep today's tabs and names; only the look changes |

## 5. Masters (`../MASTERS/`, 1290 × 2796)

| Master | Shows the look of |
|---|---|
| L01_seeker_browse__profile | Wordmark, photo, name, chips, quote, buttons, tab bar |
| L01_seeker_journeys__pending_and_free_place | Cards, thumbnails, progress |
| L01_seeker_journeys__empty | Empty state (breath mark, text, button) |
| L01_seeker_journey__stages | Step list, ghost/dawn and primary buttons |
| L01_seeker_my_selah__request | Section labels, list rows |
| L01_seeker_profile__faith | Profile card, key/value rows |
| L01_seeker_shepherd__permissions | Switches *(screen content not locked)* |
| L01_seeker_ask_for_prayer | Options, text field *(screen not locked)* |
| L01_seeker_pause__before_asking | Large heading on soft *(screen not locked)* |
| L01_shepherd_seekers, L01_shepherd_prayer | Shepherd side in the same look *(content not locked)* |

## Must not change
- What each screen does, its words and its flows (look only).
- The draft boundaries in `SELAH/AGENTS.md` (no backend, HTTP denied, release refuses the draft).
- ZYRA - nothing in ZYRA is touched.

## Not decided (later LOCKs)
Dark mode · loading and error states · iPad layout · Larger Text frames · app icon · Selah pause · prayer · Shepherd
permissions · Marriage preparation stage · onboarding · faith questions · Christian demo cast.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-03 | V1 | LOCK 1 - Founder: "A · Still Water — LOCK it" (prototype V4) |
