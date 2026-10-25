/// Display fixtures, not a compatibility algorithm or server response.
/// Used only by an authorized, non-persisted sample profile route.
abstract final class SelahCompatibilityDemo {
  static const categories = <SelahCompatibilityDemoCategory>[
    SelahCompatibilityDemoCategory('Lifestyle', 80, 15, 5),
    SelahCompatibilityDemoCategory('Work & Education', 70, 20, 10),
    SelahCompatibilityDemoCategory('Family Values', 85, 10, 5),
    SelahCompatibilityDemoCategory('Marriage Goals', 90, 5, 5),
    SelahCompatibilityDemoCategory('Personality', 60, 30, 10),
    SelahCompatibilityDemoCategory('Faith', 65, 25, 10),
  ];
}

class SelahCompatibilityDemoCategory {
  final String name;
  final int aligned;
  final int discuss;
  final int opposed;

  const SelahCompatibilityDemoCategory(
    this.name,
    this.aligned,
    this.discuss,
    this.opposed,
  ) : assert(aligned + discuss + opposed == 100),
      assert(aligned >= 0 && discuss >= 0 && opposed >= 0);
}
