/// One shared interpretation of SELAH's persisted gender codes.
///
/// Profile rows store `male` or `female`. Unknown data is never guessed in
/// user-facing copy: pronouns become they/their. The opposite-gender helper
/// keeps the app's historical female fallback for developer previews, while
/// production discovery still refuses before calling it when gender is null.
class SelahGender {
  SelahGender._();

  static String oppositeCode(String? gender) =>
      gender == 'female' ? 'male' : 'female';

  static String subject(String? gender, {bool capitalized = false}) {
    final value = switch (gender) {
      'male' => 'he',
      'female' => 'she',
      _ => 'they',
    };
    return capitalized
        ? '${value[0].toUpperCase()}${value.substring(1)}'
        : value;
  }

  static String possessive(String? gender) => switch (gender) {
    'male' => 'his',
    'female' => 'her',
    _ => 'their',
  };

  static String profileLabel(String? gender) => switch (gender) {
    'male' => 'Brother',
    'female' => 'Sister',
    _ => '—',
  };

  static String keepsPlaceLine(String? gender) => switch (gender) {
    'male' => "He keeps his place — return when you're ready.",
    'female' => "She keeps her place — return when you're ready.",
    _ => "They keep their place — return when you're ready.",
  };
}
