import '../logic/indicators.dart';
import '../models/training_models.dart';
import 'training_repository.dart';

/// Isi ringkasan terapis untuk satu periode. Semua angka berasal dari nilai
/// tersimpan (sesi, ringkasan mingguan, tes genggam); di sini hanya dijumlah
/// atau dipilih per periode.
class TherapistSummary {
  final String scope;
  final DateTime from; // Senin pertama
  final DateTime to; // Senin setelah minggu terakhir (eksklusif)
  final List<WeeklySummaryRow> weeks;
  final List<TrainingSessionRow> sessions; // urut naik
  final List<GripTestRow> grips; // dalam periode, urut naik
  final List<GripTestRow> allGrips;

  TherapistSummary({
    required this.scope,
    required this.from,
    required this.to,
    required this.weeks,
    required this.sessions,
    required this.grips,
    required this.allGrips,
  });

  int get qualifyingTotal => weeks.fold(0, (a, w) => a + w.qualifyingCount);
  int get targetTotal => weeks.fold(0, (a, w) => a + w.target);
  int get sessionsTotal => sessions.length;
  double get activeMinTotal => sessions.fold(0.0, (a, s) => a + s.activeMin);

  /// Kepatuhan periode = sesi memenuhi syarat / jumlah target mingguan x 100.
  double? get periodCompliancePct => compliancePct(qualifyingTotal, targetTotal);

  List<int> get pressesTotal {
    final out = [0, 0, 0, 0];
    for (final w in weeks) {
      for (var i = 0; i < 4; i++) {
        out[i] += w.presses[i];
      }
    }
    return out;
  }

  int get disconnectsTotal => sessions.fold(0, (a, s) => a + s.bleDisconnects);
  int get sessionsWithDisconnect => sessions.where((s) => s.bleDisconnects > 0).length;
  int get emptySessions => sessions.where((s) => s.totalPresses == 0).length;
  int get shortSessions => sessions.where((s) => !s.qualifiesForTarget && s.totalPresses > 0).length;

  GripTestRow? latest(String hand) {
    final l = grips.where((g) => g.hand == hand).toList();
    return l.isEmpty ? null : l.last;
  }

  GripTestRow? first(String hand) {
    final l = allGrips.where((g) => g.hand == hand).toList();
    return l.isEmpty ? null : l.first;
  }

  static Future<TherapistSummary> load(String scope, int periodWeeks) async {
    final repo = TrainingRepository.instance;
    final ref = DateTime.fromMillisecondsSinceEpoch(await repo.referenceNowMs(scope));
    final lastWeek = weekStartLocal(ref);
    final from = DateTime(lastWeek.year, lastWeek.month, lastWeek.day - 7 * (periodWeeks - 1));
    final to = nextWeekStart(lastWeek);
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    final weeks = (await repo.weeklySummaries(scope, fromWeekMs: fromMs))
        .where((w) => w.weekStartMs < toMs)
        .toList();
    final sessions = (await repo.sessions(scope, fromMs: fromMs, toMs: toMs)).reversed.toList();
    final allGrips = await repo.gripTests(scope);
    final grips = allGrips.where((g) => g.tMs >= fromMs && g.tMs < toMs).toList();
    return TherapistSummary(
      scope: scope,
      from: from,
      to: to,
      weeks: weeks,
      sessions: sessions,
      grips: grips,
      allGrips: allGrips,
    );
  }
}

const String kNotClinicalDisclaimer = 'Indikator ini untuk pemantauan latihan, bukan penilaian klinis';
