/// Fungsi murni untuk semua indikator di paper. Tidak ada akses database, UI,
/// atau jam sistem di file ini, supaya bisa diuji dengan unit test.
library;

/// Sesi berakhir setelah 120 s tanpa event keypad.
const int kSessionTimeoutMs = 120000;

/// Jeda antar-tekanan yang LEBIH DARI 10 s dikurangkan dari durasi aktif.
const int kIdleGapMs = 10000;

/// Sesi dihitung untuk kepatuhan bila durasi aktif >= 5 menit.
const double kQualifyingActiveMin = 5.0;

/// Target mingguan default (jumlah sesi).
const int kDefaultWeeklyTarget = 5;

/// Nama jari sesuai urutan keymap (index1..index4 di GloveProvider).
const List<String> kFingerNames = ['Telunjuk', 'Tengah', 'Manis', 'Kelingking'];

/// Median. Mengembalikan null untuk daftar kosong.
double? median(Iterable<num> values) {
  final v = values.map((e) => e.toDouble()).toList()..sort();
  if (v.isEmpty) return null;
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2.0;
}

double? mean(Iterable<num> values) {
  if (values.isEmpty) return null;
  var sum = 0.0;
  for (final x in values) {
    sum += x;
  }
  return sum / values.length;
}

/// Durasi aktif (ms) = durasi sesi dikurangi semua jeda > 10 s.
///
/// Titik waktu yang dipakai: awal sesi, setiap key-down, dan akhir sesi. Jeda dari
/// awal sesi ke tekanan pertama dan dari tekanan terakhir ke akhir sesi ikut
/// dihitung sebagai jeda, supaya layar yang dibiarkan terbuka tanpa latihan tidak
/// dihitung aktif. Sesi tanpa tekanan selalu bernilai 0. Jeda tepat 10 s tidak
/// dikurangkan ("lebih dari 10 s").
int activeDurationMs({
  required int startMs,
  required int endMs,
  required List<int> downTimesMs,
  int idleGapMs = kIdleGapMs,
}) {
  if (downTimesMs.isEmpty || endMs <= startMs) return 0;
  final pts = <int>[
    startMs,
    ...(downTimesMs.map((t) => t < startMs ? startMs : (t > endMs ? endMs : t)).toList()
      ..sort()),
    endMs,
  ];
  var active = endMs - startMs;
  for (var i = 1; i < pts.length; i++) {
    final gap = pts[i] - pts[i - 1];
    if (gap > idleGapMs) active -= gap;
  }
  return active < 0 ? 0 : active;
}

/// Jumlah key-down per jari berdasarkan keymap saat sesi dimulai.
/// [keymap] berisi 4 karakter: telunjuk, tengah, manis, kelingking.
/// Karakter yang tidak ada di keymap tidak dihitung.
List<int> pressesPerFinger(Iterable<String> downChars, String keymap) {
  final counts = [0, 0, 0, 0];
  final map = keymap.toLowerCase();
  for (final c in downChars) {
    if (c.isEmpty) continue;
    final i = map.indexOf(c.toLowerCase());
    if (i >= 0 && i < 4) counts[i]++;
  }
  return counts;
}

/// Laju tekanan (tekanan/menit). Null bila durasi aktif 0.
double? pressRate(int totalPresses, double activeMin) =>
    activeMin > 0 ? totalPresses / activeMin : null;

/// Median selisih waktu (detik) antar key-down berurutan. Null bila < 2 tekanan.
double? ipiMedianSeconds(List<int> downTimesMs) {
  if (downTimesMs.length < 2) return null;
  final t = [...downTimesMs]..sort();
  return median([for (var i = 1; i < t.length; i++) (t[i] - t[i - 1]) / 1000.0]);
}

/// Indeks jari dengan tekanan paling sedikit (seri: indeks terkecil).
/// Null bila tidak ada tekanan.
int? leastUsedFinger(List<int> perFinger) {
  final total = perFinger.fold<int>(0, (a, b) => a + b);
  if (total == 0) return null;
  var best = 0;
  for (var i = 1; i < perFinger.length; i++) {
    if (perFinger[i] < perFinger[best]) best = i;
  }
  return best;
}

/// Sebaran jari (%) = tekanan satu jari / total tekanan x 100. Null bila total 0.
List<double>? fingerDistributionPct(List<int> perFinger) {
  final total = perFinger.fold<int>(0, (a, b) => a + b);
  if (total == 0) return null;
  return [for (final c in perFinger) c / total * 100.0];
}

/// Kepatuhan (%) tanpa batas atas. Tampilan membatasi ke 100% lewat [displayCompliance].
double? compliancePct(int qualifyingSessions, int weeklyTarget) =>
    weeklyTarget > 0 ? qualifyingSessions / weeklyTarget * 100.0 : null;

double displayCompliance(double pct) => pct > 100 ? 100 : pct;

/// Nilai satu percobaan genggam (kg*) = sampel maksimum di jendela genggam
/// dikurangi rata-rata sampel saat istirahat. Null bila tidak ada sampel genggam.
double? gripTrialValue(List<double> restKg, List<double> gripKg) {
  if (gripKg.isEmpty) return null;
  final peak = gripKg.reduce((a, b) => a > b ? a : b);
  return peak - (mean(restKg) ?? 0.0);
}

/// Nilai tes genggam = rata-rata 3 nilai percobaan.
double? gripTestValue(List<double> trials) => mean(trials);

/// Perubahan dari tes pertama (%), per tangan. Null bila nilai tes pertama <= 0.
double? changeFromFirstPct(double current, double first) =>
    first > 0 ? (current - first) / first * 100.0 : null;

/// Awal minggu kalender (Senin 00:00 waktu lokal) untuk waktu [t].
DateTime weekStartLocal(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day - (local.weekday - DateTime.monday));
}

int weekStartMs(int tMs) =>
    weekStartLocal(DateTime.fromMillisecondsSinceEpoch(tMs)).millisecondsSinceEpoch;

/// Awal minggu berikutnya (aman terhadap DST karena memakai kalender, bukan +7x24 jam).
DateTime nextWeekStart(DateTime weekStart) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
