// Notification education anchored to the floating nav.
// Screens provide context only; SelahPromotionEngine decides if anything is
// allowed to appear. The five-second line is time-to-hide, never urgency.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/selah_promotion_engine.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';

class SelahBottomPromotion extends StatefulWidget {
  final SelahPromotionRole role;
  final SelahPromotionPlacement placement;
  final bool isCalmLanding;

  /// Legacy constructor inputs; this widget only shows notification education.
  final bool isEntitled;
  final bool upgradeOfferAvailable;
  final ValueChanged<SelahPromotionProduct> onOpenPlan;
  final SelahPromotionEngine? engine;

  const SelahBottomPromotion({
    super.key,
    required this.role,
    required this.placement,
    required this.isCalmLanding,
    required this.isEntitled,
    required this.upgradeOfferAvailable,
    required this.onOpenPlan,
    this.engine,
  });

  @override
  State<SelahBottomPromotion> createState() => _SelahBottomPromotionState();
}

class _SelahBottomPromotionState extends State<SelahBottomPromotion>
    with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(seconds: 5);
  late final SelahPromotionEngine _engine;
  late final AnimationController _timer;
  String? _impressionKey;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? SelahPromotionEngine.instance;
    _timer = AnimationController(vsync: this, duration: _visibleFor)
      ..addStatusListener(_onTimerStatus);
    _engine.addListener(_onEngineChange);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChange);
    _timer
      ..removeStatusListener(_onTimerStatus)
      ..dispose();
    super.dispose();
  }

  void _onEngineChange() {
    if (mounted) setState(() {});
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final offer = _decision.offer;
    if (offer != null) {
      _engine.dismiss(offer, dismissal: SelahPromotionDismissal.close);
    }
  }

  SelahPromotionDecision get _decision => _engine.decisionForSurface(
    role: widget.role,
    placement: widget.placement,
    isCalmLanding: widget.isCalmLanding,
    isEntitled: widget.isEntitled,
    upgradeOfferAvailable: widget.upgradeOfferAvailable,
  );

  void _arm(SelahPromotionOffer offer) {
    final key =
        '${offer.product.name}/${offer.feature.name}/'
        '${offer.placement.name}/${offer.trigger.name}/'
        '${offer.developerPreview}';
    if (_impressionKey == key) return;
    _impressionKey = key;
    _timer
      ..stop()
      ..reset()
      ..forward();
    _engine.recordImpression(offer);
  }

  Future<void> _dismiss(
    SelahPromotionOffer offer,
    SelahPromotionDismissal dismissal,
  ) async {
    _timer.stop();
    await _engine.dismiss(offer, dismissal: dismissal);
  }

  Future<void> _act(SelahPromotionOffer offer) async {
    if (offer.product != SelahPromotionProduct.notifications ||
        offer.dependency != SelahPromotionDependency.ready) {
      return;
    }
    _timer.stop();
    await _engine.recordOpened(offer);
    if (!mounted) return;
    final state = await _engine.requestNotificationPermission(offer);
    if (!mounted) return;
    final message = state == SelahNotificationPermissionState.enabled
        ? 'Device notifications enabled for this preview.'
        : 'Device notifications are not connected in this build yet.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    final offer = decision.offer;
    if (offer == null ||
        offer.product != SelahPromotionProduct.notifications ||
        !widget.isCalmLanding) {
      _timer.stop();
      _impressionKey = null;
      return SizedBox.shrink();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arm(offer);
    });

    final safeBottom = math.max(
      MediaQuery.paddingOf(context).bottom,
      SelahNavBarMetrics.bottomInset,
    );
    return Positioned(
      left: 18,
      right: 18,
      bottom: safeBottom + SelahNavBarMetrics.restingHeight + 12,
      child: Semantics(
        container: true,
        label: '${offer.title}. ${offer.message}',
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                SelahColors.surfaceEmphasisFill,
                SelahColors.mentorSheetBg,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SelahColors.surfaceEmphasisBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 11, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            offer.product == SelahPromotionProduct.notifications
                                ? Icons.notifications_none_rounded
                                : Icons.auto_awesome_outlined,
                            size: 18,
                            color: SelahColors.accentBorder,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              offer.title,
                              style: SelahText.body(
                                size: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('promotion_close'),
                            tooltip: 'Dismiss',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () =>
                                _dismiss(offer, SelahPromotionDismissal.close),
                            icon: Icon(
                              Icons.close,
                              size: 15,
                              color: SelahColors.ink(0.38),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(27, 1, 4, 7),
                        child: Text(
                          offer.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: SelahText.subtext(
                            size: 10.5,
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 27, right: 4),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 3,
                          children: [
                            if (offer.product ==
                                SelahPromotionProduct.notifications) ...[
                              TextButton(
                                key: const ValueKey(
                                  'notification_promotion_not_now',
                                ),
                                onPressed: () => _dismiss(
                                  offer,
                                  SelahPromotionDismissal.notNow,
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                ),
                                child: Text(
                                  'Not now',
                                  style: SelahText.subtext(
                                    size: 10.5,
                                    color: SelahColors.ink(0.54),
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const ValueKey(
                                  'notification_promotion_never',
                                ),
                                onPressed: () => _dismiss(
                                  offer,
                                  SelahPromotionDismissal.dontShow,
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                ),
                                child: Text(
                                  'Don’t ask again',
                                  maxLines: 1,
                                  style: SelahText.subtext(
                                    size: 9.5,
                                    color: SelahColors.ink(0.38),
                                  ),
                                ),
                              ),
                            ],
                            FilledButton(
                              key: const ValueKey('promotion_primary_action'),
                              onPressed:
                                  offer.product ==
                                          SelahPromotionProduct.notifications &&
                                      offer.dependency !=
                                          SelahPromotionDependency.ready
                                  ? null
                                  : () => _act(offer),
                              style: FilledButton.styleFrom(
                                backgroundColor: SelahColors.accentBg,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(
                                    color: SelahColors.accentBorder,
                                    width: 0.8,
                                  ),
                                ),
                              ),
                              child: Text(
                                offer.actionLabel,
                                style: SelahText.button(size: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => LinearProgressIndicator(
                    key: const ValueKey('promotion_countdown'),
                    value: 1 - _timer.value,
                    minHeight: 2,
                    backgroundColor: SelahColors.foreground.withValues(
                      alpha: 0.05,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      SelahColors.accentBorder.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
