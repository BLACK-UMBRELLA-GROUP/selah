import 'package:flutter/material.dart';

import '../models/selah_known_person_code.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_known_person_code_content.dart';
import '../widgets/selah_state_widgets.dart';
import 'selah_view_request_draft_model.dart';

/// A deliberately separate, non-production namespace. Never resolve a real
/// member by guessing from a name, city, photograph or the legacy demo code.
abstract final class SelahDraftKnownPersonCodes {
  static String codeFor(DraftProfile person) {
    if (!draftProfiles.any((known) => identical(known, person))) {
      throw ArgumentError('Not a canonical local profile.');
    }
    return 'SELAH-DRAFT-${person.id.substring('draft-'.length).toUpperCase()}';
  }

  static DraftProfile? resolve(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    for (final person in draftProfiles) {
      if (code == codeFor(person)) return person;
    }
    return null;
  }
}

typedef SelahDraftCodeCaptureBuilder =
    Widget Function(
      BuildContext context,
      bool Function() canCapture,
      ValueChanged<String> onCode,
      VoidCallback onManualEntry,
    );

/// Reuses the existing code-entry UI and actual camera capture. The required
/// caller-owned lookup has no production fallback, telemetry or Consider path.
/// Camera capture stays inline, so it never needs to weaken the parent route's
/// currentness guard. A code identifies a profile, not invitation consent.
class SelahDraftCodeEntry extends StatefulWidget {
  const SelahDraftCodeEntry({
    super.key,
    required this.canAct,
    required this.lookupCode,
    required this.onViewProfile,
    this.captureBuilder,
  });

  final bool Function() canAct;
  final Future<DraftProfile?> Function(String code) lookupCode;
  final ValueChanged<DraftProfile> onViewProfile;
  final SelahDraftCodeCaptureBuilder? captureBuilder;

  @override
  State<SelahDraftCodeEntry> createState() => _SelahDraftCodeEntryState();
}

class _SelahDraftCodeEntryState extends State<SelahDraftCodeEntry>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  DraftProfile? _person;
  String? _error;
  bool _busy = false;
  bool _camera = false;
  bool _closed = false;
  int _lookupEpoch = 0;
  int _cameraEpoch = 0;
  AppLifecycleState? _lifecycle;

  bool _ownerAllows(bool Function() guard) {
    if (_closed) return false;
    try {
      if (guard()) return true;
    } catch (_) {
      // A failed owner check is denial, never an alternate lookup or action.
    }
    _revoke();
    return false;
  }

  bool get _current {
    if (!mounted || _closed) return false;
    if (!_ownerAllows(widget.canAct)) return false;
    return (ModalRoute.of(context)?.isCurrent ?? true) &&
        (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      ++_lookupEpoch;
      ++_cameraEpoch;
      _busy = false;
      _camera = false;
    }
  }

  @override
  void didUpdateWidget(covariant SelahDraftCodeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ownerAllows(oldWidget.canAct) || !_ownerAllows(widget.canAct)) {
      _revoke();
      return;
    }
    if (oldWidget.canAct != widget.canAct ||
        oldWidget.lookupCode != widget.lookupCode ||
        oldWidget.onViewProfile != widget.onViewProfile ||
        oldWidget.captureBuilder != widget.captureBuilder) {
      ++_lookupEpoch;
      ++_cameraEpoch;
      _busy = false;
      _camera = false;
      _person = null;
      _error = null;
      _controller.clear();
    }
  }

  void _revoke() {
    _closed = true;
    _busy = false;
    _camera = false;
    _person = null;
    ++_lookupEpoch;
    ++_cameraEpoch;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      ++_lookupEpoch;
      if (mounted) {
        setState(() {
          _busy = false;
          // Permission prompts are inactive-only. A genuine backgrounded
          // capture session must be restarted deliberately after returning.
          if (state == AppLifecycleState.hidden ||
              state == AppLifecycleState.paused ||
              state == AppLifecycleState.detached) {
            ++_cameraEpoch;
            _camera = false;
          }
        });
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ++_lookupEpoch;
    ++_cameraEpoch;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_current || _busy) return;
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    final guard = widget.canAct;
    final lookup = widget.lookupCode;
    final epoch = ++_lookupEpoch;
    setState(() {
      _busy = true;
      _person = null;
      _error = null;
    });
    DraftProfile? person;
    bool failed = false;
    try {
      if (code.length <= 200 && code.toUpperCase().startsWith('SELAH-')) {
        person = await lookup(code).timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      failed = true;
    }
    if (!mounted || epoch != _lookupEpoch) return;
    if (!_current || !_ownerAllows(guard)) {
      setState(_revoke);
      return;
    }
    // Editing while a check is outstanding must not publish an old identity.
    if (_controller.text.trim() != code) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _person = person;
      if (failed) {
        _error = "The code couldn't be checked. Please try again.";
      } else if (person == null) {
        _error = 'That code is not available.';
      }
    });
    if (person != null) _focusNode.unfocus();
  }

  void _scan() {
    if (!_current || _busy) return;
    ++_lookupEpoch;
    ++_cameraEpoch;
    _focusNode.unfocus();
    setState(() {
      _person = null;
      _error = null;
      _camera = true;
    });
  }

  void _reset() {
    if (!_current || _busy) return;
    ++_lookupEpoch;
    setState(() {
      _controller.clear();
      _person = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) _focusNode.requestFocus();
    });
  }

  Widget _capture() {
    final epoch = _cameraEpoch;
    final guard = widget.canAct;
    bool canCapture() =>
        _current && _ownerAllows(guard) && _camera && epoch == _cameraEpoch;
    void manualEntry() {
      if (!canCapture()) return;
      setState(() {
        ++_cameraEpoch;
        _camera = false;
      });
    }

    void captured(String code) {
      if (!canCapture()) return;
      setState(() {
        ++_cameraEpoch;
        _camera = false;
        _controller.text = code;
      });
      _check();
    }

    return widget.captureBuilder?.call(
          context,
          canCapture,
          captured,
          manualEntry,
        ) ??
        SelahCodeCapture(
          canCapture: canCapture,
          onCode: captured,
          onManualEntry: manualEntry,
        );
  }

  @override
  Widget build(BuildContext context) {
    _ownerAllows(widget.canAct);
    if (_closed) return const SizedBox.shrink();
    final person = _person;
    final resultEpoch = _lookupEpoch;
    return SafeArea(
      child: Column(
        key: const ValueKey('draft_scan_presentation'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Scan',
              key: const ValueKey('draft_scan_title'),
              style: SelahText.heading(size: 28),
            ),
          ),
          Expanded(
            child: _camera
                ? _capture()
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      key: const ValueKey('draft_scan_entry_scroll'),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 44).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelahKnownPersonCodeContent(
                              controller: _controller,
                              focusNode: _focusNode,
                              preview: person == null
                                  ? null
                                  : SelahKnownPersonCodePreview(
                                      firstName: person.firstName,
                                      age: person.age,
                                      city: person.city,
                                    ),
                              busy: _busy,
                              onScan: _busy ? null : _scan,
                              onCheck: _check,
                              onReset: _reset,
                              resultAction: person == null
                                  ? null
                                  : () {
                                      if (_current &&
                                          resultEpoch == _lookupEpoch &&
                                          identical(person, _person)) {
                                        widget.onViewProfile(person);
                                      }
                                    },
                              resultActionLabel: 'View profile',
                              resultActionKey: const ValueKey(
                                'draft_known_person_view',
                              ),
                              introDetail:
                                  'Scan or enter their permanent SELAH Code '
                                  'to find their profile.',
                              resultDetail:
                                  'Check that this is the right person, '
                                  'then view their profile.',
                            ),
                            if (_error case final error?) ...[
                              const SizedBox(height: 14),
                              SelahErrorBanner(
                                message: error,
                                onDismiss: () {
                                  if (_current) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
