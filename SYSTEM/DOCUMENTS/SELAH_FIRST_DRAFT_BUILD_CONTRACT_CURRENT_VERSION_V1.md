---
id: DOC-SELAH-0003
type: STANDARD
status: CURRENT
feature: FIRST_DRAFT
purpose: The build rules for the first draft: separate source tree, allowlisted ZYRA code only, no backend or live data
links: [OA-SELAH-001, OA-AIOS-403]
owner: Fable
---

# Selah first draft — build contract

Status: implementation constraints for the Founder-requested private draft.
Product owner: APP/FIRST_DRAFT/SELAH_FIRST_DRAFT_SPEC_CURRENT_VERSION_V1.md.
As-built owner: SELAH_FIRST_DRAFT_HANDOVER_CURRENT_VERSION_V1.md.

1. Separate SOURCE tree and Dart package selah. Never edit the source app.
2. Reuse only allowlisted Dart code, local placeholder portrait assets and bundled
   fonts/notices. Exclude original main/config, credentials, native providers,
   caches/builds, repositories, live data and signing material.
3. New entrypoint; exact installed draft bundle check; release refusal;
   no Supabase initialization; blank backend/OAuth/provider authority;
   deny outbound Dart HTTP; keep a local-preview denial lease/latch.
4. All retained feature leaves use detached local adapters and existing owner/
   route lifetime guards. No sample can grant real account/billing authority.
5. Christian faith/question adaptation keeps renderer IDs and structure but
   does not assert an inherited or deployed compatibility scoring contract.
6. Own iOS bundle com.blackumbrella.selah.draft, display name Selah, own icon,
   selah/* native channels; no old OAuth, Apple-login capability, shared groups,
   signing credentials or alternate source-product icon identifiers.
7. Private development signing is limited to bundle
   com.blackumbrella.selah.draft and team `${SELAH_TEAM_ID}` under the Founder's exact
   private-test approval. The caller's `SELAH_SIGN_ID` must select the existing
   approved development signing identity. The route must not create/update provisioning,
   register a device, upload an artifact or imply public/release authority.
8. SOURCE/run.sh is the internally verified project-local no-Git delivery route
   and may be operated by Codex after exact Founder GO. It must use Profile-draft,
   lib/main.dart, SELAH_DRAFT_LOCAL_ONLY=true, the exact retained native shell,
   pinned local dependency/tool/engine/native state and the intended unlocked
   paired iPhone. Its raw Dart-layer compile must deny network, Git and Xcode-
   project builds. It must not invoke the Flutter shell wrapper or SDK Xcode
   backend; expose build/assemble through the bounded wrapper;
   resolve/fetch/update packages; inherit unapproved engine/target/define
   overrides; alter provisioning; or ask the Founder to paste a Terminal
   command. Artifact/signed app identity must be exact; the
   embedded development profile may admit only the literal team wildcard or
   exact Selah application identifier and must contain the intended device.
   Launch evidence includes a 22-second same-PID stability re-query but never
   replaces first-frame/physical acceptance.
9. Static source QA, direct native analyzer, pure local model checks, native
   file-format checks and the delivery-chain structural/preflight check must
   pass before delivery. The current chain passed deeper tool-path review with
   no blocking findings. The corrected Profile Dart layer, staged app bundle and
   strict deep signature are now measured. Device installation, first Flutter
   frame and physical UI remain pending until actually measured and receipted.
10. Preserve import hashes, failed preparation evidence, limitations and new
    Selah-only delivery receipts. Generated build/cache cleanup may remove only
    generated delivery residue; it must not remove source, user data or the
    retained evidence named by the handover. No migration, provider action or
    release is part of this work. Stop on target drift, inherited credential/
    config, signature/registration failure, wrong bundle, unavailable intended
    phone, or source-product overwrite.

Rollback: remove only the separately installed Selah app from the phone if the
Founder chooses. Do not remove ZYRA, shared SDKs, profiles, certificates or
source. No data recovery/production rollback is implied by the local draft.

The sample profile pictures are simple placeholder images made for this project; they show no real people. Earlier versions in the Git history used photos whose source was not recorded.
