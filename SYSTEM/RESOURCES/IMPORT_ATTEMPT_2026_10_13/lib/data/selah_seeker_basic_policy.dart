/// The Founder-approved Seeker Basic allowance, kept in one place so Browse,
/// membership copy and tests cannot silently drift apart.
abstract final class SelahSeekerBasicPolicy {
  static const int activeJourneyLimit = 1;
  static const int totalConsiderLimit = 25;
  static const int totalSaveLimit = 5;
  static const int dailyConsiderLimit = 5;
  static const int swipeLimit = 25;
  static const Duration swipeWindow = Duration(hours: 4);
  static const int advertEverySwipes = 5;

  static bool swipeLimitReached(int swipes) => swipes >= swipeLimit;

  static bool advertDue(int swipes) =>
      swipes > 0 && swipes % advertEverySwipes == 0;
}
