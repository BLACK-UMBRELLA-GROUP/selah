import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Product areas that may appear in SELAH's privacy-safe usage evidence.
///
/// This is deliberately an enum rather than a string. A caller cannot add a
/// person's name, a Journey id, a SELAH Code, a message, a search term or any
/// other member data to an event.
enum SelahTelemetryFeature {
  browse,
  connections,
  mySelah,
  shepherd,
  journey,
  profile,
  selahCode,
  membership,
  identityCheck,
  support,
}

/// The small measurement funnel shared by every feature.
enum SelahTelemetryEventName { shown, opened, started, completed, failed }

/// The fixed member action being measured inside a product area.
///
/// This is intentionally small and governed. It enables button/funnel
/// comparison without accepting labels, route names or arbitrary strings.
enum SelahTelemetryAction {
  pageView,
  selahCodeCheck,
  selahCodeRequest,
  knownPersonConsider,
  supportAnswer,
  supportEmail,
  identityProvider,
  shepherdHistoryConsent,
  shepherdReport,
  shepherdMakeMain,
  shepherdRemove,
}

/// The broad app surface on which an event occurred. This is not a member
/// role or identity claim; it only distinguishes the two product shells.
enum SelahTelemetrySurface { seeker, shepherd, entry }

@immutable
class SelahProductEvent {
  final DateTime occurredAt;
  final SelahTelemetryFeature feature;
  final SelahTelemetryEventName name;
  final SelahTelemetryAction action;
  final SelahTelemetrySurface surface;

  const SelahProductEvent({
    required this.occurredAt,
    required this.feature,
    required this.name,
    required this.action,
    required this.surface,
  });

  Map<String, String> get rpcPayload => {
    'p_feature_key': feature.name,
    'p_event_name': name.name,
    'p_action_key': action.name,
    'p_surface_key': surface.name,
  };
}

@immutable
class SelahTelemetrySnapshot {
  final bool productionCollectionEnabled;
  final int sessionEventCount;
  final int remoteAcceptedCount;
  final int remoteFailureCount;
  final List<SelahProductEvent> recentEvents;

  const SelahTelemetrySnapshot({
    required this.productionCollectionEnabled,
    required this.sessionEventCount,
    required this.remoteAcceptedCount,
    required this.remoteFailureCount,
    required this.recentEvents,
  });

  Map<SelahTelemetryFeature, int> get countsByFeature {
    final result = <SelahTelemetryFeature, int>{};
    for (final event in recentEvents) {
      result.update(event.feature, (count) => count + 1, ifAbsent: () => 1);
    }
    return result;
  }

  Map<SelahTelemetryFeature, int> get allCountsByFeature {
    final result = {
      for (final feature in SelahTelemetryFeature.values) feature: 0,
    };
    for (final event in recentEvents) {
      result[event.feature] = result[event.feature]! + 1;
    }
    return result;
  }

  Map<SelahTelemetryAction, int> get countsByAction {
    final result = {for (final action in SelahTelemetryAction.values) action: 0};
    for (final event in recentEvents) {
      result[event.action] = result[event.action]! + 1;
    }
    return result;
  }
}

/// One bounded, privacy-safe product evidence channel.
///
/// Production transmission is compile-time OFF by default. Enabling it later
/// still requires the staged migration to have been separately approved and
/// applied, plus the privacy/retention gate recorded under inherited upstream action 256.
/// Events never contain free text or member identifiers. Failed telemetry is
/// discarded rather than blocking or changing the member's action.
class SelahProductTelemetry extends ChangeNotifier {
  SelahProductTelemetry._();

  static final SelahProductTelemetry instance = SelahProductTelemetry._();

  static const bool productionCollectionEnabled = bool.fromEnvironment(
    'SELAH_PRODUCT_TELEMETRY_ENABLED',
    defaultValue: false,
  );

  static const int _sessionLimit = 200;
  final List<SelahProductEvent> _events = [];
  int _remoteAcceptedCount = 0;
  int _remoteFailureCount = 0;

  SelahTelemetrySnapshot get snapshot => SelahTelemetrySnapshot(
    productionCollectionEnabled: productionCollectionEnabled,
    sessionEventCount: _events.length,
    remoteAcceptedCount: _remoteAcceptedCount,
    remoteFailureCount: _remoteFailureCount,
    recentEvents: List.unmodifiable(_events),
  );

  void record({
    required SelahTelemetryFeature feature,
    required SelahTelemetryEventName name,
    required SelahTelemetryAction action,
    required SelahTelemetrySurface surface,
  }) {
    final event = SelahProductEvent(
      occurredAt: DateTime.now().toUtc(),
      feature: feature,
      name: name,
      action: action,
      surface: surface,
    );
    _events.add(event);
    if (_events.length > _sessionLimit) _events.removeAt(0);
    notifyListeners();

    if (productionCollectionEnabled) unawaited(_send(event));
  }

  Future<void> _send(SelahProductEvent event) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      final package = await PackageInfo.fromPlatform();
      final params = <String, dynamic>{
        ...event.rpcPayload,
        'p_platform_key': _platformKey,
        'p_app_version': package.version,
        'p_build_number': package.buildNumber,
      };
      await client.rpc('selah_record_product_event', params: params);
      _remoteAcceptedCount++;
    } catch (error) {
      _remoteFailureCount++;
      // Never print payloads or arbitrary exception text from this channel.
      debugPrint(
        'SELAH product telemetry send failed (${error.runtimeType}); '
        'the member action continued.',
      );
    }
    notifyListeners();
  }

  static String get _platformKey {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  @visibleForTesting
  void resetForTest() {
    _events.clear();
    _remoteAcceptedCount = 0;
    _remoteFailureCount = 0;
    notifyListeners();
  }
}
