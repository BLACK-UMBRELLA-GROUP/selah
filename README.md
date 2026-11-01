# SELAH

SELAH is a Christian marriage application concept. This repository contains a **frozen demo**, copied from ZYRA on 13 October 2026 with names and faith content replaced. The current copy is not the planned production foundation. After ZYRA launches, SELAH is planned to be rebuilt on a shared engine with ZYRA, subject to Founder approval.

Development is paused until ZYRA launches; the demo is kept so the Christian version of the product can be reviewed and designed in the meantime.

## What the demo does

The Flutter demo opens a local Browse experience with Journey, My SELAH, Shepherd and Profile presentations. It includes local request and cancellation examples, readiness and Journey progress, viewing history, Christian onboarding questions and sample profile editing. These are fixture-driven demonstrations; displayed requests, messages, scores, credits and settings do not establish live services or commercial products.

The draft has no configured member backend. Account and service integrations are inert, HTTP is denied, fixture state is session-only and release mode refuses the draft. Private developer controls simulate local states. They do not grant server authority.

Sample profile pictures are free stock photos, not real members.

The first-draft handover records passing static and pure-Dart checks and a signed build; on-device checks are still pending. No TestFlight or App Store delivery yet.

## Repository layout

- `SOURCE/` — the frozen Flutter package, local fixtures, tests and private delivery tooling.
- `APP/` — product documents, the first-draft specification and approved design workflow.
- `SYSTEM/` — build contract, as-built handover, actions and supporting records.
- `ROADMAP.md` — tentative major work remaining, with approval gates and effort ranges.

The current implementation and measured limits are described in `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_HANDOVER_CURRENT_VERSION_V1.md`. The build contract is `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_BUILD_CONTRACT_CURRENT_VERSION_V1.md`.

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

Original project code is offered under the Apache License, Version 2.0; see `LICENSE` and `NOTICE`. Third-party components and assets retain their own terms. Existing font licences and notices remain in `SOURCE/assets/fonts/`, including the Poppins, Syne and Jost notices.

SELAH names, logos and domains are reserved. The code licence does not grant permission to use them as your own branding. Sample assets and inherited third-party notices must not be represented as original contributions by a downstream project.
