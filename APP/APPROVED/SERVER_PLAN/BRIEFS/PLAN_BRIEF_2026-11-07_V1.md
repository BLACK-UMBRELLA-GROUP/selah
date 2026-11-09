---
id: DOC-SELAH-0079
type: PLAN
status: CURRENT
feature: SERVER_PLAN
purpose: Founder-named task - Codex writes SELAH's own server plan (document only); building starts after 14 Dec
links: [OA-SELAH-002, OA-SELAH-004, AD-AIOS-129, AD-AIOS-123, OA-AIOS-420]
owner: Fable (Founder-named task; written for the SELAH queue)
---

# PLAN BRIEF — SELAH'S OWN SERVER: WRITE THE PLAN ONLY — 7 Nov 2026

**Founder decision (7 Nov 2026, clickable question in the BLACK UMBRELLA GROUP chat, AD-AIOS-129):** "Plan now, build
after trip (Recommended)". You write a plan. Nothing is set up, signed up for, installed or deployed. Building starts
after 14 Dec, and each setup step will need its own yes from the Founder.

## Not allowed in this line

| Never | Detail |
|---|---|
| Accounts and sign-ups | No new provider account, project, organisation, domain or API key. Do not sign in anywhere. |
| Installs | No CLI, SDK, package or tool installs or upgrades (F33, OA-AIOS-420). |
| Code | No app code, migration, SQL or config change. This line writes documents only. |
| ZYRA's server | Never read ZYRA's live backend, keys or accounts. Read ZYRA's repo only to list what the SELAH app currently calls. |
| Keys | Never open the keys folder. |

## What to write

**1. `SYSTEM/DOCUMENTS/SELAH_SERVER_PLAN_CURRENT_VERSION_V1.md`** (id DOC-SELAH-0080, public repo, so public checks A-F
apply). Under 30 KB, plain words, tables:

| Section | Content |
|---|---|
| 1. What the app calls today | Every server call in `SOURCE/lib` (function, table, storage bucket, RPC such as `selah_advance_stage()` and `score_candidates()`), which screen uses it, and whether it exists anywhere SELAH owns. Mark each one "SELAH has none yet". |
| 2. What SELAH needs | The OA-SELAH-002 scope: sign-in, database, photo storage and moderation, verification, safety and reporting, messaging permissions, request lifecycle, compatibility consent and scoring, receipts and credits. For each: what it does, which LOCK needs it. |
| 3. The four waiting LOCK changes | The table in OA-SELAH-002: LOCK 19 Introduce (suggestion-create service; ships together with removing the old Network family requests), LOCK 21 Journey stages (remove `mentor_gate`, stage CHECK, move stored rows), LOCK 18 Deal-breakers (score reads ch4_hard_requirements only), row 10 Replace (Connections takeover). For each: the exact server change, the app change that ships with it, and the test. |
| 4. Name rule | AD-AIOS-129 rule 2: the other Main Shepherd's real name is returned only after both Seekers have said yes to a Journey; before that the server returns no name. Show where the server enforces it (not only the app). |
| 5. Personal data | Which fields are personal data and which are special category (faith answers are religious belief under UK GDPR). Keep only what a LOCK needs; where each is stored; who can read it; how a member deletes it. No legal advice - list questions for the Founder's legal review. |
| 6. Provider choice | Two or three options (for example a separate Supabase organisation and project, or another provider). For each: fit with the existing Flutter code, what changes, data region (UK/EU), and what the Founder must do himself (sign up, payment, terms). No prices in this file. |
| 7. Build order after 14 Dec | Numbered steps, each one small, each marked "Founder yes needed" where it creates an account, costs money, installs a tool or touches real data. First step: an empty project with test data only. |
| 8. Open questions | Anything only the Founder or the SELAH chat can decide. |

**2. `BLACK UMBRELLA GROUP/BUSINESS/SELAH/SELAH_SERVER_COSTS_2026-11-07_V1.md`** (private group folder; create the
folder if missing): monthly cost of each provider option at 0, 100 and 1,000 members, from the providers' public price
pages, with the date read and the link. Mark any figure you could not confirm "not confirmed".

## Finish

- Regenerate SELAH's MAP. Run public checks A-F on the SELAH commit.
- Task note: files written, the count of server calls found in section 1, open questions, and "no accounts, installs
  or code changes".
- Commit and push SELAH. Commit the BLACK UMBRELLA GROUP file in the 01:00 sweep.
- Mark the queue line BUILT, or QUESTION with a row in `APP/APPROVED/QUESTIONS.md` if something blocks you.
