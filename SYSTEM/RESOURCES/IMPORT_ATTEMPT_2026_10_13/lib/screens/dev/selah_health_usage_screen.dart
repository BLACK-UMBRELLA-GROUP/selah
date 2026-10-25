import 'package:flutter/material.dart';

import '../../services/selah_product_telemetry.dart';
import '../../services/selah_reliability_monitor.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';

/// Founder-only truth view for the first observability slice.
///
/// It reports what exists now. It does not imply that the staged database is
/// live, that a crash provider is connected, or that remote collection is on.
class SelahHealthUsageScreen extends StatelessWidget {
  const SelahHealthUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetry = SelahProductTelemetry.instance;
    final reliability = SelahReliabilityMonitor.instance;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Health & Usage',
                        textAlign: TextAlign.center,
                        style: SelahText.heading(size: 23),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([telemetry, reliability]),
                  builder: (context, _) {
                    final snapshot = telemetry.snapshot;
                    final health = reliability.snapshot;
                    final featureCounts =
                        snapshot.allCountsByFeature.entries.toList()
                          ..sort((a, b) {
                            final byCount = b.value.compareTo(a.value);
                            return byCount != 0
                                ? byCount
                                : _featureLabel(
                                    a.key,
                                  ).compareTo(_featureLabel(b.key));
                          });
                    final actionCounts =
                        snapshot.countsByAction.entries.toList()..sort((a, b) {
                          final byCount = b.value.compareTo(a.value);
                          return byCount != 0
                              ? byCount
                              : _actionLabel(
                                  a.key,
                                ).compareTo(_actionLabel(b.key));
                        });
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                      children: [
                        _statusCard(snapshot),
                        const SizedBox(height: 18),
                        Text(
                          'App health this session',
                          style: SelahText.heading(size: 18),
                        ),
                        const SizedBox(height: 10),
                        _healthCard(health),
                        const SizedBox(height: 18),
                        Text(
                          'Features this session',
                          style: SelahText.heading(size: 18),
                        ),
                        const SizedBox(height: 10),
                        if (snapshot.sessionEventCount == 0) ...[
                          _card(
                            child: Text(
                              'No events yet. Open a page or use an instrumented feature to see the local evidence here.',
                              style: SelahText.body(
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _featureMetricGroup(featureCounts),
                        const SizedBox(height: 18),
                        Text(
                          'Actions this session',
                          style: SelahText.heading(size: 18),
                        ),
                        const SizedBox(height: 10),
                        _actionMetricGroup(actionCounts),
                        const SizedBox(height: 18),
                        _card(
                          child: Text(
                            'Privacy boundary\nFixed event names only. No names, emails, SELAH Codes, profile ids, Journey ids, messages, search terms, compatibility answers, religion, safety details, precise location, advertising ids, screenshots or session replay.',
                            style: SelahText.body(
                              size: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statusCard(SelahTelemetrySnapshot snapshot) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot.productionCollectionEnabled
              ? 'Production collection on'
              : 'Production collection off',
          style: SelahText.heading(size: 19),
        ),
        const SizedBox(height: 8),
        Text(
          snapshot.productionCollectionEnabled
              ? 'Approved fixed events may be sent to SELAH.'
              : 'Events stay in memory for this app session. The staged database is not live.',
          style: SelahText.body(size: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _valueLine('Session events', snapshot.sessionEventCount),
        _valueLine('Server accepted', snapshot.remoteAcceptedCount),
        _valueLine('Send failures', snapshot.remoteFailureCount),
      ],
    ),
  );

  static Widget _healthCard(SelahReliabilitySnapshot snapshot) {
    final counts = snapshot.countsByFingerprint.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.incidentCount == 0
                ? 'No captured technical failures'
                : '${snapshot.incidentCount} captured technical failure${snapshot.incidentCount == 1 ? '' : 's'}',
            style: SelahText.heading(size: 17),
          ),
          const SizedBox(height: 7),
          Text(
            'Local only. Fixed categories; no exception text, stack traces or member data.',
            style: SelahText.body(size: 13, color: Colors.white70),
          ),
          for (final entry in counts)
            _valueLine(_reliabilityLabel(entry.key), entry.value),
        ],
      ),
    );
  }

  static Widget _featureMetricGroup(
    List<MapEntry<SelahTelemetryFeature, int>> entries,
  ) => _card(
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _inlineMetric(
            _featureLabel(entries[index].key),
            entries[index].value,
          ),
          if (index != entries.length - 1) const Divider(height: 16),
        ],
      ],
    ),
  );

  static Widget _actionMetricGroup(
    List<MapEntry<SelahTelemetryAction, int>> entries,
  ) => _card(
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _inlineMetric(_actionLabel(entries[index].key), entries[index].value),
          if (index != entries.length - 1) const Divider(height: 16),
        ],
      ],
    ),
  );

  static Widget _inlineMetric(String label, int value) => Row(
    children: [
      Expanded(child: Text(label, style: SelahText.body(size: 14))),
      Text('$value', style: SelahText.button(size: 15)),
    ],
  );

  static Widget _valueLine(String label, int value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: SelahText.body(size: 13, color: Colors.white70),
          ),
        ),
        Text('$value', style: SelahText.button(size: 14)),
      ],
    ),
  );

  static Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: SelahColors.iconButtonBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SelahColors.iconButtonBorder, width: 0.75),
    ),
    child: child,
  );

  static String _featureLabel(SelahTelemetryFeature feature) =>
      switch (feature) {
        SelahTelemetryFeature.browse => 'Browse',
        SelahTelemetryFeature.connections => 'Connections',
        SelahTelemetryFeature.mySelah => 'My SELAH',
        SelahTelemetryFeature.shepherd => 'Shepherd',
        SelahTelemetryFeature.journey => 'Journey',
        SelahTelemetryFeature.profile => 'Profile',
        SelahTelemetryFeature.selahCode => 'SELAH Code',
        SelahTelemetryFeature.membership => 'Membership',
        SelahTelemetryFeature.identityCheck => 'Identity Check',
        SelahTelemetryFeature.support => 'Support',
      };

  static String _reliabilityLabel(SelahReliabilityFingerprint fingerprint) =>
      switch (fingerprint) {
        SelahReliabilityFingerprint.backendStartup => 'Backend startup',
        SelahReliabilityFingerprint.nativeIdentity => 'App identity check',
        SelahReliabilityFingerprint.flutterFramework => 'Interface framework',
        SelahReliabilityFingerprint.unhandledPlatform => 'Unhandled platform',
      };

  static String _actionLabel(SelahTelemetryAction action) => switch (action) {
    SelahTelemetryAction.pageView => 'Page opened',
    SelahTelemetryAction.selahCodeCheck => 'SELAH Code checked',
    SelahTelemetryAction.selahCodeRequest => 'SELAH Code request',
    SelahTelemetryAction.knownPersonConsider => 'Known person considered',
    SelahTelemetryAction.supportAnswer => 'Support answer opened',
    SelahTelemetryAction.supportEmail => 'Support email',
    SelahTelemetryAction.identityProvider => 'Identity check',
    SelahTelemetryAction.shepherdHistoryConsent => 'Shepherd history consent',
    SelahTelemetryAction.shepherdReport => 'Shepherd report',
    SelahTelemetryAction.shepherdMakeMain => 'Make Main Shepherd',
    SelahTelemetryAction.shepherdRemove => 'Remove Shepherd',
  };
}
