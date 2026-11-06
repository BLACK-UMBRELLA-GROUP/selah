# SELAH

SELAH is a Christian marriage application concept. This repository contains a demo that began on 13 October 2026 as a copy of ZYRA (the same owner's matrimonial app) with names and faith content replaced. **Since 3 November 2026 SELAH is being given its own identity** - Christian content and questions, its own look, and its Shepherd and onboarding flows - so its code moves away from ZYRA wherever SELAH differs.

Each change is designed and approved (locked) before it is built; see `APP/APPROVED/BUILD_QUEUE.md`.

## What the demo does

The Flutter demo opens a local Browse experience with Journey, My Selah, Shepherd and Profile presentations. It includes local request and cancellation examples, readiness and Journey progress, viewing history, Christian onboarding questions and sample profile editing. These are fixture-driven demonstrations; displayed requests, messages, scores, credits and settings do not establish live services or commercial products.

The draft has no configured member backend. Account and service integrations are inert, HTTP is denied, fixture state is session-only and release mode refuses the draft. Private developer controls simulate local states. They do not grant server authority.

Sample profile pictures are free stock photos, not real members.

The LOCKed Still Water look uses a light mist canvas, lake accents, bundled Figtree and Cormorant Garamond, and a docked tab bar. Existing loading and failure states use the same theme; no live services are enabled.

Private Home → Explore as a Seeker opens the locked Shepherd invite: choose a trusted supporter, enter their name and send locally. Name validation appears after an empty send attempt and hides when a name is typed. After the invite, the locked consent screen leads to seven faith questions or skips them. Seven marriage questions and a languages question follow. Languages uses the locked ten-choice shortlist and the existing searchable catalogue for Another language. Your values then asks the locked 27 questions in seven parts, followed by one optional Deal-breakers screen. These answers save through the existing local profile and compatibility owners. The Faith Profile, Marriage Values and About You cards read those answers. Compatibility reads the sign-up answers through the approved mapping; Your Values no longer repeats those questions. While waiting, Browse remains available; Request and Accept show the waiting message. The private Shepherd acceptance control restores those actions. Explore as a Shepherd can review the pending local request. No message, share sheet, clipboard link or account link is created.

Journey requests, acceptance, ending and replacement use the locked Selah pause with the existing action limits. Without a Shepherd, requests and acceptance remain unavailable; ending remains possible. Replacement remains the approved atomic local action; retained service paths await the separate backend brief. Browse continues to exclude a pair’s own active Journey; its retired In-a-Journey comparison is archived.

Browse uses the approved fictional Christian cast and faith chips, with optional faith words and the approved public marriage summary. All seven marriage answers are shown in the guarded Journey profile and to the Seeker’s linked Shepherd; the corresponding four Journey Bio prompts are retired without erasing saved values. Its empty state opens the existing filters. Saved background fields remain in storage while their retired prompts and member displays are removed.

The Seeker’s Shepherd tab puts the Main Shepherd first, followed by real local Recent activity, additional Shepherds, Journey access and past Journeys. Its Message action uses the same session-owned Circle messages on reopening. A Seeker can send a local prayer request to the current Main Shepherd; the Shepherd’s Dashboard shows four locked example requests, accepts one “I prayed” per request and records the corresponding My Selah update. Empty, sending and failure states use the existing private Page options.

The opening uses the four locked quiet pages with Back, Next, Skip, Continue and horizontal swipes. It shares the existing Pause presentation and preserves the current continuation.

Offline controls that represent someone else or a server are in the existing private Page options; the member’s own Journey actions remain on screen. Draft-only explanations are private help.

At Open Conversation, the local Journey includes the locked marriage-preparation card. Its three steps can be marked in any order and stay with that local Journey for the session. No courses, external links or live sharing are enabled.

The first-draft handover records passing static and pure-Dart checks and a signed build; on-device checks are still pending. No TestFlight or App Store delivery yet.

## Repository layout

- `SOURCE/` — the Flutter package, local fixtures, tests and private delivery tooling.
- `APP/` — product documents, the first-draft specification and approved design workflow.
- `SYSTEM/` — build contract, as-built handover, actions and supporting records.
- `ROADMAP.md` — tentative major work remaining, with approval gates and effort ranges.

The current implementation and measured limits are described in `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_HANDOVER_CURRENT_VERSION_V1.md`. The build contract is `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_BUILD_CONTRACT_CURRENT_VERSION_V1.md`.

## Local visual checks

Use the existing lockfile with Flutter 3.44.2:

```bash
cd SOURCE
flutter pub get --offline --enforce-lockfile
flutter test --no-pub --dart-define=SELAH_DRAFT_LOCAL_ONLY=true
```

The Browse pack has five applicable states; the retired active-Journey state does not change discovery eligibility. The 320 × 568 layout at double text size remains deferred until its Larger Text design is locked; its header currently overflows.

Approved comparisons use real Flutter widgets at 430 × 932 and pixel ratio 3. Images live under each feature’s `APP/APPROVED/<FEATURE>/BUILT/<version>/` folder. The `APP/APPROVED/COMPARE/` standard explains capture and replay. These checks demonstrate layout and local states; phone installation and native behaviour remain separate.

## Private delivery route

`SOURCE/run.sh` is a specialized private iPhone delivery route. It depends on a prepared local environment, a retained signed native base and matching local signing/provisioning material. It is not a fresh-clone setup script.

The source tooling pins cached Flutter **3.44.2** and Dart **3.12.2**; `SOURCE/pubspec.yaml` declares the Dart constraint `^3.12.2`. Review the project-local integration before changing those versions. The launcher checks its required local artifacts and stops when prerequisites do not match.

Help does not require account or device inputs:

```bash
cd SOURCE
./run.sh --help
```

For a separately approved private delivery, provide your own Apple development team and paired-device identifiers through shell environment variables:

```bash
SELAH_SIGN_ID='YOUR_SIGNING_CERTIFICATE_IDENTITY' \
SELAH_TEAM_ID=YOUR_APPLE_TEAM_ID \
SELAH_DEVICE=YOUR_PAIRED_DEVICE_ID \
./run.sh
```

`--device YOUR_PAIRED_DEVICE_ID` overrides `SELAH_DEVICE`. `--build-only` requires `SELAH_TEAM_ID` and `SELAH_SIGN_ID` but does not require a device; it prepares the local artifact without installation or launch. These are shell environment inputs; the launcher does not read a dotenv file. Keep your actual identifiers out of committed files and reports.

The route validates and compiles the Profile Dart layer against its retained native shell.

## How work is done

The Founder designs with an AI design assistant and locks each design under `APP/APPROVED/<FEATURE>/` (real-size pictures, every state, a measured specification, a lock record in his words). An AI coding assistant builds only from those locked files; every change is a line in `APP/APPROVED/BUILD_QUEUE.md` pointing at its brief. See `ROADMAP.md` for what comes next.

## Licence and branding

Original project code is offered under the Apache License, Version 2.0; see `LICENSE` and `NOTICE`. Third-party components and assets retain their own terms. Existing font licences and notices remain in `SOURCE/assets/fonts/`, including the Figtree and Cormorant Garamond SIL Open Font Licences.

SELAH names, logos and domains are reserved. The code licence does not grant permission to use them as your own branding. Sample assets and inherited third-party notices must not be represented as original contributions by a downstream project.
