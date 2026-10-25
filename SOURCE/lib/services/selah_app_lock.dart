// App Lock — Face ID / Touch ID / device passcode to open SELAH.
//
// NEW 2026-08-07. Founder decision, overriding the review document's own
// hedging: "For SELAH I think this becomes a selling point, not just a
// privacy option."
//
// WHY THIS MATTERS MORE HERE THAN ON A TYPICAL APP. Phones get handed
// around in families. A parent, a sibling or a spouse-to-be picking up an
// unlocked phone is not a rare scenario in this audience — it is a normal
// Tuesday. And what is on screen is not merely private, it is socially
// consequential: who you passed on, who you saved, what your Shepherd said.
// The device passcode makes the PHONE private. Only this makes the APP
// private, and only the second is true when the phone is unlocked and on
// the kitchen table.
//
// ── THIS IS NOT A SECURITY BOUNDARY. Say it plainly, because designing it
// as one would make it worse. The data is protected by RLS and by the
// session token, not by this. Anyone with real device access and intent
// can get past it. It is a privacy screen against the person standing next
// to you, which is the actual threat, and it should never be described to
// a user as anything more.
//
// ── NO PIN, DELIBERATELY. The review document proposed "biometric with a
// 4-digit fallback". That was wrong and is not what was built. A PIN of our
// own would have to be stored somewhere, and the only local store this app
// has is SharedPreferences, which is plain text on disk (see
// selah_local_prefs.dart's own warning). Storing a hash instead would work
// but invents a credential system to guard something that is not a security
// boundary in the first place.
//
// So `biometricOnly: false` — local_auth falls back to the DEVICE's own
// passcode when biometrics fail, are not enrolled, or are locked out. The
// fallback is stronger than any four digits we would have designed, it
// works on devices with no biometric hardware at all, and SELAH stores no
// secret whatsoever. There is nothing here for an attacker to extract.
//
// ── THE ESCAPE HATCH IS REQUIRED, not a courtesy. Biometrics break: a
// cracked sensor, a wet thumb, a face that stopped matching, an OS update
// that lost the enrolment. Because this is not a security boundary, being
// permanently unable to open your own account would be an absurd outcome
// — so the lock screen always offers Sign out, which returns the user to
// Apple or Google. They lose nothing: the account lives on the server, and
// signing back in restores it. A lock you cannot escape is a bug, not a
// feature.

// widgets.dart, NOT foundation.dart. AppLifecycleState is a dart:ui type
// re-exported by widgets; foundation does not carry it, and the failure is
// a compile error rather than anything the static checker can see —
// tools/selah_check.py validates imports and member names, not type
// resolution. widgets re-exports foundation, so ChangeNotifier and
// debugPrint still come along.
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'selah_local_prefs.dart';

class SelahAppLock extends ChangeNotifier {
  SelahAppLock._();

  /// Fresh state for lifecycle and delayed native-authentication regression
  /// tests. Authentication still uses the same local_auth platform boundary.
  @visibleForTesting
  SelahAppLock.forTesting({bool enabled = true, bool locked = false}) {
    _enabled = enabled;
    _locked = locked;
  }

  static final SelahAppLock instance = SelahAppLock._();

  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool _locked = false;
  bool _obscured = false;
  bool _authenticating = false;
  bool? _deviceSupported;
  int _generation = 0;
  bool _disposed = false;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  /// Read from disk in main(), before runApp() — the lock has to be the
  /// first thing painted, so it cannot wait on anything.
  void hydrate() {
    _generation++;
    _enabled = SelahLocalPrefs.appLockEnabled;
    // Locked from the very first frame when enabled. Starting unlocked and
    // locking a moment later would show the app first, which is the whole
    // thing being prevented.
    _locked = _enabled;
  }

  bool get enabled => _enabled;

  /// True when the user must authenticate before seeing anything.
  bool get isLocked => _enabled && _locked;

  /// True while the app is merely inactive — the app switcher, the
  /// notification shade, a system prompt. Content is hidden but no
  /// re-authentication is required. See [handleLifecycle].
  bool get isObscured => _obscured && _enabled && !_locked;

  /// Whether the device can authenticate at all — biometrics OR a passcode.
  /// Null until first checked. A device with neither cannot use this
  /// feature, and the settings screen says so rather than offering a
  /// toggle that silently does nothing.
  bool? get deviceSupported => _deviceSupported;

  Future<bool> checkDeviceSupport() async {
    if (_disposed) return false;
    final generation = _generation;
    bool supported;
    try {
      // isDeviceSupported() is the right question, not canCheckBiometrics:
      // the latter is false on a phone with a passcode and no enrolled
      // biometrics, which is a device this feature works perfectly well on.
      supported = await _auth.isDeviceSupported();
    } on LocalAuthException catch (e) {
      debugPrint('SELAH: app lock support check failed.\n$e');
      supported = false;
    } catch (e) {
      debugPrint('SELAH: app lock support check failed unexpectedly.\n$e');
      supported = false;
    }
    if (!_isCurrent(generation)) return false;
    _deviceSupported = supported;
    notifyListeners();
    return _deviceSupported ?? false;
  }

  /// Turning it ON authenticates first. Enabling a lock you cannot pass is
  /// how someone locks themselves out on purpose without meaning to, so the
  /// toggle proves it works before it takes effect.
  ///
  /// Turning it OFF also authenticates — otherwise anyone holding the
  /// unlocked phone could simply switch the lock off, which would make the
  /// whole feature decorative.
  Future<bool> setEnabled(bool value) async {
    if (_disposed) return false;
    final generation = _generation;
    final ok = await _authenticate(
      value
          ? 'Confirm it works before turning on App Lock'
          : 'Confirm to turn off App Lock',
    );
    if (!ok || !_isCurrent(generation)) return false;

    _enabled = value;
    _locked = false; // just proved themselves either way
    await SelahLocalPrefs.setAppLockEnabled(value);
    if (!_isCurrent(generation)) return false;
    notifyListeners();
    return true;
  }

  Future<bool> unlock() async {
    if (_disposed) return false;
    if (!_locked) return true;
    final generation = _generation;
    final ok = await _authenticate('Unlock SELAH');
    if (!_isCurrent(generation)) return false;
    if (ok) {
      _locked = false;
      _obscured = false;
      notifyListeners();
    }
    return ok;
  }

  /// Signing out clears the preference (selah_local_prefs.clear()), so the
  /// lock must come down with it or the next user meets a lock screen for
  /// a setting that no longer exists.
  ///
  /// Called from SelahAuth.signOut() rather than from the lock screen, so it
  /// holds for EVERY route out — Settings, Developer Access, a session that
  /// expired — not just the one that happened to be built first.
  void clearForSignOut() {
    // A prompt may still finish after sign-out. Its result belongs only to the
    // old lifetime, even if the next account enables App Lock in the meantime.
    _generation++;
    _enabled = false;
    _locked = false;
    _obscured = false;
    notifyListeners();
  }

  Future<bool> _authenticate(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // The point of the whole design — see the header. Device passcode
        // fallback, no credential of ours.
        biometricOnly: false,
        // The OS prompt backgrounds the app on Android; without this the
        // authentication is cancelled by our own lifecycle handling.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      // notEnrolled / passcodeNotSet / lockedOut / permanentlyLockedOut all
      // land here. Logged rather than swallowed — a silent false here looks
      // identical to the user changing their mind, and that ambiguity is
      // exactly what made the pending-invite bug take three attempts.
      debugPrint('SELAH: app lock authentication failed — ${e.code.name}.\n$e');
      return false;
    } catch (e) {
      debugPrint('SELAH: app lock authentication failed unexpectedly.\n$e');
      return false;
    } finally {
      // Keep the native single-flight held across clear/hydrate until this
      // actual prompt finishes; a replacement must not start a second prompt.
      _authenticating = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _disposed = true;
    super.dispose();
  }

  /// ── THE LIFECYCLE SPLIT, which is the fiddly part.
  ///
  /// `inactive` fires for things that are NOT the user leaving: the iOS
  /// app switcher preview, the notification shade, an incoming call banner
  /// — and, critically, the Face ID sheet itself. Re-locking on `inactive`
  /// makes the unlock prompt cancel its own unlock, and the app becomes
  /// impossible to open. So `inactive` only OBSCURES: content is hidden
  /// (which is also what stops the app-switcher snapshot showing someone's
  /// matches), and coming straight back needs no re-authentication.
  ///
  /// `paused` / `hidden` mean the app genuinely went away. That locks.
  void handleLifecycle(AppLifecycleState state) {
    if (!_enabled) return;

    switch (state) {
      case AppLifecycleState.inactive:
        if (!_obscured && !_locked) {
          _obscured = true;
          notifyListeners();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Not while our own OS prompt is on screen — on some platforms it
        // pauses us, and locking here would fight the unlock in progress.
        if (_authenticating) return;
        if (!_locked) {
          _locked = true;
          _obscured = false;
          notifyListeners();
        }
      case AppLifecycleState.resumed:
        if (_obscured) {
          _obscured = false;
          notifyListeners();
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}
