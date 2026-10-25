import 'package:flutter/foundation.dart';

/// Fixed technical areas used by SELAH's local reliability evidence.
///
/// The monitor deliberately never receives an exception, stack trace, route,
/// member value or arbitrary message. It records only this closed taxonomy.
enum SelahReliabilityArea { startup, interface, platform }

enum SelahReliabilityFingerprint {
  backendStartup,
  nativeIdentity,
  flutterFramework,
  unhandledPlatform,
}

@immutable
class SelahReliabilityIncident {
  final DateTime occurredAt;
  final SelahReliabilityArea area;
  final SelahReliabilityFingerprint fingerprint;

  const SelahReliabilityIncident({
    required this.occurredAt,
    required this.area,
    required this.fingerprint,
  });
}

@immutable
class SelahReliabilitySnapshot {
  final List<SelahReliabilityIncident> recentIncidents;

  const SelahReliabilitySnapshot({required this.recentIncidents});

  int get incidentCount => recentIncidents.length;

  Map<SelahReliabilityFingerprint, int> get countsByFingerprint {
    final result = <SelahReliabilityFingerprint, int>{};
    for (final incident in recentIncidents) {
      result.update(
        incident.fingerprint,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return result;
  }
}

/// Bounded, in-memory app-health evidence for Founder testing.
///
/// Phase 2 does not send this evidence anywhere. A future provider or server
/// channel needs its own privacy, retention and activation approval. Keeping
/// this API free of arbitrary values prevents accidental personal-data or
/// secret capture while the product-health design is still staged.
class SelahReliabilityMonitor extends ChangeNotifier {
  SelahReliabilityMonitor._();

  static final SelahReliabilityMonitor instance = SelahReliabilityMonitor._();

  static const int _sessionLimit = 100;
  final List<SelahReliabilityIncident> _incidents = [];

  SelahReliabilitySnapshot get snapshot =>
      SelahReliabilitySnapshot(recentIncidents: List.unmodifiable(_incidents));

  void record({
    required SelahReliabilityArea area,
    required SelahReliabilityFingerprint fingerprint,
  }) {
    _incidents.add(
      SelahReliabilityIncident(
        occurredAt: DateTime.now().toUtc(),
        area: area,
        fingerprint: fingerprint,
      ),
    );
    if (_incidents.length > _sessionLimit) _incidents.removeAt(0);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _incidents.clear();
    notifyListeners();
  }
}
