// Edit Profile — everything that changes what is ON your profile.
//
// NEW 2026-08-07. Founder: "in settings if the compatibility section is the
// same as edit profile then you gotta maybe move that section into edit
// profile part."
//
// It was. Settings had a COMPATIBILITY section — About you, Lifestyle,
// Marriage preferences, Green/Yellow/Red, Hard requirements — and Profile
// had an "Edit Profile" button pointing at nothing. Two routes to the same
// intention, one of which did not exist yet.
//
// This resolves it against the Founder's own principle, the one that moved
// Connections out of Settings in the first place: "Settings should
// configure the account, not become a duplicate navigation hub." Your sect,
// your lifestyle, what you are looking for in a marriage — none of those
// are account configuration. They are the profile.
//
// SO THE DIVISION IS NOW:
//   Profile → Edit Profile   what you look like to other people
//   Settings                 the account, privacy, notifications, support
//   Connections              relationships
//   Shepherd page            Shepherds
//
// which supersedes the line in settings_screen.dart's header giving
// compatibility to Settings.
//
// NOT INCLUDED YET, deliberately: name, About Me and location are all
// genuinely writable today (they hold column grants on profiles), so a
// Basics section belongs here and would work. It is not written because it
// was not asked for, and inventing a text editor inside a structural move
// is how a move becomes a rewrite. It is the obvious next piece.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../main.dart';
import '../../models/selah_gender.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_pull_down_back_scope.dart';
import 'compatibility_editors.dart';

abstract interface class SelahCompatibilityEditorRepository {
  String? get currentUserId;
  int get accountGeneration;
  bool isCurrentOwner(String userId, int generation);
  Future<SelahOnboardingAnswersSnapshot?> load(String userId);
  Future<bool> save(String userId, SelahCompatibilityDraft draft);
}

class _ServerCompatibilityEditorRepository
    implements SelahCompatibilityEditorRepository {
  const _ServerCompatibilityEditorRepository();

  @override
  String? get currentUserId => supabaseReady ? SelahAuth.currentUser?.id : null;
  @override
  int get accountGeneration => SelahAccountState.generation;
  @override
  bool isCurrentOwner(String userId, int generation) =>
      supabaseReady &&
      !SelahInternalPreviewClient.isActive &&
      SelahAuth.currentUser?.id == userId &&
      SelahAccountState.isCurrent(userId, generation);
  @override
  Future<SelahOnboardingAnswersSnapshot?> load(String userId) =>
      SelahOnboardingAnswersService.fetchOwn(
        expectedUserId: userId,
        throwOnError: true,
      );
  @override
  Future<bool> save(String userId, SelahCompatibilityDraft draft) =>
      SelahOnboardingAnswersService.syncAnswers(
        expectedUserId: userId,
        ch3Answers: draft.answers,
        ch4Preferences: draft.preferences,
        ch4HardRequirements: draft.hardRequirements,
      );
}

class EditProfileScreen extends StatefulWidget {
  final SelahCompatibilityEditorRepository? repository;
  final bool _preview;
  final bool Function()? _previewCanAct;
  final String? _previewGender;
  final int? _previewAge;
  final bool embedded;
  const EditProfileScreen({super.key, this.repository})
    : _preview = false,
      _previewCanAct = null,
      _previewGender = null,
      _previewAge = null,
      embedded = false;

  /// The existing editor with caller-owned local storage and account facts.
  /// This mode cannot fall through to a live repository or global AppState.
  const EditProfileScreen.preview({
    super.key,
    required SelahCompatibilityEditorRepository this.repository,
    required bool Function() canAct,
    required String? gender,
    required int? age,
    this.embedded = true,
  }) : _preview = true,
       _previewCanAct = canAct,
       _previewGender = gender,
       _previewAge = age;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  SelahCompatibilityDraft? _draft;
  late final SelahCompatibilityEditorRepository _repository;
  late final bool _localPreview;
  late final bool _explicitPreview;
  late final bool _embeddedPreview;
  late final bool Function()? _previewOwner;
  late final String? _previewGender;
  late final int? _previewAge;
  bool _previewRevoked = false;
  int _loadEpoch = 0;
  String? _owner;
  int _ownerGeneration = 0;
  bool _loading = false;
  String? _loadError;

  bool get _currentOwner {
    try {
      return _owner != null &&
          _repository.isCurrentOwner(_owner!, _ownerGeneration);
    } catch (_) {
      if (_explicitPreview) _previewRevoked = true;
      return false;
    }
  }

  bool get _previewAvailable {
    if (!mounted || _previewRevoked) return false;
    try {
      if (!widget._preview ||
          widget.repository != _repository ||
          widget._previewCanAct != _previewOwner ||
          widget._previewGender != _previewGender ||
          widget._previewAge != _previewAge ||
          _previewOwner?.call() != true ||
          widget._previewCanAct?.call() != true ||
          !_currentOwner) {
        _previewRevoked = true;
        return false;
      }
    } catch (_) {
      _previewRevoked = true;
      return false;
    }
    return true;
  }

  bool get _canUse =>
      mounted &&
      (_explicitPreview
          ? _previewAvailable
          : _localPreview
          ? SelahInternalPreviewClient.isActive
          : _currentOwner);
  String? get _gender =>
      _explicitPreview ? _previewGender : AppState.instance.gender;
  int? get _age => _explicitPreview ? _previewAge : AppState.instance.age;

  @override
  void initState() {
    super.initState();
    _explicitPreview = widget._preview;
    _embeddedPreview = widget.embedded;
    _previewOwner = widget._previewCanAct;
    _previewGender = widget._previewGender;
    _previewAge = widget._previewAge;
    _repository =
        widget.repository ?? const _ServerCompatibilityEditorRepository();
    _localPreview = !_explicitPreview && SelahInternalPreviewClient.isActive;
    if (_localPreview) {
      // A sticky, unsaved local draft preserves the protected visual preview.
      // It never reads a member row or becomes a live editor after revocation.
      _draft = SelahCompatibilityDraft.fromSnapshot(
        gender: AppState.instance.gender,
        snapshot: null,
      );
    } else {
      try {
        _owner = _repository.currentUserId;
        _ownerGeneration = _repository.accountGeneration;
        _load();
      } catch (_) {
        if (_explicitPreview) _previewRevoked = true;
        _loadError = 'Your sign-in has changed. Reopen Profile to continue.';
      }
    }
  }

  @override
  void didUpdateWidget(covariant EditProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_explicitPreview && !_previewAvailable) {
      ++_loadEpoch;
      _loading = false;
      _draft = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_explicitPreview && !(ModalRoute.of(context)?.isCurrent ?? true)) {
      ++_loadEpoch;
      if (_loading) {
        _loadError = 'We couldn’t load your saved choices. Please try again.';
      }
      _loading = false;
    }
  }

  @override
  void dispose() {
    ++_loadEpoch;
    super.dispose();
  }

  Future<void> _load() async {
    if (_localPreview || _loading) return;
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (!_canUse) throw StateError('The profile account changed.');
      final snapshot = await _repository
          .load(_owner!)
          .timeout(const Duration(seconds: 10));
      if (!mounted || epoch != _loadEpoch) return;
      if (!_canUse) throw StateError('The profile account changed.');
      if (snapshot != null && !_explicitPreview) {
        AppState.instance.saveJourneyBio(snapshot.journeyBio);
      }
      setState(() {
        _draft = SelahCompatibilityDraft.fromSnapshot(
          gender: _gender,
          snapshot: snapshot,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loading = false;
        _draft = null;
        _loadError = _canUse
            ? 'We couldn’t load your saved choices. Please try again.'
            : 'Your sign-in has changed. Reopen Profile to continue.';
      });
    }
  }

  Future<bool> _persist(SelahCompatibilityDraft candidate) async {
    if (_localPreview || !_canUse) return false;
    try {
      final saved = await _repository
          .save(_owner!, candidate.copy())
          .timeout(const Duration(seconds: 10));
      return _canUse && saved;
    } catch (_) {
      return false;
    }
  }

  Future<void> _open(CompatibilityEditorKind kind) async {
    final draft = _draft;
    if (draft == null ||
        !_canUse ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    bool canEdit() => _canUse;
    final updated = await Navigator.of(context).push<SelahCompatibilityDraft>(
      MaterialPageRoute(
        builder: (_) => _explicitPreview
            ? CompatibilityEditorScreen.preview(
                kind: kind,
                initialDraft: draft,
                onPersist: _persist,
                canAct: canEdit,
              )
            : CompatibilityEditorScreen(
                kind: kind,
                initialDraft: draft,
                onPersist: _persist,
              ),
      ),
    );
    if (updated == null ||
        !mounted ||
        !_canUse ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    setState(() => _draft = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_explicitPreview && !_previewAvailable) {
      return const SizedBox.shrink(
        key: ValueKey('edit_profile_preview_denied'),
      );
    }
    if (_localPreview && !SelahInternalPreviewClient.isActive) {
      return const Scaffold(
        key: ValueKey('edit_profile_preview_denied'),
        body: SizedBox.expand(),
      );
    }
    final content = _content();
    if (_explicitPreview) {
      final page = Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Profile',
                  key: const ValueKey('edit_profile_preview_title'),
                  style: SelahText.heading(size: 28),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
      if (_embeddedPreview) return page;
      return SelahPullDownBackScope(
        routeIdentity: this,
        onBack: () {
          if (_canUse &&
              (ModalRoute.of(context)?.isCurrent ?? true) &&
              Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: SelahColors.genderGradient(_gender),
            ),
            child: page,
          ),
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profile', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(_gender),
        ),
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _content() => ListView(
    key: const ValueKey('edit_profile_content_scroll'),
    physics: const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    padding: EdgeInsets.fromLTRB(20, 12, 20, _explicitPreview ? 24 : 90),
    children: [
      Text(
        'Your answers stay private. SELAH uses them to calculate '
        'compatibility and honour your requirements.',
        style: SelahText.subtext(size: 12.5, color: SelahColors.ink(0.54)),
      ),
      SizedBox(height: 22),

      Text(
        'COMPATIBILITY',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
      ),
      SizedBox(height: 10),
      if (_loadError != null)
        SelahErrorBanner(
          key: const ValueKey('edit_profile_load_error'),
          retryKey: const ValueKey('edit_profile_restore_retry'),
          message: _loadError!,
          onRetry: _currentOwner ? _load : null,
        )
      else if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(child: SelahLoading.profile()),
        )
      else if (_draft != null && _canUse)
        for (final kind in CompatibilityEditorKind.values)
          _CompatibilityRow(
            key: ValueKey('compatibility-editor-${kind.name}'),
            kind: kind,
            status: _statusFor(kind, _draft!),
            onTap: () => _open(kind),
          ),

      SizedBox(height: 30),
      // Said HERE because this is where someone looks for it. A
      // person who wants to correct their birth year opens Edit
      // Profile, not Settings, and finding nothing is worse than
      // finding a plain explanation.
      Text(
        'FIXED',
        style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
      ),
      SizedBox(height: 10),
      _FixedRow(
        label: 'Date of birth',
        value: _age == null ? '—' : 'Age $_age',
      ),
      _FixedRow(label: 'Gender', value: SelahGender.profileLabel(_gender)),
      SizedBox(height: 10),
      Text(
        'Your date of birth and gender are saved with your account '
        'essentials and cannot be edited here. If either is wrong, '
        'contact Support.',
        style: SelahText.subtext(size: 12, color: SelahColors.ink(0.38)),
      ),
    ],
  );
}

class _CompatibilityRow extends StatelessWidget {
  const _CompatibilityRow({
    super.key,
    required this.kind,
    required this.status,
    required this.onTap,
  });

  final CompatibilityEditorKind kind;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${kind.label}. $status.',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SelahColors.surfaceFill,
                  border: Border.all(color: SelahColors.surfaceBorder),
                ),
                child: Icon(kind.icon, size: 18, color: SelahColors.ink(0.68)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: SelahText.body(size: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(status, style: SelahText.subtext(size: 11.5)),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: SelahColors.ink(0.45),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _statusFor(
  CompatibilityEditorKind kind,
  SelahCompatibilityDraft draft,
) => switch (kind) {
  CompatibilityEditorKind.aboutYou ||
  CompatibilityEditorKind.lifestyle ||
  CompatibilityEditorKind.marriagePreferences => () {
    final categories = categoriesForKind(kind);
    return '${draft.answeredIn(categories)} of '
        '${draft.questionsIn(categories)} answered';
  }(),
  CompatibilityEditorKind.trafficLights =>
    '${draft.preferenceAnswerCount} of '
        '${draft.preferenceOptionCount} preferences set',
  CompatibilityEditorKind.hardRequirements =>
    draft.hardRequirementCount == 1
        ? '1 introduction-blocking answer'
        : '${draft.hardRequirementCount} introduction-blocking answers',
};

class _FixedRow extends StatelessWidget {
  final String label;
  final String value;
  const _FixedRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: SelahText.body(size: 15, color: SelahColors.ink(0.54)),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: SelahText.subtext(size: 13.5, color: SelahColors.ink(0.65)),
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.lock_outline, size: 15, color: SelahColors.ink(0.24)),
      ],
    ),
  );
}
