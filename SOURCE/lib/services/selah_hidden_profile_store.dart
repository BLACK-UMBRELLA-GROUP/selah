// Account-scoped on-device summaries for Settings -> Hidden Profiles.
//
// The server remains authoritative for REAL hides: `profile_blocks` plus the
// `selah_block_user` / `selah_unblock_user` RPCs own whether two real accounts
// may see each other. RLS correctly makes the hidden profile row unreadable
// after the block, however, so Settings cannot fetch the person's display
// name after the fact. We therefore retain the small, already-visible summary
// at the moment a hide succeeds. It is a rendering cache, never an authority.
//
// Developer Browse profiles have deliberately non-UUID ids and no server row.
// Their hide/report state lives here entirely so the complete experience can
// be tested without ever sending a fake id to Supabase.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/seeker_profile.dart';
import 'selah_auth.dart';
import 'selah_report_service.dart';

@immutable
class SelahHiddenProfileRecord {
  final String id;
  final String firstName;
  final String? surnameLine;
  final int age;
  final String city;
  final String gender;
  final bool isDemo;

  const SelahHiddenProfileRecord({
    required this.id,
    required this.firstName,
    required this.age,
    required this.city,
    required this.gender,
    required this.isDemo,
    this.surnameLine,
  });

  factory SelahHiddenProfileRecord.fromProfile(SeekerProfile profile) =>
      SelahHiddenProfileRecord(
        id: profile.id,
        firstName: profile.firstName,
        surnameLine: profile.surnameLine,
        age: profile.age,
        city: profile.city,
        gender: profile.gender,
        isDemo: !SelahReportService.isPersistableId(profile.id),
      );

  factory SelahHiddenProfileRecord.fallback(String id) =>
      SelahHiddenProfileRecord(
        id: id,
        firstName: 'Hidden profile',
        age: 0,
        city: 'Details unavailable on this device',
        gender: '',
        isDemo: !SelahReportService.isPersistableId(id),
      );

  factory SelahHiddenProfileRecord.fromJson(Map<String, dynamic> json) =>
      SelahHiddenProfileRecord(
        id: json['id'] as String,
        firstName: (json['first_name'] as String?) ?? 'Hidden profile',
        surnameLine: json['surname_line'] as String?,
        age: (json['age'] as num?)?.toInt() ?? 0,
        city: (json['city'] as String?) ?? 'Details unavailable',
        gender: (json['gender'] as String?) ?? '',
        isDemo: json['is_demo'] == true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'surname_line': surnameLine,
    'age': age,
    'city': city,
    'gender': gender,
    'is_demo': isDemo,
  };

  String get displayName {
    final surname = surnameLine?.trim();
    return surname == null || surname.isEmpty
        ? firstName
        : '$firstName $surname';
  }
}

abstract final class SelahHiddenProfileStore {
  static const _keyPrefix = 'selah.hidden_profiles.v1.';
  static int _epoch = 0;

  /// Invalidates reads in flight; persisted summaries keep their own owner.
  static void clearForAccountChange() => _epoch++;

  static String get _accountScope {
    try {
      return SelahAuth.currentUser?.id ?? 'developer_preview';
    } catch (_) {
      // Unit tests and the pre-auth developer preview can exist before
      // Supabase is initialised. They still need a deterministic local scope.
      return 'developer_preview';
    }
  }

  static Future<List<SelahHiddenProfileRecord>> records() async {
    final owner = _accountScope;
    final epoch = _epoch;
    final result = await _read('$_keyPrefix$owner');
    return _isCurrent(owner, epoch) ? result : const [];
  }

  static bool _isCurrent(String owner, int epoch) =>
      epoch == _epoch && owner == _accountScope;

  static Future<List<SelahHiddenProfileRecord>> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            SelahHiddenProfileRecord.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      debugPrint('SELAH: hidden-profile cache could not be read. $e');
      return const [];
    }
  }

  static Future<void> remember(SeekerProfile profile) async {
    final owner = _accountScope;
    final epoch = _epoch;
    final current = await _read('$_keyPrefix$owner');
    if (!_isCurrent(owner, epoch)) return;
    final next = <SelahHiddenProfileRecord>[
      SelahHiddenProfileRecord.fromProfile(profile),
      for (final record in current)
        if (record.id != profile.id) record,
    ];
    await _write(next, owner: owner, epoch: epoch);
  }

  static Future<void> forget(String profileId) async {
    final owner = _accountScope;
    final epoch = _epoch;
    final current = await _read('$_keyPrefix$owner');
    if (!_isCurrent(owner, epoch)) return;
    await _write(
      [
        for (final record in current)
          if (record.id != profileId) record,
      ],
      owner: owner,
      epoch: epoch,
    );
  }

  static Future<Set<String>> hiddenIds() async {
    final owner = _accountScope;
    final epoch = _epoch;
    final saved = await records();
    if (!_isCurrent(owner, epoch)) return {};
    return {for (final record in saved) record.id};
  }

  static Future<void> _write(
    List<SelahHiddenProfileRecord> records, {
    required String owner,
    required int epoch,
  }) async {
    final key = '$_keyPrefix$owner';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrent(owner, epoch)) return;
      if (records.isEmpty) {
        await prefs.remove(key);
        return;
      }
      await prefs.setString(
        key,
        jsonEncode([for (final record in records) record.toJson()]),
      );
    } catch (e) {
      // Server hiding has already succeeded for real profiles. A rendering
      // cache failure must be visible in logs but must never undo safety.
      debugPrint('SELAH: hidden-profile cache could not be written. $e');
    }
  }
}
