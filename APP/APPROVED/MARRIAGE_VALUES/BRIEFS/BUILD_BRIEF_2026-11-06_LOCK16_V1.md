---
id: DOC-SELAH-0056
type: PLAN
status: CURRENT
feature: MARRIAGE_VALUES
purpose: Build brief for LOCK 16 - who sees the marriage answers (Browse card line, in-Journey profile) and Journey Bio stops repeating them
links: [DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# BUILD BRIEF — MARRIAGE ANSWERS UPFRONT (LOCK 16) — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 19. Build after: 5, 9, 17. Before 12. ROADMAP row: **Christian content and production experience** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Read | `MARRIAGE_VALUES/RECORD/SELAH_MARRIAGE_VALUES_SPEC_CURRENT_VERSION_V7.md` §5-6, its LOCK_RECORD, `BROWSE_CARD/RECORD/SELAH_BROWSE_CARD_SPEC_CURRENT_VERSION_V5.md` §1, masters `MARRIAGE_VALUES/MASTERS/L16_*`, re-rendered `L05_profile_marriage__answered`, `BROWSE_CARD/MASTERS/L08_browse_card__*`, `LOOK/MASTERS/L01_seeker_browse__profile`, `SHEPHERD_INVITE/MASTERS/L03_seeker_browse__waiting_for_shepherd`, `ABOUT_YOU/MASTERS/L14_profile_about_you`. |
| 2 | Browse line | The muted line under the faith chips, words exactly as BROWSE_CARD V3 §1, from line 5's saved answers. |
| 3 | In a Journey | Tapping the other person's name at the top of a Journey opens their profile there (use the app's existing in-Journey profile/detail page if it has one; otherwise build the page in master L16_journey_their_profile). It shows their faith chips and all seven marriage answers with the line "You can see these because you’re on a Journey together." Nowhere else shows all seven to another member. |
| 4 | Shepherds | A Seeker's Shepherds can see all seven where they already see the Seeker's faith profile. |
| 5 | Journey Bio | Remove `marriage_status`, `children`, `future_children`, `relocation` from `lib/models/journey_bio.dart` and every Bio screen/editor. Saved Bio values stay in storage, unused. List what moved. |
| 6 | Profile note | The muted note under your own Marriage values card (spec §5). |
| 7 | Checks | `flutter analyze`, `dart run tool/test_models.dart` (add: line words per answer, "I’d rather share later" left out, Bio fields gone), `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. |
| 8 | Compare | `COMPARE/SELAH_MASTER_COMPARE_ROUTE_CURRENT_VERSION_V1.md`; test `SOURCE/test/masters/marriage_upfront_masters_test.dart`; beside images for every master in step 1 in `MARRIAGE_VALUES/BUILT/LOCK16_V1/`. |
| 9 | Task note + queue | "Built from", files, Bio fields removed, screenshots, Disk, public checks A-F; mark line 19 BUILT or FAILED. |

## Update 2026-11-06 (answers QUESTIONS row 13; spec V7)
Step 4: in `_shepherdLinkedProfile`, keep the full-photo inspection and its taps exactly as built. Below what it already shows, add "MARRIAGE VALUES" + the same card component as the Seeker's own profile card. No new photo control; L16_journey_their_profile is the Seeker-in-a-Journey view only. Add one beside image of the Shepherd view, scrolled to the card.
