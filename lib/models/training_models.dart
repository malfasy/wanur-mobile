/// Baris tabel `training_sessions` (indikator tersimpan, tidak dihitung ulang).
class TrainingSessionRow {
  final int id;
  final int? profileId;
  final int startMs;
  final int endMs;
  final String keymap;
  final double activeMin;
  final List<int> presses; // telunjuk, tengah, manis, kelingking
  final int totalPresses;
  final double? pressRate;
  final double? ipiMedianS;
  final double? forceMedian;
  final int bleDisconnects;
  final bool qualifiesForTarget;
  final int? leastUsedFinger;
  final String? endReason;
  final int weekStartMs;
  final String source;

  const TrainingSessionRow({
    required this.id,
    required this.profileId,
    required this.startMs,
    required this.endMs,
    required this.keymap,
    required this.activeMin,
    required this.presses,
    required this.totalPresses,
    required this.pressRate,
    required this.ipiMedianS,
    required this.forceMedian,
    required this.bleDisconnects,
    required this.qualifiesForTarget,
    required this.leastUsedFinger,
    required this.endReason,
    required this.weekStartMs,
    required this.source,
  });

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);
  int get durationMs => endMs - startMs;

  factory TrainingSessionRow.fromMap(Map<String, Object?> m) => TrainingSessionRow(
        id: m['id'] as int,
        profileId: m['profile_id'] as int?,
        startMs: m['start_ms'] as int,
        endMs: m['end_ms'] as int,
        keymap: m['keymap'] as String,
        activeMin: (m['active_min'] as num).toDouble(),
        presses: [
          m['presses_f1'] as int,
          m['presses_f2'] as int,
          m['presses_f3'] as int,
          m['presses_f4'] as int,
        ],
        totalPresses: m['total_presses'] as int,
        pressRate: (m['press_rate'] as num?)?.toDouble(),
        ipiMedianS: (m['ipi_median_s'] as num?)?.toDouble(),
        forceMedian: (m['force_median'] as num?)?.toDouble(),
        bleDisconnects: m['ble_disconnects'] as int,
        qualifiesForTarget: (m['qualifies_for_target'] as int) == 1,
        leastUsedFinger: m['least_used_finger'] as int?,
        endReason: m['end_reason'] as String?,
        weekStartMs: m['week_start_ms'] as int,
        source: m['source'] as String,
      );
}

/// Baris tabel `weekly_summary`.
class WeeklySummaryRow {
  final String source;
  final int weekStartMs;
  final int sessionsCount;
  final int qualifyingCount;
  final double activeMinTotal;
  final List<int> presses;
  final int bleDisconnects;
  final int target;
  final double? compliancePct;

  const WeeklySummaryRow({
    required this.source,
    required this.weekStartMs,
    required this.sessionsCount,
    required this.qualifyingCount,
    required this.activeMinTotal,
    required this.presses,
    required this.bleDisconnects,
    required this.target,
    required this.compliancePct,
  });

  DateTime get weekStart => DateTime.fromMillisecondsSinceEpoch(weekStartMs);

  factory WeeklySummaryRow.fromMap(Map<String, Object?> m) => WeeklySummaryRow(
        source: m['source'] as String,
        weekStartMs: m['week_start_ms'] as int,
        sessionsCount: m['sessions_count'] as int,
        qualifyingCount: m['qualifying_count'] as int,
        activeMinTotal: (m['active_min_total'] as num).toDouble(),
        presses: [
          m['presses_f1'] as int,
          m['presses_f2'] as int,
          m['presses_f3'] as int,
          m['presses_f4'] as int,
        ],
        bleDisconnects: m['ble_disconnects'] as int,
        target: m['target'] as int,
        compliancePct: (m['compliance_pct'] as num?)?.toDouble(),
      );
}

/// Baris tabel `grip_tests`.
class GripTestRow {
  final int id;
  final String hand; // 'right' / 'left'
  final int tMs;
  final List<double> trials;
  final double value;
  final double? changeFromFirstPct;
  final String source;
  final int? profileId;

  const GripTestRow({
    required this.id,
    required this.hand,
    required this.tMs,
    required this.trials,
    required this.value,
    required this.changeFromFirstPct,
    required this.source,
    required this.profileId,
  });

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(tMs);
  String get handLabel => hand == 'left' ? 'Kiri' : 'Kanan';

  factory GripTestRow.fromMap(Map<String, Object?> m) => GripTestRow(
        id: m['id'] as int,
        hand: m['hand'] as String,
        tMs: m['t_ms'] as int,
        trials: [
          (m['trial1'] as num).toDouble(),
          (m['trial2'] as num).toDouble(),
          (m['trial3'] as num).toDouble(),
        ],
        value: (m['value'] as num).toDouble(),
        changeFromFirstPct: (m['change_from_first_pct'] as num?)?.toDouble(),
        source: m['source'] as String,
        profileId: m['profile_id'] as int?,
      );
}

/// Sampel mentah satu percobaan tes genggam (kg*).
class GripTrialRaw {
  final List<({int tMs, double kg})> rest;
  final List<({int tMs, double kg})> grip;
  const GripTrialRaw({required this.rest, required this.grip});
}
