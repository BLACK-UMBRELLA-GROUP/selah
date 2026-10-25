// SELAH reference data — countries, nationalities, languages, ethnicities.
//
// GENERATED 2026-08-01. Replaces data/mock_reference_lists.dart, whose own
// header admitted it was a stand-in: 30 countries, 20 languages, 12
// ethnicities. A Seeker born in Kenya, Kosovo, Uzbekistan or the
// Philippines could not answer "which country were you born in" — there was
// no Other and no free-text fallback.
//
// THE RULE THAT MATTERS MOST HERE:
//
//   STORE THE CODE. NEVER STORE THE LABEL.
//
// Every entry has a stable machine code and a human label. `code` is what
// goes in the database; `name` is only ever for display. This is not
// tidiness — it is what stops the Founder's stated fear ("I'd rather solve
// this once than migrate user data later") from ever happening. Relabel
// "Turkey" to "Türkiye" and no user row changes, because the row says 'TR'.
//
// It is also already load-bearing. ISO 639-1 names two of this audience's
// most-spoken languages "Panjabi" and "Pushto" — spellings nobody would
// search for — and suffixes others "(macrolanguage)". Those are corrected in
// the labels below while the codes stay canonical. Had the labels been the
// stored value, correcting them would have orphaned every affected user.
//
// SOURCES
//   Countries    ISO 3166-1 alpha-2, via pycountry. 197 = UN member states
//                and observers, plus Taiwan and Kosovo (XK, user-assigned).
//                Uninhabited territories deliberately excluded.
//   Nationality  Demonyms, hand-written and asserted to cover all 197.
//                A nationality is "Pakistani", not "Pakistan" — the old
//                list used the country names for both, which typed the
//                data wrong at source.
//   Languages    ISO 639-1, via pycountry. All 184.
//   Ethnicity    No ISO standard exists. SELAH's own codes, below.
//
// Do not hand-edit country or language entries. Correct labels via the
// override map in the generator and regenerate, so codes cannot drift.

class SelahRefItem {
  /// Stored in the database. Stable forever.
  final String code;

  /// Shown to the user. Safe to change at any time.
  final String name;

  const SelahRefItem(this.code, this.name);
}

class SelahCountryItem {
  final String code;
  final String name;

  /// Demonym — "Pakistani" for PK. Same country list backs both the
  /// country-of-birth and nationality questions; only the label differs.
  final String nationality;

  const SelahCountryItem(this.code, this.name, this.nationality);
}

/// 197 countries, ISO 3166-1 alpha-2.
const List<SelahCountryItem> selahCountries = [
  SelahCountryItem('AF', 'Afghanistan', 'Afghan'),
  SelahCountryItem('AL', 'Albania', 'Albanian'),
  SelahCountryItem('DZ', 'Algeria', 'Algerian'),
  SelahCountryItem('AD', 'Andorra', 'Andorran'),
  SelahCountryItem('AO', 'Angola', 'Angolan'),
  SelahCountryItem('AG', 'Antigua and Barbuda', 'Antiguan and Barbudan'),
  SelahCountryItem('AR', 'Argentina', 'Argentine'),
  SelahCountryItem('AM', 'Armenia', 'Armenian'),
  SelahCountryItem('AU', 'Australia', 'Australian'),
  SelahCountryItem('AT', 'Austria', 'Austrian'),
  SelahCountryItem('AZ', 'Azerbaijan', 'Azerbaijani'),
  SelahCountryItem('BS', 'Bahamas', 'Bahamian'),
  SelahCountryItem('BH', 'Bahrain', 'Bahraini'),
  SelahCountryItem('BD', 'Bangladesh', 'Bangladeshi'),
  SelahCountryItem('BB', 'Barbados', 'Barbadian'),
  SelahCountryItem('BY', 'Belarus', 'Belarusian'),
  SelahCountryItem('BE', 'Belgium', 'Belgian'),
  SelahCountryItem('BZ', 'Belize', 'Belizean'),
  SelahCountryItem('BJ', 'Benin', 'Beninese'),
  SelahCountryItem('BT', 'Bhutan', 'Bhutanese'),
  SelahCountryItem('BO', 'Bolivia', 'Bolivian'),
  SelahCountryItem('BA', 'Bosnia and Herzegovina', 'Bosnian'),
  SelahCountryItem('BW', 'Botswana', 'Botswanan'),
  SelahCountryItem('BR', 'Brazil', 'Brazilian'),
  SelahCountryItem('BN', 'Brunei', 'Bruneian'),
  SelahCountryItem('BG', 'Bulgaria', 'Bulgarian'),
  SelahCountryItem('BF', 'Burkina Faso', 'Burkinabè'),
  SelahCountryItem('BI', 'Burundi', 'Burundian'),
  SelahCountryItem('CV', 'Cabo Verde', 'Cabo Verdean'),
  SelahCountryItem('KH', 'Cambodia', 'Cambodian'),
  SelahCountryItem('CM', 'Cameroon', 'Cameroonian'),
  SelahCountryItem('CA', 'Canada', 'Canadian'),
  SelahCountryItem('CF', 'Central African Republic', 'Central African'),
  SelahCountryItem('TD', 'Chad', 'Chadian'),
  SelahCountryItem('CL', 'Chile', 'Chilean'),
  SelahCountryItem('CN', 'China', 'Chinese'),
  SelahCountryItem('CO', 'Colombia', 'Colombian'),
  SelahCountryItem('KM', 'Comoros', 'Comoran'),
  SelahCountryItem('CR', 'Costa Rica', 'Costa Rican'),
  SelahCountryItem('HR', 'Croatia', 'Croatian'),
  SelahCountryItem('CU', 'Cuba', 'Cuban'),
  SelahCountryItem('CY', 'Cyprus', 'Cypriot'),
  SelahCountryItem('CZ', 'Czechia', 'Czech'),
  SelahCountryItem('CI', 'Côte d\'Ivoire', 'Ivorian'),
  SelahCountryItem('CD', 'Democratic Republic of the Congo', 'Congolese (DRC)'),
  SelahCountryItem('DK', 'Denmark', 'Danish'),
  SelahCountryItem('DJ', 'Djibouti', 'Djiboutian'),
  SelahCountryItem('DM', 'Dominica', 'Dominican'),
  SelahCountryItem('DO', 'Dominican Republic', 'Dominican'),
  SelahCountryItem('EC', 'Ecuador', 'Ecuadorian'),
  SelahCountryItem('EG', 'Egypt', 'Egyptian'),
  SelahCountryItem('SV', 'El Salvador', 'Salvadoran'),
  SelahCountryItem('GQ', 'Equatorial Guinea', 'Equatorial Guinean'),
  SelahCountryItem('ER', 'Eritrea', 'Eritrean'),
  SelahCountryItem('EE', 'Estonia', 'Estonian'),
  SelahCountryItem('SZ', 'Eswatini', 'Swazi'),
  SelahCountryItem('ET', 'Ethiopia', 'Ethiopian'),
  SelahCountryItem('FJ', 'Fiji', 'Fijian'),
  SelahCountryItem('FI', 'Finland', 'Finnish'),
  SelahCountryItem('FR', 'France', 'French'),
  SelahCountryItem('GA', 'Gabon', 'Gabonese'),
  SelahCountryItem('GM', 'Gambia', 'Gambian'),
  SelahCountryItem('GE', 'Georgia', 'Georgian'),
  SelahCountryItem('DE', 'Germany', 'German'),
  SelahCountryItem('GH', 'Ghana', 'Ghanaian'),
  SelahCountryItem('GR', 'Greece', 'Greek'),
  SelahCountryItem('GD', 'Grenada', 'Grenadian'),
  SelahCountryItem('GT', 'Guatemala', 'Guatemalan'),
  SelahCountryItem('GN', 'Guinea', 'Guinean'),
  SelahCountryItem('GW', 'Guinea-Bissau', 'Bissau-Guinean'),
  SelahCountryItem('GY', 'Guyana', 'Guyanese'),
  SelahCountryItem('HT', 'Haiti', 'Haitian'),
  SelahCountryItem('HN', 'Honduras', 'Honduran'),
  SelahCountryItem('HU', 'Hungary', 'Hungarian'),
  SelahCountryItem('IS', 'Iceland', 'Icelandic'),
  SelahCountryItem('IN', 'India', 'Indian'),
  SelahCountryItem('ID', 'Indonesia', 'Indonesian'),
  SelahCountryItem('IR', 'Iran', 'Iranian'),
  SelahCountryItem('IQ', 'Iraq', 'Iraqi'),
  SelahCountryItem('IE', 'Ireland', 'Irish'),
  SelahCountryItem('IL', 'Israel', 'Israeli'),
  SelahCountryItem('IT', 'Italy', 'Italian'),
  SelahCountryItem('JM', 'Jamaica', 'Jamaican'),
  SelahCountryItem('JP', 'Japan', 'Japanese'),
  SelahCountryItem('JO', 'Jordan', 'Jordanian'),
  SelahCountryItem('KZ', 'Kazakhstan', 'Kazakhstani'),
  SelahCountryItem('KE', 'Kenya', 'Kenyan'),
  SelahCountryItem('KI', 'Kiribati', 'I-Kiribati'),
  SelahCountryItem('XK', 'Kosovo', 'Kosovan'),
  SelahCountryItem('KW', 'Kuwait', 'Kuwaiti'),
  SelahCountryItem('KG', 'Kyrgyzstan', 'Kyrgyzstani'),
  SelahCountryItem('LA', 'Laos', 'Lao'),
  SelahCountryItem('LV', 'Latvia', 'Latvian'),
  SelahCountryItem('LB', 'Lebanon', 'Lebanese'),
  SelahCountryItem('LS', 'Lesotho', 'Basotho'),
  SelahCountryItem('LR', 'Liberia', 'Liberian'),
  SelahCountryItem('LY', 'Libya', 'Libyan'),
  SelahCountryItem('LI', 'Liechtenstein', 'Liechtensteiner'),
  SelahCountryItem('LT', 'Lithuania', 'Lithuanian'),
  SelahCountryItem('LU', 'Luxembourg', 'Luxembourgish'),
  SelahCountryItem('MG', 'Madagascar', 'Malagasy'),
  SelahCountryItem('MW', 'Malawi', 'Malawian'),
  SelahCountryItem('MY', 'Malaysia', 'Malaysian'),
  SelahCountryItem('MV', 'Maldives', 'Maldivian'),
  SelahCountryItem('ML', 'Mali', 'Malian'),
  SelahCountryItem('MT', 'Malta', 'Maltese'),
  SelahCountryItem('MH', 'Marshall Islands', 'Marshallese'),
  SelahCountryItem('MR', 'Mauritania', 'Mauritanian'),
  SelahCountryItem('MU', 'Mauritius', 'Mauritian'),
  SelahCountryItem('MX', 'Mexico', 'Mexican'),
  SelahCountryItem('FM', 'Micronesia, Federated States of', 'Micronesian'),
  SelahCountryItem('MD', 'Moldova', 'Moldovan'),
  SelahCountryItem('MC', 'Monaco', 'Monégasque'),
  SelahCountryItem('MN', 'Mongolia', 'Mongolian'),
  SelahCountryItem('ME', 'Montenegro', 'Montenegrin'),
  SelahCountryItem('MA', 'Morocco', 'Moroccan'),
  SelahCountryItem('MZ', 'Mozambique', 'Mozambican'),
  SelahCountryItem('MM', 'Myanmar', 'Burmese'),
  SelahCountryItem('NA', 'Namibia', 'Namibian'),
  SelahCountryItem('NR', 'Nauru', 'Nauruan'),
  SelahCountryItem('NP', 'Nepal', 'Nepali'),
  SelahCountryItem('NL', 'Netherlands', 'Dutch'),
  SelahCountryItem('NZ', 'New Zealand', 'New Zealander'),
  SelahCountryItem('NI', 'Nicaragua', 'Nicaraguan'),
  SelahCountryItem('NE', 'Niger', 'Nigerien'),
  SelahCountryItem('NG', 'Nigeria', 'Nigerian'),
  SelahCountryItem('KP', 'North Korea', 'North Korean'),
  SelahCountryItem('MK', 'North Macedonia', 'North Macedonian'),
  SelahCountryItem('NO', 'Norway', 'Norwegian'),
  SelahCountryItem('OM', 'Oman', 'Omani'),
  SelahCountryItem('PK', 'Pakistan', 'Pakistani'),
  SelahCountryItem('PW', 'Palau', 'Palauan'),
  SelahCountryItem('PS', 'Palestine', 'Palestinian'),
  SelahCountryItem('PA', 'Panama', 'Panamanian'),
  SelahCountryItem('PG', 'Papua New Guinea', 'Papua New Guinean'),
  SelahCountryItem('PY', 'Paraguay', 'Paraguayan'),
  SelahCountryItem('PE', 'Peru', 'Peruvian'),
  SelahCountryItem('PH', 'Philippines', 'Filipino'),
  SelahCountryItem('PL', 'Poland', 'Polish'),
  SelahCountryItem('PT', 'Portugal', 'Portuguese'),
  SelahCountryItem('QA', 'Qatar', 'Qatari'),
  SelahCountryItem('CG', 'Republic of the Congo', 'Congolese'),
  SelahCountryItem('RO', 'Romania', 'Romanian'),
  SelahCountryItem('RU', 'Russia', 'Russian'),
  SelahCountryItem('RW', 'Rwanda', 'Rwandan'),
  SelahCountryItem('KN', 'Saint Kitts and Nevis', 'Kittitian and Nevisian'),
  SelahCountryItem('LC', 'Saint Lucia', 'Saint Lucian'),
  SelahCountryItem('VC', 'Saint Vincent and the Grenadines', 'Vincentian'),
  SelahCountryItem('WS', 'Samoa', 'Samoan'),
  SelahCountryItem('SM', 'San Marino', 'Sammarinese'),
  SelahCountryItem('ST', 'Sao Tome and Principe', 'São Toméan'),
  SelahCountryItem('SA', 'Saudi Arabia', 'Saudi'),
  SelahCountryItem('SN', 'Senegal', 'Senegalese'),
  SelahCountryItem('RS', 'Serbia', 'Serbian'),
  SelahCountryItem('SC', 'Seychelles', 'Seychellois'),
  SelahCountryItem('SL', 'Sierra Leone', 'Sierra Leonean'),
  SelahCountryItem('SG', 'Singapore', 'Singaporean'),
  SelahCountryItem('SK', 'Slovakia', 'Slovak'),
  SelahCountryItem('SI', 'Slovenia', 'Slovenian'),
  SelahCountryItem('SB', 'Solomon Islands', 'Solomon Islander'),
  SelahCountryItem('SO', 'Somalia', 'Somali'),
  SelahCountryItem('ZA', 'South Africa', 'South African'),
  SelahCountryItem('KR', 'South Korea', 'South Korean'),
  SelahCountryItem('SS', 'South Sudan', 'South Sudanese'),
  SelahCountryItem('ES', 'Spain', 'Spanish'),
  SelahCountryItem('LK', 'Sri Lanka', 'Sri Lankan'),
  SelahCountryItem('SD', 'Sudan', 'Sudanese'),
  SelahCountryItem('SR', 'Suriname', 'Surinamese'),
  SelahCountryItem('SE', 'Sweden', 'Swedish'),
  SelahCountryItem('CH', 'Switzerland', 'Swiss'),
  SelahCountryItem('SY', 'Syria', 'Syrian'),
  SelahCountryItem('TW', 'Taiwan', 'Taiwanese'),
  SelahCountryItem('TJ', 'Tajikistan', 'Tajikistani'),
  SelahCountryItem('TZ', 'Tanzania', 'Tanzanian'),
  SelahCountryItem('TH', 'Thailand', 'Thai'),
  SelahCountryItem('TL', 'Timor-Leste', 'Timorese'),
  SelahCountryItem('TG', 'Togo', 'Togolese'),
  SelahCountryItem('TO', 'Tonga', 'Tongan'),
  SelahCountryItem('TT', 'Trinidad and Tobago', 'Trinidadian and Tobagonian'),
  SelahCountryItem('TN', 'Tunisia', 'Tunisian'),
  SelahCountryItem('TM', 'Turkmenistan', 'Turkmen'),
  SelahCountryItem('TV', 'Tuvalu', 'Tuvaluan'),
  SelahCountryItem('TR', 'Türkiye', 'Turkish'),
  SelahCountryItem('UG', 'Uganda', 'Ugandan'),
  SelahCountryItem('UA', 'Ukraine', 'Ukrainian'),
  SelahCountryItem('AE', 'United Arab Emirates', 'Emirati'),
  SelahCountryItem('GB', 'United Kingdom', 'British'),
  SelahCountryItem('US', 'United States', 'American'),
  SelahCountryItem('UY', 'Uruguay', 'Uruguayan'),
  SelahCountryItem('UZ', 'Uzbekistan', 'Uzbekistani'),
  SelahCountryItem('VU', 'Vanuatu', 'Ni-Vanuatu'),
  SelahCountryItem('VA', 'Vatican City', 'Vatican'),
  SelahCountryItem('VE', 'Venezuela', 'Venezuelan'),
  SelahCountryItem('VN', 'Vietnam', 'Vietnamese'),
  SelahCountryItem('YE', 'Yemen', 'Yemeni'),
  SelahCountryItem('ZM', 'Zambia', 'Zambian'),
  SelahCountryItem('ZW', 'Zimbabwe', 'Zimbabwean'),
];

/// Display names for the country-of-birth picker.
List<String> get selahCountryNames => [for (final c in selahCountries) c.name];

/// Display names for the nationality picker.
List<String> get selahNationalityNames => [
  for (final c in selahCountries) c.nationality,
];

/// 184 languages, ISO 639-1.
const List<SelahRefItem> selahLanguages = [
  SelahRefItem('ab', 'Abkhazian'),
  SelahRefItem('aa', 'Afar'),
  SelahRefItem('af', 'Afrikaans'),
  SelahRefItem('ak', 'Akan'),
  SelahRefItem('sq', 'Albanian'),
  SelahRefItem('am', 'Amharic'),
  SelahRefItem('ar', 'Arabic'),
  SelahRefItem('an', 'Aragonese'),
  SelahRefItem('hy', 'Armenian'),
  SelahRefItem('as', 'Assamese'),
  SelahRefItem('av', 'Avaric'),
  SelahRefItem('ae', 'Avestan'),
  SelahRefItem('ay', 'Aymara'),
  SelahRefItem('az', 'Azerbaijani'),
  SelahRefItem('bm', 'Bambara'),
  SelahRefItem('ba', 'Bashkir'),
  SelahRefItem('eu', 'Basque'),
  SelahRefItem('be', 'Belarusian'),
  SelahRefItem('bn', 'Bengali'),
  SelahRefItem('bi', 'Bchristianitya'),
  SelahRefItem('bs', 'Bosnian'),
  SelahRefItem('br', 'Breton'),
  SelahRefItem('bg', 'Bulgarian'),
  SelahRefItem('my', 'Burmese'),
  SelahRefItem('ca', 'Catalan'),
  SelahRefItem('ch', 'Chamorro'),
  SelahRefItem('ce', 'Chechen'),
  SelahRefItem('ny', 'Chichewa'),
  SelahRefItem('zh', 'Chinese (Mandarin)'),
  SelahRefItem('cu', 'Church Slavic'),
  SelahRefItem('cv', 'Chuvash'),
  SelahRefItem('kw', 'Cornish'),
  SelahRefItem('co', 'Corsican'),
  SelahRefItem('cr', 'Cree'),
  SelahRefItem('hr', 'Croatian'),
  SelahRefItem('cs', 'Czech'),
  SelahRefItem('da', 'Danish'),
  SelahRefItem('dv', 'Divehi'),
  SelahRefItem('nl', 'Dutch'),
  SelahRefItem('dz', 'Dzongkha'),
  SelahRefItem('en', 'English'),
  SelahRefItem('eo', 'Esperanto'),
  SelahRefItem('et', 'Estonian'),
  SelahRefItem('ee', 'Ewe'),
  SelahRefItem('fo', 'Faroese'),
  SelahRefItem('fj', 'Fijian'),
  SelahRefItem('fi', 'Finnish'),
  SelahRefItem('fr', 'French'),
  SelahRefItem('ff', 'Fulah'),
  SelahRefItem('gl', 'Galician'),
  SelahRefItem('lg', 'Ganda'),
  SelahRefItem('ka', 'Georgian'),
  SelahRefItem('de', 'German'),
  SelahRefItem('gn', 'Guarani'),
  SelahRefItem('gu', 'Gujarati'),
  SelahRefItem('ht', 'Haitian Creole'),
  SelahRefItem('ha', 'Hausa'),
  SelahRefItem('he', 'Hebrew'),
  SelahRefItem('hz', 'Herero'),
  SelahRefItem('hi', 'Hindi'),
  SelahRefItem('ho', 'Hiri Motu'),
  SelahRefItem('hu', 'Hungarian'),
  SelahRefItem('is', 'Icelandic'),
  SelahRefItem('io', 'Ido'),
  SelahRefItem('ig', 'Igbo'),
  SelahRefItem('id', 'Indonesian'),
  SelahRefItem(
    'ia',
    'Interlingua (International Auxiliary Language Association)',
  ),
  SelahRefItem('ie', 'Interlingue'),
  SelahRefItem('iu', 'Inuktitut'),
  SelahRefItem('ik', 'Inupiaq'),
  SelahRefItem('ga', 'Irish'),
  SelahRefItem('it', 'Italian'),
  SelahRefItem('ja', 'Japanese'),
  SelahRefItem('jv', 'Javanese'),
  SelahRefItem('kl', 'Kalaallisut'),
  SelahRefItem('kn', 'Kannada'),
  SelahRefItem('kr', 'Kanuri'),
  SelahRefItem('ks', 'Kashmiri'),
  SelahRefItem('kk', 'Kazakh'),
  SelahRefItem('km', 'Khmer'),
  SelahRefItem('ki', 'Kikuyu'),
  SelahRefItem('rw', 'Kinyarwanda'),
  SelahRefItem('ky', 'Kirghiz'),
  SelahRefItem('kv', 'Komi'),
  SelahRefItem('kg', 'Kongo'),
  SelahRefItem('ko', 'Korean'),
  SelahRefItem('kj', 'Kuanyama'),
  SelahRefItem('ku', 'Kurdish'),
  SelahRefItem('lo', 'Lao'),
  SelahRefItem('la', 'Latin'),
  SelahRefItem('lv', 'Latvian'),
  SelahRefItem('li', 'Limburgan'),
  SelahRefItem('ln', 'Lingala'),
  SelahRefItem('lt', 'Lithuanian'),
  SelahRefItem('lu', 'Luba-Katanga'),
  SelahRefItem('lb', 'Luxembourgish'),
  SelahRefItem('mk', 'Macedonian'),
  SelahRefItem('mg', 'Malagasy'),
  SelahRefItem('ms', 'Malay'),
  SelahRefItem('ml', 'Malayalam'),
  SelahRefItem('mt', 'Maltese'),
  SelahRefItem('gv', 'Manx'),
  SelahRefItem('mi', 'Maori'),
  SelahRefItem('mr', 'Marathi'),
  SelahRefItem('mh', 'Marshallese'),
  SelahRefItem('el', 'Modern Greek (1453-)'),
  SelahRefItem('mn', 'Mongolian'),
  SelahRefItem('na', 'Nauru'),
  SelahRefItem('nv', 'Navajo'),
  SelahRefItem('ng', 'Ndonga'),
  SelahRefItem('ne', 'Nepali'),
  SelahRefItem('nd', 'North Ndebele'),
  SelahRefItem('se', 'Northern Sami'),
  SelahRefItem('no', 'Norwegian'),
  SelahRefItem('nb', 'Norwegian (Bokmål)'),
  SelahRefItem('nn', 'Norwegian (Nynorsk)'),
  SelahRefItem('oc', 'Occitan'),
  SelahRefItem('oj', 'Ojibwa'),
  SelahRefItem('or', 'Oriya'),
  SelahRefItem('om', 'Oromo'),
  SelahRefItem('os', 'Ossetian'),
  SelahRefItem('pi', 'Pali'),
  SelahRefItem('ps', 'Pashto'),
  SelahRefItem('fa', 'Persian (Farsi)'),
  SelahRefItem('pl', 'Polish'),
  SelahRefItem('pt', 'Portuguese'),
  SelahRefItem('pa', 'Punjabi'),
  SelahRefItem('qu', 'Quechua'),
  SelahRefItem('ro', 'Romanian'),
  SelahRefItem('rm', 'Romansh'),
  SelahRefItem('rn', 'Rundi'),
  SelahRefItem('ru', 'Russian'),
  SelahRefItem('sm', 'Samoan'),
  SelahRefItem('sg', 'Sango'),
  SelahRefItem('sa', 'Sanskrit'),
  SelahRefItem('sc', 'Sardinian'),
  SelahRefItem('gd', 'Scottish Gaelic'),
  SelahRefItem('sr', 'Serbian'),
  SelahRefItem('sh', 'Serbo-Croatian'),
  SelahRefItem('sn', 'Shona'),
  SelahRefItem('sd', 'Sindhi'),
  SelahRefItem('si', 'Sinhala'),
  SelahRefItem('sk', 'Slovak'),
  SelahRefItem('sl', 'Slovenian'),
  SelahRefItem('so', 'Somali'),
  SelahRefItem('nr', 'South Ndebele'),
  SelahRefItem('st', 'Southern Sotho'),
  SelahRefItem('es', 'Spanish'),
  SelahRefItem('su', 'Sundanese'),
  SelahRefItem('sw', 'Swahili'),
  SelahRefItem('ss', 'Swati'),
  SelahRefItem('sv', 'Swedish'),
  SelahRefItem('tl', 'Tagalog'),
  SelahRefItem('ty', 'Tahitian'),
  SelahRefItem('tg', 'Tajik'),
  SelahRefItem('ta', 'Tamil'),
  SelahRefItem('tt', 'Tatar'),
  SelahRefItem('te', 'Telugu'),
  SelahRefItem('th', 'Thai'),
  SelahRefItem('bo', 'Tibetan'),
  SelahRefItem('ti', 'Tigrinya'),
  SelahRefItem('to', 'Tonga (Tonga Islands)'),
  SelahRefItem('ts', 'Tsonga'),
  SelahRefItem('tn', 'Tswana'),
  SelahRefItem('tr', 'Turkish'),
  SelahRefItem('tk', 'Turkmen'),
  SelahRefItem('tw', 'Twi'),
  SelahRefItem('ug', 'Uighur'),
  SelahRefItem('uk', 'Ukrainian'),
  SelahRefItem('ur', 'Urdu'),
  SelahRefItem('uz', 'Uzbek'),
  SelahRefItem('ve', 'Venda'),
  SelahRefItem('vi', 'Vietnamese'),
  SelahRefItem('vo', 'Volapük'),
  SelahRefItem('wa', 'Walloon'),
  SelahRefItem('cy', 'Welsh'),
  SelahRefItem('fy', 'Western Frisian'),
  SelahRefItem('wo', 'Wolof'),
  SelahRefItem('xh', 'Xhosa'),
  SelahRefItem('ii', 'Yi'),
  SelahRefItem('yi', 'Yiddish'),
  SelahRefItem('yo', 'Yoruba'),
  SelahRefItem('za', 'Zhuang'),
  SelahRefItem('zu', 'Zulu'),
];

List<String> get selahLanguageNames => [for (final l in selahLanguages) l.name];

/// 29 ethnicities. SELAH codes — no ISO standard exists.
///
/// Granularity is deliberately mixed. "Pakistani" and "South Asian"
/// sit in one list because that is how people describe themselves, and
/// for this audience the specific answer is the meaningful one. Raised
/// with the Founder rather than decided here.
const List<SelahRefItem> selahEthnicities = [
  SelahRefItem('pakistani', 'Pakistani'),
  SelahRefItem('indian', 'Indian'),
  SelahRefItem('bangladeshi', 'Bangladeshi'),
  SelahRefItem('sri_lankan', 'Sri Lankan'),
  SelahRefItem('south_asian_other', 'South Asian (other)'),
  SelahRefItem('arab', 'Arab'),
  SelahRefItem('north_african', 'North African'),
  SelahRefItem('berber', 'Berber / Amazigh'),
  SelahRefItem('somali', 'Somali'),
  SelahRefItem('black_african', 'Black African'),
  SelahRefItem('black_caribbean', 'Black Caribbean'),
  SelahRefItem('turkish', 'Turkish'),
  SelahRefItem('kurdish', 'Kurdish'),
  SelahRefItem('persian', 'Persian / Iranian'),
  SelahRefItem('afghan', 'Afghan'),
  SelahRefItem('central_asian', 'Central Asian'),
  SelahRefItem('malay', 'Malay'),
  SelahRefItem('indonesian', 'Indonesian'),
  SelahRefItem('southeast_asian_other', 'Southeast Asian (other)'),
  SelahRefItem('east_asian', 'East Asian'),
  SelahRefItem('uyghur', 'Uyghur'),
  SelahRefItem('bosnian', 'Bosnian'),
  SelahRefItem('albanian', 'Albanian'),
  SelahRefItem('balkan_other', 'Balkan (other)'),
  SelahRefItem('white_european', 'White / European'),
  SelahRefItem('latin_american', 'Latin American'),
  SelahRefItem('mixed', 'Mixed heritage'),
  SelahRefItem('other', 'Other'),
  SelahRefItem('prefer_not_to_say', 'Prefer not to say'),
];

List<String> get selahEthnicityNames => [
  for (final e in selahEthnicities) e.name,
];

/// Location preference — Founder decision 2026-08-01, replacing mileage
/// bands (10/25/50/100 miles).
///
/// The old question could never be answered: `location_text` is free text
/// with no coordinates, so no distance in miles was ever computable. These
/// buckets need no geocoding.
const List<SelahRefItem> selahLocationPreferences = [
  SelahRefItem('same_city', 'Same city'),
  SelahRefItem('same_region', 'Same region or county'),
  SelahRefItem('same_country', 'Same country'),
  SelahRefItem('anywhere', 'Anywhere'),
];

List<String> get selahLocationPreferenceNames => [
  for (final l in selahLocationPreferences) l.name,
];

/// Code for a label, for the pickers that still hand back display strings.
/// Returns null if the label is unknown — callers must treat that as a bug,
/// never as a value to store.
String? selahCodeFor(List<SelahRefItem> list, String? name) {
  if (name == null) return null;
  for (final i in list) {
    if (i.name == name) return i.code;
  }
  return null;
}

String? selahCountryCodeFor(String? name) {
  if (name == null) return null;
  for (final c in selahCountries) {
    if (c.name == name) return c.code;
  }
  return null;
}

String? selahNationalityCodeFor(String? nationality) {
  if (nationality == null) return null;
  for (final c in selahCountries) {
    if (c.nationality == nationality) return c.code;
  }
  return null;
}

/// Label for a stored code — the reverse of [selahCodeFor], and the direction
/// every display surface needs. Returns null for an unknown code rather than
/// echoing it back: rendering a raw code to a user is a bug that should look
/// like one, not a slightly-odd-looking word they learn to ignore.
String? selahNameFor(List<SelahRefItem> list, String? code) {
  if (code == null) return null;
  for (final i in list) {
    if (i.code == code) return i.name;
  }
  return null;
}

/// Selah draft relationship choices, selected by the person involved rather
/// than inferred from gender, name, church tradition or family background.
/// A Shepherd is a trusted supporter, not a replacement for Christ and not
/// automatically a legal representative or a holder of spiritual authority.
/// These are local draft values only; no Selah database enum is deployed.
const List<SelahRefItem> selahShepherdRelationships = [
  SelahRefItem('parent', 'Parent'),
  SelahRefItem('father', 'Father'),
  SelahRefItem('mother', 'Mother'),
  SelahRefItem('grandfather', 'Grandfather'),
  SelahRefItem('grandmother', 'Grandmother'),
  SelahRefItem('brother', 'Brother'),
  SelahRefItem('sister', 'Sister'),
  SelahRefItem('son', 'Son'),
  SelahRefItem('daughter', 'Daughter'),
  SelahRefItem('uncle', 'Uncle'),
  SelahRefItem('aunt', 'Aunt'),
  SelahRefItem('cousin', 'Cousin'),
  SelahRefItem('nephew', 'Nephew'),
  SelahRefItem('niece', 'Niece'),
  SelahRefItem('father_in_law', 'Father-in-law'),
  SelahRefItem('mother_in_law', 'Mother-in-law'),
  SelahRefItem('brother_in_law', 'Brother-in-law'),
  SelahRefItem('sister_in_law', 'Sister-in-law'),
  SelahRefItem('pastor', 'Pastor'),
  SelahRefItem('mentor', 'Mentor'),
  SelahRefItem('church_elder', 'Church Elder'),
  SelahRefItem('trusted_christian', 'Trusted Mature Christian'),
  SelahRefItem('family_friend', 'Family Friend'),
  SelahRefItem('trusted_friend', 'Trusted Friend'),
  // Retain this detached key for compatibility with the copied local editor.
  // A legal guardian relationship does not confer additional app permissions.
  SelahRefItem('legal_shepherd', 'Legal Guardian'),
  SelahRefItem('family_representative', 'Family Representative'),
  SelahRefItem('other', 'Other'),
];

List<String> get selahShepherdRelationshipNames => [
  for (final r in selahShepherdRelationships) r.name,
];

/// The same local choices grouped for the retained picker presentation.
/// Any selected relationship remains subject to the Seeker's invitation and
/// access choices; labels alone never confer access to a Journey or messages.
const List<({String title, List<SelahRefItem> items})>
selahShepherdRelationshipGroups = [
  (
    title: 'Immediate Family',
    items: [
      SelahRefItem('parent', 'Parent'),
      SelahRefItem('father', 'Father'),
      SelahRefItem('mother', 'Mother'),
      SelahRefItem('brother', 'Brother'),
      SelahRefItem('sister', 'Sister'),
      SelahRefItem('son', 'Son'),
      SelahRefItem('daughter', 'Daughter'),
    ],
  ),
  (
    title: 'Grandparents',
    items: [
      SelahRefItem('grandfather', 'Grandfather'),
      SelahRefItem('grandmother', 'Grandmother'),
    ],
  ),
  (
    title: 'Extended Family',
    items: [
      SelahRefItem('uncle', 'Uncle'),
      SelahRefItem('aunt', 'Aunt'),
      SelahRefItem('cousin', 'Cousin'),
      SelahRefItem('nephew', 'Nephew'),
      SelahRefItem('niece', 'Niece'),
    ],
  ),
  (
    title: 'Marriage',
    items: [
      SelahRefItem('father_in_law', 'Father-in-law'),
      SelahRefItem('mother_in_law', 'Mother-in-law'),
      SelahRefItem('brother_in_law', 'Brother-in-law'),
      SelahRefItem('sister_in_law', 'Sister-in-law'),
    ],
  ),
  (
    title: 'Trusted People',
    items: [
      SelahRefItem('pastor', 'Pastor'),
      SelahRefItem('mentor', 'Mentor'),
      SelahRefItem('church_elder', 'Church Elder'),
      SelahRefItem('trusted_christian', 'Trusted Mature Christian'),
      SelahRefItem('family_friend', 'Family Friend'),
      SelahRefItem('trusted_friend', 'Trusted Friend'),
      SelahRefItem('legal_shepherd', 'Legal Guardian'),
      SelahRefItem('family_representative', 'Family Representative'),
      SelahRefItem('other', 'Other'),
    ],
  ),
];

/// Whether a code is recognised by this local draft's relationship picker.
/// The inherited function name is not a claim of backend deployment.
bool selahRelationshipIsLive(String code) =>
    selahShepherdRelationships.any((r) => r.code == code);

/// "uncle" -> "Uncle". Null for null or unknown.
String? selahRelationshipLabel(String? code) =>
    selahNameFor(selahShepherdRelationships, code);

/// "Uncle" -> "uncle". Null for null or unknown.
String? selahRelationshipCode(String? label) =>
    selahCodeFor(selahShepherdRelationships, label);
