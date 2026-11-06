---
id: DOC-SELAH-0069
type: SPEC
status: ARCHIVED
feature: JOURNEY_STAGES
purpose: The Journey has 7 stages - the "Shepherd support" stage (mentor_gate) leaves what Seekers and Shepherds see, because every Seeker already has a Main Shepherd before any Journey can begin (LOCK 21)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0044, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH JOURNEY STAGES — SPEC — V1 (ARCHIVED 2026-11-06) (LOCK 21)

Founder, 6 Nov 2026: "A · 7 stages — LOCK it" (prototype V47, cleaned as V48). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## Why
`lib/data/selah_journey_stages.dart` holds the 8 stages agreed 2026-08-09 for the earlier app. Stage 3, "Shepherd support"
(`mentor_gate`, "Each of you needs a Shepherd beside you before the Journey continues."), waits for something that is always
already true in Selah: since LOCK 3 (Seeker and Shepherd, DOC-SELAH-0044) no Seeker without a Shepherd can send or accept a
request. The stage is a wait with nothing to wait for.

## 1. The stages (what everyone sees)

| # | Stored value | Label | Kind | Change |
|---|---|---|---|---|
| 1 | `greeting_exchange` | First greeting | threshold | none |
| 2 | `compatibility_reveal` | Compatibility Reveal | threshold | none (Compatibility Unlocks are pricing - OA-SELAH-004) |
| 3 | `phase_1` | Faith & Values | sustained | was stage 4 |
| 4 | `phase_2` | Building a Life | sustained | was 5 |
| 5 | `phase_3` | Navigating Life | sustained | was 6 |
| 6 | `family_stage` | Family Compatibility | sustained | was 7 |
| 7 | `conversation` | Open Conversation | destination | was 8 |

Every "Stage n of N" reads **of 7**, numbered from this list. Descriptions, arrival copy, Family Review gates and the
Marriage preparation card (LOCK 9) are unchanged.

## 2. Behaviour

| Case | What happens | Master |
|---|---|---|
| Compatibility Reveal → Continue | The Journey goes straight to Faith & Values. No Shepherd screen in between | L01_seeker_journey__stages |
| A Journey already stored at `mentor_gate` | Shown as stage 3 of 7, Faith & Values, and moved on in the background when either Seeker opens it. If that fails: the existing "That didn't save. Try again." state | L09_marriage_prep__didnt_save (state pattern) |
| Journeys list, My Selah, Seeker profile, Shepherd Seekers | "Stage n of 7 · <label>" | L01_seeker_journeys__pending_and_free_place, L01_seeker_my_selah__request, L01_seeker_profile__faith, L01_shepherd_seekers |
| Journey header | "Stage n of 7 · Shepherds: <both Main Shepherds>" - the couple sees each other's Shepherds from the start | L01_seeker_journey__stages |

**Removed with the stage:** the Shepherd Gate screen, its mutual "reveal your Shepherds" step and the optional Shepherd
greetings at that stage; any Shepherd Dashboard or roster item that said a Journey was waiting at the Shepherd stage.

## Must not change
Compatibility Reveal and Compatibility Unlocks (pricing, OA-SELAH-004) · Family Review 48-hour gates · Shepherd Circle ·
Marriage preparation (LOCK 9) · look · draft boundaries. Server tables and functions are not changed by this spec.

## Not decided (server - OA-SELAH-002, via Fable)
Removing `mentor_gate` from `selah_advance_stage()`'s map and from the `matches.journey_stage` CHECK constraint, and moving
stored rows on. Until then the app passes through it (section 2).

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 21 - Founder: "A · 7 stages — LOCK it" |
