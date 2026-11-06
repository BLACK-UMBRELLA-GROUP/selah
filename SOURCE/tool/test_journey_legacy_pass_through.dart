// Standalone pure checks run directly, without a Flutter engine or backend.
// ignore_for_file: avoid_relative_lib_imports, avoid_print

import '../lib/data/selah_journey_legacy_pass_through.dart';

Future<void> main() async {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  final calls = <String>[];
  var result = await advanceSelahVisibleThreshold(
    fromStage: 'compatibility_reveal',
    canAct: () => true,
    advance: (stage) async {
      calls.add(stage);
      return stage == 'compatibility_reveal'
          ? const SelahStageAdvance(true, 'mentor_gate', 'advanced')
          : const SelahStageAdvance(true, 'phase_1', 'advanced');
    },
  );
  check(
    calls.join(',') == 'compatibility_reveal,mentor_gate',
    'exact legacy pass-through',
  );
  check(
    result?.advanced == true && result?.stage == 'phase_1',
    'confirmed destination',
  );

  calls.clear();
  result = await advanceSelahVisibleThreshold(
    fromStage: 'mentor_gate',
    canAct: () => true,
    advance: (stage) async {
      calls.add(stage);
      return const SelahStageAdvance(false, 'phase_2', 'stage_moved');
    },
  );
  check(
    calls.length == 1 && calls.single == 'mentor_gate',
    'legacy open calls existing stage once',
  );
  check(
    result?.accepted == true && result?.stage == 'phase_2',
    'already-moved is accepted without guessing stage',
  );

  for (final reason in [
    'waiting_for_reveal',
    'journey_paused',
    'call_failed',
  ]) {
    calls.clear();
    final refusal = SelahStageAdvance(false, 'compatibility_reveal', reason);
    result = await advanceSelahVisibleThreshold(
      fromStage: 'compatibility_reveal',
      canAct: () => true,
      advance: (stage) async {
        calls.add(stage);
        return refusal;
      },
    );
    check(
      identical(result, refusal) && calls.length == 1,
      'preserve $reason refusal',
    );
  }

  calls.clear();
  const refusedAtLegacy = SelahStageAdvance(
    false,
    'mentor_gate',
    'shepherd_required_other',
  );
  result = await advanceSelahVisibleThreshold(
    fromStage: 'compatibility_reveal',
    canAct: () => true,
    advance: (stage) async {
      calls.add(stage);
      return refusedAtLegacy;
    },
  );
  check(
    identical(result, refusedAtLegacy) && calls.length == 1,
    'a refused legacy destination cannot trigger another RPC',
  );

  result = await advanceSelahVisibleThreshold(
    fromStage: 'compatibility_reveal',
    canAct: () => true,
    advance: (stage) async => stage == 'compatibility_reveal'
        ? const SelahStageAdvance(false, 'mentor_gate', 'stage_moved')
        : const SelahStageAdvance(
            false,
            'mentor_gate',
            'shepherd_required_other',
          ),
  );
  check(
    result?.reason == 'shepherd_required_other' && result?.accepted == false,
    'legacy refusal remains failure',
  );

  calls.clear();
  result = await advanceSelahVisibleThreshold(
    fromStage: 'phase_1',
    canAct: () => true,
    advance: (stage) async {
      calls.add(stage);
      return const SelahStageAdvance(true, 'phase_2', 'advanced');
    },
  );
  check(
    calls.isEmpty && result == SelahStageAdvance.failed,
    'cannot bypass Family Review',
  );

  var current = false;
  result = await advanceSelahVisibleThreshold(
    fromStage: 'mentor_gate',
    canAct: () => current,
    advance: (stage) async {
      calls.add(stage);
      return const SelahStageAdvance(true, 'phase_1', 'advanced');
    },
  );
  check(result == null && calls.isEmpty, 'expired owner cannot start RPC');

  current = true;
  result = await advanceSelahVisibleThreshold(
    fromStage: 'compatibility_reveal',
    canAct: () => current,
    advance: (stage) async {
      calls.add(stage);
      current = false;
      return const SelahStageAdvance(true, 'mentor_gate', 'advanced');
    },
  );
  check(
    result == null && calls.length == 1,
    'revocation between calls prevents hidden-stage RPC',
  );

  current = true;
  calls.clear();
  result = await advanceSelahVisibleThreshold(
    fromStage: 'compatibility_reveal',
    canAct: () => current,
    advance: (stage) async {
      calls.add(stage);
      if (stage == 'mentor_gate') current = false;
      return SelahStageAdvance(
        true,
        stage == 'mentor_gate' ? 'phase_1' : 'mentor_gate',
        'advanced',
      );
    },
  );
  check(
    result == null && calls.length == 2,
    'revoked result cannot update a new owner',
  );
  var refetches = 0;
  var readsCurrent = true;
  final moved = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(false, 'phase_1', 'stage_moved'),
    canAct: () => readsCurrent,
    refetch: () async {
      refetches++;
      return 'phase_3';
    },
    stageOf: (value) => value,
  );
  check(
    moved?.value == 'phase_3' && refetches == 1,
    'already-moved uses authoritative refetch destination',
  );
  check(
    moved?.failureReason == null,
    'confirmed destination does not publish a failure',
  );
  refetches = 0;
  final unchanged = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(true, 'phase_1', 'advanced'),
    canAct: () => true,
    refetch: () async {
      refetches++;
      return 'mentor_gate';
    },
    stageOf: (value) => value,
  );
  check(
    unchanged?.value == 'mentor_gate' &&
        unchanged?.failureReason == 'stage_not_confirmed',
    'unchanged raw legacy stage holds save failure',
  );
  check(
    refetches == 1,
    'unchanged stage does not recursively refetch or advance',
  );
  final unchangedSource = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(false, 'phase_1', 'stage_moved'),
    fromStage: 'compatibility_reveal',
    canAct: () => true,
    refetch: () async => 'compatibility_reveal',
    stageOf: (value) => value,
  );
  check(
    unchangedSource?.value == 'compatibility_reveal' &&
        unchangedSource?.failureReason == 'stage_not_confirmed',
    'unchanged source stage is not a confirmed transition',
  );
  refetches = 0;
  final refused = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(false, 'mentor_gate', 'journey_paused'),
    canAct: () => true,
    refetch: () async {
      refetches++;
      return 'phase_1';
    },
    stageOf: (value) => value,
  );
  check(
    refused?.failureReason == 'journey_paused' && refetches == 0,
    'refusal remains truthful without another request',
  );
  final missing = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(true, 'phase_1', 'advanced'),
    canAct: () => true,
    refetch: () async => null,
    stageOf: (value) => value,
  );
  check(
    missing?.value == null && missing?.failureReason == 'stage_not_confirmed',
    'missing confirmation is a held failure',
  );
  for (final rawStage in <String?>[null, '', 'unknown_stage']) {
    refetches = 0;
    final unconfirmed = await confirmSelahVisibleThreshold<({String? stage})>(
      result: const SelahStageAdvance(false, 'phase_1', 'stage_moved'),
      canAct: () => true,
      refetch: () async {
        refetches++;
        return (stage: rawStage);
      },
      stageOf: (value) => value.stage,
    );
    check(
      unconfirmed?.value?.stage == rawStage &&
          unconfirmed?.failureReason == 'stage_not_confirmed' &&
          refetches == 1,
      'invalid raw stage $rawStage holds once without guessing',
    );
  }
  readsCurrent = false;
  refetches = 0;
  final expiredBeforeRead = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(false, null, 'stage_moved'),
    canAct: () => readsCurrent,
    refetch: () async {
      refetches++;
      return 'phase_1';
    },
    stageOf: (value) => value,
  );
  check(
    expiredBeforeRead == null && refetches == 0,
    'revoked owner cannot begin confirmation read',
  );
  readsCurrent = true;
  final expiredAfterRead = await confirmSelahVisibleThreshold<String>(
    result: const SelahStageAdvance(false, null, 'stage_moved'),
    canAct: () => readsCurrent,
    refetch: () async {
      readsCurrent = false;
      return 'mentor_gate';
    },
    stageOf: (value) => value,
  );
  check(
    expiredAfterRead == null,
    'revoked result publishes neither stale stage nor stale failure',
  );
  readsCurrent = true;
  final expiredWithMissingStage =
      await confirmSelahVisibleThreshold<({String? stage})>(
        result: const SelahStageAdvance(true, 'phase_1', 'advanced'),
        canAct: () => readsCurrent,
        refetch: () async {
          readsCurrent = false;
          return (stage: null);
        },
        stageOf: (value) => value.stage,
      );
  check(
    expiredWithMissingStage == null,
    'expired missing-stage read cannot publish a held error to another owner',
  );
  print('Journey legacy pass-through: $checks checks passed.');
}
