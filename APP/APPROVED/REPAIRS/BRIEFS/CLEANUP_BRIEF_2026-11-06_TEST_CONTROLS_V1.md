---
id: DOC-SELAH-0051
type: PLAN
status: CURRENT
feature: REPAIRS
purpose: Clean-up brief - move test/demo controls out of member screens into the private developer controls, and take "sample/demo/preview" words out of member text
links: [DOC-SELAH-0020, DOC-SELAH-0041, OA-SELAH-001, AD-AIOS-123]
owner: SELAH chat
---

# CLEAN-UP BRIEF — TEST CONTROLS OUT OF MEMBER SCREENS — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear → QUESTIONS.md (rule 10).**

Founder-named (Shakeel 6 Nov, clickable: "Yes, queue the clean-up (Recommended)"), after the SELAH chat's build check of
line 10 (finding SC-0604). Queue line 16. Build after: 3, 5, 6, 7, 8, 9, 10, 11, 13, 15. **Before line 12** (wording sweeps
the result). ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

## Rule
A member screen shows only what the real app would show. Everything that exists only to drive the offline draft
(simulating the other person, Shepherds, checkpoints, sample messages, credits) lives in the **existing private developer
controls** (`lib/dev/selah_dev_page_options.dart` "Page options", reached the way line 10 reached its failure control).
Masters never show these controls - they are the reference.

| # | Step | Detail |
|---|---|---|
| 1 | Find | In `lib/dev/selah_one_journey_concept_shell.dart` (and any member-visible screen it builds): every inline control or block that simulates someone else or the server - e.g. the "LOCAL PREVIEW CONTROLS" block (~line 2885: "Demo: <Name> says hello", "Demo: <Name> also chooses reveal", "Sample message" / "Add sample message", "Demo: <Name> is also ready"), "Demo: recipient accepts", "Demo: other person agrees to resume", "Demo: both agree to Pause / continue", the "PREVIEW ONLY" card, sample-credit setters. List every one in the task note. |
| 2 | Move | Each becomes a Page option on the page it belongs to, same behaviour and same model calls. The member's **own** actions in those blocks ("I’m ready for the next step", "Continue together" and similar) stay on the member screen where the masters show them. |
| 3 | Words | Member-visible text: remove "sample", "demo", "preview", "simulated", "local" where they only describe the draft (≈69 strings, e.g. "Sample request declined." → "Request declined."; "Sample Journey ended. History retained." → "Journey ended. Your history stays."; eyebrow "SAMPLE UPDATES" → "UPDATES"). A sentence whose only job is to say it is a demo ("This sample does not calculate a score…", "This local preview has no score or private result…", "Phase review is simulated, not a server approval.") moves into that page's Page options help text. Where a LOCK gives exact words, the LOCK wins. Keys, semantic IDs, logs and test names are not member text - leave them. |
| 4 | Never | No new developer menu, no new toggle without real behaviour, no change to what the model does, no member action removed. |
| 5 | Checks | `flutter analyze`, `dart run tool/test_models.dart`, `node tool/analyze_cached.mjs`, `node tool/check_draft_boundaries.mjs`; update any widget test that tapped an inline demo button to use Page options. |
| 6 | Compare | Re-capture the beside images of lines already BUILT whose screens had these controls (at least `MARRIAGE_PREP/BUILT/V1_1/`); state in the task note that no demo control or demo word remains visible. |
| 7 | Task note + queue | List from step 1, strings changed (before → after), tests updated, screenshots, Disk, public checks A-F; mark line 16 BUILT or FAILED. |
