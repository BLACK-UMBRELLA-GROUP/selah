---
id: DOC-SELAH-0035
type: SPEC
status: CURRENT
feature: MARRIAGE_PREP
purpose: SELAH's "Preparing for marriage" card shown at Open Conversation - three steps a couple ticks as they do a church marriage preparation course (LOCK 9)
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0009]
owner: SELAH chat
---

# SELAH MARRIAGE PREPARATION — SPEC — CURRENT VERSION V1 (LOCK 9)

Founder, 6 Nov 2026: "B · Card after Open Conversation — LOCK it" (prototype V19, cleaned as V20). New to SELAH.
Look: LOOK spec V2. ROADMAP row: **Christian content and production experience**.

## 1. Where
On the Journey screen when the Journey is at its last stage, **Open Conversation** (`conversation`, the destination), below
the stage list and its buttons. The 8 stages (`lib/data/selah_journey_stages.dart`) do **not** change; no new stage value.

## 2. Card (exact words)

| Part | Text / look |
|---|---|
| Label | WHEN YOU’RE BOTH READY (section label style) |
| Title | Preparing for marriage (16 px, 600) |
| Line | Not finished: "Your Shepherds can help you find a marriage preparation course." · All three done: "You’ve finished your marriage preparation together. Well done." |
| Step 1 | **Talk with your pastor or Shepherds** / Ask who runs marriage preparation near you. |
| Step 2 | **Choose a course together** / Many churches run one over a few weeks. |
| Step 3 | **Finish the course** / Mark it here when you both have. |
| Step mark | Lake "○" not done, lake "✓" done; the whole row is tappable and toggles; toast "Marked done." / "Unmarked." |

Steps can be ticked in any order. Ticks are saved on the Journey and show for both members of the couple.

## 3. States (masters)

| State | Master |
|---|---|
| Not started | L09_marriage_prep__not_started |
| One done | L09_marriage_prep__one_done |
| All done | L09_marriage_prep__all_done |
| Didn't save | L09_marriage_prep__didnt_save - error bar (LOOK §5) at the top of the card: "That didn’t save. Try again." + **Try again** |

Masters are scrolled to the card.

## Must not change
The 8 Journey stages, their words, Family Review gates, End Journey, Continue/Finished button · look · draft boundaries.

## Not decided
What the Shepherds see of these ticks · course suggestions or links.

## Version history
| Date | Version | Change |
|---|---|---|
| 2026-11-06 | V1 | LOCK 9 - Founder: "B · Card after Open Conversation — LOCK it" |
