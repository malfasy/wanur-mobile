import 'package:sqflite/sqflite.dart';

import '../logic/indicators.dart';
import '../logic/session_machine.dart';
import '../logic/weekly.dart';
import '../models/training_models.dart';
import 'database_helper.dart';

/// Akses data logbook latihan, tes genggam, target, dan ringkasan mingguan.
///
/// Semua indikator dihitung SEKALI saat sesi/tes disimpan (lewat fungsi murni di
/// `lib/logic/`) lalu ditulis ke database. Layar hanya membaca nilai tersimpan.
/// Ringkasan mingguan (`weekly_summary`) diperbarui setiap kali sesi disimpan
/// atau target diubah.
class TrainingRepository {
  TrainingRepository._();
  static final TrainingRepository instance = TrainingRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ------------------------------------------------------------------
  // SIMPAN
  // ------------------------------------------------------------------

  /// Simpan satu sesi beserta data mentahnya, lalu perbarui ringkasan mingguan.
  Future<int> saveSession(RawSession raw, SessionIndicators ind,
      {required String source, int? profileId}) async {
    final db = await _db;
    late int id;
    await db.transaction((txn) async {
      id = await insertSession(txn, raw, ind, source: source, profileId: profileId);
      await refreshWeeks(txn, source, fromMs: ind.startMs);
    });
    return id;
  }

  /// Sisipkan sesi tanpa memperbarui ringkasan (dipakai impor massal).
  Future<int> insertSession(DatabaseExecutor ex, RawSession raw, SessionIndicators ind,
      {required String source, int? profileId}) async {
    final id = await ex.insert('training_sessions', {
      'profile_id': profileId,
      'start_ms': ind.startMs,
      'end_ms': ind.endMs,
      'keymap': ind.keymap,
      'active_min': ind.activeMin,
      'presses_f1': ind.pressesPerFinger[0],
      'presses_f2': ind.pressesPerFinger[1],
      'presses_f3': ind.pressesPerFinger[2],
      'presses_f4': ind.pressesPerFinger[3],
      'total_presses': ind.totalPresses,
      'press_rate': ind.pressRate,
      'ipi_median_s': ind.ipiMedianS,
      'force_median': ind.forceMedian,
      'ble_disconnects': ind.bleDisconnects,
      'qualifies_for_target': ind.qualifiesForTarget ? 1 : 0,
      'least_used_finger': ind.leastUsedFinger,
      'end_reason': ind.endReason,
      'week_start_ms': weekStartMs(ind.startMs),
      'source': source,
    });
    final batch = ex.batch();
    for (final k in raw.keys) {
      batch.insert('key_events', {
        'session_id': id,
        'char': k.char,
        'action': k.action,
        't_ms': k.tMs,
      });
    }
    for (final f in raw.force) {
      batch.insert('force_samples', {
        'session_id': id,
        'grip_test_id': null,
        'value': f.kg,
        't_ms': f.tMs,
        'phase': null,
      });
    }
    await batch.commit(noResult: true);
    return id;
  }

  /// Simpan tes genggam 3 percobaan. Nilai percobaan, nilai tes, dan perubahan
  /// dari tes pertama (per tangan, per sumber data) dihitung di sini sekali.
  Future<GripTestRow> saveGripTest({
    required String hand,
    required int tMs,
    required List<GripTrialRaw> trials,
    required String source,
    int? profileId,
    DatabaseExecutor? executor,
  }) async {
    if (trials.length != 3) {
      throw ArgumentError('Tes genggam harus berisi tepat 3 percobaan');
    }
    final ex = executor ?? await _db;
    final trialValues = [
      for (final t in trials)
        gripTrialValue([for (final s in t.rest) s.kg], [for (final s in t.grip) s.kg]) ?? 0.0
    ];
    final value = gripTestValue(trialValues)!;
    final first = await ex.query('grip_tests',
        columns: ['value'],
        where: 'source = ? AND hand = ? AND t_ms < ?',
        whereArgs: [source, hand, tMs],
        orderBy: 't_ms ASC',
        limit: 1);
    final double? change = first.isEmpty
        ? 0.0
        : changeFromFirstPct(value, (first.first['value'] as num).toDouble());
    final id = await ex.insert('grip_tests', {
      'hand': hand,
      't_ms': tMs,
      'trial1': trialValues[0],
      'trial2': trialValues[1],
      'trial3': trialValues[2],
      'value': value,
      'change_from_first_pct': change,
      'source': source,
      'profile_id': profileId,
    });
    final batch = ex.batch();
    for (var i = 0; i < trials.length; i++) {
      for (final s in trials[i].rest) {
        batch.insert('force_samples',
            {'session_id': null, 'grip_test_id': id, 'value': s.kg, 't_ms': s.tMs, 'phase': 'rest${i + 1}'});
      }
      for (final s in trials[i].grip) {
        batch.insert('force_samples',
            {'session_id': null, 'grip_test_id': id, 'value': s.kg, 't_ms': s.tMs, 'phase': 'grip${i + 1}'});
      }
    }
    await batch.commit(noResult: true);
    return GripTestRow(
      id: id,
      hand: hand,
      tMs: tMs,
      trials: trialValues,
      value: value,
      changeFromFirstPct: change,
      source: source,
      profileId: profileId,
    );
  }

  // ------------------------------------------------------------------
  // TARGET MINGGUAN
  // ------------------------------------------------------------------

  Future<List<({int setAtMs, int sessionsPerWeek})>> _targets(DatabaseExecutor ex) async {
    final rows = await ex.query('weekly_target', orderBy: 'set_at_ms ASC');
    return [
      for (final r in rows)
        (setAtMs: r['set_at_ms'] as int, sessionsPerWeek: r['sessions_per_week'] as int)
    ];
  }

  Future<int> currentTarget() async {
    final t = await _targets(await _db);
    return t.isEmpty ? kDefaultWeeklyTarget : t.last.sessionsPerWeek;
  }

  /// Set target baru, lalu hitung ulang ringkasan minggu ini (dan sesudahnya)
  /// untuk kedua sumber data. Minggu yang sudah lewat memakai target lamanya.
  Future<void> setWeeklyTarget(int sessionsPerWeek, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('weekly_target', {'sessions_per_week': sessionsPerWeek, 'set_at_ms': now});
      for (final src in ['real', 'sim']) {
        await refreshWeeks(txn, src, fromMs: now, onlyExisting: true);
      }
    });
  }

  // ------------------------------------------------------------------
  // RINGKASAN MINGGUAN
  // ------------------------------------------------------------------

  /// Hitung ulang baris `weekly_summary` untuk [source] dari minggu [fromMs]
  /// sampai minggu terakhir (minggu ini atau minggu sesi terakhir). Minggu
  /// kosong di tengah ikut dibuat (0 sesi, kepatuhan 0%).
  Future<void> refreshWeeks(DatabaseExecutor ex, String source,
      {required int fromMs, bool onlyExisting = false}) async {
    final bounds = await ex.rawQuery(
        'SELECT MIN(week_start_ms) AS a, MAX(week_start_ms) AS b FROM training_sessions WHERE source = ?',
        [source]);
    final minSession = bounds.first['a'] as int?;
    final maxSession = bounds.first['b'] as int?;
        if (minSession == null || maxSession == null) {
      await ex.delete('weekly_summary', where: 'source = ?', whereArgs: [source]);
      return;
    }
    final lastSummary = (await ex.rawQuery(
            'SELECT MAX(week_start_ms) AS m FROM weekly_summary WHERE source = ?', [source]))
        .first['m'] as int?;
    var from = weekStartMs(fromMs);
    if (lastSummary != null && lastSummary < from) from = lastSummary;
    if (from < minSession) from = minSession;
    // Data simulasi memakai timestamp dari file (bisa di masa lalu), jadi
    // ringkasannya berhenti di minggu sesi terakhir, bukan diperpanjang ke hari ini.
    final nowWeek =
        source == 'sim' ? maxSession : weekStartMs(DateTime.now().millisecondsSinceEpoch);
    var to = maxSession > nowWeek ? maxSession : nowWeek;
    if (onlyExisting && lastSummary != null && lastSummary > to) to = lastSummary;
    if (from > to) return;

    final agg = await ex.rawQuery('''
      SELECT week_start_ms AS w, COUNT(*) AS n, SUM(qualifies_for_target) AS q,
             SUM(active_min) AS a, SUM(presses_f1) AS p1, SUM(presses_f2) AS p2,
             SUM(presses_f3) AS p3, SUM(presses_f4) AS p4, SUM(ble_disconnects) AS d
      FROM training_sessions WHERE source = ? AND week_start_ms BETWEEN ? AND ?
      GROUP BY week_start_ms
    ''', [source, from, to]);
    final byWeek = {for (final r in agg) r['w'] as int: r};
    final targets = await _targets(ex);
    final batch = ex.batch();
    for (final w in weekRange(from, to)) {
      final r = byWeek[w];
      final q = (r?['q'] as num?)?.toInt() ?? 0;
      final target = targetForWeek(targets, w);
      batch.insert(
        'weekly_summary',
        {
          'source': source,
          'week_start_ms': w,
          'sessions_count': (r?['n'] as num?)?.toInt() ?? 0,
          'qualifying_count': q,
          'active_min_total': (r?['a'] as num?)?.toDouble() ?? 0.0,
          'presses_f1': (r?['p1'] as num?)?.toInt() ?? 0,
          'presses_f2': (r?['p2'] as num?)?.toInt() ?? 0,
          'presses_f3': (r?['p3'] as num?)?.toInt() ?? 0,
          'presses_f4': (r?['p4'] as num?)?.toInt() ?? 0,
          'ble_disconnects': (r?['d'] as num?)?.toInt() ?? 0,
          'target': target,
          'compliance_pct': compliancePct(q, target),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ------------------------------------------------------------------
  // BACA
  // ------------------------------------------------------------------

  Future<List<TrainingSessionRow>> sessions(String source, {int? fromMs, int? toMs}) async {
    final db = await _db;
    final where = StringBuffer('source = ?');
    final args = <Object?>[source];
    if (fromMs != null) {
      where.write(' AND start_ms >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.write(' AND start_ms < ?');
      args.add(toMs);
    }
    final rows = await db.query('training_sessions',
        where: where.toString(), whereArgs: args, orderBy: 'start_ms DESC');
    return rows.map(TrainingSessionRow.fromMap).toList();
  }

  /// "Hari ini" untuk satu sumber data. Untuk glove nyata = sekarang. Untuk
  /// simulasi = data terakhir yang ada (sesi atau tes genggam), supaya kartu
  /// "minggu ini" menampilkan minggu terakhir profil.
  Future<int> referenceNowMs(String source) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (source != 'sim') return now;
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT MAX(m) AS m FROM (
        SELECT MAX(start_ms) AS m FROM training_sessions WHERE source = 'sim'
        UNION ALL SELECT MAX(t_ms) AS m FROM grip_tests WHERE source = 'sim')
    ''');
    return (r.first['m'] as int?) ?? now;
  }

  Future<TrainingSessionRow?> sessionById(int id) async {
    final db = await _db;
    final rows = await db.query('training_sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TrainingSessionRow.fromMap(rows.first);
  }

  Future<List<WeeklySummaryRow>> weeklySummaries(String source, {int? fromWeekMs}) async {
    final db = await _db;
    final rows = await db.query('weekly_summary',
        where: fromWeekMs == null ? 'source = ?' : 'source = ? AND week_start_ms >= ?',
        whereArgs: fromWeekMs == null ? [source] : [source, fromWeekMs],
        orderBy: 'week_start_ms ASC');
    return rows.map(WeeklySummaryRow.fromMap).toList();
  }

  Future<WeeklySummaryRow?> weekSummary(String source, int weekStart) async {
    final db = await _db;
    final rows = await db.query('weekly_summary',
        where: 'source = ? AND week_start_ms = ?', whereArgs: [source, weekStart]);
    return rows.isEmpty ? null : WeeklySummaryRow.fromMap(rows.first);
  }

  Future<List<GripTestRow>> gripTests(String source, {int? fromMs}) async {
    final db = await _db;
    final rows = await db.query('grip_tests',
        where: fromMs == null ? 'source = ?' : 'source = ? AND t_ms >= ?',
        whereArgs: fromMs == null ? [source] : [source, fromMs],
        orderBy: 't_ms ASC');
    return rows.map(GripTestRow.fromMap).toList();
  }

  // ------------------------------------------------------------------
  // HAPUS
  // ------------------------------------------------------------------

  /// Hapus semua data logbook untuk satu sumber ('real' / 'sim').
  Future<void> clearSource(String source, {DatabaseExecutor? executor}) async {
    Future<void> run(DatabaseExecutor ex) async {
      await ex.rawDelete(
          'DELETE FROM key_events WHERE session_id IN (SELECT id FROM training_sessions WHERE source = ?)',
          [source]);
      await ex.rawDelete(
          'DELETE FROM force_samples WHERE session_id IN (SELECT id FROM training_sessions WHERE source = ?)',
          [source]);
      await ex.rawDelete(
          'DELETE FROM force_samples WHERE grip_test_id IN (SELECT id FROM grip_tests WHERE source = ?)',
          [source]);
      await ex.delete('training_sessions', where: 'source = ?', whereArgs: [source]);
      await ex.delete('grip_tests', where: 'source = ?', whereArgs: [source]);
      await ex.delete('weekly_summary', where: 'source = ?', whereArgs: [source]);
    }

    if (executor != null) {
      await run(executor);
    } else {
      final db = await _db;
      await db.transaction(run);
    }
  }

  /// Hapus semua data logbook (kedua sumber) dan target. Tabel pengukuran lama
  /// `sessions` tidak disentuh.
  Future<void> clearAll() async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final t in [
        'key_events',
        'force_samples',
        'training_sessions',
        'grip_tests',
        'weekly_summary',
        'weekly_target'
      ]) {
        await txn.delete(t);
      }
      await DatabaseHelper.ensureDefaultTarget(txn);
    });
  }
}
