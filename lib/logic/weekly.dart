import 'indicators.dart';

/// Target mingguan yang berlaku untuk minggu yang dimulai [weekStartMs].
///
/// Dipakai target terakhir yang diset sebelum minggu tersebut berakhir. Bila
/// semua target diset sesudahnya, dipakai target paling awal. Bila belum pernah
/// diset, dipakai default 5.
int targetForWeek(List<({int setAtMs, int sessionsPerWeek})> targets, int weekStartMs) {
  if (targets.isEmpty) return kDefaultWeeklyTarget;
  final sorted = [...targets]..sort((a, b) => a.setAtMs.compareTo(b.setAtMs));
  final weekEnd = nextWeekStart(DateTime.fromMillisecondsSinceEpoch(weekStartMs)).millisecondsSinceEpoch;
  int? chosen;
  for (final t in sorted) {
    if (t.setAtMs < weekEnd) chosen = t.sessionsPerWeek;
  }
  return chosen ?? sorted.first.sessionsPerWeek;
}

/// Semua awal minggu dari [fromWeekMs] sampai [toWeekMs] (inklusif).
List<int> weekRange(int fromWeekMs, int toWeekMs) {
  final out = <int>[];
  var w = weekStartLocal(DateTime.fromMillisecondsSinceEpoch(fromWeekMs));
  final end = weekStartLocal(DateTime.fromMillisecondsSinceEpoch(toWeekMs)).millisecondsSinceEpoch;
  while (w.millisecondsSinceEpoch <= end) {
    out.add(w.millisecondsSinceEpoch);
    w = nextWeekStart(w);
  }
  return out;
}
