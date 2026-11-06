---
id: DOC-SELAH-0014
type: SPEC
status: ARCHIVED (2026-11-06, replaced by SELAH_SHEPHERD_INVITE_SPEC_CURRENT_VERSION_V4.md)
feature: SHEPHERD_INVITE
purpose: How a new SELAH Seeker invites their Shepherd at sign-up, what they can do while waiting, and how the Shepherd accepts (LOCK 3)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH SHEPHERD INVITE — SPEC — CURRENT VERSION V3 (LOCK 3, updated by LOCKs 4 and 6)

Founder, 4 Nov 2026: "A · Browse while waiting — LOCK it" (prototype V6, cleaned as V7). Founder rule, 3 Nov: "I DONT WANT IT
TO BE A DATING APP SO I THINK A SHEPARD IS NEEDED" - every Seeker has a Shepherd. Look: LOOK spec V2 (DOC-SELAH-0009).
ROADMAP row: **SELAH's own identity and private delivery acceptance** (Shepherd and onboarding flows).

Replaces, for the Seeker, the copied code-and-scan link ("Enter code" / "Scan SELAH Code" / "How are you related?").

## 1. Flow

| # | Screen | Master | Words (exact) | Actions |
|---|---|---|---|---|
| 1 | Welcome | L03_signup_welcome | Wordmark "Selah’" (44 px); label "WELCOME"; heading "No one should walk toward marriage alone."; body "Selah means pause. Here you take each step slowly, with a Shepherd you trust beside you."; footnote "Asked to be someone’s Shepherd? Open the invite in your message." | **Begin** → 2 |
| 2 | Who will walk with you? | L03_signup_choose__empty / __selected | "‹ Back" · "Step 1 of 2"; title "Who will walk with you?"; body "Your Shepherd encourages you, prays for you and sees each request you send or receive. Choose someone who knows you and your faith."; six choices: Parent · Pastor · Mentor · Church elder · Family member · A mature Christian friend (one only) | **Continue** → 3; Back → 1 |
| 2e | – no choice | L03_signup_choose__error | Under the list, dawn 13 px: "Choose who your Shepherd is." | Clears on choosing |
| 3 | Invite your Shepherd | L03_signup_invite | "‹ Back" · "Step 2 of 2"; title "Invite your Shepherd"; field label "THEIR NAME"; card "WHAT YOUR SHEPHERD WILL SEE": ✓ Every request you send or receive · ✓ Which stage each Journey is at · ✓ Prayer requests you share · ✕ Your private messages; note "They get a message with a link. They don’t need to be looking for marriage themselves. You can add another Shepherd later." | **Send invite by message** (primary) → 4; **Copy invite link** (ghost) → 4 + toast "Invite link copied." |
| 3e | – no name | L03_signup_invite__name_error | Under the field: "Enter your Shepherd’s name." | Clears on next try |
| 3s | – sending | L03_signup_invite__sending | Primary button reads "Sending…", 75% opacity, not tappable; Copy link hidden | – |
| 3f | – didn't send | L03_signup_invite__failed | Error bar (LOOK §5) at top: "Your invite didn’t send. Try again." + **Try again** | Try again = Send again |
| 4 | Invite sent | L03_signup_sent | Selah pause layout (soft background, dawn ’); label "INVITE SENT"; heading "<First name> has your invite."; body "You can look around Selah now. You can ask or accept once <First name> says yes." | **Continue** → consent screen (CONSENT spec V1, LOCK 6) → faith questions → marriage questions → Browse (state "waiting"); Back → 3 |

## 2. While waiting (option A)

| Where | Master | What changes |
|---|---|---|
| Browse | L03_seeker_browse__waiting_for_shepherd | Soft bar above the photo: initial circle + "Waiting for <First name> to accept. You can ask once they say yes."; the primary button reads **Ask later** and only shows toast "You can ask once <First name> accepts your invite." |
| My Selah → Accept on a request | (L01 my_selah master) | Accept shows toast "You can accept once <First name> accepts your invite."; nothing else changes |
| Shepherd tab | L03_seeker_shepherd__invite_pending | Card: initial circle 64 px, full name, "Invite sent · waiting for a yes", **Remind <First name>** and **Copy link again** (ghost); card "ONCE <FIRST NAME> SAYS YES, THEY WILL SEE" with the same 4 rows as screen 3; footnote "A Shepherd is needed in Selah. Until <First name> accepts, you can’t send or accept a request." |
| Everything else | – | Usable as normal (Journey, Profile, filters) |

When the Shepherd accepts: the waiting bar goes, **Ask to begin** returns, Shepherd tab shows the normal linked Shepherd card, and an update reads "<Full name> accepted. Your Shepherd walks with you now."; toast "<First name> said yes. You can ask and accept now."

## 3. The Shepherd's side

| Screen | Master | Words (exact) | Actions |
|---|---|---|---|
| Be <Seeker>’s Shepherd? | L03_shepherd_invitation | Title "Be James’s Shepherd?"; Seeker card (photo, "James, 31", "Asked you as his pastor" - the chosen relation); card "AS HIS SHEPHERD YOU WILL": ✓ Walk with him toward marriage · ✓ See every request he sends or receives · ✓ See which stage each Journey is at · ✓ Receive the prayer requests he shares · ✕ You won’t see his private messages; note "You don’t need a profile of your own or be looking for marriage. You can step back at any time." | **Accept** → Shepherd home + toast "You are now James’s Shepherd."; **Not now** → back + toast "James will be told kindly. You can accept later from the message." |

Pronouns follow the Seeker's profile (his/her).

## 4. Rules
- One Shepherd is needed before a Seeker can send or accept a request. More can be added later (existing plan limits unchanged).
- Choices on screen 2 are a closed list of six; no free text.
- In this offline draft nothing is really sent: Send / Copy link go straight to screen 4 locally; "sending", "didn't send" and "Shepherd accepts" are reached through the private developer controls (like the other demo steps), never shown to members.

## Must not change
Look (LOOK V2) · Browse, Journey, My Selah behaviour other than §2 · Shepherd permissions on the Shepherd tab once linked · the code screen's other uses (Find by code, a Shepherd inviting a Seeker, mentor link) · draft boundaries in `SELAH/AGENTS.md`.

## Not decided (later LOCKs)
Real invite delivery (OA-SELAH-002) · reminders schedule · what happens if the Shepherd declines (beyond the toast) · adding a second Shepherd screen · faith profile and onboarding questions · identity verification step.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-04 | V1 | LOCK 3 - Founder: "A · Browse while waiting — LOCK it" |
| 2026-11-06 | V2 | LOCK 4 (Founder 4 Nov: "A · One per screen — LOCK it"): Invite sent → Continue now opens the faith questions. V1 archived |
| 2026-11-06 | V3 | LOCK 6 (Founder 6 Nov: "Yes — LOCK it"): Invite sent → Continue opens the consent screen. V2 archived |
