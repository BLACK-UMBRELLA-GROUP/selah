# Selah local iPhone delivery

Selah has a project-local, non-interactive delivery route. After the Founder
says to update the app and the applicable delivery authority is satisfied,
Codex can operate `run.sh` directly. The Founder does not need to paste a
command into Terminal.

## Fixed delivery identity

- configuration: `Profile-draft`
- scheme and flavor: `draft`
- entry point: `lib/main.dart`
- compile-time isolation: `SELAH_DRAFT_LOCAL_ONLY=true`
- bundle identifier: `com.blackumbrella.selah.draft`
- development team: caller-supplied `SELAH_TEAM_ID`
- device target: caller-supplied `SELAH_DEVICE` or `--device`

Export `SELAH_SIGN_ID` with your existing Apple development signing identity,
`SELAH_TEAM_ID` with your Apple development team and `SELAH_DEVICE` with
your paired-device identifier before `./run.sh`. `--device` overrides the device
variable. `./run.sh --help` needs no private inputs. `./run.sh --build-only`
requires the signing identity and team but does not require a device; it performs the artifact checks
and stops before device access. These are shell environment variables; the
route does not read a dotenv file. Public preparation does not authorize a run.

## What the route does

1. Validates the pinned cached Flutter 3.44.2 tools without invoking the
   Flutter shell wrapper.
2. Verifies that the prepared Dart packages and all locked Swift-package
   checkouts already exist locally at their recorded revisions.
3. Generates the exact draft Xcode settings directly from the pinned local
   SDK manifest and project version. It does not enter Flutter's iOS project
   command or Swift-package resolution path.
4. Compiles the Profile Dart layer inside the bounded local sandbox, stages
   it in a copy of the preserved verified native shell and re-signs that staged
   app. Network, Git and Xcode-project builds are denied during compilation.
   It does not pass provisioning-update or device-registration flags.
5. Rejects an artifact unless its source fingerprint, display name, bundle,
   delivery mode, code signature, signing team, application identifier,
   embedded profile and intended device all match.
6. When not in build-only mode, verifies that the phone is unlocked, installs
   the exact checked app, launches it, then queries the installed metadata and
   running process immediately and again after the iOS splash-watchdog window.
7. Retains local evidence under `build/selah-delivery-receipts/`.

`tooling/check_delivery_chain.sh` is the read-only structural check. It does
not compile, sign, install, launch, fetch dependencies, change provisioning or
register a device.

## Fail-closed boundaries

This route never repairs missing dependency caches, changes Flutter versions,
updates Swift packages, creates signing assets, registers devices, configures
an external backend or uploads an app. It stops and reports the missing
prerequisite instead. A successful script receipt proves local artifact and
device delivery; it does not replace Founder acceptance of the running app.

The Flutter-derived project-local backend remains under the BSD terms in
`tooling/LICENSE`.
