---
id: DOC-SELAH-0069
type: SPEC
status: CURRENT
feature: JOURNEY_STAGES
purpose: The Journey has 7 stages - the "Shepherd support" stage (mentor_gate) leaves what Seekers and Shepherds see, because every Seeker already has a Main Shepherd before any Journey can begin (LOCK 21)
links: [AD-AIOS-129, OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0044, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH JOURNEY STAGES — SPEC — CURRENT VERSION V3 (LOCK 21)

Founder, 6 Nov 2026: "A · 7 stages — LOCK it" (prototype V47, cleaned as V48). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## Founder amendment — 7 Nov 2026 (AD-AIOS-129)

> Founder decision 7 Nov (AD-AIOS-129): the other Main Shepherd's real name is shown only after both Seekers say yes to a Journey - never sold, never part of an unlock. Before that, "<Name>'s Shepherd".

This records the Founder's direct name-rule amendment, not a new LOCK number. It applies to the same two Seekers and their
Journey. Another pair's agreement is never authority to show this name. The original LOCK words, master pictures and
as-built evidence remain historical; this update changes the specs and prototype only, with no app or server build.

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
| Journeys list, My Selah, Seeker profile | "Stage n of 7 · <label>" | L01_seeker_journeys__pending_and_free_place, L01_seeker_my_selah__request, L01_seeker_profile__faith |
| Shepherd Seekers | "Stage n · <label>" as built - no "of 7" (it never showed a total; the master wins) | L01_shepherd_seekers |
| Journey header | "Stage n of 7 · Shepherds: <your Main Shepherd> and <other Shepherd>" - names per §2a | L01_seeker_journey__stages |

### 2a. Main Shepherd names (AD-AIOS-129; supersedes the name rule from QUESTIONS row 15)

The earliest name reveal is when **both Seekers have genuinely said yes to this Journey**, as confirmed by the existing
Journey request/accept flow. It does not wait for readiness, a Greeting, a later stage or Compatibility Reveal. A Shepherd
accepting their own invitation, a Main link, a stage label or a paid grant is not evidence that these two Seekers agreed.

| Case | Name used |
|---|---|
| This pair has not both said yes, or their mutual agreement is not confirmed | "<Name>'s Shepherd"; no real peer Main Shepherd name |
| Both Seekers have said yes to this Journey and the other Main Shepherd's name is available | The other Main Shepherd's real display name, including in an existing admitted Journey fixture |
| Both have said yes but that name is genuinely unavailable | "<Name>'s Shepherd"; never invent a name or borrow one from another Journey |
| Your own Main Shepherd | Their existing display name, unchanged. No Shepherd (SELAH_PAUSE no-Shepherd state) → header is "Stage n of 7" only |

The same rule applies to the offline demo cast and the real app. The draft-only names remain local fixture data
(BROWSE_CARD V5 §3): Grace → "Her mother, Ruth" · Esther → "Pastor Ama Mensah" · Naomi → "Her father, Peter" ·
Abigail → "Her aunt, Teresa". A fixture name alone is not consent: only show it after that fixture pair's genuine mutual
Journey agreement. James's agreement must not reveal Joel's counterpart's Shepherd, or the reverse.

**Never sold; never part of an unlock.** A payment, subscription, Compatibility Unlock or existing paid-name lookup does
not grant name visibility and is never required to see an eligible name. This removes the earlier pricing question about
peer Main Shepherd names; the separate Compatibility Reveal/Unlock product rules are unchanged. Name visibility also grants
no new Journey, profile, View or Chat permission. This documentation amendment defines no new server field, RPC, table or
backend state mapping; the existing Journey agreement flow supplies the evidence.

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
| 2026-11-06 | V2 | QUESTIONS row 15 (no Founder decision needed): §2a Shepherd names with the "<Name>’s Shepherd" fallback; Shepherd Seekers caption keeps "Stage n ·" - V1 wrongly listed it under "of 7" (SELAH chat spec error). V1 archived |
| 2026-11-07 | V3 | Direct Founder amendment AD-AIOS-129: peer Main name only after the same pair both say yes to their Journey; never sold/unlocked; generic before agreement or when unavailable; own Main unchanged. Supersedes the V2 name/pricing rule; V2 archived |
