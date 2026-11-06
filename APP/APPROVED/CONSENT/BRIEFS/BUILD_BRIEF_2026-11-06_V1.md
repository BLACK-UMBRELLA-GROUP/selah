---
id: DOC-SELAH-0027
type: PLAN
status: CURRENT
feature: CONSENT
purpose: Build brief for LOCK 6 - consent screen in SELAH's words, placed between Shepherd invite and the faith questions
links: [DOC-SELAH-0025, DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — SELAH CONSENT (LOCK 6) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 6. Build after: lines 3 and 5. ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SELAH/AGENTS.md`, `MAP.md` to "Route paths", `CONSENT/RECORD/SELAH_CONSENT_SPEC_CURRENT_VERSION_V2.md`, its LOCK_RECORD, the 4 masters, SHEPHERD_INVITE V4 §1, FAITH_PROFILE V4, MARRIAGE_VALUES V2 §1. |
| 2 | Words | Replace `kArticle9ConsentTitle`, `kArticle9ConsentBody` (split into the spec's paragraphs), `kArticle9ConsentDeclineNote` and the two button labels with spec §2 exactly. Set `kArticle9PolicyVersion = '2026-11-06'`. |
| 3 | Place | Show the existing consent screen between Shepherd invite screen 4 and faith question 1 (spec §1). Agree → faith 1; Skip → marriage 1 (no faith questions); Back → screen 4. Keep the existing consent recording and Settings withdrawal exactly as they are. |
| 4 | States | Spec §3: saving (button), didn't save (error bar instead of the snackbar), Profile note when skipped. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 6 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/consent_masters_test.dart`; 4 beside images in `CONSENT/BUILT/V1/`. |
| 7 | Task note + queue | "Built from", screenshots, Disk, public checks A-F; mark line 6 BUILT or FAILED. |

## Update 2026-11-06 (LOCK 14)
Spec is now V2: Body 1 names faith only (SELAH no longer asks ethnicity, country of birth or nationality - queue line 15). Use the re-rendered masters.
