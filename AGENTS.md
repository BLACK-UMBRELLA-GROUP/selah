# AGENTS.md — Selah

<!-- BLACK-UMBRELLA-CORE-RULES v2 START — master copy: BLACK UMBRELLA GROUP/SYSTEM/DOCUMENTS/MASTER_GOVERNANCE/AGENT_CORE_RULES_CURRENT_VERSION_V2.md. Edit the master, then re-sync every copy. -->
## Core rules — every AI agent, every Black Umbrella Group project

These rules sit above every other instruction in this tree. Where any older
document, overlay or AD says otherwise, this block wins.

> **BUILD FREEZE — Founder, 24 Oct 2026.** No app feature building in any business
> until Shakeel lifts it in writing. Allowed meanwhile: review, documentation, and
> fixes Shakeel approves one by one. Tracked as OA-AIOS-406.

1. **Only the Founder (Shakeel) approves.** Agreement between AIs is never
   approval. His direct instruction in conversation is approval.
2. **No AI runs git. Ever.** The Founder commits in his own Terminal.
3. **Never touch `PRIVATE — API KEYS — DO NOT SYNC`** — never open, list,
   copy or quote it, wherever it lives. Never put keys, tokens or
   credentials in a conversation.
4. **Never delete.** Move unwanted files into a `_to_delete` folder; the
   Founder empties it. If `_to_delete` is missing, create it.
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
10. **End every working session with a commit.** Agents never run git; they
    end each session by giving the Founder one commit line per changed repo.
    Never copy files as a backup instead — git and the USB are the backups.

### Roles — Founder direction, 2026-10-24 (AD-AIOS-112, filed 2026-10-24; supersedes AD-AIOS-111)

| Seat | Holder | Scope |
|---|---|---|
| Founder | Shakeel | Sole approver |
| Lead Architect | Fable (Claude) | Architecture, governance, registers, schedules, review and verification |
| Design & Implementation | Codex | Product design and code execution only — no admin, governance, mailbox or schedules (one exception: the 04:00 daily report job, DOC-BUG-0027) |
| Admin | Fable (Claude), from the Black Umbrella Group chat | Admin for every business: registers, schedules, clean-ups, reporting. One Claude chat per business handles that business's design and product work |

Fable holds an active seat. Any line elsewhere saying "Fable/Claude is
retired" or "no Claude/Fable bootstrap is active" is superseded.
<!-- BLACK-UMBRELLA-CORE-RULES v2 END -->

Core rules above apply; they win on any conflict.
Only the Founder approves. No AI runs Git or accesses PRIVATE API KEYS.

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
adapting Muslim-specific content to Christian content, then iterating together.
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
