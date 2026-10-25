/// Selah's Christian tradition and denomination taxonomy.
///
/// This is a self-description system, not a theological judgement. Families
/// make the first choice manageable; denominations provide the detailed,
/// searchable answer. `Other`, `Not sure` and `Prefer not to say` keep the
/// product honest about the limits of any finite list.
const String selahChristianTaxonomyVersion = 'christian_tradition_v1';

class SelahChristianDenomination {
  const SelahChristianDenomination(
    this.code,
    this.label, {
    this.aliases = const [],
  });

  final String code;
  final String label;
  final List<String> aliases;
}

class SelahChristianFamily {
  const SelahChristianFamily({
    required this.code,
    required this.label,
    required this.denominations,
  });

  final String code;
  final String label;
  final List<SelahChristianDenomination> denominations;
}

const List<SelahChristianFamily> selahChristianFamilies = [
  SelahChristianFamily(
    code: 'catholic',
    label: 'Catholic',
    denominations: [
      SelahChristianDenomination('roman_catholic', 'Roman Catholic'),
      SelahChristianDenomination(
        'eastern_catholic',
        'Eastern Catholic',
        aliases: [
          'Ukrainian Greek Catholic',
          'Melkite',
          'Maronite',
          'Syro-Malabar',
          'Syro-Malankara',
          'Chaldean Catholic',
          'Coptic Catholic',
          'Armenian Catholic',
        ],
      ),
      SelahChristianDenomination('old_catholic', 'Old Catholic'),
      SelahChristianDenomination('other_catholic', 'Another Catholic church'),
    ],
  ),
  SelahChristianFamily(
    code: 'orthodox_eastern',
    label: 'Orthodox & Eastern Christian',
    denominations: [
      SelahChristianDenomination(
        'eastern_orthodox',
        'Eastern Orthodox',
        aliases: [
          'Greek Orthodox',
          'Antiochian Orthodox',
          'Russian Orthodox',
          'Romanian Orthodox',
          'Serbian Orthodox',
          'Bulgarian Orthodox',
          'Ukrainian Orthodox',
          'Georgian Orthodox',
        ],
      ),
      SelahChristianDenomination(
        'oriental_orthodox',
        'Oriental Orthodox',
        aliases: [
          'Coptic Orthodox',
          'Armenian Apostolic',
          'Syriac Orthodox',
          'Ethiopian Orthodox Tewahedo',
          'Eritrean Orthodox Tewahedo',
          'Malankara Orthodox Syrian',
        ],
      ),
      SelahChristianDenomination(
        'church_of_the_east',
        'Church of the East',
        aliases: ['Assyrian Church of the East', 'Ancient Church of the East'],
      ),
      SelahChristianDenomination('mar_thoma_syrian', 'Mar Thoma Syrian Church'),
      SelahChristianDenomination(
        'other_eastern_christian',
        'Another Orthodox or Eastern Christian church',
      ),
    ],
  ),
  SelahChristianFamily(
    code: 'anglican_episcopal',
    label: 'Anglican & Episcopal',
    denominations: [
      SelahChristianDenomination('church_of_england', 'Church of England'),
      SelahChristianDenomination('church_in_wales', 'Church in Wales'),
      SelahChristianDenomination('scottish_episcopal', 'Scottish Episcopal Church'),
      SelahChristianDenomination('church_of_ireland', 'Church of Ireland'),
      SelahChristianDenomination('episcopal', 'Episcopal Church'),
      SelahChristianDenomination('free_church_of_england', 'Free Church of England'),
      SelahChristianDenomination(
        'other_anglican_episcopal',
        'Another Anglican or Episcopal church',
      ),
    ],
  ),
  SelahChristianFamily(
    code: 'protestant',
    label: 'Protestant',
    denominations: [
      SelahChristianDenomination('baptist', 'Baptist'),
      SelahChristianDenomination('lutheran', 'Lutheran'),
      SelahChristianDenomination('methodist_wesleyan', 'Methodist or Wesleyan'),
      SelahChristianDenomination('reformed_presbyterian', 'Reformed or Presbyterian'),
      SelahChristianDenomination('congregational', 'Congregational'),
      SelahChristianDenomination('anabaptist_mennonite', 'Anabaptist or Mennonite'),
      SelahChristianDenomination('quaker', 'Quaker / Religious Society of Friends'),
      SelahChristianDenomination('moravian', 'Moravian'),
      SelahChristianDenomination('holiness_nazarene', 'Holiness or Nazarene'),
      SelahChristianDenomination('salvation_army', 'Salvation Army'),
      SelahChristianDenomination('adventist', 'Seventh-day Adventist'),
      SelahChristianDenomination(
        'restoration_churches_of_christ',
        'Churches of Christ or Restoration Movement',
      ),
      SelahChristianDenomination('brethren', 'Brethren'),
      SelahChristianDenomination('evangelical_free_church', 'Evangelical Free Church'),
      SelahChristianDenomination('united_uniting', 'United or Uniting Church'),
      SelahChristianDenomination('other_protestant', 'Another Protestant church'),
    ],
  ),
  SelahChristianFamily(
    code: 'pentecostal_charismatic_apostolic',
    label: 'Pentecostal, Charismatic & Apostolic',
    denominations: [
      SelahChristianDenomination('assemblies_of_god', 'Assemblies of God'),
      SelahChristianDenomination('elim_pentecostal', 'Elim Pentecostal Church'),
      SelahChristianDenomination('apostolic_church_uk', 'Apostolic Church'),
      SelahChristianDenomination('church_of_god_of_prophecy', 'Church of God of Prophecy'),
      SelahChristianDenomination('church_of_god_in_christ', 'Church of God in Christ'),
      SelahChristianDenomination('new_testament_church_of_god', 'New Testament Church of God'),
      SelahChristianDenomination('new_testament_assembly', 'New Testament Assembly'),
      SelahChristianDenomination(
        'redeemed_christian_church_of_god',
        'Redeemed Christian Church of God',
      ),
      SelahChristianDenomination('full_gospel', 'Full Gospel church'),
      SelahChristianDenomination('charismatic_church', 'Charismatic church'),
      SelahChristianDenomination(
        'other_pentecostal_apostolic',
        'Another Pentecostal, Charismatic or Apostolic church',
      ),
    ],
  ),
  SelahChristianFamily(
    code: 'african_instituted_independent',
    label: 'African Instituted & Independent',
    denominations: [
      SelahChristianDenomination('cherubim_seraphim', 'Cherubim and Seraphim'),
      SelahChristianDenomination('celestial_church_of_christ', 'Celestial Church of Christ'),
      SelahChristianDenomination('kimbanguist', 'Kimbanguist Church'),
      SelahChristianDenomination('zionist_apostolic_african', 'African Zionist or Apostolic church'),
      SelahChristianDenomination('aladura', 'Aladura church'),
      SelahChristianDenomination(
        'other_african_instituted',
        'Another African Instituted or Independent church',
      ),
    ],
  ),
  SelahChristianFamily(
    code: 'independent_non_denominational',
    label: 'Independent & Non-denominational',
    denominations: [
      SelahChristianDenomination('non_denominational', 'Non-denominational'),
      SelahChristianDenomination('independent_evangelical', 'Independent Evangelical'),
      SelahChristianDenomination('independent_charismatic', 'Independent Charismatic'),
      SelahChristianDenomination('house_church', 'House church'),
      SelahChristianDenomination('community_church', 'Community church'),
      SelahChristianDenomination('interdenominational', 'Interdenominational'),
      SelahChristianDenomination('christian_fellowship', 'Christian fellowship'),
      SelahChristianDenomination('other_independent', 'Another independent church'),
    ],
  ),
  SelahChristianFamily(
    code: 'other_christian',
    label: 'Another Christian tradition or movement',
    denominations: [
      SelahChristianDenomination('christadelphian', 'Christadelphian'),
      SelahChristianDenomination(
        'church_of_jesus_christ_latter_day_saints',
        'The Church of Jesus Christ of Latter-day Saints',
      ),
      SelahChristianDenomination('jehovahs_witnesses', "Jehovah's Witnesses"),
      SelahChristianDenomination('christian_science', 'Christian Science'),
      SelahChristianDenomination('unitarian_christian', 'Unitarian Christian'),
      SelahChristianDenomination('unification_movement', 'Unification movement'),
      SelahChristianDenomination('messianic_jewish', 'Messianic Jewish'),
      SelahChristianDenomination('celtic_christian', 'Celtic Christian'),
      SelahChristianDenomination('mixed_christian_traditions', 'Mixed Christian traditions'),
      SelahChristianDenomination(
        'other_self_described_christian',
        'Another self-described Christian tradition',
      ),
    ],
  ),
  SelahChristianFamily(
    code: 'not_sure_exploring',
    label: 'Not sure / still exploring',
    denominations: [],
  ),
  SelahChristianFamily(
    code: 'prefer_not_to_say',
    label: 'Prefer not to say',
    denominations: [],
  ),
];

const Map<String, String> selahFaithJourneyLabels = {
  'raised_christian': 'I was raised Christian',
  'became_christian_later': 'I became Christian later in life',
  'returned_to_faith': 'I returned to Christian faith',
  'exploring_christian_faith': 'I am exploring Christian faith',
  'other': 'My story is different',
  'prefer_not_to_say': 'Prefer not to say',
};

const Map<String, String> selahChurchPreferenceScopeLabels = {
  'no_preference': 'No denomination preference',
  'same_family': 'My wider Christian tradition',
  'same_denomination': 'My denomination',
  'selected': 'Choose Christian traditions',
};

List<String> get selahChristianFamilyLabels =>
    [for (final family in selahChristianFamilies) family.label];

List<String> selahChristianDenominationLabelsFor(String familyLabel) {
  final family = selahChristianFamilyForLabel(familyLabel);
  return family == null
      ? const []
      : [for (final denomination in family.denominations) denomination.label];
}

SelahChristianFamily? selahChristianFamilyForLabel(String? label) {
  if (label == null) return null;
  for (final family in selahChristianFamilies) {
    if (family.label == label) return family;
  }
  return null;
}

SelahChristianFamily? selahChristianFamilyForCode(String? code) {
  if (code == null) return null;
  for (final family in selahChristianFamilies) {
    if (family.code == code) return family;
  }
  return null;
}

SelahChristianDenomination? selahChristianDenominationForLabel(
  String? label,
) {
  if (label == null) return null;
  for (final family in selahChristianFamilies) {
    for (final denomination in family.denominations) {
      if (denomination.label == label || denomination.aliases.contains(label)) {
        return denomination;
      }
    }
  }
  return null;
}

SelahChristianDenomination? selahChristianDenominationForCode(String? code) {
  if (code == null) return null;
  for (final family in selahChristianFamilies) {
    for (final denomination in family.denominations) {
      if (denomination.code == code) return denomination;
    }
  }
  return null;
}

SelahChristianFamily? selahChristianFamilyForDenominationCode(String? code) {
  if (code == null) return null;
  for (final family in selahChristianFamilies) {
    if (family.denominations.any((denomination) => denomination.code == code)) {
      return family;
    }
  }
  return null;
}

/// True when the selected catch-all answer should be followed by a short,
/// self-described church or denomination name. Every family has its own
/// catch-all so a finite taxonomy never pretends to be exhaustive.
bool selahChristianDenominationAcceptsOtherText(String? label) {
  final code = selahChristianDenominationForLabel(label)?.code;
  return code != null && code.startsWith('other_');
}

String? selahFaithJourneyCodeForLabel(String? label) {
  if (label == null) return null;
  for (final entry in selahFaithJourneyLabels.entries) {
    if (entry.value == label) return entry.key;
  }
  return null;
}

String? selahChurchPreferenceScopeCodeForLabel(String? label) {
  if (label == null) return null;
  for (final entry in selahChurchPreferenceScopeLabels.entries) {
    if (entry.value == label) return entry.key;
  }
  return null;
}
