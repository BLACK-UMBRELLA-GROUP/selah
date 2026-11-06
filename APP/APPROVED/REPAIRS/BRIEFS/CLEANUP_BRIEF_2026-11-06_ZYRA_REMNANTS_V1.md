---
id: DOC-SELAH-0028
type: PLAN
status: CURRENT
feature: REPAIRS
purpose: Founder-named clean-up - remove the remaining ZYRA faith remnants from SELAH source comments and switch the compatibility category keys to SELAH's own faith answers
links: [OA-SELAH-003, AD-AIOS-123, DOC-SELAH-0021]
owner: SELAH chat
---

# CLEAN-UP BRIEF — ZYRA REMNANTS IN SELAH SOURCE — 6 NOV 2026 — V1

**Founder-named task** (Shakeel, 6 Nov 2026, clickable answer: "Yes, queue the clean-up (Recommended)").
**Copy exactly. No improvements. Unclear or conflicting → stop and report (QUESTIONS.md, rule 10).**

Queue line 7. Build after: line 6 (the consent wording is changed there, not here). No member-visible change.
ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

| # | Step | Detail |
|---|---|---|
| 1 | Data keys | `SOURCE/lib/data/compatibility_categories.dart` lines ~43-44: replace `'sect'` and `'revert'` in `chapter2Keys` with the keys SELAH saves - `'church_background'` and `'faith_journey'` (as in `selah_seeker_details_service.dart` and the line 4 repair). Check every reader of `chapter2Keys` still counts correctly; add model checks in `tool/test_models.dart`. |
| 2 | Comments | In the files from your 6 Nov line 4 task note (settings_screen.dart:341, profile_screen.dart:467-470, edit_profile_screen.dart:14, traffic_light_question_screen.dart:34-41, help_content.dart:287, selah_consent_service.dart:3, selah_unlock_service.dart:289, selah_dev_scenario.dart:1337): rewrite each comment so it keeps its technical point in neutral SELAH terms - "faith background" / "church tradition" / "faith journey" - with no other community's faith branches, no "sect", no "revert", no other app's name. Where a comment is only history with no technical point, remove it. |
| 3 | Leave alone | Ordinary verbs ("revert a card", "reverted to old design" in selah_profile_name_block.dart, discovery "reverting") stay. Code that rejects inherited fields (selah_seeker_details_service.dart:195) keeps working; reword only its comment. |
| 4 | Search | Afterwards a case-insensitive search of `SOURCE/lib` for the two old faith-branch names, "sect" (as a word) and the competitor name returns nothing; list the command and result in the task note. |
| 5 | Checks | `flutter analyze` (no new issues), `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`. No behaviour change apart from step 1. |
| 6 | Task note + queue | Files changed with a one-line reason each; mark line 7 BUILT or FAILED. |
