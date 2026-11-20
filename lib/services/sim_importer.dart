import 'package:flutter/foundation.dart';

import '../data/sim_profile.dart';
import '../logic/session_machine.dart';
import '../logic/sim_replay.dart';
import '../models/training_models.dart';
import 'database_helper.dart';
import 'training_repository.dart';

class ImportResult {
  final int sessions;
  final int gripTests;
  final Duration elapsed;
  const ImportResult(this.sessions, this.gripTests, this.elapsed);
}

/// Impor seluruh profil simulasi seketika. Data simulasi lama (source = 'sim')
/// dihapus dulu; data glove nyata tidak disentuh.
class SimImporter {
  static Future<ImportResult> importProfile(SimProfile p,
      {void Function(double progress)? onProgress}) async {
    final sw = Stopwatch()..start();
    final repo = TrainingRepository.instance;
    final db = await DatabaseHelper.instance.database;
    var nSessions = 0;
    await db.transaction((txn) async {
      await repo.clearSource('sim', executor: txn);
      final total = p.sessions.length + p.gripTests.length;
      var done = 0;
      int? earliest;
      for (final s in p.sessions) {
        for (final raw in replaySimSession(s)) {
          final ind = computeSessionIndicators(raw);
          await repo.insertSession(txn, raw, ind, source: 'sim', profileId: p.profileId);
          nSessions++;
          if (earliest == null || raw.startMs < earliest) earliest = raw.startMs;
        }
        onProgress?.call(++done / total);
      }
      final tests = [...p.gripTests]..sort((a, b) => a.tMs.compareTo(b.tMs));
      for (final g in tests) {
        await repo.saveGripTest(
          hand: g.hand,
          tMs: g.tMs,
          trials: [
            for (final t in g.trials)
              GripTrialRaw(
                rest: [for (final f in t.rest) (tMs: f.tMs, kg: f.raw / 1000.0)],
                grip: [for (final f in t.grip) (tMs: f.tMs, kg: f.raw / 1000.0)],
              )
          ],
          source: 'sim',
          profileId: p.profileId,
          executor: txn,
        );
        onProgress?.call(++done / total);
      }
      if (earliest != null) await repo.refreshWeeks(txn, 'sim', fromMs: earliest);
    });
    sw.stop();
    debugPrint('[SimImporter] profil ${p.profileId}: $nSessions sesi, '
        '${p.gripTests.length} tes, ${sw.elapsedMilliseconds} ms');
    return ImportResult(nSessions, p.gripTests.length, sw.elapsed);
  }
}
