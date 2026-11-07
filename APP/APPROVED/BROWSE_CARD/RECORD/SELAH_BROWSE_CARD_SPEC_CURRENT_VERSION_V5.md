---
id: DOC-SELAH-0032
type: SPEC
status: CURRENT
feature: BROWSE_CARD
purpose: What a profile card shows on SELAH's Browse (faith chips only), the "no one new" state, and SELAH's own demo cast replacing ZYRA's (LOCK 8)
links: [AD-AIOS-129, OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0017, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH BROWSE CARD — SPEC — CURRENT VERSION V5 (LOCK 8, updated by LOCK 11)

Founder, 6 Nov 2026: "A · Faith chips only — LOCK it" (prototype V17, cleaned as V18). Look: LOOK spec V2. Faith answers:
FAITH_PROFILE spec. ROADMAP rows: **SELAH's own identity and private delivery acceptance** and **Christian content and production experience**.

## Founder amendment — 7 Nov 2026 (AD-AIOS-129)

> Founder decision 7 Nov (AD-AIOS-129): the other Main Shepherd's real name is shown only after both Seekers say yes to a Journey - never sold, never part of an unlock. Before that, "<Name>'s Shepherd".

This records the Founder's direct name-rule amendment, not a new LOCK number. It applies to the same two Seekers and their
Journey. Another pair's agreement is never authority to show this name. The original LOCK words, master pictures and
as-built evidence remain historical; this update changes the specs and prototype only, with no app or server build.

## 1. Chips on the card (in this order, nothing else)

| Chip | From faith answer | Text |
|---|---|---|
| 1 | Church tradition | The tradition as answered (e.g. "Anglican", "Non-denominational"); "Another tradition" shows the member's own denomination text if given, else no chip |
| 2 | How often at church | Every week → "Church weekly" · Most weeks → "Church most weeks" · Sometimes → "Church sometimes" · Rarely right now → no chip |
| 3 | Baptised | Yes → "Baptised" · Not yet → "Not yet baptised" · I'd rather not say → no chip |

**Removed from the card:** nationality and ethnicity chips (they stay on the full profile where the member chose to show them).
Under the chips (LOCK 16): one muted 13 px line from the marriage answers - married before · children · would like children, joined by " · ": No → "Never married", Yes, divorced → "Divorced", Yes, widowed → "Widowed", Yes, annulled → "Annulled", I’d rather share later → left out; children No → "No children", either Yes → "Has children"; would like children Yes → "Would like children", Open to it → "Open to children", No → "Doesn’t want children", Not sure yet → "Not sure about children". Unanswered parts are left out; nothing answered → no line (MARRIAGE_VALUES spec V7, masters L08_* re-rendered, L16_browse_card__share_later).

A member who skipped the faith questions (consent) shows no chips. The quote under the chips is "Your faith, in your own
words" (FAITH_PROFILE q7); none given → no quote. Everything else on the card (photo, name block, Shepherd line, buttons)
stays as built; the main button reads **Request a Journey** (WORDING spec V1). Masters re-rendered with it (old in `ARCHIVE/MASTERS_V1/`).

### 1a. Other Main Shepherd name (AD-AIOS-129)

The existing Shepherd line follows JOURNEY_STAGES V3 §2a. Before both Seekers have genuinely said yes to a Journey with
each other, or where that agreement is not confirmed, show "<Name>'s Shepherd". A Browse visit, suggestion, request sent by
one person, Main link or paid/unlock entitlement does not reveal the other Main Shepherd's real name. After this same
pair's confirmed mutual yes, use the real display name when available; if it is unavailable keep "<Name>'s Shepherd".
The earliest reveal is that mutual agreement, not readiness, a Greeting or a later stage. No name is sold or included in an
unlock. Own Main Shepherd display is unchanged. Do not change discovery eligibility or add a Journey card to demonstrate
this rule; the cast names below are local data, not permission to disclose them before agreement.

## 2. States (masters)

| State | Master |
|---|---|
| Cards | L08_browse_card__grace / __esther / __naomi / __abigail |
| No one new | L08_browse__no_one_new - breath mark ’; "You’ve seen everyone for now"; "New people join every week. Check back soon, or widen who you’d like to meet."; button "Change who you’d like to meet" (opens the existing filters) |
| Loading / didn't load | LOOK spec V2 §5 (already locked) |

## 3. Demo cast (replaces every ZYRA demo person in the draft's demo data)

| Women (Seekers) | Men (Seekers) |
|---|---|
| Grace Clarke · Esther Mensah · Naomi Fernandes · Abigail Reyes · Ruth Adeyemi · Lydia Thomas · Phoebe Wright · Chloe Bennett · Miriam Okoro · Rebecca Lewis · Joanna Silva · Priscilla Evans | James Carter · Daniel Owusu · Samuel Hughes · Joel Martins · Caleb Moore · Nathan Brooks · Elijah Grant · Matthew Osei · Isaac Novak · Jonah Price · Simon Patel · Andrew Kim |

Shepherds: Pastor David Okafor (James's), Pastor Ama Mensah, Elder Joseph Clarke, mentor Sarah Lewis; family Shepherds by
first name with a matching relation ("Her mother, Ruth", "Her father, Peter", "Her aunt, Teresa", "His brother, Mark").
Rules: every relation matches the person (no woman as "father"); church traditions spread across the §1 list; ages 24-38;
UK towns; demo pictures use project-made placeholders with the existing name/gender mapping; nationality/ethnicity values
plausible for the name. Demo data stays made-up and local (public repo).

## Must not change
Card layout, photo carousel, name block, Shepherd line, buttons, filters · look · draft boundaries.

## Not decided
Filters screen design · full profile page layout.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 8 - Founder: "A · Faith chips only — LOCK it" |
| 2026-11-06 | V2 | LOCK 11: masters re-rendered with "Request a Journey". V1 archived |
| 2026-11-06 | V3 | LOCK 16 (Founder: "A · Upfront — LOCK it"): marriage line under the chips; 5 card masters re-rendered (old in ARCHIVE/MASTERS_V2). V2 archived |
| 2026-11-06 | V4 | Answers Codex QUESTIONS row 9: the app keeps leaving out anyone you already have a Journey or request with (peerOccupied) - the better rule; the "In a Journey" state is retired, master moved to ARCHIVE/MASTERS_V3. V3 archived |
| 2026-11-07 | V5 | Direct Founder amendment AD-AIOS-129: existing peer Shepherd line follows the same-pair mutual Journey agreement gate, generic fallback, no sale/unlock; own Main unchanged. V4 archived |

The sample profile pictures are simple placeholder images made for this project; they show no real people. Earlier versions in the Git history used photos whose source was not recorded.
