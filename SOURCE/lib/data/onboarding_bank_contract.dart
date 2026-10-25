import 'dart:convert';

import '../models/onboarding_question.dart';
import 'chapter3_categories.dart';

class OnboardingBankContractEntry {
  final String qid;
  final String variant;
  final bool ch4Scored;
  final String? showIfQid;
  final List<String> showIfNotAnyOf;

  const OnboardingBankContractEntry({
    required this.qid,
    required this.variant,
    required this.ch4Scored,
    required this.showIfQid,
    required this.showIfNotAnyOf,
  });
}

List<OnboardingBankContractEntry> get onboardingBankContract {
  final entries = [
    for (final category in chapter3Categories)
      for (final question in category.questions)
        OnboardingBankContractEntry(
          qid: question.id,
          variant: question.genderVisibility.name,
          ch4Scored: question.ch4Status != Ch4Status.none,
          showIfQid: question.showIf?.questionId,
          showIfNotAnyOf: question.showIf?.notAnyOf ?? const [],
        ),
  ];
  entries.sort((a, b) {
    final aNumber = int.parse(a.qid.substring('ch3_q'.length));
    final bNumber = int.parse(b.qid.substring('ch3_q'.length));
    final byNumber = aNumber.compareTo(bNumber);
    return byNumber != 0 ? byNumber : a.variant.compareTo(b.variant);
  });
  return entries;
}

String _sqlText(String value) => "'${value.replaceAll("'", "''")}'";

/// Generated VALUES body consumed by the live SQL suite.
///
/// The Flutter test compares this exact text with the marked block in
/// `supabase/tests/selah_onboarding_bank_suite.sql`. A Dart-only change goes
/// red locally; a table-only change goes red in SQL. Together they close both
/// halves of inherited upstream action 196 without making either copy silently authoritative.
String onboardingBankExpectedSqlValues() {
  return onboardingBankContract
      .map((entry) {
        final showIf = entry.showIfQid == null
            ? 'NULL'
            : _sqlText(entry.showIfQid!);
        final notAnyOf = _sqlText(jsonEncode(entry.showIfNotAnyOf));
        return '    (${_sqlText(entry.qid)}, ${_sqlText(entry.variant)}, '
            '${entry.ch4Scored}, $showIf, $notAnyOf::jsonb)';
      })
      .join(',\n');
}
