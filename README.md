# SELAH

SELAH is a Christian marriage application concept. This repository contains a **frozen demo**, copied from ZYRA on 13 October 2026 with names and faith content replaced. The current copy is not the planned production foundation. After ZYRA launches, SELAH is planned to be rebuilt on a shared engine with ZYRA, subject to Founder approval.

The app remains frozen. This repository preparation does not authorize further app development or a public release. The repository remains private until a separate publication instruction.

## What the demo does

The Flutter demo opens a local Browse experience with Journey, My SELAH, Shepherd and Profile presentations. It includes local request and cancellation examples, readiness and Journey progress, viewing history, Christian onboarding questions and sample profile editing. These are fixture-driven demonstrations; displayed requests, messages, scores, credits and settings do not establish live services or commercial products.

The draft has no configured member backend. Account and service integrations are inert, HTTP is denied, fixture state is session-only and release mode refuses the draft. Private developer controls simulate local states. They do not grant server authority.

Sample profile pictures are free stock photos, not real members.

The historical handover records successful static and pure-Dart checks and a corrected compiled/signed artifact. Corrected device installation, first Flutter frame, stable runtime, unplugged launch and Founder visual acceptance remain pending. No TestFlight or App Store delivery is claimed.

## Repository layout

- `SOURCE/` — the frozen Flutter package, local fixtures, tests and private delivery tooling.
- `APP/` — product documents, the first-draft specification and approved design workflow.
- `SYSTEM/` — build contract, as-built handover, actions and supporting records.
- `ROADMAP.md` — tentative major work remaining, with approval gates and effort ranges.

The current implementation and measured limits are described in `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_HANDOVER_CURRENT_VERSION_V1.md`. The build contract is `SYSTEM/DOCUMENTS/SELAH_FIRST_DRAFT_BUILD_CONTRACT_CURRENT_VERSION_V1.md`.

## Private delivery route

`SOURCE/run.sh` is a specialized private iPhone delivery route. It depends on a prepared local environment, a retained signed native base and matching local signing/provisioning material. It is not a fresh-clone setup script. Do not run it while the app is frozen without a separate, explicit instruction authorizing that delivery.

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

The route validates and compiles the Profile Dart layer against its retained native shell. It is not authorization to install an SDK, rebuild native projects, change signing accounts or activate a backend. No real launcher, Flutter or installer execution was performed for this repository preparation.

## Contributions and approvals

The Founder must lift SELAH's build freeze in writing before app work resumes. The SELAH lead designer records each Founder `LOCK` under `APP/APPROVED/<FEATURE>/`, including real-size pictures, every state, a measured specification and the Founder's words in `LOCK_RECORD.md`. A build brief and a `WAITING` entry in `APP/APPROVED/BUILD_QUEUE.md` define authorized implementation. Implementation follows those locked files exactly.

A roadmap entry is not a build approval. Backend setup, production assets, company formation, store submission and publication require their own Founder decisions.

## Licence and branding

Original project code is offered under the Apache License, Version 2.0; see `LICENSE` and `NOTICE`. Third-party components and assets retain their own terms. Existing font licences and notices remain in `SOURCE/assets/fonts/`, including the Poppins, Syne and Jost notices.

SELAH names, logos and domains are reserved. The code licence does not grant permission to use them as your own branding. Sample assets and inherited third-party notices must not be represented as original contributions by a downstream project.
