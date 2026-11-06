---
id: DOC-SELAH-0066
type: SPEC
status: CURRENT
feature: SHEPHERD_DASHBOARD
purpose: The Shepherd Dashboard - prayer requests, what needs the Shepherd, gentle check-ins from Journey stages, updates; family snapshot and paid family-process insights removed (LOCK 20)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0038, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH SHEPHERD DASHBOARD — SPEC — CURRENT VERSION V1 (LOCK 20)

Founder, 6 Nov 2026: "B · With gentle check-ins — LOCK it" (prototype V45, cleaned as V46). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

Today `lib/screens/mentor/mentor_dashboard_screen.dart` shows PRAYER REQUESTS (LOCK 10) · RIGHT NOW · FAMILY SNAPSHOT
("YOUR FAMILY", repeats the Seekers tab) · SHEPHERD INSIGHTS (family-process insights, locked behind "Upgrade to unlock …
Shepherd One") · UPDATES.

## 1. Order (top to bottom)

| # | Section | Content | Master |
|---|---|---|---|
| 1 | Title | Wordmark row with "Shepherd"; title "Dashboard" (as built) | L10_shepherd_dashboard__* |
| 2 | PRAYER REQUESTS | LOCK 10, unchanged | L10_* |
| 3 | NEEDS YOU | Replaces "RIGHT NOW": only things a Shepherd can act on from the existing priorities (e.g. a request a Seeker has not answered: "<Requester> asked <Seeker> to begin" / "He hasn’t answered yet. A word from you may help." + ghost **Encourage** → that Seeker's Shepherd Circle). Empty: "Nothing needs you right now." | L20_dashboard__check_in, __nothing_needs_you |
| 4 | A GOOD TIME TO CHECK IN | One card per Journey stage change in the last 7 days among the Shepherd's Seekers (newest first, up to 3): "<Seeker> and <Name> reached <Stage>" / "Ask how it’s going, or pray for them this week." + ghost **Message <Seeker>** → Shepherd Circle. None → section not shown | L20_dashboard__check_in |
| 5 | UPDATES | As built | L20_* |
| 6 | Note | "Seekers you walk with can ask you for prayer. They see when you have prayed." (as LOCK 10) | L20_* |

**Removed:** FAMILY SNAPSHOT / YOUR FAMILY card, SHEPHERD INSIGHTS (including the locked "Upgrade to unlock" card and its
action). The Seekers tab keeps everything the snapshot pointed to.

## 2. States
Needs you empty (master) · check-ins none (section hidden) · existing loading / "UPDATES UNAVAILABLE" / "PRIORITIES UNAVAILABLE"
states stay as built, re-labelled "Needs you" where they said "Right now".

## Must not change
Prayer requests (LOCK 10) · Introduce, Seekers, Profile tabs · look · draft boundaries. Membership catalogue untouched (pricing is OA-SELAH-004).

## Not decided
Check-ins for events other than stage changes · how long a check-in stays.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 20 - Founder: "B · With gentle check-ins — LOCK it" |
