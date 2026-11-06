---
id: DOC-SELAH-0029
type: SPEC
status: ARCHIVED
feature: SELAH_PAUSE
purpose: The Selah pause - SELAH's calm full-screen moment before asking someone to begin a Journey, accepting a request, or ending a Journey (LOCK 7)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH PAUSE — SPEC — V1 (ARCHIVED 2026-11-06) (LOCK 7)

Founder, 6 Nov 2026: "A · Gentle — LOCK it" (prototype V15, cleaned as V16). New to SELAH - today these three actions
commit at once. Look: LOOK spec V2. ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## 1. When it shows
Before the action commits, every time: (a) sending a Journey request, (b) accepting a request, (c) ending a Journey.
Where the app already has its own confirmation for one of these, the pause **replaces** it (never two confirmations).

## 2. Layout (full screen, no tab bar)
Background soft `#DCE7E8`; padding 20 top, 26 sides/bottom; three blocks spaced between: top ("‹ Back" lake 15 px;
dawn breath mark ’ Cormorant 120 px), middle (label "SELAH"; heading Cormorant 600 48 px; body 15 px; 4 px breath bar
filling lake over 6 s ease-in-out once, full at once with Reduce Motion; muted 13 px line "Take a breath. Pray if you wish."),
bottom (primary button; ghost **Not yet**). Gentle: both buttons work at once.

## 3. Words (exact; <Name> = the other member's first name; <Shepherd> = your Shepherd as shown on your Shepherd tab)

| Kind | Heading | Body | Primary | Master |
|---|---|---|---|---|
| Ask | Pause before you ask. | Asking <Name> to begin a Journey is a serious step toward marriage. <Shepherd> will see this request, and so will <Name>’s Shepherd. | Send request | L07_pause_ask |
| Accept | Pause before you accept. | Accepting <Name> starts a Journey. Your Shepherd and hers will both walk with you. (his/hers by the other member's profile) | Accept and begin | L07_pause_accept |
| End | Pause before you end. | Ending your Journey with <Name> closes it for both of you. <Shepherd> will be told so he can support you. (he/she by the Shepherd) | End Journey (dawn outline + dawn text) | L07_pause_end |

**Not yet** → back to where you were, nothing sent. **‹ Back** = Not yet.

## 4. States

| State | Master | Look / words |
|---|---|---|
| Sending / ending | L07_pause_ask__sending, L07_pause_end__ending | Primary reads "Sending…" (ask, accept) or "Ending…" (end), 75%, not tappable; Not yet stays |
| Didn't go through | L07_pause_ask__didnt_send | Error bar (LOOK §5) under Back: ask "Your request didn’t send. Try again." · accept "Your answer didn’t send. Try again." · end "Ending didn’t go through. Try again." + **Try again** |
| Done | – | Leaves the pause; toasts as today's screens already show (e.g. "Request sent to <Name>. <Shepherd> has been told.") |

## Must not change
What each action does, its limits (three Journeys) and who is told · the look · draft boundaries.

## Not decided
A pause for other steps (e.g. Journey stage changes) · whether Shepherds get a pause on their own actions.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 7 - Founder: "A · Gentle — LOCK it" |
