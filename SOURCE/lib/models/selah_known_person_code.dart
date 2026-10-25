class SelahKnownPersonCodePreview {
  final String firstName;
  final int age;
  final String city;

  const SelahKnownPersonCodePreview({
    required this.firstName,
    required this.age,
    required this.city,
  });

  static SelahKnownPersonCodePreview? fromRow(Map<String, dynamic> row) {
    final firstName = row['owner_first_name'];
    final age = row['owner_age'];
    final city = row['owner_location'];
    if (firstName is! String ||
        firstName.trim().isEmpty ||
        age is! num ||
        city is! String ||
        city.trim().isEmpty) {
      return null;
    }
    return SelahKnownPersonCodePreview(
      firstName: firstName.trim(),
      age: age.toInt(),
      city: city.trim(),
    );
  }
}

class SelahKnownPersonCodeLookup {
  final bool serverAvailable;
  final SelahKnownPersonCodePreview? person;

  const SelahKnownPersonCodeLookup.available(this.person)
    : serverAvailable = true;

  const SelahKnownPersonCodeLookup.unavailable()
    : serverAvailable = false,
      person = null;
}

enum SelahKnownPersonConsiderOutcome {
  considered,
  matched,
  noLongerAvailable,
  failed,
}
