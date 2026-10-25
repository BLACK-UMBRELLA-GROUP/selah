// Shared boundary for a Seeker who explicitly taps a membership-locked
// feature. The feature remains visible and the user's deliberate action opens
// membership information; this helper never mutates or grants entitlement.

import 'package:flutter/material.dart';

import '../screens/subscription/upgrade_screen.dart';
import '../services/selah_promotion_engine.dart';
import '../services/selah_product_telemetry.dart';
import '../state/app_state.dart';

void recordSeekerLockedFeatureView(
  SelahPromotionFeature feature, {
  SelahPromotionPlacement placement = SelahPromotionPlacement.lockedFeature,
}) {
  SelahPromotionEngine.instance.recordLockedFeature(
    ctaTapped: false,
    role: SelahPromotionRole.seeker,
    product: SelahPromotionProduct.selahOne,
    feature: feature,
    placement: placement,
  );
}

void openSeekerLockedFeaturePlan(
  BuildContext context, {
  required SelahPromotionFeature feature,
  SelahPromotionPlacement placement = SelahPromotionPlacement.lockedFeature,
}) {
  final engine = SelahPromotionEngine.instance;
  engine.recordLockedFeature(
    ctaTapped: true,
    role: SelahPromotionRole.seeker,
    product: SelahPromotionProduct.selahOne,
    feature: feature,
    placement: placement,
  );
  if (AppState.instance.plan == SelahPlan.one || !context.mounted) {
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          const UpgradeScreen(telemetrySurface: SelahTelemetrySurface.seeker),
    ),
  );
}
