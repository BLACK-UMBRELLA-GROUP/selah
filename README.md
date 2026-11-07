# SELAH

SELAH is a Christian marriage application concept. This repository contains a demo that began on 13 October 2026 as a copy of ZYRA (the same owner's matrimonial app) with names and faith content replaced. **Since 3 November 2026 SELAH is being given its own identity** - Christian content and questions, its own look, and its Shepherd and onboarding flows - so its code moves away from ZYRA wherever SELAH differs.

Each change is designed and approved (locked) before it is built; see `APP/APPROVED/BUILD_QUEUE.md`.

## What the demo does

The Flutter demo opens a local Browse experience with Journey, My Selah, Shepherd and Profile presentations. It includes local request and cancellation examples, readiness and Journey progress, viewing history, Christian onboarding questions and sample profile editing. These are fixture-driven demonstrations; displayed requests, messages, scores, credits and settings do not establish live services or commercial products.

The draft has no configured member backend. Account and service integrations are inert, HTTP is denied, fixture state is session-only and release mode refuses the draft. Private developer controls simulate local states. They do not grant server authority.

The sample profile pictures are simple placeholder images made for this project; they show no real people. Earlier versions in the Git history used photos whose source was not recorded. The placeholders use this repository’s existing Apache-2.0 licence; see `LICENSE`.

The LOCKed Still Water look uses a light mist canvas, lake accents, bundled Figtree and Cormorant Garamond, and a docked tab bar. Existing loading and failure states use the same theme; no live services are enabled. Member text uses “Selah”; profile actions read “Request a Journey”, or “Request later” while waiting for the Shepherd. The shared quiet-page labels render in capitals; Pause and Prayer use the same recorded short Shepherd display name as the Shepherd tab.

Private Home → Explore as a Seeker opens the locked Shepherd invite: choose a trusted supporter, enter their name and send locally. Name validation appears after an empty send attempt and hides when a name is typed. After the invite, the locked consent screen leads to seven faith questions or skips them. Seven marriage questions and a languages question follow. Languages uses the locked ten-choice shortlist and the existing searchable catalogue for Another language. Your values then asks the locked 27 questions in seven parts, followed by one optional Deal-breakers screen. These answers save through the existing local profile and compatibility owners. The Faith Profile, Marriage Values and About You cards read those answers. Compatibility reads the sign-up answers through the approved mapping; Your Values no longer repeats those questions. While waiting, Browse remains available; Request and Accept show the waiting message. The private Shepherd acceptance control restores those actions. Explore as a Shepherd can review the pending local request. No message, share sheet, clipboard link or account link is created.

Journey requests, acceptance, ending and replacement use the locked Selah pause with the existing action limits. Without a Shepherd, requests and acceptance remain unavailable; ending remains possible. Replacement remains the approved atomic local action; retained service paths await the separate backend brief. Browse continues to exclude a pair’s own active Journey; its retired In-a-Journey comparison is archived.

Browse uses the approved fictional Christian cast and faith chips, with optional faith words and the approved public marriage summary. All seven marriage answers are shown in the guarded Journey profile and to the Seeker’s linked Shepherd; the corresponding four Journey Bio prompts are retired without erasing saved values. Its empty state opens the existing filters. Saved background fields remain in storage while their retired prompts and member displays are removed.

The Seeker’s Shepherd tab puts the Main Shepherd first, followed by real local Recent activity, additional Shepherds, Journey access and past Journeys. Its Message action uses the same session-owned Circle messages on reopening. A Seeker can send a local prayer request to the current Main Shepherd; the Shepherd’s Dashboard shows four locked example requests, accepts one “I prayed” per request and records the corresponding My Selah update. Empty, sending and failure states use the existing private Page options.

The opening uses the four locked quiet pages with Back, Next, Skip, Continue and horizontal swipes. It shares the existing Pause presentation and preserves the current continuation.

Offline controls that represent someone else or a server are in the existing private Page options; the member’s own Journey actions remain on screen. Draft-only explanations are private help.

At Open Conversation, the local Journey includes the locked marriage-preparation card. Its three steps can be marked in any order and stay with that local Journey for the session. No courses, external links or live sharing are enabled.

History: the first-draft handover recorded passing static and pure-Dart checks and a signed build, with device checks pending at that earlier attempt. Private delivery to the Founder’s iPhone worked on 6 November 2026. Founder visual acceptance and live services are not established; Android remains held on Question 17. No TestFlight or App Store delivery is established.

The draft Shepherd tab is now Introduce. A Main Shepherd can suggest an eligible profile for James or the separately scoped Joel fixture. Each uses their own discovery state; a suggestion creates one account-local Introduction and sends nothing to the other person. The Seeker sees it on My Selah and Introductions, can open that person in Browse, or dismiss it privately. Seen and dismissed states are not disclosed to the Shepherd. The retained connected-service Network is unchanged and remains inactive in this offline entrypoint. Dashboard shows Prayer requests, actionable Needs you, recent check-ins and Updates. Check-ins come only from successful recorded stage advances in the existing local Journey owner, cover seven days and show at most three; their actions open the same guarded Circle. The Dashboard no longer repeats the family snapshot or offers paid Insights. Existing retained priority/Updates failure and last-known states remain; no completion event is relabelled as an unproved stage entry.

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

`SOURCE/run.sh` is a specialized private iPhone delivery route. It depends on a prepared local environment, a reviewed signed native base and matching local signing/provisioning material. It is not a fresh-clone setup script. The separately approved 6 November repair rebuilt that base with the existing iPhoneOS 27.2 SDK and the pinned Flutter/Dart tools. Dart dependencies came from the offline cache; the eight locked Swift checkouts were restored from Xcode's cache. No tool, SDK or package version was upgraded.

The repaired route installed and opened the app on the intended paired iPhone, verified the same process after 22 seconds, and captured a visible Flutter screen. The later phone update includes the approved Introduce, Dashboard, seven-stage Journey and Family Compatibility changes; its post-update check again passed, and a private app-switcher frame showed the rendered Browse screen. This proves private draft delivery; it does not establish Founder visual acceptance or live services. On the Founder’s follow-up iPhone icon request, the existing iOS host was rebuilt and reinstalled with the exact LOCK23 light icon and centred wordmark launch screen. Android remains held on Question17 because this checkout has no Android host; the full cross-platform queue line is not complete.

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

`--device YOUR_PAIRED_DEVICE_ID` overrides `SELAH_DEVICE`. `--build-only` also requires the explicit intended device so the development profile can be checked; it prepares the local artifact without installation or launch. These are shell environment inputs; the launcher does not read a dotenv file. Keep your actual identifiers out of committed files and reports.

The route validates and compiles the Profile Dart layer against its reviewed native shell. Compilation denies network, Git and Xcode-project builds. Complete input/content pins, strict signatures, an unexpired development profile, exact physical-device identity and pairing, unlocked state and the 22-second same-PID check all remain mandatory. Changing source requires a separately reviewed compiled-content pin; changing native resources requires rebuilding and reviewing the native base.

Delivery regression checks use existing tools:

```bash
cd SOURCE
python3 -B -m unittest tooling.test_macho_content_digest
./tooling/flutter_env.sh # verifies the pinned cached tool identity
/opt/homebrew/Caskroom/flutter/3.44.2/flutter/bin/cache/dart-sdk/bin/dart tool/test_delivery_receipts.dart
```

## How work is done

The Founder designs with an AI design assistant and locks each design under `APP/APPROVED/<FEATURE>/` (real-size pictures, every state, a measured specification, a lock record in his words). An AI coding assistant builds only from those locked files; every change is a line in `APP/APPROVED/BUILD_QUEUE.md` pointing at its brief. See `ROADMAP.md` for what comes next.

## Licence and branding

Original project code is offered under the Apache License, Version 2.0; see `LICENSE` and `NOTICE`. Third-party components and assets retain their own terms. Existing font licences and notices remain in `SOURCE/assets/fonts/`, including the Figtree and Cormorant Garamond SIL Open Font Licences.

SELAH names, logos and domains are reserved. The code licence does not grant permission to use them as your own branding. Sample assets and inherited third-party notices must not be represented as original contributions by a downstream project.

The draft Journey now has seven visible stages. Compatibility Reveal goes directly to Faith & Values; the former Shepherd support step is no longer shown. Headers use the current stage and Main Shepherd names only, with the recorded generic fallback for unnamed peers. Seeker captions use “Stage n of 7”; Shepherd captions omit the total. Retained older Journeys pass the legacy gate only after the existing guarded server result and authoritative refresh confirm a visible stage; refusal or an unknown stage stays on the existing retry state. Existing Main admission and Family Review remain required.

Family Compatibility now asks the four locked questions, with a 400-character limit and a count for each answer. Each Seeker sends their own set; sending, retry and read-only sent states use the same Journey owner. Both independent sets must be sent before the existing Continue and Family Review checks can progress. Old question rows remain stored but are no longer displayed. Draft answers stay in this local session; the retained connected path reads each real answerer separately and confirms the exact submitted answers before reporting success.
