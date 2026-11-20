import 'package:flutter_application_1/logic/indicators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('median', () {
    test('kosong -> null', () => expect(median(<num>[]), isNull));
    test('ganjil', () => expect(median([3, 1, 2]), 2));
    test('genap', () => expect(median([4, 1, 3, 2]), 2.5));
  });

  group('activeDurationMs', () {
    test('sesi kosong (tanpa tekanan) = 0', () {
      expect(activeDurationMs(startMs: 0, endMs: 600000, downTimesMs: []), 0);
    });

    test('satu tekanan: jeda > 10 s di kedua sisi dikurangkan', () {
      // 0 --30 s-- tekan --30 s-- akhir => semua jeda > 10 s => 0
      expect(activeDurationMs(startMs: 0, endMs: 60000, downTimesMs: [30000]), 0);
      // 0 --5 s-- tekan --5 s-- akhir => tidak ada jeda > 10 s => 10 s
      expect(activeDurationMs(startMs: 0, endMs: 10000, downTimesMs: [5000]), 10000);
    });

    test('jeda tepat 10 s TIDAK dikurangkan', () {
      expect(activeDurationMs(startMs: 0, endMs: 20000, downTimesMs: [0, 10000, 20000]), 20000);
    });

    test('jeda 10.001 s dikurangkan', () {
      expect(activeDurationMs(startMs: 0, endMs: 20001, downTimesMs: [0, 10000, 20001]), 10000);
    });

    test('jeda panjang di tengah dikurangkan', () {
      // tekanan tiap 1 s selama 60 s, jeda 40 s, tekanan tiap 1 s selama 60 s
      final downs = [
        for (var i = 0; i <= 60; i++) i * 1000,
        for (var i = 0; i <= 60; i++) 100000 + i * 1000,
      ];
      expect(activeDurationMs(startMs: 0, endMs: 160000, downTimesMs: downs), 120000);
    });

    test('sesi melewati tengah malam dihitung normal', () {
      final start = DateTime(2026, 9, 12, 23, 55).millisecondsSinceEpoch;
      final downs = [for (var i = 0; i < 600; i++) start + 1000 + i * 1000];
      final end = downs.last + 2000;
      expect(activeDurationMs(startMs: start, endMs: end, downTimesMs: downs), end - start);
    });
  });

  group('pressesPerFinger dan sebaran', () {
    test('memakai keymap saat sesi dimulai', () {
      expect(pressesPerFinger(['f', 'g', 'g', 'j', 'x'], 'fghj'), [1, 2, 0, 1]);
      expect(pressesPerFinger(['a', 's', 'f'], 'asdl'), [1, 1, 0, 0]);
    });
    test('huruf besar disamakan', () => expect(pressesPerFinger(['F'], 'fghj'), [1, 0, 0, 0]));
    test('sebaran jari', () {
      expect(fingerDistributionPct([1, 1, 2, 0]), [25.0, 25.0, 50.0, 0.0]);
      expect(fingerDistributionPct([0, 0, 0, 0]), isNull);
    });
    test('jari paling jarang (seri -> indeks terkecil)', () {
      expect(leastUsedFinger([5, 3, 3, 9]), 1);
      expect(leastUsedFinger([0, 0, 0, 0]), isNull);
    });
  });

  group('laju dan jeda antar-tekanan', () {
    test('laju tekanan', () {
      expect(pressRate(120, 4.0), 30.0);
      expect(pressRate(0, 0), isNull);
    });
    test('IPI median', () {
      expect(ipiMedianSeconds([0, 1000, 3000, 4000]), 1.0);
      expect(ipiMedianSeconds([5000]), isNull);
      expect(ipiMedianSeconds([]), isNull);
    });
  });

  group('kepatuhan', () {
    test('tanpa batas atas saat disimpan', () {
      expect(compliancePct(3, 5), 60.0);
      expect(compliancePct(7, 5), 140.0);
      expect(displayCompliance(140.0), 100.0);
      expect(compliancePct(1, 0), isNull);
    });
  });

  group('tes genggam', () {
    test('nilai percobaan = maks genggam - rata-rata istirahat', () {
      expect(gripTrialValue([0.2, 0.4], [1.0, 9.3, 8.0]), closeTo(9.0, 1e-9));
      expect(gripTrialValue([], [5.0]), 5.0);
      expect(gripTrialValue([0.3], []), isNull);
    });
    test('nilai tes = rata-rata 3 percobaan', () {
      expect(gripTestValue([9.0, 10.0, 11.0]), 10.0);
    });
    test('perubahan dari tes pertama', () {
      expect(changeFromFirstPct(11.8, 10.0), closeTo(18.0, 1e-9));
      expect(changeFromFirstPct(5.0, 0.0), isNull);
    });
  });

  group('minggu kalender', () {
    test('Senin sampai Minggu, waktu lokal', () {
      final mon = DateTime(2026, 11, 16);
      expect(weekStartLocal(DateTime(2026, 11, 16, 0, 0)), mon);
      expect(weekStartLocal(DateTime(2026, 11, 22, 23, 59)), mon);
      expect(weekStartLocal(DateTime(2026, 11, 23, 0, 0)), DateTime(2026, 11, 23));
    });
    test('sesi Minggu 23:55 masuk minggu yang sama walau berakhir Senin', () {
      final start = DateTime(2026, 11, 22, 23, 55).millisecondsSinceEpoch;
      expect(weekStartMs(start), DateTime(2026, 11, 16).millisecondsSinceEpoch);
    });
  });
}
