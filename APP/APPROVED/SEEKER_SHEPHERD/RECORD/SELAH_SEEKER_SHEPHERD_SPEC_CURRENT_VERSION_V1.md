---
id: DOC-SELAH-0044
type: SPEC
status: CURRENT
feature: SEEKER_SHEPHERD
purpose: The Seeker's Shepherd tab - the Main Shepherd shown first as a person (Ask for prayer, Message, what he has done lately), then the app's existing Shepherd sections (LOCK 12)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0038, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH SEEKER SHEPHERD TAB — SPEC — CURRENT VERSION V1 (LOCK 12)

Founder, 6 Nov 2026: "B · Main Shepherd first — LOCK it" (prototype V25, cleaned as V26). Look: LOOK spec V2.
ROADMAP row: **Christian content and production experience**.

Built today in `lib/screens/mentor/seeker_mentor_tab.dart` and `seeker_shepherd_designs.dart` (ShepherdshipManagerView,
_ManagerShepherdCard, _MainShepherdJourneyAccess). This LOCK **reorders and re-presents** what is there. It adds no new
system: no new chat, no new permission model, no new data store.

## 1. Order of the tab (top to bottom)

| # | Section | What it shows | Master |
|---|---|---|---|
| 1 | Title | "My Shepherd" (Cormorant, as LOOK V2 screen titles) | L12_..._top |
| 2 | Main Shepherd card | Photo · name (600) · one line "<Role> · walking with you since <Month>" · pill "Main Shepherd". Buttons: **Ask for prayer** (primary, from LOCK 10) · **Message** (ghost). Second row: **Manage** (ghost, full width) | L12_..._top |
| 3 | RECENTLY FROM <SHEPHERD FIRST NAME> | Up to 3 lines, newest first, from data the app already has: "Prayed for you" / "Prayed for your Journey with <Name>" (LOCK 10 "I prayed") and the Main Shepherd's latest messages in Your Shepherd Circle (quoted). Each line ends " · <Yesterday / weekday / date>" | L12_..._top |
| 4 | ADDITIONAL SHEPHERDS | As built: each Additional Shepherd (name, role, "Supports you with your Journey.") with **Manage**; then **Add a Shepherd** | L12_..._top / _bottom |
| 5 | JOURNEY ACCESS | As built: per active Journey "Journey with <Name>" + "View is required for each active Journey." + View pill; **Chat** switch "<Shepherd> can join the chat for this Journey." | L12_..._bottom |
| 6 | PAST JOURNEY SUMMARIES | As built: "Share past Journey summaries" switch, line "Names, messages, answers and notes are never included." | L12_..._bottom |

## 2. Buttons

| Button | Opens |
|---|---|
| Ask for prayer | LOCK 10 page (PRAYER spec V2 §1) - unchanged |
| Message | **Your Shepherd Circle** - the existing chat (`family_messaging_screens.dart`). The app has no one-to-one Shepherd chat and none is built. The separate "Shepherd Circle" button on today's Main Shepherd card is removed so there is one way in |
| Manage | Today's Main Shepherd actions as built (Make Main Shepherd / Remove as Main Shepherd / Remove Shepherd) |

The Main Shepherd appears **once** (no separate "MAIN SHEPHERD" section below the card).

## 3. States (rule 11)

| State | Master | Words |
|---|---|---|
| Nothing from the Shepherd yet | L12_seeker_shepherd_tab__nothing_yet | "Nothing yet. When <Shepherd first name> prays for you or sends a message, it shows here." |
| Journey access loading | L12_seeker_shepherd_tab__access_loading | "Loading Journey access…" (muted, inside the card) |
| Journey access didn't load | L12_seeker_shepherd_tab__access_didnt_load | Error bar "Journey access didn’t load." + **Try again** |
| No active Journeys | L12_seeker_shepherd_tab__no_active_journeys | "No active Journeys. Access is set when one begins." |
| Shepherd not yet accepted | (LOCK 3 masters, unchanged) | LOCK 3 waiting screen |

Today's caps labels (LOADING JOURNEY ACCESS, JOURNEY ACCESS UNAVAILABLE, NO ACTIVE JOURNEYS) are replaced by these words.

## 4. Relation to other LOCKs
- **PRAYER V1 (LOCK 10)** said the rest of this tab stays as built. LOCK 12 now decides the rest of the tab; line 11 builds
  first as written, line 13 then reorders the tab around its button.
- **WORDING V1 (LOCK 11)**: "Selah" in text; this tab uses no request wording.
- Demo names: Main Shepherd from the existing cast (Pastor David Okafor); Additional Shepherd demo "Mark Carter" replaces
  leftover demo names on this tab.

## Must not change
Permission rules (View required per active Journey; Chat depends on Journey availability) · Make/Remove Main Shepherd
behaviour · Add a Shepherd flow (LOCK 3) · Shepherd Circle chat itself · look · draft boundaries.

## Not decided
Shepherd's own view of what the Seeker shares · reminders · showing more than 3 recent lines.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 12 - Founder: "B · Main Shepherd first — LOCK it". Message opens Your Shepherd Circle (no new chat); duplicate Shepherd Circle button removed (flagged to Founder same session) |
