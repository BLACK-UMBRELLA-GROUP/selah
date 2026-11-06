---
id: DOC-SELAH-0047
type: PLAN
status: CURRENT
feature: SHEPHERD_INVITE
purpose: Fix brief from the line 2 build check - the "no name" state shows a filled name with the error
links: [DOC-SELAH-0020, OA-SELAH-003, AD-AIOS-123]
owner: SELAH chat
---

# FIX BRIEF — SHEPHERD INVITE "NO NAME" STATE — 6 NOV 2026 — V1

**Copy exactly. No improvements. Unclear → QUESTIONS.md (rule 10).**

Queue line 14. Build after: 2. ROADMAP row: **SELAH's own identity and private delivery acceptance** (not ticked).

Found by the SELAH chat's build check of line 2 (charter rule 8). Everything else on line 2 matches its masters.

| # | Step | Detail |
|---|---|---|
| 1 | Read | `SHEPHERD_INVITE/RECORD/SELAH_SHEPHERD_INVITE_SPEC_CURRENT_VERSION_V4.md` row 3e; master `MASTERS/L03_signup_invite__name_error.png`; your `BUILT/V1/L03_signup_invite__name_error__master_beside_build.png`. |
| 2 | The gap | Master: name field **empty**, "Enter your Shepherd’s name." under it. Build capture: field shows "David Okafor" with the error under it. |
| 3 | Fix | If the app can show the error with a name typed, fix the logic (error only when the field is empty after trimming; clears on next try). If the app is right and only the capture typed the name first, fix the capture. Say which in the task note. |
| 4 | Also re-capture | `L03_shepherd_invitation` - its master was re-rendered with the real Shepherd tabs you built (old master was wrong, not your build). New beside image only; no code change. |
| 5 | Checks + queue | Same checks as line 2; new beside images in `SHEPHERD_INVITE/BUILT/V1_1/`; mark line 14 BUILT or FAILED. |
