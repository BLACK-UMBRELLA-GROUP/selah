---
id: DOC-SELAH-0038
type: SPEC
status: ARCHIVED
feature: PRAYER
purpose: SELAH prayer requests - a Seeker asks their Shepherd for prayer; the Shepherd sees requests at the top of the Dashboard and taps "I prayed"; the Seeker sees it (LOCK 10)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH PRAYER — SPEC — V1 (ARCHIVED 2026-11-06) (LOCK 10)

Founder, 6 Nov 2026: "A · On the Dashboard — LOCK it" (prototype V21, cleaned as V22). New to SELAH - the app has no
prayer feature today. Look: LOOK spec V2. ROADMAP row: **Christian content and production experience**.

## 1. Seeker: Ask for prayer
Entry: a primary **Ask for prayer** button on the Seeker's Shepherd tab, beside the Shepherd's card (the rest of that tab
stays as built). Opens a page (master L10_seeker_ask_for_prayer):

| Part | Text |
|---|---|
| Header / title | "‹ Back" · "Ask for prayer" |
| Line | <Shepherd> will see this and pray for you. |
| Three suggestions (option rows, one chosen at a time, first chosen by default) | For wisdom in my Journey with <Name of an active Journey, else "my Journey"> · For patience while I wait · For my family to be at peace with my choice |
| Text box | placeholder "Or write your own" (own text wins over the chosen suggestion) |
| Button | Send to <Shepherd> |

Sent → back to the Shepherd tab; toast "Sent. <Shepherd> will pray for you."; My Selah update "You asked <Shepherd> for prayer."

## 2. Shepherd: Dashboard (tabs unchanged: Dashboard · Network · Seekers · Profile)
Top of the Dashboard, before its existing content: label "PRAYER REQUESTS", card listing each request (newest first):
Seeker's first name (600) · request text · "<n> prayed"; button **I prayed** (primary) → becomes **Prayed** (ghost),
count +1, toast "<Seeker> will see that you prayed." Under the card, muted: "Seekers you walk with can ask you for prayer.
They see when you have prayed." (masters L10_shepherd_dashboard__requests / __prayed)

## 3. Seeker sees it
My Selah → Updates gets "<Shepherd> prayed for you." (master L10_seeker_my_selah__prayed_update shows the updates card).

## 4. States

| State | Master | Words |
|---|---|---|
| No requests (Shepherd) | L10_shepherd_dashboard__no_requests | "No prayer requests right now. When <Seeker names> ask you to pray, they’ll show here." |
| Sending | L10_seeker_ask_for_prayer__sending | Button "Sending…", 75%, not tappable |
| Didn't send | L10_seeker_ask_for_prayer__didnt_send | Error bar: "Your prayer request didn’t send. Try again." + **Try again** |

## Must not change
Shepherd tabs and the rest of the Dashboard, Network, Seekers, Profile · the Seeker's Shepherd tab apart from the button ·
look · draft boundaries. The prototype's other Shepherd-tab content (permissions, "Last from") is **not** part of this LOCK.

## Not decided
Prayer request privacy beyond the Seeker's own Shepherds · deleting a request · reminders.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 10 - Founder: "A · On the Dashboard — LOCK it" |
