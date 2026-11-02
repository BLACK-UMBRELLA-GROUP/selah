# AGENTS.md — Selah

<!-- BLACK-UMBRELLA-CORE-RULES v4 START — master copy: BLACK UMBRELLA GROUP/SYSTEM/DOCUMENTS/MASTER_GOVERNANCE/AGENT_CORE_RULES_CURRENT_VERSION_V4.md. Edit the master, then re-sync every copy. -->
## Core rules — every AI agent, every Black Umbrella Group project

These rules sit above every other instruction in this tree. Where any older
document, overlay or AD says otherwise, this block wins.

> **BUILD FREEZE — Founder, 24 Oct 2026. LIFTED FOR ZYRA on 29 Oct 2026** ("so i wanna
> do freeze lift do it"). ZYRA builds again - only from LOCKed designs (rule 11) and
> work Shakeel names. AZMARA, SELAH and WAFA stay frozen until Shakeel lifts each in
> writing. Allowed while frozen: review, documentation, and fixes Shakeel approves one
> by one. Tracked as OA-AIOS-406.

1. **Only the Founder (Shakeel) approves.** Agreement between AIs is never
   approval. His direct instruction in conversation is approval.
2. **Only Codex runs git, and only within these limits** (AD-AIOS-114). Allowed:
   `git status`, `git add`, `git commit`, and `git push` to `origin` on the current
   branch - in the repo of the project he is working in, at the end of a task whose
   tests passed; plus the 01:00 job's sweep, which commits and pushes what is left in
   every repo. Never: force-push, reset, rebase, amend or rewrite pushed history,
   `git clean`, checkout/restore over working files, delete branches, change remotes or
   git config, or commit a file over 50 MB or anything from the keys folder.
   `ZYRA/SITE`: commit, but never push until Shakeel's Cloudflare check (OA-AIOS-407).
   Read-only commands are always allowed (`git log`, `git rev-list`, `git show`, `git diff`,
   `git ls-files`, `git branch -a`) and so are read-only scanners such as gitleaks; the
   limits above are about writing (Founder, 1 Nov 2026: "Yes, permanently" - AD-AIOS-120).
   Claude chats (Fable and the business chats) never run git.
3. **Never touch `PRIVATE — API KEYS — DO NOT SYNC`** — never open, list,
   copy or quote it, wherever it lives. Never put keys, tokens or
   credentials in a conversation.
4. **Never delete.** Move unwanted files to `~/_to_delete/<WHAT>_<date>/` on the Mac,
   or `BLACK UMBRELLA GROUP/tmp/_to_delete/<BUSINESS>_<date>/` for repo files;
   **never a `_to_delete` inside a business repo** (S22). The Founder empties it.
   If the folder is missing, create it.
5. **Findings become actions** — every finding gets an OA number or a
   written refusal.
6. **One CURRENT_VERSION per document system.** Register entries append
   above the metadata block and bump the live NEXT IDENTIFIER.
7. **BUILD → DOCUMENT → TRACE → HANDOVER.** Code-complete is not
   handover-complete.
8. **Evidence is not a build store.** Review evidence = screenshots, JSON
   and a text BUILD.json (commit SHA, Flutter version, build mode,
   timestamp). Never copy compiled apps (`Runner.app`, build products) or
   source trees into registers or evidence folders.
9. **`AGENTS.md` holds standing rules only.** Progress, round status and
   decisions go in the registers. Keep every `AGENTS.md` under 16 KB —
   Codex stops reading at 32 KiB.
10. **Every finished task ends in a commit.** Codex commits and pushes his own work
    at the end of each task (message: what changed, with the OA/DR IDs) and lists the
    commit in his task note. The 01:00 sweep commits what Fable and the business chats
    changed ("Admin changes <date>"). Until Codex is onboarded, the Founder commits
    from one line per changed repo. Never copy files as a backup instead — git and
    the USB are the backups.
11. **Nothing is built until it is LOCKed** (AD-AIOS-115). Each business's Claude chat is
    its lead designer. A design is a draft until Shakeel says `LOCK` and the chat records
    it in that business's approved folder: picture(s) at real screen size with the real
    navigation on top, every state (empty, loading, error), a written spec with numbers,
    and his words. Codex builds only from locked files - he checks them first and
    reports problems, and never invents, redraws or "improves" a design.

### Roles — Founder direction, 2026-10-24 (AD-AIOS-112, filed 2026-10-24; supersedes AD-AIOS-111)

| Seat | Holder | Scope |
|---|---|---|
| Founder | Shakeel | Sole approver |
| Lead Architect | Fable (Claude) | Architecture, governance, registers, schedules, review and verification |
| Lead designer, per business | That business's Claude chat (ZYRA, AZMARA, WAFA…) | Product, rules, UX, layout, wording, look, master pictures and specs; records each LOCK (rule 11); writes build briefs for Codex. Never code, never git |
| Implementation | Codex | Builds from locked designs only (rule 11): code, tests, as-built handovers. No design of his own, no admin, governance, mailbox or schedules. Exceptions: the 01:00 daily report job with its commit sweep (DOC-BUG-0027), and git within rule 2 |
| Admin | Fable (Claude), from the Black Umbrella Group chat | Admin for every business: registers, schedules, clean-ups, reporting, the daily review |

Fable holds an active seat. Any line elsewhere saying "Fable/Claude is
retired" or "no Claude/Fable bootstrap is active" is superseded.
<!-- BLACK-UMBRELLA-CORE-RULES v4 END -->

Core rules above apply; they win on any conflict.
Only the Founder approves. Only Codex runs git, within core rule 2 (AD-AIOS-114); nothing is built on the frozen demo. No AI accesses PRIVATE API KEYS.

## Locked design workflow (core rule 11, AD-AIOS-115; charters V6 rule 11 - the same system as ZYRA)

| Step | Who | Where |
|---|---|---|
| Brief | Shakeel | SELAH chat (Claude) - the **lead designer** |
| 2-5 options, one picture at a time, each with "what changed"; shown in the business's **one interactive prototype** (Artifact page Shakeel can tap through) | SELAH chat | Chat + prototype |
| Pick and tweak, then `LOCK`; the other options leave the prototype the same day | Shakeel | Chat |
| Record the LOCK: pictures at real size with every state, a spec with numbers, and a `LOCK_RECORD.md` line with Shakeel's words and the date | SELAH chat | `APP/APPROVED/<FEATURE>/` |
| Build brief: locked file paths, "copy exactly, no improvements", what not to touch, checks; then one WAITING line in `APP/APPROVED/BUILD_QUEUE.md` | SELAH chat | `APP/APPROVED/<FEATURE>/BUILD_BRIEF_<YYYY-MM-DD>.md`. Codex builds the queue at 01:00 or at once on any message from Shakeel in the SELAH Codex chat (charters rule 9); he never asks Shakeel - a question goes in `APP/APPROVED/QUESTIONS.md` and the line waits as QUESTION (rule 10) |
| Check the locked files first, report problems, then build exactly | Codex | Task note: "Built from: <paths>" plus a screenshot of the built screen beside the master |
| Compare the build with the master (MATCH or each difference); answer `QUESTIONS.md`; update the prototype to the real app | SELAH chat | Its chat note; Fable files the decision at 04:15 |
| Morning check task (copy of ZYRA's 05:36) | Fable sets it up when the business is unfrozen | Scheduled task |

Until the Founder lifts this business's build freeze in writing, design and prototype work continues but no queue line is built.

## Current scope — Founder instruction, 2026-10-13

Selah is a separate Christian marriage application and separate-company
workstream, not a theme, mode or new identity inside ZYRA. Do not modify ZYRA
from this chat without a later explicit scoped instruction. Legal company
formation, name clearance and production infrastructure are not established
by source creation or Apple development signing.

> **Decision 26 Oct 2026 (AD-AIOS-113):** `SOURCE/` is a **frozen demo** - a 13 Oct copy of ZYRA's code with
> names and faith words replaced. Build nothing more on it. After ZYRA launches, SELAH is rebuilt on one shared
> engine with ZYRA (OA-AIOS-414); the code licence between the companies is set up at incorporation.

The Founder requested the first phone draft by reusing the current app core,
adapting content for ZYRA's faith community to Christian content, then
iterating together.
The prepared draft reuses presentation/code and local stock fixtures only.

## Load next

1. `MAP.md` (next to this file) — every SELAH document by ID with a one-line purpose. Read it only down to "Route paths" (the file paths); search the rest by ID.
2. Open only the documents its **task routes** table lists for your task. Never read
   the actions register whole; search it for the `OA-SELAH-` ID you need.
3. After adding, renaming or superseding a document, give it a header and re-run
   `python3 "../BLACK UMBRELLA GROUP/SYSTEM/TOOLS/generate_map.py" .` (Knowledge
   Routing Standard).

## Boundaries that prevent wasted sessions

- SOURCE/lib/main.dart is fresh. It opens the detached request-flow shell,
  not the inherited AuthGate or production HomeShell.
- No configured backend, real account, OAuth client, server grant, secret,
  member photo, provider record, signing file, shared keychain or app group
  was imported. Supabase/OAuth config is intentionally inert.
- HTTP is denied, fixtures are session-only, and release mode refuses the
  draft. Do not weaken these boundaries to make a screen appear functional.
- Developer controls are private draft-local controls, not server authority.
- Shepherd is the public trusted-support role. Internal Mentor/Shepherd
  namespaces remain distinct to preserve formerly separate source types.
- Inherited comments and numbered references are origin history, not Selah
  approvals. “inherited decision N” means source DR-ZYRA-N; “inherited upstream
  action N” means source OA-ZYRA-N. Actual Selah actions are in its own register.
- Own proposed native ID: com.blackumbrella.selah.draft; display name Selah.
  Development team reuse is private testing only, not company formation.
- SOURCE/run.sh is the internally verified project-local, non-interactive
  Profile-draft delivery route. It verifies the exact retained signed native
  shell, compiles a raw Profile Dart layer in a bounded sandbox, stages a fresh
  app copy and re-signs it. SDK/engine/cache/native inputs are hard-pinned;
  inherited build inputs are sanitized; network, Git and Xcode-project builds
  are denied during Dart-layer compilation. It accepts one exact fingerprinted
  artifact/signature/device target and re-queries the same launched PID after
  22 seconds. Codex may operate it after exact Founder GO; the Founder has
  already directed this no-paste fixed rebuild/install.
- tool/analyze_cached.mjs is a direct native static analyzer only. It does not
  call the Flutter tool or its native build phases. tool/test_models.dart is
  pure Dart without Flutter/plugin/backend execution. Neither proves an iOS
  build, installation, camera function or native launch.

## Delivery status

Prepared source and local checks passed on 2026-10-13. An initial separate
Selah build/install reached the native launch storyboard, then remained there
until iOS watchdog termination; that attempt is evidence, not accepted
delivery. The pre-runApp platform-plugin wait was removed; the corrected
startup source and project-local delivery route are internally verified. The
corrected Dart-layer compile, staged-bundle assembly and strict signing now
pass. Device install/launch did not execute because the physical Founder iPhone
was unavailable/offline (CoreDevice 4016). Founder GO remains recorded;
post-launch checks, unplugged launch and Founder visual acceptance are PENDING.
No App Store/TestFlight/public release is authorized by this draft.
