---
id: DOC-SELAH-0029
type: SPEC
status: CURRENT
feature: SELAH_PAUSE
purpose: The Selah pause - SELAH's calm full-screen moment before asking someone to begin a Journey, accepting a request, or ending a Journey (LOCK 7, LOCK 13)
links: [AD-AIOS-129, OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH PAUSE — SPEC — CURRENT VERSION V5 (LOCK 7, LOCK 13)

Founder, 6 Nov 2026: "A · Gentle — LOCK it" (prototype V15, cleaned as V16). New to SELAH - today these three actions
commit at once. Look: LOOK spec V2. ROADMAP row: **SELAH's own identity and private delivery acceptance**.

## Founder amendment — 7 Nov 2026 (AD-AIOS-129)

> Founder decision 7 Nov (AD-AIOS-129): the other Main Shepherd's real name is shown only after both Seekers say yes to a Journey - never sold, never part of an unlock. Before that, "<Name>'s Shepherd".

This records the Founder's direct name-rule amendment, not a new LOCK number. It applies to the same two Seekers and their
Journey. Another pair's agreement is never authority to show this name. The original LOCK words, master pictures and
as-built evidence remain historical; this update changes the specs and prototype only, with no app or server build.

## 1. When it shows
Before the action commits, every time: (a) sending a Journey request, (b) accepting a request, (c) ending a Journey,
(d) accepting a request when the Seeker's Journeys are full (any membership capacity), which ends one of them in the same step (LOCK 13).

**No Shepherd** (a Seeker has removed every Shepherd): a Shepherd is needed in Selah (LOCK 3), so asking, accepting and
Replace do not open a pause - the button shows the toast "Add a Shepherd to request or accept a Journey." and nothing is
sent. Ending is always possible: the End pause shows without its Shepherd sentence (master L07_pause_end__no_shepherd).
No Shepherd name is ever invented.
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
| End | Pause before you end. | Ending your Journey with <Name> closes it for both of you. <Shepherd> will be told and can support you. | End Journey (dawn outline + dawn text) | L07_pause_end |
| Replace (LOCK 13) | Pause before you choose. | Your Journeys are full. Accepting <Name> means ending your Journey with <Ending name>. Your history stays. <Shepherd> will be told, and so will <Ending name>’s and <Name>’s Shepherds. | End and accept (dawn outline + dawn text, as End) | L07_pause_replace |

**Not yet** → back to where you were, nothing sent. **‹ Back** = Not yet.

Replace: the Journey to end is chosen exactly as the app does today, before this pause. This one pause **replaces** the
app's "End Journey & accept request?" box (`_confirmCapacityReplacement` in `lib/dev/selah_one_journey_concept_shell.dart`
and any other takeover path with the same effect) - never two confirmations. The end and the accept happen together or
not at all, as today. Done → Journey tab; My Selah update "You ended your Journey with <Ending name> and accepted <Name>.
Both Shepherds were told."; toast "Journey with <Name> has begun."

### 3a. Name visibility before the action commits (AD-AIOS-129)

The Ask, Accept and Replace pauses are before the new pair's mutual Journey agreement is committed. Their references to
that other Main Shepherd remain generic: "<Name>'s Shepherd" (or the existing generic his/hers wording in the exact copy
above). Do not substitute the peer's real name merely because it exists in a fixture, Main link, request, paid grant or
unlock. Your own <Shepherd> continues to use the existing display name; the no-Shepherd rule stays as built.

Once both Seekers' yes to **this** Journey is confirmed by the existing request/accept flow, the other Main Shepherd's real
name may be shown wherever the existing surface calls for it. That is the earliest reveal: no extra readiness, Greeting,
stage or payment gate. If the name is genuinely unavailable use "<Name>'s Shepherd". Follow JOURNEY_STAGES V3 §2a; another
pair's agreement cannot authorize this name. This does not change the exact pause copy, who is told, existing permissions,
capacity or the action's success/failure rules, and creates no backend state mapping. Names are never sold or part of an unlock.

## 4. States

| State | Master | Look / words |
|---|---|---|
| Sending / ending | L07_pause_ask__sending, L07_pause_end__ending, L07_pause_replace__ending | Primary reads "Sending…" (ask, accept) or "Ending…" (end, replace), 75%, not tappable; Not yet stays |
| Didn't go through | L07_pause_ask__didnt_send | Error bar (LOOK §5) under Back: ask "Your request didn’t send. Try again." · accept "Your answer didn’t send. Try again." · end "Ending didn’t go through. Try again." · replace "That didn’t go through. Nothing has changed. Try again." (master L07_pause_replace__didnt_go_through) + **Try again** |
| Done | – | Leaves the pause; toasts as today's screens already show (e.g. "Request sent to <Name>. <Shepherd> has been told.") |

## Must not change
What each action does, its limits (three Journeys) and who is told · the look · draft boundaries.

## Not decided
A pause for other steps (e.g. Journey stage changes) · whether Shepherds get a pause on their own actions.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 7 - Founder: "A · Gentle — LOCK it" |
| 2026-11-06 | V2 | LOCK 13 - Founder: "Yes — LOCK it" (prototype V27): Replace pause (d) + 2 states, answers QUESTIONS row 5. Also the End body no longer guesses the Shepherd's gender ("will be told and can support you"); L07_pause_end and __ending re-rendered, old ones in ARCHIVE/MASTERS_V1. Accept keeps "hers/his" from the other member's profile. V1 archived |
| 2026-11-06 | V3 | Answers Codex QUESTIONS row 7: no-Shepherd state - ask/accept/Replace blocked with a toast, End pause without the Shepherd sentence; 1 new master. V2 archived |
| 2026-11-06 | V4 | Answers Codex QUESTIONS row 10: Replace wording no longer names a number ("Your Journeys are full.") so it fits every membership; 3 Replace masters re-rendered (old in ARCHIVE/MASTERS_V3). Scope: the offline draft's local path only; retained server takeover paths in Connections are out of scope for line 8 and stay as built. V3 archived |
| 2026-11-07 | V5 | Direct Founder amendment AD-AIOS-129: new-pair peer name stays generic before Ask/Accept/Replace commit; earliest reveal is the same pair's confirmed mutual yes, never payment/unlock; unavailable-name fallback and own Main unchanged. V4 archived |
