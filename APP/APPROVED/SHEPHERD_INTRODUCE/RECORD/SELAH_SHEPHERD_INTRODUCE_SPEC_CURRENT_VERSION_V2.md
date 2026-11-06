---
id: DOC-SELAH-0063
type: SPEC
status: CURRENT
feature: SHEPHERD_INTRODUCE
purpose: The Shepherd's Introduce tab - a Shepherd suggests someone to their own Seeker, who decides; replaces the guardian matchmaking Network (LOCK 19)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH SHEPHERD INTRODUCE — SPEC — CURRENT VERSION V2 (LOCK 19)

Founder, 6 Nov 2026: "A · Shepherds suggest — LOCK it" (prototype V43, cleaned as V44). Look: LOOK spec V2.
ROADMAP row: **SELAH's own identity and private delivery acceptance**.

Today `lib/screens/mentor/mentor_network_screen.dart` ("Network") lets a Shepherd browse "families" and send requests to
other Seekers' Main Shepherds, with request caps ("Selah is choosing the next family…", "Request limit reached"). That
is removed from the member app. SELAH keeps the existing **Introductions** idea (My Selah "People put forward by your
Shepherds") and makes it the Shepherd's tab.

## 1. Shepherd tabs
Dashboard · **Introduce** · Seekers · Profile (tab icon as Network today). Every Shepherd master shows this bar.

## 2. Introduce (masters L19_introduce, __for_joel)

| Part | Words / look |
|---|---|
| Title | "Introduce" |
| Line | Know someone who might be right for one of your Seekers? Suggest them. Your Seeker decides - nothing is sent to the other person or their Shepherd. |
| Seeker pills | "For <Seeker first name>" for each linked Seeker (one chosen; first by default) |
| Card | One person at a time, as the Browse card content: photo, "<Name>, <age>", city, faith chips, marriage line (BROWSE_CARD V4), own-words quote. People come from the same discovery list the chosen Seeker would see (same rules - nobody they already have a Journey or request with) |
| Buttons | Ghost "Not for <Seeker>" (next person) · primary "Suggest to <Seeker>" → toast "Suggested <Name> to <Seeker>. <Seeker> decides." and the next person |

## 3. The Seeker sees it (master L19_my_selah__suggestion)
Top of My Selah: label "FROM YOUR SHEPHERD", card: photo · "<Name>, <age>" · "<Shepherd display name> thinks you might like to meet <Name>."
Buttons: ghost "Not now" (removes it; toast "Noted. <Shepherd> won’t be told why.") · primary "See <Name>" (opens Browse on that person; the Seeker then uses Request a Journey and the LOCK 7 pause as normal). The Shepherd is never told the Seeker's answer.

## 4. States (rule 11)

| State | Master | Words |
|---|---|---|
| Suggesting | L19_introduce__suggesting | "Suggesting…" 75%, not tappable |
| Didn't send | L19_introduce__didnt_send | Error bar "Your suggestion didn’t send. Try again." + **Try again** |
| No one new | L19_introduce__no_one_new | Breath mark; "No one new to suggest for <Seeker>" / "New people join every week. Come back soon." |
| No linked Seeker | (as built) | Existing "Link a Seeker first" state, unchanged |

## 5. Scope and draft data (answers QUESTIONS row 16)

| Item | Rule |
|---|---|
| Where it works | The offline draft only (same rule as SELAH_PAUSE V4 for Replace). A suggestion is one record in one same-account local Introductions collection, using the existing ShepherdSuggestion DTO and its existing read / markSeen. No new table, store, RPC or backend call |
| Real app (HomeShell) | Stays exactly as built - Network and its retained paths unchanged, no new "unavailable" state - until a backend brief (OA-SELAH-002) adds a create service and retires family requests together |
| Joel (draft fixture) | Joel Martins, 28 (BROWSE_CARD V4 §3 cast), draft-only local Seeker whose Main Shepherd is Pastor David. No Journeys, no requests sent or received, nothing hidden or blocked, the draft's default Browse preferences for a new Seeker. Nothing is copied from James's private data |
| Joel's candidates | The draft women cast through the same discovery rules as any Seeker; first card Grace (master L19_introduce__for_joel), then cast order |

## Must not change
Seekers tab, Dashboard (incl. LOCK 10 prayer requests), Shepherd Profile · Seeker's own Browse and request flow · look · draft boundaries. Server-side family-request code stays as built (not reachable from the app) until a backend brief (OA-SELAH-002).

## Not decided
How many suggestions a Shepherd can make · a Shepherd suggesting to an Additional Shepherd's Seeker.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 19 - Founder: "A · Shepherds suggest — LOCK it" |
| 2026-11-06 | V2 | QUESTIONS row 16: §5 scope (offline draft; real app as built until OA-SELAH-002) and the Joel fixture. V1 archived |
