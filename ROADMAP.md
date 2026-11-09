---
id: DOC-SELAH-0008
type: PLAN
status: CURRENT
feature: GOVERNANCE
purpose: Approval-gated roadmap for SELAH - its own identity from 3 Nov 2026, then member services and launch preparation
links: [OA-SELAH-001, OA-SELAH-002, OA-SELAH-003, OA-SELAH-004, OA-AIOS-414]
owner: SELAH
---

# SELAH roadmap

**Overall:** roughly **150 hours** of work to give SELAH its own identity and product (content, onboarding, Shepherd flows, backend, tests). The table below is the first slice.

Status: demo. Work on SELAH's own identity resumed on 3 November 2026 under Founder decision AD-AIOS-123. Delivery status updated 9 November 2026.

The current source is a ZYRA-derived local demo. From 3 November 2026 it moves away from ZYRA wherever SELAH differs; any later sharing of an engine with ZYRA is a separate decision. Nothing below authorizes development, deployment, incorporation, spending or publication.

These are tentative engineering/preparation estimates for major unfinished work streams, each exceeding 20 hours. They are planning ranges rather than commitments or an approved backlog. Locked designs and detailed discovery may change the estimates. External decisions, professional advice, fees and waiting time are excluded.

| Major work stream | Tentative effort | Existing basis and scope | Required gate |
|---|---:|---|---|
| SELAH's own identity and private delivery acceptance | 32–48 hours | OA-AIOS-414 and OA-SELAH-001. From 3 Nov 2026 (Founder): replace the copied ZYRA foundation with SELAH's own design and code wherever SELAH differs - Christian content and questions, look, Shepherd and onboarding flows. Plan migration and verify the approved private delivery, first frame, stable runtime, unplugged launch and Founder visual acceptance. | Locked SELAH designs and a named build brief for each step; Founder visual acceptance. |
| Independent real-member services | 48–80 hours | OA-SELAH-002. Design and prepare independent authentication, database, photo storage/moderation, verification, safety/reporting, request lifecycle, messaging permissions, compatibility consent/scoring and receipt/credit authority. The demo activates none of these. No other company's accounts, records or service identities are to be reused. | Founder-approved service design and separate setup/deployment decisions, followed by locked product states and scoped implementation briefs. |
| Christian content and production experience | 24–40 hours | OA-SELAH-003. Review Christian onboarding/questions and Shepherd semantics, denomination scope, compatibility validity, original production content, runtime layout and accessibility. Keep the project-made placeholder pictures as demo fixtures; production content and visual acceptance remain separate work. The sample profile pictures are simple placeholder images made for this project; they show no real people. Earlier versions in the Git history used photos whose source was not recorded. | Founder content and visual acceptance; approved production assets; locked designs; written unfreeze before app changes. |
| Separate company and commercial preparation | 24–32 hours | OA-SELAH-004. Prepare the separate company, name/domain/trademark/store availability decisions, independent privacy/support identity, pricing/products and real commerce configuration. This estimate covers bounded preparation, not legal outcomes or purchases. | Founder decisions and separate authority for any filing, purchase, registration, commerce setup, deployment or release. |

**Indicative total: 128–200 hours**, subject to scope refinement and approval. This is not a delivery date.

## Current boundaries

Each app change needs a locked design and a named build brief. The demo uses local fixtures and has no configured member services.

## Private delivery status

The [6 November private delivery](README.md#private-delivery-route) recorded installation on the paired iPhone, a rendered Flutter screen and the same process after 22 seconds. Later private deliveries included the Journey and Family Compatibility updates and the rebuilt iPhone icon and launch screen.

Unplugged cold launch and Founder visual acceptance remain open for the private delivery work stream. Android remains held on Question 17 because this checkout has no Android host.

## Before implementation

The SELAH lead designer records Founder `LOCK` evidence in `APP/APPROVED/<FEATURE>/`: real-size pictures with real navigation, empty/loading/error states, a written specification with measurements and `LOCK_RECORD.md` with the Founder's words. A build brief and a `WAITING` line in `APP/APPROVED/BUILD_QUEUE.md` identify the authorized work. Codex then checks those locked files and implements only that scope.

The live actions register remains the authority for outstanding work: `SYSTEM/OUTSTANDING_ACTIONS/OUTSTANDING_ACTIONS_V1.md`. This roadmap does not close its actions or change recorded acceptance. Publication requires a separate instruction.
