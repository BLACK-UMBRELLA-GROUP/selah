/// Founder-directed membership catalogue, amended 2026-10-03 (inherited decision 252).
///
/// Product information is never purchase proof, an entitlement grant, or a
/// device-timed trial. StoreKit's verified transaction price remains the
/// billing authority when checkout is activated.
enum SelahMembershipProduct {
  seekerOne,
  seekerBasic,
  shepherdOne,
  shepherdBasic,
}

class SelahFamilyQuote {
  final int seekers;
  final int shepherds;
  final int members;
  final int discountPercent;
  final int individualMonthlyPence;
  final int formulaMonthlyPence;
  final int savingPence;

  const SelahFamilyQuote._({
    required this.seekers,
    required this.shepherds,
    required this.members,
    required this.discountPercent,
    required this.individualMonthlyPence,
    required this.formulaMonthlyPence,
    required this.savingPence,
  });

  bool get hasMembers => members > 0;

  /// Protected onboarding comparison, calculated from selected role places.
  /// This does not establish unique-person eligibility or a store charge.
  int get introFirstMonthPence =>
      members * SelahMembershipCatalog.familyIntroMonthPerPlacePence;
}

class SelahMembershipCatalog {
  SelahMembershipCatalog._();

  static const trialDays = 14;
  static const checkoutAvailable = false;
  static const familyMaxPerRole = 10;
  static const seekerOneTitle = 'Seeker One';
  static const shepherdOneTitle = 'Shepherd One';

  /// Available choices are commercial information, never evidence of payment.
  static const products = [
    SelahMembershipProduct.seekerOne,
    SelahMembershipProduct.seekerBasic,
    SelahMembershipProduct.shepherdOne,
    SelahMembershipProduct.shepherdBasic,
  ];

  // Founder ruling, 2026-09-24: separate monthly role memberships.
  static const seekerOneMonthlyPence = 2999;
  static const shepherdOneMonthlyPence = 1999;
  // Basic has a joining charge, not a monthly subscription or a free trial.
  static const basicJoiningPence = 499;
  // Founder-requested Family onboarding comparison, not an active store offer.
  static const familyIntroMonthPerPlacePence = 499;

  static bool isBasic(SelahMembershipProduct product) =>
      product == SelahMembershipProduct.seekerBasic ||
      product == SelahMembershipProduct.shepherdBasic;

  static const basicTerms =
      'Seeker Basic and Shepherd Basic each have a £4.99 one-time joining '
      'fee covering joining and verification, with no monthly subscription. '
      'Choosing Basic does not confirm payment or identity verification. '
      'Basic does not include a trial.';
  static const shepherdBasicTerms =
      'Shepherd Basic includes viewing permitted linked Journeys and their '
      'Timeline, with essential relationship, consent, Main Shepherd review '
      'and safety controls. Conversation, compatibility answering and Network '
      'access are One features. Membership never creates a Shepherd link or '
      'Main Shepherd authority.';

  static String pounds(int pence) {
    if (pence < 0) throw RangeError.value(pence, 'pence');
    return '£${pence ~/ 100}.${(pence % 100).toString().padLeft(2, '0')}';
  }

  /// The governed formula price. App Store combinations must use the nearest
  /// supported price point at or above this amount. Once StoreKit is live,
  /// display its verified localised price rather than treating this estimate
  /// as the amount charged.
  static SelahFamilyQuote familyQuote(int seekers, int shepherds) {
    RangeError.checkValueInInterval(seekers, 0, familyMaxPerRole, 'seekers');
    RangeError.checkValueInInterval(
      shepherds,
      0,
      familyMaxPerRole,
      'shepherds',
    );
    final members = seekers + shepherds;
    final discountPercent = ((members - 2) * 5).clamp(0, 40);
    final individualMonthlyPence =
        seekers * seekerOneMonthlyPence + shepherds * shepherdOneMonthlyPence;
    final formulaMonthlyPence =
        (individualMonthlyPence * (100 - discountPercent) + 50) ~/ 100;
    return SelahFamilyQuote._(
      seekers: seekers,
      shepherds: shepherds,
      members: members,
      discountPercent: discountPercent,
      individualMonthlyPence: individualMonthlyPence,
      formulaMonthlyPence: formulaMonthlyPence,
      savingPence: individualMonthlyPence - formulaMonthlyPence,
    );
  }

  static const familyTerms =
      'Choose 0–10 Seeker One and 0–10 Shepherd One places. One or two '
      'places use their individual monthly prices. From three places, the '
      'saving rises by five percentage points per place to a maximum of 40% '
      'from ten places onward. All places are billed monthly. Zero places '
      'cannot be purchased.';
  static const familyAvailability =
      'This is an estimate, not checkout. The App Store will show the exact '
      'local monthly price before purchase; it is rounded upward to a '
      'supported price point where required. Family checkout, allocation and '
      'paid access activation are not available yet.';

  // Separate optional purchases, not membership subscriptions.
  static const compatibilitySinglePence = 299;
  static const compatibilityFivePence = 999;
  static const compatibilityTerms =
      'Compatibility Unlock is an optional purchase, '
      'charged separately from your membership.';
  static const compatibilityPrices =
      'Compatibility Unlock: £2.99 each or £9.99 for five.';
  static const compatibilityAvailability =
      'Purchasing unlocks is not available in this build. Existing credits '
      'and previously unlocked access are kept.';

  static String title(SelahMembershipProduct product) => switch (product) {
    SelahMembershipProduct.seekerOne => seekerOneTitle,
    SelahMembershipProduct.seekerBasic => 'Seeker Basic',
    SelahMembershipProduct.shepherdOne => shepherdOneTitle,
    SelahMembershipProduct.shepherdBasic => 'Shepherd Basic',
  };

  static String price(SelahMembershipProduct product) => switch (product) {
    SelahMembershipProduct.seekerOne =>
      '${pounds(seekerOneMonthlyPence)} / month',
    SelahMembershipProduct.seekerBasic => '${pounds(basicJoiningPence)} once',
    SelahMembershipProduct.shepherdOne =>
      '${pounds(shepherdOneMonthlyPence)} / month',
    SelahMembershipProduct.shepherdBasic => '${pounds(basicJoiningPence)} once',
  };

  static const availability =
      'Membership setup is being prepared. Payments, trial activation and '
      'paid access activation are not available in this build. No payment '
      'will be taken and no trial will start here.';

  /// Paid capability never becomes relationship or Journey authority.
  static const shepherdAccessTerms =
      'Shepherd One makes paid Shepherd features available; it does not '
      'guarantee access to every Journey. A Main Shepherd has View and Chat '
      'for every Active Journey while they remain Main. An Additional '
      'Shepherd starts with View and Chat enabled for each Active Journey; '
      'the linked Seeker may switch either permission off. Chat requires '
      'View. An accepted Shepherd link and all Journey privacy rules still '
      'apply.';

  static const trialTerms =
      'Seeker One includes one 14-day trial per verified person for life, '
      'then continues as a paid monthly subscription unless cancelled. The '
      'trial starts only after identity verification and App Store payment '
      'authorisation succeed. Shepherd One and Selah Family do not include a '
      'trial. The store will show eligibility, renewal price and cancellation '
      'terms before subscription.';
}
