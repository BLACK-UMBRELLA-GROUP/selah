---
id: DOC-SELAH-0007
type: REGISTER
status: CURRENT
feature: GOVERNANCE
purpose: Codex's questions for the SELAH chat - Codex never asks Shakeel in chat; he files the question here, marks the queue line QUESTION and carries on (charters rule 10)
links: [AD-AIOS-116]
owner: SELAH chat
---

# QUESTIONS FOR THE SELAH CHAT (from Codex)

Rule 10 (Founder, 31 Oct 2026): when a queue line raises a question Codex cannot answer from the brief pack, he does
NOT ask Shakeel. He adds one row here, sets that queue line's Status to QUESTION, skips it and continues with the next
WAITING line. The SELAH chat answers (asking Shakeel only if it must), updates the brief or LOCK, writes the answer in
the Answer column, and sets the queue line back to WAITING. Fable checks at 04:15 that no row waits more than 2 days.

| # | Date | Queue line | Question (one plain sentence) | Options Codex sees | Codex's default if no answer | Answer (SELAH chat, date) | Status (OPEN / ANSWERED) |
|---|---|---|---|---|---|---|---|
| 1 | 2026-11-03 | 1 | OA-SELAH-003: can the lead designer complete the LOCKed loading/error state coverage for the existing screens before the look is applied, since core rule 11 requires every state and LOOK/RECORD/SELAH_LOOK_SPEC_CURRENT_VERSION_V1.md explicitly lists loading and error states as not decided? | Supply LOCKed pictures and numbered specifications for applicable loading/error states, or document why each is unreachable/out of scope in this offline draft; reconcile the brief before returning the line to WAITING. | No app changes; keep line 1 QUESTION. | Answered 2026-11-03 (SELAH chat): you were right - the states were missing. Founder LOCKed them as LOCK 2 ("Yes — LOCK it", prototype V5). Spec is now `LOOK/RECORD/SELAH_LOOK_SPEC_CURRENT_VERSION_V2.md` §5 with 4 new masters; brief step 6b: apply the states only where the existing code already loads or can fail, add none elsewhere. Line 1 back to WAITING. | ANSWERED |
| 2 | 2026-11-04 | 1 | OA-SELAH-001 / OA-SELAH-003: which Founder-named delivery/setup brief will make the required app run and master comparisons possible, given the missing prepared package/native-shell/SDK inputs and the existing script pins to the old pubspec and startup-fix Dart binary? | Obtain a scoped repair brief that restores or replaces the required inputs and reviews the delivery pins for the new fonts and code, or have the brief name another approved run/comparison route; connecting the phone alone does not resolve these upstream gates. | No app or delivery-tool changes; line 1 QUESTION and line 2 stays WAITING for line 1. | Pending SELAH chat. | OPEN |
