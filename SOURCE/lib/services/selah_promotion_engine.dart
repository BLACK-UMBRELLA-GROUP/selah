// Notification education and compatibility entry points for retired promotions.
// Paid-only product direction, 2026-09-13: commercial campaigns are removed.
// Legacy product/argument identifiers remain callable while their screen owners
// migrate; they never create an offer, retain campaign state, or grant access.
// Only notification education preferences persist. Developer evidence remains
// local and allowlisted; there is no analytics SDK or production collection.

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'selah_developer_access.dart';
import 'selah_local_prefs.dart';

enum SelahPromotionRole { seeker, shepherd }

enum SelahPromotionProduct { notifications, selahOne, shepherdPlus }

enum SelahPromotionFeature {
  deviceNotifications,
  generalMembership,
  shepherdNetwork,
  planLimit,
  adFreeBrowsing,
  selahIntelligence,
}

enum SelahPromotionPlacement { home, profile, shepherdNetwork, lockedFeature }

enum SelahPromotionTrigger {
  firstActiveJourney,
  firstSeekerLink,
  saveSucceeded,
  considerSucceeded,
  mutualMatch,
  journeyStageCompleted,
  familyReviewSaved,
  shepherdActionCompleted,
  manualPlanEntry,
  lockedFeatureTap,
  developerPreview,
}

enum SelahPromotionIntent { proactive, lockedFeatureTap, manualPlanEntry }

enum SelahPromotionDependency { ready, missing, serviceUnavailable, notBuilt }

/// Fixed, non-sensitive reason codes only. No safety cause, score, answer or
/// relationship identifier can enter the evaluator.
enum SelahPromotionExclusion {
  none,
  launch,
  onboarding,
  authentication,
  recovery,
  verification,
  osPermission,
  anotherModal,
  keyboardCritical,
  safetyOrModeration,
  shepherdChange,
  journeyDecision,
  familyDecision,
  compatibilityReveal,
  paymentFailure,
  safetyCooldown,
  journeyCooldown,
}

enum SelahPromotionDecisionKind {
  hidden,
  inlineInvitation,
  lockedExplanation,
  notificationEducation,
  openPlanOnUserTap,
  openDeviceSettingsOnUserTap,
}

enum SelahNotificationPermissionState {
  unavailable,
  notDetermined,
  enabled,
  denied,
  restricted,
}

enum SelahPromotionDismissal { close, notNow, notInterested, dontShow }

/// Developer-only Shepherd Network access matrix. Production access is always
/// resolved from live link and entitlement services; this value is never
/// persisted and cannot change either source of truth.
enum SelahDeveloperShepherdNetworkState {
  d14Preview,
  unlinkedBasic,
  linkedBasic,
  unlinkedEntitled,
  linkedEntitledUnavailable,
}

@immutable
class SelahPromotionOffer {
  final SelahPromotionProduct product;
  final SelahPromotionRole role;
  final SelahPromotionPlacement placement;
  final SelahPromotionFeature feature;
  final SelahPromotionTrigger trigger;
  final SelahPromotionDependency dependency;
  final bool developerPreview;

  const SelahPromotionOffer({
    required this.product,
    required this.role,
    required this.placement,
    required this.feature,
    required this.trigger,
    this.dependency = SelahPromotionDependency.ready,
    this.developerPreview = false,
  });

  String get targetProduct => switch (product) {
    SelahPromotionProduct.notifications => 'notifications',
    SelahPromotionProduct.selahOne => 'selah_one',
    SelahPromotionProduct.shepherdPlus => 'shepherd_plus',
  };

  String get title => switch (product) {
    SelahPromotionProduct.notifications =>
      role == SelahPromotionRole.seeker
          ? 'Stay close to your Journey'
          : 'Stay close to the people you support',
    SelahPromotionProduct.selahOne || SelahPromotionProduct.shepherdPlus => '',
  };

  String get message => switch (product) {
    SelahPromotionProduct.notifications =>
      dependency != SelahPromotionDependency.ready
          ? 'Device alerts are not connected in this build yet. Updates in My Selah still work.'
          : role == SelahPromotionRole.seeker
          ? 'Turn on notifications for replies and decisions that need you. You can change this any time.'
          : 'Turn on notifications for requests and Journey decisions that need you. You can change this any time.',
    SelahPromotionProduct.selahOne || SelahPromotionProduct.shepherdPlus => '',
  };

  String get actionLabel => switch (product) {
    SelahPromotionProduct.notifications =>
      dependency == SelahPromotionDependency.ready
          ? 'Enable notifications'
          : 'Not connected yet',
    SelahPromotionProduct.selahOne || SelahPromotionProduct.shepherdPlus => '',
  };
}

@immutable
class SelahPromotionPromptHistory {
  final DateTime policyFirstSeen;
  final int notificationExplainers;
  final int rollingUpgradeImpressions;
  final bool proactiveShownThisSession;

  const SelahPromotionPromptHistory({
    required this.policyFirstSeen,
    required this.notificationExplainers,
    required this.rollingUpgradeImpressions,
    required this.proactiveShownThisSession,
  });
}

@immutable
class SelahPromotionRequest {
  final SelahPromotionRole roleContext;
  final SelahPromotionProduct targetProduct;
  final SelahPromotionFeature feature;
  final SelahPromotionPlacement placement;
  final SelahPromotionTrigger trigger;
  final SelahPromotionIntent presentationIntent;
  final bool isEntitled;
  final SelahPromotionDependency dependency;
  final bool isOnboardingComplete;
  final bool hasSuccessfulValueMarker;
  final bool isCalmLanding;
  final bool offerAvailable;
  final SelahPromotionExclusion exclusion;
  final SelahPromotionPromptHistory history;

  const SelahPromotionRequest({
    required this.roleContext,
    required this.targetProduct,
    required this.feature,
    required this.placement,
    required this.trigger,
    required this.presentationIntent,
    required this.isEntitled,
    required this.dependency,
    required this.isOnboardingComplete,
    required this.hasSuccessfulValueMarker,
    required this.isCalmLanding,
    required this.offerAvailable,
    required this.exclusion,
    required this.history,
  });
}

@immutable
class SelahPromotionDecision {
  final SelahPromotionDecisionKind kind;
  final String reason;
  final SelahPromotionOffer? offer;

  const SelahPromotionDecision._(this.kind, this.reason, [this.offer]);

  const SelahPromotionDecision.hidden(String reason)
    : this._(SelahPromotionDecisionKind.hidden, reason);

  const SelahPromotionDecision.show(
    SelahPromotionDecisionKind kind,
    SelahPromotionOffer offer,
  ) : this._(kind, 'eligible', offer);
}

@immutable
class SelahPromotionAnalyticsEvent {
  final String name;
  final DateTime occurredAt;
  final Map<String, String> attributes;

  const SelahPromotionAnalyticsEvent({
    required this.name,
    required this.occurredAt,
    required this.attributes,
  });
}

class SelahPromotionEngine extends ChangeNotifier {
  SelahPromotionEngine({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final SelahPromotionEngine instance = SelahPromotionEngine();

  static const policyVersion = '2026-09-13-notifications-only';
  static const notificationCooldown = Duration(days: 30);
  static const notificationLifetimeLimit = 2;
  final DateTime Function() _now;
  bool _initialized = false;
  int _accountEpoch = 0;
  DateTime? _policyStartedAt;

  bool _notificationPending = false;
  SelahPromotionRole? _notificationRole;
  SelahPromotionTrigger _notificationTrigger =
      SelahPromotionTrigger.firstActiveJourney;
  int _notificationImpressions = 0;
  DateTime? _notificationCooldownUntil;
  bool _notificationNeverAsk = false;

  SelahPromotionOffer? _developerOffer;
  SelahDeveloperShepherdNetworkState _developerShepherdNetworkState =
      SelahDeveloperShepherdNetworkState.d14Preview;
  SelahNotificationPermissionState _permissionState =
      SelahNotificationPermissionState.unavailable;

  final List<SelahPromotionAnalyticsEvent> _events = [];
  final Set<String> _decisionEvidence = {};
  List<SelahPromotionAnalyticsEvent> get developerEvents =>
      List.unmodifiable(_events);
  SelahNotificationPermissionState get permissionState => _permissionState;
  SelahDeveloperShepherdNetworkState get developerShepherdNetworkState =>
      _developerShepherdNetworkState;

  Future<void> initialize() async {
    if (_initialized) return;
    final epoch = _accountEpoch;
    _resetMemory(keepEvents: true);
    final raw = SelahLocalPrefs.promotionPolicy;
    if (raw != null) {
      try {
        _hydrate(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (error) {
        debugPrint(
          'SELAH promotion policy could not be read; starting clean.\n$error',
        );
      }
    }
    _policyStartedAt ??= _now().toUtc();
    _initialized = true;
    await _persist();
    if (epoch != _accountEpoch) return;
    notifyListeners();
  }

  /// Synchronous principal boundary: drop memory before any disk cleanup.
  /// This never persists old policy into the newly bound account.
  void resetForAccountChange() {
    _accountEpoch++;
    _resetMemory(keepEvents: false);
    _initialized = false;
    notifyListeners();
  }

  Future<void> clearForSignOut() async {
    resetForAccountChange();
    await SelahLocalPrefs.clearPromotionPolicy();
  }

  Future<void> clearForAccountSwitch() => clearForSignOut();

  Future<void> markNotificationValueMoment({
    required SelahPromotionRole role,
    required SelahPromotionTrigger trigger,
  }) async {
    final epoch = _accountEpoch;
    if (_notificationNeverAsk ||
        _notificationImpressions >= notificationLifetimeLimit) {
      return;
    }
    _notificationPending = true;
    _notificationRole = role;
    _notificationTrigger = trigger;
    await _persist();
    if (epoch != _accountEpoch) return;
    notifyListeners();
  }

  /// Compatibility entry point; commercial value moments are retired.
  Future<void> markUpgradeValueMoment({
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required SelahPromotionPlacement placement,
    required SelahPromotionFeature feature,
    required SelahPromotionTrigger trigger,
  }) async {}

  SelahPromotionPromptHistory get promptHistory => SelahPromotionPromptHistory(
    policyFirstSeen: _policyStartedAt ?? _now().toUtc(),
    notificationExplainers: _notificationImpressions,
    rollingUpgradeImpressions: 0,
    proactiveShownThisSession: false,
  );

  /// The single screen-facing entry. It assembles the current prompt-history
  /// snapshot and routes notification education through [evaluate].
  SelahPromotionDecision decisionForSurface({
    required SelahPromotionRole role,
    required SelahPromotionPlacement placement,
    required bool isCalmLanding,
    required bool isEntitled,
    required bool upgradeOfferAvailable,
    SelahPromotionExclusion exclusion = SelahPromotionExclusion.none,
  }) {
    final forced = _developerOffer;
    if (forced != null &&
        forced.product == SelahPromotionProduct.notifications &&
        forced.role == role &&
        isCalmLanding &&
        exclusion == SelahPromotionExclusion.none) {
      return SelahPromotionDecision.show(
        SelahPromotionDecisionKind.notificationEducation,
        forced,
      );
    }

    if (_notificationPending && _notificationRole == role) {
      final notificationRequest = SelahPromotionRequest(
        roleContext: role,
        targetProduct: SelahPromotionProduct.notifications,
        feature: SelahPromotionFeature.deviceNotifications,
        placement: placement,
        trigger: _notificationTrigger,
        presentationIntent: SelahPromotionIntent.proactive,
        isEntitled: _permissionState == SelahNotificationPermissionState.enabled,
        dependency:
            _permissionState == SelahNotificationPermissionState.unavailable
            ? SelahPromotionDependency.notBuilt
            : SelahPromotionDependency.ready,
        isOnboardingComplete: true,
        hasSuccessfulValueMarker: true,
        isCalmLanding: isCalmLanding,
        offerAvailable: true,
        exclusion: exclusion,
        history: promptHistory,
      );
      final notificationDecision = _recordDecision(
        notificationRequest,
        evaluate(notificationRequest),
      );
      if (notificationDecision.kind != SelahPromotionDecisionKind.hidden) {
        return notificationDecision;
      }
    }

    return const SelahPromotionDecision.hidden('no_notification_candidate');
  }

  /// Compatibility boundary for older locked-feature callers. Commercial
  /// requests are hidden; feature owners render their own availability state.
  SelahPromotionDecision decisionForLockedFeature({
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required SelahPromotionFeature feature,
    required SelahPromotionPlacement placement,
    required bool isEntitled,
    SelahPromotionDependency dependency = SelahPromotionDependency.ready,
  }) {
    final request = SelahPromotionRequest(
      roleContext: role,
      targetProduct: product,
      feature: feature,
      placement: placement,
      trigger: SelahPromotionTrigger.lockedFeatureTap,
      presentationIntent: SelahPromotionIntent.lockedFeatureTap,
      isEntitled: isEntitled,
      dependency: dependency,
      isOnboardingComplete: true,
      hasSuccessfulValueMarker: true,
      isCalmLanding: true,
      offerAvailable: true,
      exclusion: SelahPromotionExclusion.none,
      history: promptHistory,
    );
    return _recordDecision(request, evaluate(request));
  }

  /// Notification requests obey the stored permission/education preferences.
  /// Every commercial request is refused before a display intent is evaluated.
  SelahPromotionDecision evaluate(SelahPromotionRequest request) {
    if (request.targetProduct != SelahPromotionProduct.notifications) {
      return const SelahPromotionDecision.hidden(
        'commercial_promotions_retired',
      );
    }
    if (request.exclusion != SelahPromotionExclusion.none) {
      return SelahPromotionDecision.hidden('excluded_${request.exclusion.name}');
    }
    if (!request.isOnboardingComplete) {
      return const SelahPromotionDecision.hidden('onboarding_incomplete');
    }
    if (!request.isCalmLanding) {
      return const SelahPromotionDecision.hidden('not_calm_landing');
    }
    if (!request.hasSuccessfulValueMarker) {
      return const SelahPromotionDecision.hidden('no_successful_value_marker');
    }
    if (request.isEntitled ||
        _permissionState == SelahNotificationPermissionState.enabled) {
      _notificationPending = false;
      unawaited(_persist());
      return const SelahPromotionDecision.hidden('permission_enabled');
    }
    if (_permissionState == SelahNotificationPermissionState.denied ||
        _permissionState == SelahNotificationPermissionState.restricted) {
      _notificationPending = false;
      _notificationNeverAsk = true;
      unawaited(_persist());
      return const SelahPromotionDecision.hidden('permission_final');
    }
    final cooling =
        _notificationCooldownUntil?.isAfter(_now().toUtc()) ?? false;
    if (cooling ||
        _notificationNeverAsk ||
        _notificationImpressions >= notificationLifetimeLimit) {
      return const SelahPromotionDecision.hidden('notification_cooldown');
    }
    return SelahPromotionDecision.show(
      SelahPromotionDecisionKind.notificationEducation,
      _offerFrom(request),
    );
  }

  SelahPromotionOffer _offerFrom(SelahPromotionRequest request) =>
      SelahPromotionOffer(
        product: request.targetProduct,
        role: request.roleContext,
        placement: request.placement,
        feature: request.feature,
        trigger: request.trigger,
        dependency: request.dependency,
      );

  Future<void> recordImpression(SelahPromotionOffer offer) async {
    if (offer.product != SelahPromotionProduct.notifications) return;
    _track('notification_education_shown', offer);
    if (offer.developerPreview) return;
    _notificationImpressions++;
    await _persist();
  }

  Future<void> dismiss(
    SelahPromotionOffer offer, {
    required SelahPromotionDismissal dismissal,
  }) async {
    final epoch = _accountEpoch;
    if (offer.product != SelahPromotionProduct.notifications) return;
    _track('notification_education_dismissed', offer, {
      'outcome': dismissal.name,
    });
    if (offer.developerPreview) {
      _developerOffer = null;
      notifyListeners();
      return;
    }
    if (dismissal == SelahPromotionDismissal.dontShow ||
        _notificationImpressions >= notificationLifetimeLimit) {
      _notificationNeverAsk = true;
      _notificationPending = false;
    } else {
      _notificationCooldownUntil = _now().toUtc().add(notificationCooldown);
    }
    await _persist();
    if (epoch != _accountEpoch) return;
    notifyListeners();
  }

  Future<void> recordOpened(SelahPromotionOffer offer) async {
    final epoch = _accountEpoch;
    if (offer.product != SelahPromotionProduct.notifications) return;
    _track('notification_permission_requested', offer);
    await _persist();
    if (epoch != _accountEpoch) return;
    notifyListeners();
  }

  Future<SelahNotificationPermissionState> requestNotificationPermission(
    SelahPromotionOffer offer,
  ) async {
    final epoch = _accountEpoch;
    // The production gateway remains unavailable until APNs/FCM and token
    // registration are built. Developer preview simulates the real positive
    // transition so the complete UI can be rehearsed without lying in release.
    if (offer.product != SelahPromotionProduct.notifications ||
        !offer.developerPreview ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return SelahNotificationPermissionState.unavailable;
    }
    _permissionState = SelahNotificationPermissionState.enabled;
    _notificationPending = false;
    _developerOffer = null;
    _track('notification_permission_result', offer, {'outcome': 'enabled'});
    await _persist();
    if (epoch != _accountEpoch) {
      return SelahNotificationPermissionState.unavailable;
    }
    notifyListeners();
    return _permissionState;
  }

  /// Retained for older callers; commercial suggestions cannot be re-enabled.
  Future<void> setUpgradeSuggestionsEnabled(
    SelahPromotionProduct product,
    bool enabled,
  ) async {}

  bool upgradeSuggestionsEnabled(SelahPromotionProduct product) => false;

  Future<void> recordUpgradeScreenViewed({
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required SelahPromotionPlacement placement,
  }) async {
    _trackName('upgrade_screen_viewed', {
      'role_context': role.name,
      'target_product': product == SelahPromotionProduct.selahOne
          ? 'selah_one'
          : 'shepherd_plus',
      'placement': placement.name,
    });
  }

  void recordLockedFeature({
    required bool ctaTapped,
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required SelahPromotionFeature feature,
    required SelahPromotionPlacement placement,
  }) {
    _trackName(
      ctaTapped ? 'locked_feature_cta_tapped' : 'locked_feature_viewed',
      {
        'role_context': role.name,
        'target_product': product == SelahPromotionProduct.selahOne
            ? 'selah_one'
            : 'shepherd_plus',
        'feature_key': feature.name,
        'placement': placement.name,
      },
    );
  }

  void recordPreferenceChanged({
    required SelahPromotionRole role,
    required String categoryCode,
    required bool marketing,
    required bool enabled,
  }) {
    _trackName(
      marketing
          ? 'marketing_consent_changed'
          : 'notification_preference_changed',
      {
        'role_context': role.name,
        'feature_key': categoryCode,
        'outcome': enabled ? 'enabled' : 'disabled',
      },
    );
  }

  @visibleForTesting
  void recordDeveloperEventForTest(
    String name,
    Map<String, String> attributes,
  ) => _trackName(name, attributes);

  Future<void> recordPurchaseResult({
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required bool success,
  }) async {
    _trackName(success ? 'purchase_succeeded' : 'purchase_failed', {
      'role_context': role.name,
      'target_product': product == SelahPromotionProduct.selahOne
          ? 'selah_one'
          : 'shepherd_plus',
      'outcome': success ? 'success' : 'failure',
    });
  }

  void recordCheckoutStarted({
    required SelahPromotionRole role,
    required SelahPromotionProduct product,
    required SelahPromotionPlacement placement,
  }) {
    _trackName('checkout_started', {
      'role_context': role.name,
      'target_product': product == SelahPromotionProduct.selahOne
          ? 'selah_one'
          : 'shepherd_plus',
      'placement': placement.name,
    });
  }

  Future<void> notePlanLapse() async {}

  void showDeveloperPreview({
    required SelahPromotionProduct product,
    required SelahPromotionRole role,
    SelahPromotionPlacement placement = SelahPromotionPlacement.home,
  }) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    if (product != SelahPromotionProduct.notifications) return;
    _permissionState = SelahNotificationPermissionState.notDetermined;
    _developerOffer = SelahPromotionOffer(
      product: product,
      role: role,
      placement: placement,
      feature: SelahPromotionFeature.deviceNotifications,
      trigger: SelahPromotionTrigger.developerPreview,
      developerPreview: true,
    );
    notifyListeners();
  }

  void setDeveloperShepherdNetworkState(
    SelahDeveloperShepherdNetworkState state,
  ) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    _developerShepherdNetworkState = state;
    notifyListeners();
  }

  /// Test/developer seam for the OS state. Production will replace this with
  /// the platform permission gateway under inherited upstream action 254.
  void setDeveloperNotificationPermissionState(
    SelahNotificationPermissionState state,
  ) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    _permissionState = state;
    notifyListeners();
  }

  Future<void> resetDeveloperPolicy() async {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    final epoch = _accountEpoch;
    await SelahLocalPrefs.clearPromotionPolicy();
    if (epoch != _accountEpoch) return;
    _resetMemory(keepEvents: false);
    _policyStartedAt = _now().toUtc();
    _initialized = true;
    await _persist();
    if (epoch != _accountEpoch) return;
    notifyListeners();
  }

  void _hydrate(Map<String, dynamic> json) {
    _policyStartedAt = _date(json['policy_started_at']);
    _notificationPending = json['notification_pending'] == true;
    _notificationRole = _role(json['notification_role']);
    _notificationTrigger =
        _trigger(json['notification_trigger']) ??
        SelahPromotionTrigger.firstActiveJourney;
    _notificationImpressions =
        (json['notification_impressions'] as num?)?.toInt() ?? 0;
    _notificationCooldownUntil = _date(json['notification_cooldown_until']);
    _notificationNeverAsk = json['notification_never_ask'] == true;
    _permissionState =
        _permission(json['notification_permission_state']) ??
        SelahNotificationPermissionState.unavailable;
    // Legacy commercial campaign fields are intentionally ignored.
  }

  Future<void> _persist() async {
    if (!_initialized) return;
    final json = <String, dynamic>{
      'policy_version': policyVersion,
      'policy_started_at': _policyStartedAt?.toIso8601String(),
      'notification_pending': _notificationPending,
      'notification_role': _notificationRole?.name,
      'notification_trigger': _notificationTrigger.name,
      'notification_impressions': _notificationImpressions,
      'notification_cooldown_until': _notificationCooldownUntil
          ?.toIso8601String(),
      'notification_never_ask': _notificationNeverAsk,
      'notification_permission_state': _permissionState.name,
    };
    try {
      await SelahLocalPrefs.setPromotionPolicy(jsonEncode(json));
    } catch (error) {
      debugPrint('SELAH promotion policy could not be saved.\n$error');
    }
  }

  void _resetMemory({required bool keepEvents}) {
    _policyStartedAt = null;
    _notificationPending = false;
    _notificationRole = null;
    _notificationTrigger = SelahPromotionTrigger.firstActiveJourney;
    _notificationImpressions = 0;
    _notificationCooldownUntil = null;
    _notificationNeverAsk = false;
    _developerOffer = null;
    _developerShepherdNetworkState =
        SelahDeveloperShepherdNetworkState.d14Preview;
    _permissionState = SelahNotificationPermissionState.unavailable;
    _decisionEvidence.clear();
    if (!keepEvents) _events.clear();
  }

  SelahPromotionDecision _recordDecision(
    SelahPromotionRequest request,
    SelahPromotionDecision decision,
  ) {
    // A protection/safety hold is deliberately invisible to analytics.
    if (request.exclusion == SelahPromotionExclusion.safetyOrModeration ||
        request.exclusion == SelahPromotionExclusion.safetyCooldown) {
      return decision;
    }
    final key = <String>[
      request.roleContext.name,
      request.targetProduct.name,
      request.feature.name,
      request.placement.name,
      decision.kind.name,
      decision.reason,
    ].join('/');
    if (!_decisionEvidence.add(key)) return decision;
    final attributes = <String, String>{
      'role_context': request.roleContext.name,
      'target_product': request.targetProduct.name,
      'feature_key': request.feature.name,
      'placement': request.placement.name,
      'trigger': request.trigger.name,
      'presentation': request.presentationIntent.name,
      'outcome': decision.kind.name,
    };
    _trackName('promotion_evaluated', attributes);
    if (decision.kind == SelahPromotionDecisionKind.hidden) {
      _trackName('promotion_suppressed', {
        ...attributes,
        'suppression_reason': decision.reason,
      });
    }
    return decision;
  }

  void _track(
    String name,
    SelahPromotionOffer offer, [
    Map<String, String> extra = const {},
  ]) {
    _trackName(name, {
      'role_context': offer.role.name,
      'target_product': offer.targetProduct,
      'feature_key': offer.feature.name,
      'placement': offer.placement.name,
      'trigger': offer.trigger.name,
      'presentation': 'bottom_nav_pill',
      ...extra,
    });
  }

  void _trackName(String name, Map<String, String> attributes) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    if (!_allowedEventNames.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Not in the governed taxonomy');
    }
    final invalid = attributes.keys.where(
      (key) => !_allowedAttributes.contains(key),
    );
    if (invalid.isNotEmpty) {
      throw ArgumentError.value(
        invalid.join(', '),
        'attributes',
        'Attribute is outside the governed analytics allowlist',
      );
    }
    _events.add(
      SelahPromotionAnalyticsEvent(
        name: name,
        occurredAt: _now().toUtc(),
        attributes: {'policy_version': policyVersion, ...attributes},
      ),
    );
    if (_events.length > 200) _events.removeAt(0);
  }

  static const Set<String> _allowedEventNames = {
    'promotion_evaluated',
    'promotion_suppressed',
    'promotion_impression',
    'promotion_opened',
    'promotion_dismissed',
    'promotion_declined',
    'locked_feature_viewed',
    'locked_feature_cta_tapped',
    'upgrade_screen_viewed',
    'checkout_started',
    'purchase_succeeded',
    'purchase_failed',
    'purchase_restored',
    'notification_education_shown',
    'notification_education_dismissed',
    'notification_permission_requested',
    'notification_permission_result',
    'notification_device_settings_opened',
    'notification_preference_changed',
    'marketing_consent_changed',
  };

  static const Set<String> _allowedAttributes = {
    'policy_version',
    'role_context',
    'target_product',
    'feature_key',
    'placement',
    'trigger',
    'presentation',
    'outcome',
    'suppression_reason',
    'permission_state',
    'platform',
    'app_version',
  };

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static SelahPromotionRole? _role(dynamic value) {
    for (final role in SelahPromotionRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  static SelahPromotionTrigger? _trigger(dynamic value) {
    for (final trigger in SelahPromotionTrigger.values) {
      if (trigger.name == value) return trigger;
    }
    return null;
  }

  static SelahNotificationPermissionState? _permission(dynamic value) {
    for (final state in SelahNotificationPermissionState.values) {
      if (state.name == value) return state;
    }
    return null;
  }
}
